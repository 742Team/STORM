# Collecteur de métriques ultra-optimisé pour STORM WebSocket
# Collecte, agrégation et analyse des métriques de performance en temps réel

require 'json'
require 'thread'

module STORM
  class MetricsCollector
    attr_reader :metrics, :aggregated_metrics, :alerts
    
    def initialize(options = {})
      @metrics = {}
      @aggregated_metrics = {}
      @alerts = []
      @collection_interval = options[:collection_interval] || 10
      @retention_period = options[:retention_period] || 3600
      @alert_thresholds = options[:alert_thresholds] || {}
      @custom_collectors = {}
      @metric_history = {}
      @percentile_calculator = PercentileCalculator.new
      
      @mutex = Mutex.new
      @running = false
      
      setup_default_metrics
      setup_default_thresholds
      
      @stats = {
        collection_count: 0,
        last_collection_time: nil,
        collection_duration_ms: 0,
        metrics_count: 0,
        alerts_triggered: 0,
        data_points_collected: 0
      }
    end
    
    def start_collection
      return if @running
      
      @running = true
      @collection_thread = Thread.new { collection_loop }
      @aggregation_thread = Thread.new { aggregation_loop }
      @cleanup_thread = Thread.new { cleanup_loop }
      
      puts "⚪️ MetricsCollector démarré (intervalle: #{@collection_interval}s)"
    end
    
    def stop_collection
      @running = false
      [@collection_thread, @aggregation_thread, @cleanup_thread].each(&:kill)
      puts "⚪️ MetricsCollector arrêté"
    end
    
    def record_metric(name, value, tags = {})
      @mutex.synchronize do
        timestamp = Time.now
        
        @metrics[name] ||= []
        @metrics[name] << {
          value: value,
          timestamp: timestamp,
          tags: tags
        }
        
        @stats[:data_points_collected] += 1
        
        # Vérifier les seuils d'alerte
        check_alert_threshold(name, value, tags)
        
        # Maintenir l'historique pour les percentiles
        @metric_history[name] ||= []
        @metric_history[name] << value
        
        # Limiter la taille de l'historique
        if @metric_history[name].size > 1000
          @metric_history[name].shift(@metric_history[name].size - 1000)
        end
      end
    end
    
    def increment_counter(name, value = 1, tags = {})
      current_value = get_current_value(name) || 0
      record_metric(name, current_value + value, tags)
    end
    
    def set_gauge(name, value, tags = {})
      record_metric(name, value, tags)
    end
    
    def record_timing(name, duration_ms, tags = {})
      record_metric("#{name}_duration_ms", duration_ms, tags)
      
      # Enregistrer aussi les statistiques de timing
      timing_stats = get_timing_stats(name)
      timing_stats[:count] += 1
      timing_stats[:total_ms] += duration_ms
      timing_stats[:avg_ms] = timing_stats[:total_ms] / timing_stats[:count]
      timing_stats[:min_ms] = [timing_stats[:min_ms], duration_ms].compact.min
      timing_stats[:max_ms] = [timing_stats[:max_ms], duration_ms].compact.max
    end
    
    def time_block(name, tags = {}, &block)
      start_time = Time.now
      result = yield
      duration_ms = ((Time.now - start_time) * 1000).round(2)
      record_timing(name, duration_ms, tags)
      result
    end
    
    def add_custom_collector(name, &block)
      @custom_collectors[name] = block
    end
    
    def set_alert_threshold(metric_name, threshold_config)
      @alert_thresholds[metric_name] = threshold_config
    end
    
    def get_metric_summary(name, time_range = 300)
      @mutex.synchronize do
        cutoff_time = Time.now - time_range
        recent_data = @metrics[name]&.select { |point| point[:timestamp] > cutoff_time } || []
        
        return nil if recent_data.empty?
        
        values = recent_data.map { |point| point[:value] }
        
        {
          name: name,
          count: values.size,
          min: values.min,
          max: values.max,
          avg: (values.sum.to_f / values.size).round(2),
          sum: values.sum,
          percentiles: @percentile_calculator.calculate(values),
          latest: values.last,
          time_range: time_range,
          data_points: recent_data.size
        }
      end
    end
    
    def get_all_metrics_summary(time_range = 300)
      @mutex.synchronize do
        summary = {}
        @metrics.keys.each do |name|
          summary[name] = get_metric_summary(name, time_range)
        end
        summary.compact
      end
    end
    
    def get_aggregated_metrics
      @mutex.synchronize do
        @aggregated_metrics.dup
      end
    end
    
    def get_recent_alerts(limit = 10)
      @mutex.synchronize do
        @alerts.last(limit)
      end
    end
    
    def get_system_metrics
      {
        memory_usage_mb: get_memory_usage,
        cpu_usage_percent: get_cpu_usage,
        disk_usage_percent: get_disk_usage,
        network_connections: get_network_connections,
        load_average: get_load_average,
        uptime_seconds: get_uptime
      }
    end
    
    def get_comprehensive_stats
      @mutex.synchronize do
        {
          collector_stats: @stats.dup,
          metrics_count: @metrics.keys.size,
          total_data_points: @metrics.values.map(&:size).sum,
          aggregated_metrics_count: @aggregated_metrics.keys.size,
          active_alerts: @alerts.select { |a| a[:active] }.size,
          total_alerts: @alerts.size,
          custom_collectors: @custom_collectors.keys,
          system_metrics: get_system_metrics,
          memory_usage: {
            metrics_data_mb: calculate_metrics_memory_usage,
            ruby_heap_mb: (GC.stat[:heap_allocated_pages] * GC::INTERNAL_CONSTANTS[:HEAP_PAGE_SIZE]) / (1024 * 1024)
          }
        }
      end
    end
    
    def export_metrics(format = :json, time_range = 3600)
      case format
      when :json
        export_json(time_range)
      when :prometheus
        export_prometheus(time_range)
      when :csv
        export_csv(time_range)
      else
        raise ArgumentError, "Format non supporté: #{format}"
      end
    end
    
    def reset_metrics
      @mutex.synchronize do
        @metrics.clear
        @aggregated_metrics.clear
        @alerts.clear
        @metric_history.clear
        @stats = @stats.transform_values { |v| v.is_a?(Numeric) ? 0 : nil }
        puts "⚪️ Métriques réinitialisées"
      end
    end
    
    private
    
    def setup_default_metrics
      # Métriques système de base
      add_custom_collector('system_memory') { get_memory_usage }
      add_custom_collector('system_cpu') { get_cpu_usage }
      add_custom_collector('ruby_gc_count') { GC.count }
      add_custom_collector('ruby_object_count') { ObjectSpace.count_objects[:TOTAL] }
      add_custom_collector('thread_count') { Thread.list.size }
    end
    
    def setup_default_thresholds
      @alert_thresholds.merge!({
        'memory_usage_mb' => { max: 1000, severity: :warning },
        'cpu_usage_percent' => { max: 80, severity: :warning },
        'error_rate' => { max: 10, severity: :critical },
        'response_time_ms' => { max: 1000, severity: :warning },
        'connection_count' => { max: 10000, severity: :warning }
      })
    end
    
    def collection_loop
      while @running
        begin
          start_time = Time.now
          
          collect_custom_metrics
          collect_system_metrics
          
          @stats[:collection_count] += 1
          @stats[:last_collection_time] = Time.now
          @stats[:collection_duration_ms] = ((Time.now - start_time) * 1000).round(2)
          @stats[:metrics_count] = @metrics.keys.size
          
          sleep(@collection_interval)
        rescue => e
          puts "⚫️ Erreur dans collection_loop: #{e.message}"
          sleep(1)
        end
      end
    end
    
    def aggregation_loop
      while @running
        begin
          sleep(60) # Agrégation chaque minute
          aggregate_metrics
        rescue => e
          puts "⚫️ Erreur dans aggregation_loop: #{e.message}"
        end
      end
    end
    
    def cleanup_loop
      while @running
        begin
          sleep(300) # Nettoyage toutes les 5 minutes
          cleanup_old_data
        rescue => e
          puts "⚫️ Erreur dans cleanup_loop: #{e.message}"
        end
      end
    end
    
    def collect_custom_metrics
      @custom_collectors.each do |name, collector|
        begin
          value = collector.call
          record_metric(name, value) if value
        rescue => e
          puts "⚫️ Erreur collecteur #{name}: #{e.message}"
        end
      end
    end
    
    def collect_system_metrics
      system_metrics = get_system_metrics
      system_metrics.each do |name, value|
        record_metric(name.to_s, value) if value
      end
    end
    
    def aggregate_metrics
      @mutex.synchronize do
        @metrics.each do |name, data_points|
          next if data_points.empty?
          
          # Agrégation par minute
          minute_groups = data_points.group_by { |point| point[:timestamp].strftime('%Y-%m-%d %H:%M') }
          
          minute_groups.each do |minute, points|
            values = points.map { |p| p[:value] }
            
            @aggregated_metrics["#{name}_per_minute"] ||= []
            @aggregated_metrics["#{name}_per_minute"] << {
              timestamp: minute,
              count: values.size,
              sum: values.sum,
              avg: (values.sum.to_f / values.size).round(2),
              min: values.min,
              max: values.max
            }
          end
        end
      end
    end
    
    def cleanup_old_data
      cutoff_time = Time.now - @retention_period
      
      @mutex.synchronize do
        @metrics.each do |name, data_points|
          @metrics[name] = data_points.select { |point| point[:timestamp] > cutoff_time }
        end
        
        @alerts.reject! { |alert| alert[:timestamp] < cutoff_time }
        
        # Nettoyer les métriques vides
        @metrics.reject! { |_, data_points| data_points.empty? }
      end
    end
    
    def check_alert_threshold(name, value, tags)
      threshold_config = @alert_thresholds[name]
      return unless threshold_config
      
      alert_triggered = false
      
      if threshold_config[:max] && value > threshold_config[:max]
        trigger_alert(name, :max_exceeded, value, threshold_config[:max], tags)
        alert_triggered = true
      end
      
      if threshold_config[:min] && value < threshold_config[:min]
        trigger_alert(name, :min_exceeded, value, threshold_config[:min], tags)
        alert_triggered = true
      end
      
      @stats[:alerts_triggered] += 1 if alert_triggered
    end
    
    def trigger_alert(metric_name, alert_type, current_value, threshold_value, tags)
      alert = {
        id: SecureRandom.hex(8),
        metric_name: metric_name,
        alert_type: alert_type,
        current_value: current_value,
        threshold_value: threshold_value,
        tags: tags,
        timestamp: Time.now,
        severity: @alert_thresholds[metric_name][:severity] || :info,
        active: true
      }
      
      @alerts << alert
      
      puts "⚫️ ALERTE #{alert[:severity].upcase}: #{metric_name} = #{current_value} (seuil: #{threshold_value})"
    end
    
    def get_current_value(name)
      return nil unless @metrics[name] && !@metrics[name].empty?
      @metrics[name].last[:value]
    end
    
    def get_timing_stats(name)
      @timing_stats ||= {}
      @timing_stats[name] ||= {
        count: 0,
        total_ms: 0,
        avg_ms: 0,
        min_ms: nil,
        max_ms: nil
      }
    end
    
    def get_memory_usage
      begin
        `ps -o rss= -p #{Process.pid}`.to_i / 1024.0 # MB
      rescue
        nil
      end
    end
    
    def get_cpu_usage
      begin
        # Approximation simple du CPU usage
        load_avg = `uptime`.match(/load average: ([\d.]+)/)
        load_avg ? (load_avg[1].to_f * 100 / `nproc`.to_i).round(2) : nil
      rescue
        nil
      end
    end
    
    def get_disk_usage
      begin
        df_output = `df -h /`.lines[1]
        usage_percent = df_output.split[4].gsub('%', '').to_i
        usage_percent
      rescue
        nil
      end
    end
    
    def get_network_connections
      begin
        `netstat -an | wc -l`.to_i
      rescue
        nil
      end
    end
    
    def get_load_average
      begin
        File.read('/proc/loadavg').split.first.to_f
      rescue
        nil
      end
    end
    
    def get_uptime
      begin
        File.read('/proc/uptime').split.first.to_f
      rescue
        nil
      end
    end
    
    def calculate_metrics_memory_usage
      total_size = 0
      @metrics.each do |_, data_points|
        total_size += data_points.size * 200 # Estimation approximative
      end
      (total_size / (1024 * 1024)).round(2)
    end
    
    def export_json(time_range)
      {
        exported_at: Time.now.iso8601,
        time_range_seconds: time_range,
        metrics_summary: get_all_metrics_summary(time_range),
        aggregated_metrics: get_aggregated_metrics,
        recent_alerts: get_recent_alerts,
        system_metrics: get_system_metrics,
        collector_stats: get_comprehensive_stats
      }.to_json
    end
    
    def export_prometheus(time_range)
      output = []
      
      get_all_metrics_summary(time_range).each do |name, summary|
        next unless summary
        
        output << "# HELP #{name} Metric collected by STORM"
        output << "# TYPE #{name} gauge"
        output << "#{name}_total #{summary[:sum]}"
        output << "#{name}_count #{summary[:count]}"
        output << "#{name}_avg #{summary[:avg]}"
      end
      
      output.join("\n")
    end
    
    def export_csv(time_range)
      require 'csv'
      
      CSV.generate do |csv|
        csv << ['metric_name', 'timestamp', 'value', 'tags']
        
        cutoff_time = Time.now - time_range
        @metrics.each do |name, data_points|
          data_points.select { |point| point[:timestamp] > cutoff_time }.each do |point|
            csv << [name, point[:timestamp].iso8601, point[:value], point[:tags].to_json]
          end
        end
      end
    end
  end
  
  class PercentileCalculator
    def calculate(values)
      return {} if values.empty?
      
      sorted = values.sort
      size = sorted.size
      
      {
        p50: percentile(sorted, 50),
        p75: percentile(sorted, 75),
        p90: percentile(sorted, 90),
        p95: percentile(sorted, 95),
        p99: percentile(sorted, 99)
      }
    end
    
    private
    
    def percentile(sorted_values, percentile)
      return sorted_values.first if sorted_values.size == 1
      
      index = (percentile / 100.0) * (sorted_values.size - 1)
      lower_index = index.floor
      upper_index = index.ceil
      
      if lower_index == upper_index
        sorted_values[lower_index]
      else
        lower_value = sorted_values[lower_index]
        upper_value = sorted_values[upper_index]
        weight = index - lower_index
        (lower_value * (1 - weight) + upper_value * weight).round(2)
      end
    end
  end
end