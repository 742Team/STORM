# Gestionnaire de connexions ultra-optimisé pour STORM
# Capable de gérer des millions de connexions WebSocket simultanées

require 'set'
require 'thread'
require 'monitor'
require 'digest/sha1'

module STORM
  class ConnectionManager
    include MonitorMixin
    
    # Pool de connexions optimisé
    class ConnectionPool
      def initialize(max_size = 50_000)
        @max_size = max_size
        @connections = {}
        @active_count = 0
        @mutex = Mutex.new
        @last_cleanup = Time.now
      end
      
      def add_connection(id, connection)
        @mutex.synchronize do
          return false if @active_count >= @max_size
          
          @connections[id] = {
            connection: connection,
            created_at: Time.now,
            last_activity: Time.now,
            message_count: 0,
            bytes_sent: 0,
            bytes_received: 0,
            compression_enabled: false
          }
          @active_count += 1
          true
        end
      end
      
      def remove_connection(id)
        @mutex.synchronize do
          if @connections.delete(id)
            @active_count -= 1
            true
          else
            false
          end
        end
      end
      
      def get_connection(id)
        @mutex.synchronize do
          conn_data = @connections[id]
          if conn_data
            conn_data[:last_activity] = Time.now
            conn_data
          end
        end
      end
      
      def update_activity(id, bytes_sent = 0, bytes_received = 0)
        @mutex.synchronize do
          conn_data = @connections[id]
          if conn_data
            conn_data[:last_activity] = Time.now
            conn_data[:message_count] += 1
            conn_data[:bytes_sent] += bytes_sent
            conn_data[:bytes_received] += bytes_received
          end
        end
      end
      
      def cleanup_inactive(timeout = 300)
        return unless Time.now - @last_cleanup > 60 # Nettoyage max 1x par minute
        
        inactive_ids = []
        cutoff_time = Time.now - timeout
        
        @mutex.synchronize do
          @connections.each do |id, data|
            if data[:last_activity] < cutoff_time
              inactive_ids << id
            end
          end
          
          inactive_ids.each do |id|
            @connections.delete(id)
            @active_count -= 1
          end
          
          @last_cleanup = Time.now
        end
        
        inactive_ids.size
      end
      
      def stats
        @mutex.synchronize do
          {
            total_connections: @active_count,
            max_connections: @max_size,
            utilization: (@active_count.to_f / @max_size * 100).round(2),
            oldest_connection: @connections.values.map { |c| c[:created_at] }.min,
            total_messages: @connections.values.sum { |c| c[:message_count] },
            total_bytes_sent: @connections.values.sum { |c| c[:bytes_sent] },
            total_bytes_received: @connections.values.sum { |c| c[:bytes_received] }
          }
        end
      end
    end
    
    # Gestionnaire de sessions avec sharding
    class SessionManager
      def initialize(shard_count = 16)
        @shard_count = shard_count
        @shards = Array.new(shard_count) { { sessions: {}, mutex: Mutex.new } }
      end
      
      def create_session(connection_id, metadata = {})
        shard = get_shard(connection_id)
        session_id = generate_session_id
        
        shard[:mutex].synchronize do
          shard[:sessions][session_id] = {
            connection_id: connection_id,
            created_at: Time.now,
            last_activity: Time.now,
            metadata: metadata,
            message_queue: [],
            subscriptions: Set.new
          }
        end
        
        session_id
      end
      
      def get_session(session_id)
        shard = get_shard(session_id)
        shard[:mutex].synchronize do
          session = shard[:sessions][session_id]
          session[:last_activity] = Time.now if session
          session
        end
      end
      
      def update_session(session_id, updates)
        shard = get_shard(session_id)
        shard[:mutex].synchronize do
          session = shard[:sessions][session_id]
          if session
            session.merge!(updates)
            session[:last_activity] = Time.now
            true
          else
            false
          end
        end
      end
      
      def remove_session(session_id)
        shard = get_shard(session_id)
        shard[:mutex].synchronize do
          shard[:sessions].delete(session_id)
        end
      end
      
      def add_subscription(session_id, channel)
        shard = get_shard(session_id)
        shard[:mutex].synchronize do
          session = shard[:sessions][session_id]
          session[:subscriptions].add(channel) if session
        end
      end
      
      def remove_subscription(session_id, channel)
        shard = get_shard(session_id)
        shard[:mutex].synchronize do
          session = shard[:sessions][session_id]
          session[:subscriptions].delete(channel) if session
        end
      end
      
      def get_sessions_by_channel(channel)
        sessions = []
        @shards.each do |shard|
          shard[:mutex].synchronize do
            shard[:sessions].each do |session_id, session|
              sessions << session_id if session[:subscriptions].include?(channel)
            end
          end
        end
        sessions
      end
      
      def cleanup_expired(timeout = 3600)
        cutoff_time = Time.now - timeout
        expired_count = 0
        
        @shards.each do |shard|
          shard[:mutex].synchronize do
            expired_sessions = shard[:sessions].select do |_, session|
              session[:last_activity] < cutoff_time
            end
            
            expired_sessions.each do |session_id, _|
              shard[:sessions].delete(session_id)
              expired_count += 1
            end
          end
        end
        
        expired_count
      end
      
      def stats
        total_sessions = 0
        total_subscriptions = 0
        
        @shards.each do |shard|
          shard[:mutex].synchronize do
            total_sessions += shard[:sessions].size
            total_subscriptions += shard[:sessions].values.sum { |s| s[:subscriptions].size }
          end
        end
        
        {
          total_sessions: total_sessions,
          total_subscriptions: total_subscriptions,
          average_subscriptions_per_session: total_sessions > 0 ? (total_subscriptions.to_f / total_sessions).round(2) : 0,
          shard_count: @shard_count
        }
      end
      
      private
      
      def get_shard(id)
        shard_index = Digest::SHA1.hexdigest(id.to_s).to_i(16) % @shard_count
        @shards[shard_index]
      end
      
      def generate_session_id
        "session_#{Time.now.to_f}_#{rand(1000000)}"
      end
    end
    
    # Rate limiter ultra-rapide
    class RateLimiter
      def initialize(max_requests = 1000, window_seconds = 60)
        @max_requests = max_requests
        @window_seconds = window_seconds
        @buckets = {}
        @mutex = Mutex.new
        @last_cleanup = Time.now
      end
      
      def allow?(identifier)
        now = Time.now.to_i
        window_start = now - @window_seconds
        
        @mutex.synchronize do
          # Nettoyage périodique
          cleanup_old_buckets if now - @last_cleanup.to_i > 60
          
          bucket = @buckets[identifier] ||= []
          
          # Supprimer les requêtes anciennes
          bucket.reject! { |timestamp| timestamp < window_start }
          
          if bucket.size < @max_requests
            bucket << now
            true
          else
            false
          end
        end
      end
      
      def get_remaining(identifier)
        now = Time.now.to_i
        window_start = now - @window_seconds
        
        @mutex.synchronize do
          bucket = @buckets[identifier] || []
          bucket.reject! { |timestamp| timestamp < window_start }
          [@max_requests - bucket.size, 0].max
        end
      end
      
      def reset(identifier)
        @mutex.synchronize do
          @buckets.delete(identifier)
        end
      end
      
      private
      
      def cleanup_old_buckets
        cutoff_time = Time.now.to_i - @window_seconds * 2
        
        @buckets.each do |identifier, bucket|
          bucket.reject! { |timestamp| timestamp < cutoff_time }
          @buckets.delete(identifier) if bucket.empty?
        end
        
        @last_cleanup = Time.now
      end
    end
    
    def initialize(options = {})
      super()
      
      @max_connections = options[:max_connections] || 1_000_000
      @max_connections_per_worker = options[:max_connections_per_worker] || 50_000
      @connection_timeout = options[:connection_timeout] || 300
      @rate_limit = options[:rate_limit] || 1000
      @rate_window = options[:rate_window] || 60
      
      # Pools de connexions par worker
      @connection_pools = {}
      @session_manager = SessionManager.new
      @rate_limiter = RateLimiter.new(@rate_limit, @rate_window)
      
      # Statistiques globales
      @global_stats = {
        total_connections: 0,
        total_messages: 0,
        total_bytes: 0,
        start_time: Time.now,
        errors: 0
      }
      
      # Thread de nettoyage
      start_cleanup_thread
      
      puts "⚪️ ConnectionManager initialisé (max: #{@max_connections} connexions)"
    end
    
    def add_connection(worker_id, connection_id, connection, metadata = {})
      synchronize do
        # Créer le pool pour ce worker si nécessaire
        @connection_pools[worker_id] ||= ConnectionPool.new(@max_connections_per_worker)
        
        pool = @connection_pools[worker_id]
        
        if pool.add_connection(connection_id, connection)
          # Créer une session
          session_id = @session_manager.create_session(connection_id, metadata)
          
          @global_stats[:total_connections] += 1
          
          puts "⚪️ Connexion ajoutée: #{connection_id} (worker: #{worker_id}, session: #{session_id})"
          { success: true, session_id: session_id }
        else
          puts "⚫️ Pool worker #{worker_id} plein (#{@max_connections_per_worker} connexions)"
          { success: false, error: 'Worker pool full' }
        end
      end
    end
    
    def remove_connection(worker_id, connection_id)
      synchronize do
        pool = @connection_pools[worker_id]
        return false unless pool
        
        if pool.remove_connection(connection_id)
          # Supprimer la session associée
          session = @session_manager.get_session(connection_id)
          @session_manager.remove_session(session[:session_id]) if session
          
          @global_stats[:total_connections] -= 1
          
          puts "⚪️ Connexion supprimée: #{connection_id} (worker: #{worker_id})"
          true
        else
          false
        end
      end
    end
    
    def get_connection(worker_id, connection_id)
      synchronize do
        pool = @connection_pools[worker_id]
        pool&.get_connection(connection_id)
      end
    end
    
    def update_connection_activity(worker_id, connection_id, bytes_sent = 0, bytes_received = 0)
      synchronize do
        pool = @connection_pools[worker_id]
        if pool
          pool.update_activity(connection_id, bytes_sent, bytes_received)
          @global_stats[:total_messages] += 1
          @global_stats[:total_bytes] += bytes_sent + bytes_received
        end
      end
    end
    
    def check_rate_limit(identifier)
      @rate_limiter.allow?(identifier)
    end
    
    def get_rate_limit_remaining(identifier)
      @rate_limiter.get_remaining(identifier)
    end
    
    def broadcast_to_channel(channel, message)
      session_ids = @session_manager.get_sessions_by_channel(channel)
      sent_count = 0
      
      session_ids.each do |session_id|
        session = @session_manager.get_session(session_id)
        next unless session
        
        # Trouver la connexion et envoyer le message
        @connection_pools.each do |worker_id, pool|
          conn_data = pool.get_connection(session[:connection_id])
          if conn_data
            begin
              conn_data[:connection].send(message)
              sent_count += 1
            rescue => e
              puts "⚫️ Erreur broadcast: #{e.message}"
              @global_stats[:errors] += 1
            end
            break
          end
        end
      end
      
      sent_count
    end
    
    def get_comprehensive_stats
      synchronize do
        pool_stats = @connection_pools.map do |worker_id, pool|
          [worker_id, pool.stats]
        end.to_h
        
        session_stats = @session_manager.stats
        
        uptime = Time.now - @global_stats[:start_time]
        
        {
          global: @global_stats.merge({
            uptime_seconds: uptime.to_i,
            messages_per_second: uptime > 0 ? (@global_stats[:total_messages] / uptime).round(2) : 0,
            bytes_per_second: uptime > 0 ? (@global_stats[:total_bytes] / uptime).round(2) : 0
          }),
          pools: pool_stats,
          sessions: session_stats,
          rate_limiting: {
            max_requests_per_window: @rate_limit,
            window_seconds: @rate_window
          },
          memory: {
            connection_pools: @connection_pools.size,
            total_pool_capacity: @connection_pools.size * @max_connections_per_worker
          }
        }
      end
    end
    
    def cleanup_inactive_connections
      cleaned_count = 0
      
      synchronize do
        @connection_pools.each do |worker_id, pool|
          cleaned = pool.cleanup_inactive(@connection_timeout)
          cleaned_count += cleaned
          @global_stats[:total_connections] -= cleaned
        end
        
        # Nettoyer les sessions expirées
        expired_sessions = @session_manager.cleanup_expired(@connection_timeout)
        
        puts "⚪️ Nettoyage: #{cleaned_count} connexions, #{expired_sessions} sessions"
      end
      
      cleaned_count
    end
    
    private
    
    def start_cleanup_thread
      Thread.new do
        loop do
          begin
            sleep 60 # Nettoyage toutes les minutes
            cleanup_inactive_connections
          rescue => e
            puts "⚫️ Erreur thread nettoyage: #{e.message}"
            @global_stats[:errors] += 1
          end
        end
      end
    end
  end
end