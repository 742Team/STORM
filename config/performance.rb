# Configuration de performance pour STORM WebSocket Ultra-Optimisé
# Gestion de millions de connexions simultanées

module STORM
  module Performance
    # Configuration système optimisée
    SYSTEM_CONFIG = {
      # Limites de connexions
      max_connections: 1_000_000,
      max_connections_per_worker: 50_000,
      connection_timeout: 300, # 5 minutes
      
      # Configuration mémoire
      max_memory_per_worker: 512 * 1024 * 1024, # 512MB
      gc_compact_interval: 30, # secondes
      gc_major_interval: 60,   # secondes
      
      # Configuration réseau
      tcp_nodelay: true,
      tcp_keepalive: true,
      keepalive_time: 7200,    # 2 heures
      keepalive_interval: 75,  # 75 secondes
      keepalive_probes: 9,
      
      # Configuration WebSocket
      websocket_max_frame_size: 65536,  # 64KB
      websocket_ping_interval: 30,      # 30 secondes
      websocket_pong_timeout: 10,       # 10 secondes
      
      # Configuration compression
      compression_threshold: 1024,      # 1KB minimum
      compression_level: 6,             # Équilibre vitesse/ratio
      compression_window_bits: 15,      # Fenêtre de compression
      compression_mem_level: 8,         # Niveau mémoire
      
      # Configuration cache
      cache_size: 10_000,              # Nombre d'entrées
      cache_ttl: 3600,                 # 1 heure
      cache_cleanup_interval: 300,     # 5 minutes
      
      # Configuration monitoring
      metrics_interval: 5,             # 5 secondes
      health_check_interval: 10,       # 10 secondes
      stats_retention: 86400,          # 24 heures
      
      # Configuration auto-scaling
      scale_up_threshold: 0.8,         # 80% CPU
      scale_down_threshold: 0.3,       # 30% CPU
      scale_check_interval: 30,        # 30 secondes
      min_workers: 2,
      max_workers: 50,
      
      # Configuration load balancing
      lb_algorithm: :least_connections,
      lb_health_check_interval: 5,     # 5 secondes
      lb_session_persistence: true,
      lb_failover_timeout: 3,          # 3 secondes
      
      # Configuration sécurité
      rate_limit_per_ip: 1000,         # Messages par minute
      rate_limit_window: 60,           # Fenêtre en secondes
      max_message_size: 4096,          # 4KB par message
      connection_limit_per_ip: 100,    # Connexions par IP
      
      # Configuration logging
      log_level: :info,
      log_rotation: :daily,
      log_max_size: 100 * 1024 * 1024, # 100MB
      log_compress: true
    }.freeze
    
    # Optimisations système
    def self.optimize_system!
      # Configuration Ruby GC
      GC::Profiler.enable
      
      # Variables d'environnement Ruby optimisées
      ENV['RUBY_GC_HEAP_INIT_SLOTS'] ||= '1000000'
      ENV['RUBY_GC_HEAP_FREE_SLOTS'] ||= '500000'
      ENV['RUBY_GC_HEAP_GROWTH_FACTOR'] ||= '1.1'
      ENV['RUBY_GC_HEAP_GROWTH_MAX_SLOTS'] ||= '1000000'
      ENV['RUBY_GC_MALLOC_LIMIT'] ||= '90000000'
      ENV['RUBY_GC_MALLOC_LIMIT_MAX'] ||= '180000000'
      ENV['RUBY_GC_MALLOC_LIMIT_GROWTH_FACTOR'] ||= '1.4'
      ENV['RUBY_GC_OLDMALLOC_LIMIT'] ||= '90000000'
      ENV['RUBY_GC_OLDMALLOC_LIMIT_MAX'] ||= '180000000'
      
      # Configuration EventMachine
      if defined?(EventMachine)
        EventMachine.epoll = true if EventMachine.respond_to?(:epoll=)
        EventMachine.kqueue = true if EventMachine.respond_to?(:kqueue=)
      end
      
      puts "⚪️ Optimisations système appliquées"
    end
    
    # Configuration des limites système
    def self.configure_limits!
      begin
        # Augmenter les limites de fichiers ouverts
        Process.setrlimit(Process::RLIMIT_NOFILE, 65536, 65536)
        
        # Augmenter les limites de processus
        Process.setrlimit(Process::RLIMIT_NPROC, 32768, 32768) rescue nil
        
        puts "⚪️ Limites système configurées"
      rescue => e
        puts "⚫️ Erreur configuration limites: #{e.message}"
      end
    end
    
    # Monitoring des performances
    class PerformanceMonitor
      def initialize
        @start_time = Time.now
        @metrics = {
          connections: 0,
          messages_sent: 0,
          messages_received: 0,
          bytes_sent: 0,
          bytes_received: 0,
          compression_ratio: 0.0,
          cpu_usage: 0.0,
          memory_usage: 0,
          gc_count: 0,
          errors: 0
        }
        @last_gc_count = GC.count
      end
      
      def update_metrics
        @metrics[:cpu_usage] = get_cpu_usage
        @metrics[:memory_usage] = get_memory_usage
        @metrics[:gc_count] = GC.count - @last_gc_count
        @last_gc_count = GC.count
      end
      
      def increment(metric, value = 1)
        @metrics[metric] += value if @metrics.key?(metric)
      end
      
      def set(metric, value)
        @metrics[metric] = value if @metrics.key?(metric)
      end
      
      def get_stats
        update_metrics
        uptime = Time.now - @start_time
        
        @metrics.merge({
          uptime: uptime.to_i,
          messages_per_second: (@metrics[:messages_sent] + @metrics[:messages_received]) / uptime,
          bytes_per_second: (@metrics[:bytes_sent] + @metrics[:bytes_received]) / uptime,
          connections_per_worker: @metrics[:connections] / [Process.respond_to?(:fork) ? 1 : 1, 1].max
        })
      end
      
      private
      
      def get_cpu_usage
        # Utilisation CPU simplifiée (peut être améliorée avec des gems spécialisées)
        begin
          load_avg = File.read('/proc/loadavg').split.first.to_f rescue 0.0
          cpu_count = `nproc`.to_i rescue 1
          (load_avg / cpu_count * 100).round(2)
        rescue
          0.0
        end
      end
      
      def get_memory_usage
        # Utilisation mémoire du processus Ruby
        begin
          if RUBY_PLATFORM =~ /darwin/
            # macOS
            `ps -o rss= -p #{Process.pid}`.to_i * 1024
          else
            # Linux
            File.read("/proc/#{Process.pid}/status")
                .lines
                .find { |line| line.start_with?('VmRSS:') }
                &.split&.at(1)&.to_i&.*(1024) || 0
          end
        rescue
          0
        end
      end
    end
    
    # Gestionnaire de nettoyage automatique
    class AutoCleaner
      def initialize(interval = 300) # 5 minutes
        @interval = interval
        @running = false
      end
      
      def start
        return if @running
        @running = true
        
        Thread.new do
          while @running
            begin
              cleanup_memory
              cleanup_connections
              sleep @interval
            rescue => e
              puts "⚫️ Erreur auto-nettoyage: #{e.message}"
              sleep 60 # Attendre 1 minute avant de réessayer
            end
          end
        end
        
        puts "⚪️ Auto-nettoyage démarré (intervalle: #{@interval}s)"
      end
      
      def stop
        @running = false
        puts "⚪️ Auto-nettoyage arrêté"
      end
      
      private
      
      def cleanup_memory
        # Forcer le garbage collection
        GC.start
        GC.compact if GC.respond_to?(:compact)
        
        # Statistiques GC
        stats = GC.stat
        puts "⚪️ GC: #{stats[:count]} collections, #{stats[:heap_live_slots]} objets actifs"
      end
      
      def cleanup_connections
        # Nettoyage des connexions inactives (implémenté dans les handlers)
        puts "⚪️ Nettoyage des connexions inactives"
      end
    end
    
    # Configuration globale
    def self.configure!
      optimize_system!
      configure_limits!
      
      # Démarrer le monitoring
      @monitor = PerformanceMonitor.new
      @cleaner = AutoCleaner.new(SYSTEM_CONFIG[:cache_cleanup_interval])
      @cleaner.start
      
      puts "⚪️ Configuration de performance STORM initialisée"
      puts "⚪️ Prêt pour #{SYSTEM_CONFIG[:max_connections]} connexions simultanées"
    end
    
    def self.monitor
      @monitor
    end
    
    def self.cleaner
      @cleaner
    end
  end
end

# Auto-configuration au chargement
STORM::Performance.configure! if defined?(STORM)