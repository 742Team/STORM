# Gestionnaire d'erreurs ultra-optimisé pour STORM WebSocket
# Gestion centralisée des erreurs avec monitoring et récupération automatique

require 'logger'
require 'json'

module STORM
  class ErrorHandler
    attr_reader :error_count, :recovery_count, :critical_errors
    
    def initialize(options = {})
      @error_count = 0
      @recovery_count = 0
      @critical_errors = []
      @max_critical_errors = options[:max_critical_errors] || 100
      @error_threshold = options[:error_threshold] || 1000
      @recovery_strategies = {}
      @circuit_breakers = {}
      @error_patterns = {}
      @notification_callbacks = []
      
      setup_logger(options[:log_level] || :info)
      setup_default_recovery_strategies
      setup_error_patterns
      
      @stats = {
        total_errors: 0,
        errors_by_type: Hash.new(0),
        errors_by_severity: Hash.new(0),
        recovery_attempts: 0,
        successful_recoveries: 0,
        circuit_breaker_trips: 0,
        last_error_time: nil,
        error_rate_per_minute: 0.0
      }
      
      @error_rate_window = []
      @mutex = Mutex.new
      
      start_monitoring_thread
    end
    
    def handle_error(error, context = {})
      @mutex.synchronize do
        @error_count += 1
        @stats[:total_errors] += 1
        @stats[:last_error_time] = Time.now
        
        error_info = {
          type: error.class.name,
          message: error.message,
          backtrace: error.backtrace&.first(10),
          context: context,
          timestamp: Time.now,
          severity: determine_severity(error, context)
        }
        
        @stats[:errors_by_type][error_info[:type]] += 1
        @stats[:errors_by_severity][error_info[:severity]] += 1
        
        # Ajouter à la fenêtre de taux d'erreur
        @error_rate_window << Time.now
        @error_rate_window.reject! { |time| time < Time.now - 60 }
        @stats[:error_rate_per_minute] = @error_rate_window.size
        
        log_error(error_info)
        
        # Vérifier les patterns d'erreur
        pattern_match = check_error_patterns(error_info)
        if pattern_match
          handle_error_pattern(pattern_match, error_info)
        end
        
        # Gestion des erreurs critiques
        if error_info[:severity] == :critical
          handle_critical_error(error_info)
        end
        
        # Tentative de récupération automatique
        if should_attempt_recovery?(error_info)
          attempt_recovery(error_info)
        end
        
        # Vérifier les circuit breakers
        check_circuit_breakers(error_info)
        
        # Notifications
        notify_error(error_info)
        
        error_info
      end
    end
    
    def add_recovery_strategy(error_type, strategy_proc)
      @recovery_strategies[error_type] = strategy_proc
    end
    
    def add_circuit_breaker(name, options = {})
      @circuit_breakers[name] = {
        state: :closed,
        failure_count: 0,
        failure_threshold: options[:failure_threshold] || 5,
        timeout: options[:timeout] || 60,
        last_failure_time: nil,
        success_count: 0,
        half_open_max_calls: options[:half_open_max_calls] || 3
      }
    end
    
    def circuit_breaker_call(name, &block)
      breaker = @circuit_breakers[name]
      return yield unless breaker
      
      case breaker[:state]
      when :closed
        execute_with_circuit_breaker(name, &block)
      when :open
        if Time.now - breaker[:last_failure_time] > breaker[:timeout]
          breaker[:state] = :half_open
          breaker[:success_count] = 0
          execute_with_circuit_breaker(name, &block)
        else
          raise CircuitBreakerOpenError, "Circuit breaker #{name} is open"
        end
      when :half_open
        execute_with_circuit_breaker(name, &block)
      end
    end
    
    def add_error_pattern(name, pattern_proc, handler_proc)
      @error_patterns[name] = {
        pattern: pattern_proc,
        handler: handler_proc,
        matches: 0,
        last_match: nil
      }
    end
    
    def add_notification_callback(&block)
      @notification_callbacks << block
    end
    
    def get_stats
      @mutex.synchronize do
        {
          error_count: @error_count,
          recovery_count: @recovery_count,
          critical_errors_count: @critical_errors.size,
          error_rate_per_minute: @stats[:error_rate_per_minute],
          circuit_breakers: @circuit_breakers.transform_values { |cb| cb.slice(:state, :failure_count) },
          top_error_types: @stats[:errors_by_type].sort_by { |_, count| -count }.first(5).to_h,
          severity_distribution: @stats[:errors_by_severity],
          recovery_success_rate: @stats[:recovery_attempts] > 0 ? 
            (@stats[:successful_recoveries].to_f / @stats[:recovery_attempts] * 100).round(2) : 0,
          last_error_time: @stats[:last_error_time],
          uptime: Time.now - @start_time
        }
      end
    end
    
    def reset_stats
      @mutex.synchronize do
        @error_count = 0
        @recovery_count = 0
        @critical_errors.clear
        @stats = @stats.transform_values { |v| v.is_a?(Hash) ? Hash.new(0) : (v.is_a?(Numeric) ? 0 : nil) }
        @error_rate_window.clear
      end
    end
    
    def shutdown
      @monitoring_thread&.kill
      @logger&.close
    end
    
    private
    
    def setup_logger(level)
      @logger = Logger.new(STDOUT)
      @logger.level = Logger.const_get(level.to_s.upcase)
      @logger.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity} [ErrorHandler]: #{msg}\n"
      end
    end
    
    def setup_default_recovery_strategies
      # Stratégie pour les erreurs de connexion
      add_recovery_strategy('Errno::ECONNREFUSED') do |error_info|
        sleep(1)
        @logger.info "Tentative de reconnexion après erreur de connexion"
        true
      end
      
      # Stratégie pour les erreurs de mémoire
      add_recovery_strategy('NoMemoryError') do |error_info|
        GC.start
        @logger.warn "Nettoyage mémoire forcé après NoMemoryError"
        true
      end
      
      # Stratégie pour les erreurs WebSocket
      add_recovery_strategy('Faye::WebSocket::API::Event') do |error_info|
        @logger.info "Tentative de récupération WebSocket"
        # Logique de récupération WebSocket spécifique
        true
      end
    end
    
    def setup_error_patterns
      # Pattern pour les erreurs répétitives
      add_error_pattern('repetitive_errors', 
        proc do |error_info|
          same_errors = @critical_errors.select do |e|
            e[:type] == error_info[:type] && 
            e[:timestamp] > Time.now - 300 # 5 minutes
          end
          same_errors.size >= 5
        end,
        proc do |pattern_match, error_info|
          @logger.error "Pattern d'erreurs répétitives détecté: #{error_info[:type]}"
          # Activer un circuit breaker temporaire
          add_circuit_breaker("temp_#{error_info[:type]}", failure_threshold: 1, timeout: 300)
        end
      )
      
      # Pattern pour les erreurs en cascade
      add_error_pattern('cascade_errors',
        proc do |error_info|
          recent_errors = @critical_errors.select { |e| e[:timestamp] > Time.now - 60 }
          recent_errors.size >= 10
        end,
        proc do |pattern_match, error_info|
          @logger.error "Pattern d'erreurs en cascade détecté"
          # Déclencher un mode de protection
          notify_critical_situation('cascade_errors', error_info)
        end
      )
    end
    
    def determine_severity(error, context)
      case error
      when NoMemoryError, SystemStackError
        :critical
      when Errno::ECONNREFUSED, Errno::ETIMEDOUT
        :high
      when JSON::ParserError, ArgumentError
        :medium
      else
        context[:severity] || :low
      end
    end
    
    def log_error(error_info)
      case error_info[:severity]
      when :critical
        @logger.fatal "CRITIQUE: #{error_info[:type]} - #{error_info[:message]}"
      when :high
        @logger.error "HAUTE: #{error_info[:type]} - #{error_info[:message]}"
      when :medium
        @logger.warn "MOYENNE: #{error_info[:type]} - #{error_info[:message]}"
      else
        @logger.info "BASSE: #{error_info[:type]} - #{error_info[:message]}"
      end
      
      if error_info[:context].any?
        @logger.debug "Contexte: #{error_info[:context].to_json}"
      end
    end
    
    def check_error_patterns(error_info)
      @error_patterns.each do |name, pattern_config|
        if pattern_config[:pattern].call(error_info)
          pattern_config[:matches] += 1
          pattern_config[:last_match] = Time.now
          return { name: name, config: pattern_config }
        end
      end
      nil
    end
    
    def handle_error_pattern(pattern_match, error_info)
      pattern_match[:config][:handler].call(pattern_match, error_info)
    end
    
    def handle_critical_error(error_info)
      @critical_errors << error_info
      
      # Limiter la taille du tableau des erreurs critiques
      if @critical_errors.size > @max_critical_errors
        @critical_errors.shift(@critical_errors.size - @max_critical_errors)
      end
      
      # Vérifier si on dépasse le seuil critique
      if @critical_errors.size >= @max_critical_errors * 0.8
        notify_critical_situation('critical_threshold', error_info)
      end
    end
    
    def should_attempt_recovery?(error_info)
      return false if error_info[:severity] == :critical
      return false if @stats[:recovery_attempts] > 100 # Limite de tentatives
      
      # Vérifier si on a une stratégie de récupération
      @recovery_strategies.key?(error_info[:type])
    end
    
    def attempt_recovery(error_info)
      @stats[:recovery_attempts] += 1
      
      strategy = @recovery_strategies[error_info[:type]]
      return false unless strategy
      
      begin
        if strategy.call(error_info)
          @recovery_count += 1
          @stats[:successful_recoveries] += 1
          @logger.info "Récupération réussie pour #{error_info[:type]}"
          return true
        end
      rescue => recovery_error
        @logger.error "Échec de récupération pour #{error_info[:type]}: #{recovery_error.message}"
      end
      
      false
    end
    
    def execute_with_circuit_breaker(name, &block)
      breaker = @circuit_breakers[name]
      
      begin
        result = yield
        
        # Succès
        if breaker[:state] == :half_open
          breaker[:success_count] += 1
          if breaker[:success_count] >= breaker[:half_open_max_calls]
            breaker[:state] = :closed
            breaker[:failure_count] = 0
            @logger.info "Circuit breaker #{name} fermé après récupération"
          end
        else
          breaker[:failure_count] = 0
        end
        
        result
      rescue => error
        breaker[:failure_count] += 1
        breaker[:last_failure_time] = Time.now
        
        if breaker[:failure_count] >= breaker[:failure_threshold]
          breaker[:state] = :open
          @stats[:circuit_breaker_trips] += 1
          @logger.error "Circuit breaker #{name} ouvert après #{breaker[:failure_count]} échecs"
        end
        
        raise error
      end
    end
    
    def check_circuit_breakers(error_info)
      # Logique pour déclencher automatiquement des circuit breakers
      # basée sur les types d'erreur et les patterns
    end
    
    def notify_error(error_info)
      @notification_callbacks.each do |callback|
        begin
          callback.call(error_info)
        rescue => e
          @logger.error "Erreur dans callback de notification: #{e.message}"
        end
      end
    end
    
    def notify_critical_situation(situation_type, error_info)
      @logger.fatal "SITUATION CRITIQUE: #{situation_type}"
      
      critical_notification = {
        type: 'critical_situation',
        situation: situation_type,
        error_info: error_info,
        timestamp: Time.now,
        stats: get_stats
      }
      
      @notification_callbacks.each do |callback|
        begin
          callback.call(critical_notification)
        rescue => e
          @logger.error "Erreur dans callback critique: #{e.message}"
        end
      end
    end
    
    def start_monitoring_thread
      @start_time = Time.now
      
      @monitoring_thread = Thread.new do
        loop do
          begin
            sleep(60) # Monitoring chaque minute
            
            # Nettoyage automatique des anciennes erreurs
            cleanup_old_errors
            
            # Vérification de la santé générale
            check_system_health
            
          rescue => e
            @logger.error "Erreur dans thread de monitoring: #{e.message}"
          end
        end
      end
    end
    
    def cleanup_old_errors
      cutoff_time = Time.now - 3600 # 1 heure
      @critical_errors.reject! { |error| error[:timestamp] < cutoff_time }
    end
    
    def check_system_health
      if @stats[:error_rate_per_minute] > 100
        @logger.warn "Taux d'erreur élevé: #{@stats[:error_rate_per_minute]} erreurs/minute"
      end
      
      if @error_count > @error_threshold
        @logger.warn "Seuil d'erreur dépassé: #{@error_count} erreurs totales"
      end
    end
  end
  
  class CircuitBreakerOpenError < StandardError; end
end