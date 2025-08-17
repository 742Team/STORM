require 'redis'
require 'connection_pool'
require 'concurrent-ruby'
require 'zlib'
require 'json'
require 'digest'

class PerformanceOptimizer
  include Singleton
  
  def initialize
    @redis_pool = ConnectionPool.new(size: 50, timeout: 5) { Redis.new(host: 'localhost', port: 6379, db: 0) }
    @thread_pool = Concurrent::ThreadPoolExecutor.new(
      min_threads: 5,
      max_threads: 50,
      max_queue: 1000,
      fallback_policy: :caller_runs
    )
    @message_cache = Concurrent::Map.new
    @user_cache = Concurrent::Map.new
    @room_cache = Concurrent::Map.new
    @compression_enabled = true
    @batch_size = 100
    @cache_ttl = 3600 # 1 hour
  end
  
  # Cache Redis ultra-rapide
  def cache_get(key)
    @redis_pool.with do |redis|
      data = redis.get(key)
      data ? decompress_data(data) : nil
    end
  rescue => e
    puts "Cache get error: #{e.message}"
    nil
  end
  
  def cache_set(key, value, ttl = @cache_ttl)
    @redis_pool.with do |redis|
      compressed_data = compress_data(value)
      redis.setex(key, ttl, compressed_data)
    end
  rescue => e
    puts "Cache set error: #{e.message}"
  end
  
  def cache_delete(key)
    @redis_pool.with do |redis|
      redis.del(key)
    end
  rescue => e
    puts "Cache delete error: #{e.message}"
  end
  
  # Traitement asynchrone des messages
  def async_broadcast(room, message, sender, exclude_user = nil)
    @thread_pool.post do
      begin
        compressed_message = compress_message(message, sender)
        
        # Batch processing pour les gros salons
        clients = room.clients.reject { |username, _| username == exclude_user }
        
        if clients.size > @batch_size
          clients.each_slice(@batch_size) do |batch|
            @thread_pool.post do
              batch.each do |username, driver|
                send_message_safe(driver, compressed_message)
              end
            end
          end
        else
          clients.each do |username, driver|
            send_message_safe(driver, compressed_message)
          end
        end
        
        # Cache du message pour l'historique
        cache_message(room.name, message, sender)
      rescue => e
        puts "Async broadcast error: #{e.message}"
      end
    end
  end
  
  # Optimisation des requêtes utilisateur
  def get_user_fast(username)
    cache_key = "user:#{username}"
    cached_user = @user_cache[cache_key]
    
    return cached_user if cached_user && (Time.now - cached_user[:cached_at]) < 300
    
    # Si pas en cache, récupérer de Redis puis DB
    user_data = cache_get(cache_key)
    unless user_data
      user_data = fetch_user_from_db(username)
      cache_set(cache_key, user_data, 1800) if user_data
    end
    
    @user_cache[cache_key] = { data: user_data, cached_at: Time.now } if user_data
    user_data
  end
  
  # Optimisation des salons
  def get_room_fast(room_name)
    cache_key = "room:#{room_name}"
    cached_room = @room_cache[cache_key]
    
    return cached_room if cached_room && (Time.now - cached_room[:cached_at]) < 60
    
    room_data = cache_get(cache_key)
    unless room_data
      room_data = fetch_room_from_db(room_name)
      cache_set(cache_key, room_data, 600) if room_data
    end
    
    @room_cache[cache_key] = { data: room_data, cached_at: Time.now } if room_data
    room_data
  end
  
  # Compression intelligente
  def compress_data(data)
    return data unless @compression_enabled
    
    json_data = data.is_a?(String) ? data : JSON.generate(data)
    return json_data if json_data.length < 100 # Pas de compression pour les petites données
    
    compressed = Zlib::Deflate.deflate(json_data)
    Base64.encode64(compressed)
  end
  
  def decompress_data(compressed_data)
    return compressed_data unless @compression_enabled
    
    begin
      decoded = Base64.decode64(compressed_data)
      decompressed = Zlib::Inflate.inflate(decoded)
      JSON.parse(decompressed)
    rescue
      compressed_data # Fallback si ce n'est pas compressé
    end
  end
  
  # Pool de connexions DB optimisé
  def with_db_connection(&block)
    require_relative '../config/database_config'
    @db_pool ||= ConnectionPool.new(size: 25, timeout: 5) do
      DatabaseConfig.get_connection
    end
    
    @db_pool.with(&block)
  end
  
  # Batch operations pour les mises à jour
  def batch_update_users(updates)
    return if updates.empty?
    
    @thread_pool.post do
      with_db_connection do |db|
        db.transaction do
          updates.each do |update|
            db.execute(update[:query], update[:params])
          end
        end
      end
    end
  end
  
  # Préchargement intelligent
  def preload_popular_rooms
    @thread_pool.post do
      popular_rooms = ['Main', 'General', 'users']
      popular_rooms.each do |room_name|
        get_room_fast(room_name)
      end
    end
  end
  
  # Nettoyage automatique du cache
  def cleanup_cache
    @thread_pool.post do
      current_time = Time.now
      
      # Nettoyer le cache local
      [@user_cache, @room_cache, @message_cache].each do |cache|
        cache.each do |key, value|
          if current_time - value[:cached_at] > 3600
            cache.delete(key)
          end
        end
      end
      
      # Nettoyer Redis (expire automatiquement avec TTL)
      puts "Cache cleanup completed at #{current_time}"
    end
  end
  
  # Métriques de performance
  def get_performance_stats
    {
      thread_pool_size: @thread_pool.length,
      thread_pool_queue: @thread_pool.queue_length,
      local_cache_size: @user_cache.size + @room_cache.size + @message_cache.size,
      redis_connections: @redis_pool.size,
      db_connections: @db_pool&.size || 0
    }
  end
  
  private
  
  def compress_message(message, sender)
    timestamp = (Time.now + 3600).strftime('%H:%M')
    "[#{timestamp}] #{sender}: #{message}"
  end
  
  def send_message_safe(driver, message)
    driver.text(message)
  rescue IOError, Errno::EPIPE => e
    puts "Failed to send message to client: #{e.message}"
  rescue => e
    puts "Unexpected error sending message: #{e.message}"
  end
  
  def cache_message(room_name, message, sender)
    cache_key = "messages:#{room_name}"
    messages = cache_get(cache_key) || []
    messages << { message: message, sender: sender, timestamp: Time.now.to_i }
    messages = messages.last(1000) # Garder seulement les 1000 derniers messages
    cache_set(cache_key, messages, 7200) # 2 heures
  end
  
  def fetch_user_from_db(username)
    with_db_connection do |db|
      result = db.execute('SELECT * FROM users WHERE username = ? LIMIT 1', [username])
      result.first
    end
  rescue => e
    puts "DB fetch user error: #{e.message}"
    nil
  end
  
  def fetch_room_from_db(room_name)
    with_db_connection do |db|
      result = db.execute('SELECT * FROM rooms WHERE name = ? LIMIT 1', [room_name])
      result.first
    end
  rescue => e
    puts "DB fetch room error: #{e.message}"
    nil
  end
end

# Auto-démarrage du nettoyage
Thread.new do
  loop do
    sleep 1800 # 30 minutes
    PerformanceOptimizer.instance.cleanup_cache
  end
end