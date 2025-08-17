require 'concurrent-ruby'
require 'digest'
require 'lz4-ruby'
require 'msgpack'

class UltraFastCache
  include Singleton
  
  def initialize
    # Cache en mémoire ultra-rapide avec partitioning
    @cache_partitions = Array.new(16) { Concurrent::Map.new }
    @message_buffer = Concurrent::Array.new
    @user_sessions = Concurrent::Map.new
    @room_states = Concurrent::Map.new
    
    # Statistiques de performance
    @stats = Concurrent::Map.new
    @stats[:hits] = Concurrent::AtomicFixnum.new(0)
    @stats[:misses] = Concurrent::AtomicFixnum.new(0)
    @stats[:writes] = Concurrent::AtomicFixnum.new(0)
    
    # Configuration optimisée
    @max_message_buffer = 10000
    @max_cache_size_per_partition = 1000
    @compression_threshold = 200
    
    # Démarrer les tâches de maintenance
    start_maintenance_tasks
  end
  
  # Cache ultra-rapide avec partitioning
  def get(key)
    partition = get_partition(key)
    value = partition[key]
    
    if value
      @stats[:hits].increment
      # Vérifier l'expiration
      if value[:expires_at] && Time.now.to_f > value[:expires_at]
        partition.delete(key)
        @stats[:misses].increment
        return nil
      end
      decompress_value(value[:data])
    else
      @stats[:misses].increment
      nil
    end
  end
  
  def set(key, value, ttl = 3600)
    partition = get_partition(key)
    
    # Éviction LRU si la partition est pleine
    if partition.size >= @max_cache_size_per_partition
      evict_lru_from_partition(partition)
    end
    
    expires_at = ttl > 0 ? Time.now.to_f + ttl : nil
    compressed_value = compress_value(value)
    
    partition[key] = {
      data: compressed_value,
      expires_at: expires_at,
      accessed_at: Time.now.to_f
    }
    
    @stats[:writes].increment
    true
  end
  
  def delete(key)
    partition = get_partition(key)
    partition.delete(key)
  end
  
  # Buffer de messages ultra-rapide pour broadcasting
  def buffer_message(room_name, message, sender, timestamp = Time.now.to_f)
    message_data = {
      room: room_name,
      message: message,
      sender: sender,
      timestamp: timestamp,
      id: generate_message_id
    }
    
    @message_buffer << message_data
    
    # Éviction automatique si le buffer est plein
    if @message_buffer.size > @max_message_buffer
      @message_buffer.shift(1000) # Supprimer les 1000 plus anciens
    end
    
    message_data[:id]
  end
  
  def get_recent_messages(room_name, limit = 50)
    @message_buffer.select { |msg| msg[:room] == room_name }
                   .last(limit)
  end
  
  # Gestion des sessions utilisateur ultra-rapide
  def set_user_session(username, session_data)
    @user_sessions[username] = {
      data: session_data,
      last_activity: Time.now.to_f,
      message_count: 0
    }
  end
  
  def get_user_session(username)
    session = @user_sessions[username]
    if session
      session[:last_activity] = Time.now.to_f
      session[:data]
    else
      nil
    end
  end
  
  def increment_user_activity(username)
    session = @user_sessions[username]
    if session
      session[:message_count] += 1
      session[:last_activity] = Time.now.to_f
    end
  end
  
  # État des salons en temps réel
  def update_room_state(room_name, state_data)
    @room_states[room_name] = {
      data: state_data,
      updated_at: Time.now.to_f,
      version: (@room_states[room_name]&.dig(:version) || 0) + 1
    }
  end
  
  def get_room_state(room_name)
    state = @room_states[room_name]
    state ? state[:data] : nil
  end
  
  def get_room_version(room_name)
    state = @room_states[room_name]
    state ? state[:version] : 0
  end
  
  # Préchargement intelligent basé sur les patterns d'usage
  def preload_hot_data
    # Précharger les salons les plus actifs
    active_rooms = get_active_rooms
    active_rooms.each do |room_name|
      preload_room_data(room_name)
    end
    
    # Précharger les utilisateurs les plus actifs
    active_users = get_active_users
    active_users.each do |username|
      preload_user_data(username)
    end
  end
  
  # Compression ultra-rapide avec LZ4
  def compress_value(value)
    serialized = MessagePack.pack(value)
    
    if serialized.bytesize > @compression_threshold
      compressed = LZ4.compress(serialized)
      { compressed: true, data: compressed }
    else
      { compressed: false, data: serialized }
    end
  end
  
  def decompress_value(value_data)
    if value_data[:compressed]
      decompressed = LZ4.decompress(value_data[:data])
      MessagePack.unpack(decompressed)
    else
      MessagePack.unpack(value_data[:data])
    end
  end
  
  # Statistiques de performance en temps réel
  def get_stats
    total_requests = @stats[:hits].value + @stats[:misses].value
    hit_rate = total_requests > 0 ? (@stats[:hits].value.to_f / total_requests * 100).round(2) : 0
    
    {
      hits: @stats[:hits].value,
      misses: @stats[:misses].value,
      writes: @stats[:writes].value,
      hit_rate: "#{hit_rate}%",
      total_cache_size: @cache_partitions.sum(&:size),
      message_buffer_size: @message_buffer.size,
      active_sessions: @user_sessions.size,
      room_states: @room_states.size,
      memory_usage: get_memory_usage
    }
  end
  
  # Nettoyage ultra-rapide
  def cleanup_expired
    current_time = Time.now.to_f
    cleaned_count = 0
    
    @cache_partitions.each do |partition|
      partition.each do |key, value|
        if value[:expires_at] && current_time > value[:expires_at]
          partition.delete(key)
          cleaned_count += 1
        end
      end
    end
    
    # Nettoyer les sessions inactives (plus de 1 heure)
    @user_sessions.each do |username, session|
      if current_time - session[:last_activity] > 3600
        @user_sessions.delete(username)
        cleaned_count += 1
      end
    end
    
    cleaned_count
  end
  
  # Optimisation de la mémoire
  def optimize_memory
    # Compacter les partitions
    @cache_partitions.each(&:compact)
    
    # Réduire le buffer de messages si nécessaire
    if @message_buffer.size > @max_message_buffer * 0.8
      @message_buffer.shift(@message_buffer.size - @max_message_buffer)
    end
    
    # Forcer le garbage collection
    GC.start
  end
  
  private
  
  def get_partition(key)
    hash = Digest::MD5.hexdigest(key.to_s)
    partition_index = hash[0, 2].to_i(16) % @cache_partitions.size
    @cache_partitions[partition_index]
  end
  
  def evict_lru_from_partition(partition)
    # Trouver l'entrée la moins récemment utilisée
    oldest_key = nil
    oldest_time = Float::INFINITY
    
    partition.each do |key, value|
      if value[:accessed_at] < oldest_time
        oldest_time = value[:accessed_at]
        oldest_key = key
      end
    end
    
    partition.delete(oldest_key) if oldest_key
  end
  
  def generate_message_id
    "#{Time.now.to_f}_#{SecureRandom.hex(4)}"
  end
  
  def get_active_rooms
    room_activity = Hash.new(0)
    
    @message_buffer.each do |msg|
      room_activity[msg[:room]] += 1
    end
    
    room_activity.sort_by { |_, count| -count }.first(10).map(&:first)
  end
  
  def get_active_users
    @user_sessions.select { |_, session| Time.now.to_f - session[:last_activity] < 300 }
                  .sort_by { |_, session| -session[:message_count] }
                  .first(20)
                  .map(&:first)
  end
  
  def preload_room_data(room_name)
    # Précharger les données de salon si pas déjà en cache
    cache_key = "room:#{room_name}"
    unless get(cache_key)
      # Simuler le chargement des données de salon
      room_data = { name: room_name, preloaded: true, timestamp: Time.now.to_f }
      set(cache_key, room_data, 1800)
    end
  end
  
  def preload_user_data(username)
    # Précharger les données utilisateur si pas déjà en cache
    cache_key = "user:#{username}"
    unless get(cache_key)
      # Simuler le chargement des données utilisateur
      user_data = { username: username, preloaded: true, timestamp: Time.now.to_f }
      set(cache_key, user_data, 1800)
    end
  end
  
  def get_memory_usage
    # Estimation approximative de l'usage mémoire
    total_size = 0
    
    @cache_partitions.each do |partition|
      total_size += partition.size * 200 # Estimation moyenne par entrée
    end
    
    total_size += @message_buffer.size * 150
    total_size += @user_sessions.size * 100
    total_size += @room_states.size * 300
    
    "#{(total_size / 1024.0 / 1024.0).round(2)} MB"
  end
  
  def start_maintenance_tasks
    # Tâche de nettoyage toutes les 5 minutes
    Thread.new do
      loop do
        sleep 300
        cleanup_expired
      end
    end
    
    # Tâche d'optimisation mémoire toutes les 15 minutes
    Thread.new do
      loop do
        sleep 900
        optimize_memory
      end
    end
    
    # Tâche de préchargement toutes les 10 minutes
    Thread.new do
      loop do
        sleep 600
        preload_hot_data
      end
    end
  end
end