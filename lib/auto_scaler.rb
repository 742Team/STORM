#!/usr/bin/env ruby

# Auto-scaler pour gestion de millions de connexions WebSocket
# Optimisations: compression, load balancing, clustering

require 'concurrent-ruby'
require 'json'
require 'zlib'
require 'socket'

class AutoScaler
  attr_reader :workers, :load_threshold, :scale_factor
  
  def initialize(options = {})
    @workers = Concurrent::Array.new
    @load_threshold = options[:load_threshold] || 0.8
    @scale_factor = options[:scale_factor] || 2
    @min_workers = options[:min_workers] || 2
    @max_workers = options[:max_workers] || 100
    @compression_enabled = options[:compression] || true
    @metrics = Concurrent::Map.new
    @running = false
    
    initialize_metrics
  end
  
  def start
    @running = true
    start_monitoring_thread
    start_health_check_thread
    puts "⚪️ Auto-scaler started with #{@min_workers} initial workers"
  end
  
  def stop
    @running = false
    puts "⚫️ Auto-scaler stopped"
  end
  
  def add_worker(port)
    worker = {
      port: port,
      pid: nil,
      connections: 0,
      cpu_usage: 0.0,
      memory_usage: 0.0,
      status: :starting,
      last_health_check: Time.now
    }
    
    @workers << worker
    spawn_worker(worker)
    update_metrics
  end
  
  def remove_worker(port)
    worker = @workers.find { |w| w[:port] == port }
    return false unless worker
    
    graceful_shutdown(worker)
    @workers.delete(worker)
    update_metrics
    true
  end
  
  def get_best_worker
    active_workers = @workers.select { |w| w[:status] == :running }
    return nil if active_workers.empty?
    
    # Load balancing: choisir le worker avec le moins de connexions
    active_workers.min_by { |w| w[:connections] }
  end
  
  def compress_message(data)
    return data unless @compression_enabled
    
    begin
      compressed = Zlib::Deflate.deflate(data.to_json)
      # Utiliser compression seulement si gain > 20%
      compressed.size < data.to_json.size * 0.8 ? compressed : data.to_json
    rescue
      data.to_json
    end
  end
  
  def decompress_message(data)
    return JSON.parse(data) unless @compression_enabled
    
    begin
      # Detecter si donnees compressees
      if data.start_with?("\x78\x9C") || data.start_with?("\x78\x01")
        decompressed = Zlib::Inflate.inflate(data)
        JSON.parse(decompressed)
      else
        JSON.parse(data)
      end
    rescue
      # Fallback si decompression echoue
      begin
        JSON.parse(data)
      rescue
        { error: "Invalid message format" }
      end
    end
  end
  
  def get_metrics
    {
      total_workers: @workers.size,
      active_workers: @workers.count { |w| w[:status] == :running },
      total_connections: @workers.sum { |w| w[:connections] },
      average_cpu: @workers.map { |w| w[:cpu_usage] }.sum / [@workers.size, 1].max,
      average_memory: @workers.map { |w| w[:memory_usage] }.sum / [@workers.size, 1].max,
      compression_enabled: @compression_enabled,
      load_threshold: @load_threshold,
      uptime: Time.now - @start_time
    }
  end
  
  private
  
  def initialize_metrics
    @start_time = Time.now
    @metrics[:scale_events] = 0
    @metrics[:total_messages] = 0
    @metrics[:compressed_messages] = 0
  end
  
  def start_monitoring_thread
    Thread.new do
      while @running
        check_scaling_needs
        sleep 5 # Verifier toutes les 5 secondes
      end
    end
  end
  
  def start_health_check_thread
    Thread.new do
      while @running
        perform_health_checks
        sleep 10 # Health check toutes les 10 secondes
      end
    end
  end
  
  def check_scaling_needs
    return if @workers.empty?
    
    active_workers = @workers.select { |w| w[:status] == :running }
    return if active_workers.empty?
    
    # Calculer charge moyenne
    avg_load = calculate_average_load(active_workers)
    
    if avg_load > @load_threshold && @workers.size < @max_workers
      scale_up
    elsif avg_load < (@load_threshold * 0.3) && @workers.size > @min_workers
      scale_down
    end
  end
  
  def calculate_average_load(workers)
    return 0.0 if workers.empty?
    
    total_load = workers.sum do |worker|
      connection_load = worker[:connections] / 1000.0 # Normaliser sur 1000 connexions
      cpu_load = worker[:cpu_usage] / 100.0
      memory_load = worker[:memory_usage] / 100.0
      
      (connection_load + cpu_load + memory_load) / 3.0
    end
    
    total_load / workers.size
  end
  
  def scale_up
    new_port = find_available_port
    add_worker(new_port)
    @metrics[:scale_events] += 1
    puts "⚪️ Scaling up: added worker on port #{new_port}"
  end
  
  def scale_down
    # Supprimer le worker avec le moins de connexions
    worker_to_remove = @workers.select { |w| w[:status] == :running }
                               .min_by { |w| w[:connections] }
    
    if worker_to_remove
      remove_worker(worker_to_remove[:port])
      @metrics[:scale_events] += 1
      puts "⚫️ Scaling down: removed worker on port #{worker_to_remove[:port]}"
    end
  end
  
  def find_available_port
    (4000..5000).each do |port|
      next if @workers.any? { |w| w[:port] == port }
      
      begin
        server = TCPServer.new('localhost', port)
        server.close
        return port
      rescue Errno::EADDRINUSE
        next
      end
    end
    
    raise "No available ports found"
  end
  
  def spawn_worker(worker)
    Thread.new do
      begin
        # Commande pour demarrer un nouveau worker Puma
        cmd = "cd #{Dir.pwd} && bundle exec puma -p #{worker[:port]} -e production -w 1 -t 5:20 --preload"
        worker[:pid] = spawn(cmd)
        
        # Attendre que le worker soit pret
        sleep 2
        worker[:status] = :running
        
        Process.detach(worker[:pid])
      rescue => e
        puts "⚫️ Failed to spawn worker on port #{worker[:port]}: #{e.message}"
        worker[:status] = :failed
      end
    end
  end
  
  def graceful_shutdown(worker)
    return unless worker[:pid]
    
    begin
      # Signal TERM pour arret gracieux
      Process.kill('TERM', worker[:pid])
      
      # Attendre jusqu'a 10 secondes
      timeout = 10
      while timeout > 0 && process_running?(worker[:pid])
        sleep 1
        timeout -= 1
      end
      
      # Force kill si necessaire
      if process_running?(worker[:pid])
        Process.kill('KILL', worker[:pid])
      end
      
      worker[:status] = :stopped
    rescue => e
      puts "⚫️ Error shutting down worker #{worker[:port]}: #{e.message}"
    end
  end
  
  def process_running?(pid)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
  end
  
  def perform_health_checks
    @workers.each do |worker|
      next unless worker[:status] == :running
      
      begin
        # Simple health check via HTTP
        response = `curl -s -o /dev/null -w "%{http_code}" http://localhost:#{worker[:port]}/health 2>/dev/null`
        
        if response.strip == "200"
          worker[:last_health_check] = Time.now
          update_worker_stats(worker)
        else
          handle_unhealthy_worker(worker)
        end
      rescue => e
        handle_unhealthy_worker(worker)
      end
    end
  end
  
  def update_worker_stats(worker)
    # Simuler stats (dans un vrai environnement, utiliser des metriques reelles)
    worker[:cpu_usage] = rand(10..90)
    worker[:memory_usage] = rand(20..80)
    worker[:connections] = rand(0..1000)
  end
  
  def handle_unhealthy_worker(worker)
    puts "⚫️ Unhealthy worker detected on port #{worker[:port]}"
    
    # Si worker non responsive depuis plus de 30 secondes, le redemarrer
    if Time.now - worker[:last_health_check] > 30
      restart_worker(worker)
    end
  end
  
  def restart_worker(worker)
    puts "⚪️ Restarting worker on port #{worker[:port]}"
    graceful_shutdown(worker)
    sleep 1
    spawn_worker(worker)
  end
  
  def update_metrics
    # Mettre a jour les metriques globales
    @metrics[:last_update] = Time.now
  end
end