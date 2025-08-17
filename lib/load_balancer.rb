#!/usr/bin/env ruby

# Load Balancer intelligent pour millions de connexions WebSocket
# Algorithmes: Round Robin, Least Connections, Weighted

require 'concurrent-ruby'
require 'json'
require 'digest'

class LoadBalancer
  ALGORITHMS = [:round_robin, :least_connections, :weighted, :ip_hash].freeze
  
  def initialize(options = {})
    @algorithm = options[:algorithm] || :least_connections
    @workers = Concurrent::Array.new
    @current_index = Concurrent::AtomicFixnum.new(0)
    @connection_pool = Concurrent::Map.new
    @health_check_interval = options[:health_check_interval] || 30
    @sticky_sessions = options[:sticky_sessions] || false
    @session_store = Concurrent::Map.new if @sticky_sessions
    @running = false
    
    validate_algorithm
  end
  
  def add_worker(host, port, weight = 1)
    worker = {
      id: "#{host}:#{port}",
      host: host,
      port: port,
      weight: weight,
      connections: Concurrent::AtomicFixnum.new(0),
      total_requests: Concurrent::AtomicFixnum.new(0),
      failed_requests: Concurrent::AtomicFixnum.new(0),
      response_time: Concurrent::AtomicReference.new(0.0),
      status: :healthy,
      last_check: Time.now,
      cpu_usage: 0.0,
      memory_usage: 0.0
    }
    
    @workers << worker
    puts "⚪️ Worker added: #{worker[:id]} (weight: #{weight})"
    worker
  end
  
  def remove_worker(host, port)
    worker_id = "#{host}:#{port}"
    worker = @workers.find { |w| w[:id] == worker_id }
    
    if worker
      @workers.delete(worker)
      puts "⚫️ Worker removed: #{worker_id}"
      true
    else
      false
    end
  end
  
  def get_worker(client_ip = nil, session_id = nil)
    healthy_workers = @workers.select { |w| w[:status] == :healthy }
    return nil if healthy_workers.empty?
    
    case @algorithm
    when :round_robin
      round_robin_select(healthy_workers)
    when :least_connections
      least_connections_select(healthy_workers)
    when :weighted
      weighted_select(healthy_workers)
    when :ip_hash
      ip_hash_select(healthy_workers, client_ip)
    else
      healthy_workers.first
    end
  end
  
  def start_health_monitoring
    return if @running
    
    @running = true
    @health_thread = Thread.new do
      while @running
        perform_health_checks
        sleep @health_check_interval
      end
    end
    
    puts "⚪️ Health monitoring started"
  end
  
  def stop_health_monitoring
    @running = false
    @health_thread&.join
    puts "⚫️ Health monitoring stopped"
  end
  
  def increment_connections(worker)
    worker[:connections].increment
  end
  
  def decrement_connections(worker)
    worker[:connections].decrement
  end
  
  def record_request(worker, response_time, success = true)
    worker[:total_requests].increment
    worker[:failed_requests].increment unless success
    
    # Moyenne mobile pour temps de reponse
    current_avg = worker[:response_time].get
    new_avg = (current_avg * 0.9) + (response_time * 0.1)
    worker[:response_time].set(new_avg)
  end
  
  def get_statistics
    total_connections = @workers.sum { |w| w[:connections].get }
    total_requests = @workers.sum { |w| w[:total_requests].get }
    total_failures = @workers.sum { |w| w[:failed_requests].get }
    
    {
      algorithm: @algorithm,
      total_workers: @workers.size,
      healthy_workers: @workers.count { |w| w[:status] == :healthy },
      total_connections: total_connections,
      total_requests: total_requests,
      total_failures: total_failures,
      success_rate: total_requests > 0 ? ((total_requests - total_failures).to_f / total_requests * 100).round(2) : 100.0,
      workers: @workers.map { |w| worker_stats(w) }
    }
  end
  
  def get_worker_by_session(session_id)
    return nil unless @sticky_sessions && session_id
    
    worker_id = @session_store.get(session_id)
    return nil unless worker_id
    
    @workers.find { |w| w[:id] == worker_id && w[:status] == :healthy }
  end
  
  def bind_session(session_id, worker)
    return unless @sticky_sessions && session_id
    
    @session_store.put(session_id, worker[:id])
  end
  
  def unbind_session(session_id)
    return unless @sticky_sessions && session_id
    
    @session_store.delete(session_id)
  end
  
  private
  
  def validate_algorithm
    unless ALGORITHMS.include?(@algorithm)
      raise ArgumentError, "Invalid algorithm: #{@algorithm}. Must be one of: #{ALGORITHMS.join(', ')}"
    end
  end
  
  def round_robin_select(workers)
    index = @current_index.get_and_increment % workers.size
    workers[index]
  end
  
  def least_connections_select(workers)
    workers.min_by { |w| w[:connections].get }
  end
  
  def weighted_select(workers)
    total_weight = workers.sum { |w| w[:weight] }
    random_weight = rand(total_weight)
    
    current_weight = 0
    workers.each do |worker|
      current_weight += worker[:weight]
      return worker if random_weight < current_weight
    end
    
    workers.last
  end
  
  def ip_hash_select(workers, client_ip)
    return workers.first unless client_ip
    
    hash = Digest::MD5.hexdigest(client_ip).to_i(16)
    index = hash % workers.size
    workers[index]
  end
  
  def perform_health_checks
    @workers.each do |worker|
      check_worker_health(worker)
    end
  end
  
  def check_worker_health(worker)
    start_time = Time.now
    
    begin
      # Health check HTTP simple
      response = `curl -s -o /dev/null -w "%{http_code},%{time_total}" --max-time 5 http://#{worker[:host]}:#{worker[:port]}/health 2>/dev/null`
      
      if response && !response.empty?
        status_code, response_time = response.strip.split(',')
        
        if status_code == '200'
          worker[:status] = :healthy
          worker[:response_time].set(response_time.to_f * 1000) # Convert to ms
          update_worker_metrics(worker)
        else
          mark_worker_unhealthy(worker, "HTTP #{status_code}")
        end
      else
        mark_worker_unhealthy(worker, "No response")
      end
      
      worker[:last_check] = Time.now
      
    rescue => e
      mark_worker_unhealthy(worker, e.message)
    end
  end
  
  def mark_worker_unhealthy(worker, reason)
    if worker[:status] == :healthy
      puts "⚫️ Worker #{worker[:id]} marked unhealthy: #{reason}"
    end
    worker[:status] = :unhealthy
  end
  
  def update_worker_metrics(worker)
    # Simuler metriques systeme (remplacer par vraies metriques)
    worker[:cpu_usage] = rand(5.0..95.0).round(1)
    worker[:memory_usage] = rand(10.0..85.0).round(1)
  end
  
  def worker_stats(worker)
    {
      id: worker[:id],
      host: worker[:host],
      port: worker[:port],
      status: worker[:status],
      connections: worker[:connections].get,
      total_requests: worker[:total_requests].get,
      failed_requests: worker[:failed_requests].get,
      success_rate: calculate_success_rate(worker),
      avg_response_time: worker[:response_time].get.round(2),
      cpu_usage: worker[:cpu_usage],
      memory_usage: worker[:memory_usage],
      weight: worker[:weight],
      last_check: worker[:last_check]
    }
  end
  
  def calculate_success_rate(worker)
    total = worker[:total_requests].get
    return 100.0 if total == 0
    
    failed = worker[:failed_requests].get
    ((total - failed).to_f / total * 100).round(2)
  end
end

# Proxy WebSocket pour load balancing
class WebSocketProxy
  def initialize(load_balancer)
    @load_balancer = load_balancer
    @active_connections = Concurrent::Map.new
  end
  
  def handle_connection(client_socket, client_ip, session_id = nil)
    # Obtenir worker optimal
    worker = @load_balancer.get_worker_by_session(session_id) || 
             @load_balancer.get_worker(client_ip, session_id)
    
    unless worker
      client_socket.close
      return false
    end
    
    begin
      # Etablir connexion avec worker
      backend_socket = TCPSocket.new(worker[:host], worker[:port])
      
      # Enregistrer connexion
      connection_id = "#{client_ip}:#{client_socket.object_id}"
      @active_connections[connection_id] = {
        worker: worker,
        client: client_socket,
        backend: backend_socket,
        start_time: Time.now
      }
      
      @load_balancer.increment_connections(worker)
      @load_balancer.bind_session(session_id, worker) if session_id
      
      # Proxy bidirectionnel
      proxy_data(client_socket, backend_socket, worker, connection_id)
      
      true
    rescue => e
      puts "⚫️ Proxy error: #{e.message}"
      cleanup_connection(connection_id)
      false
    end
  end
  
  private
  
  def proxy_data(client_socket, backend_socket, worker, connection_id)
    threads = []
    
    # Client vers backend
    threads << Thread.new do
      begin
        while data = client_socket.readpartial(4096)
          backend_socket.write(data)
        end
      rescue => e
        puts "⚫️ Client to backend error: #{e.message}"
      ensure
        backend_socket.close rescue nil
      end
    end
    
    # Backend vers client
    threads << Thread.new do
      begin
        while data = backend_socket.readpartial(4096)
          client_socket.write(data)
        end
      rescue => e
        puts "⚫️ Backend to client error: #{e.message}"
      ensure
        client_socket.close rescue nil
      end
    end
    
    # Attendre fin de connexion
    threads.each(&:join)
    cleanup_connection(connection_id)
  end
  
  def cleanup_connection(connection_id)
    connection = @active_connections.delete(connection_id)
    return unless connection
    
    worker = connection[:worker]
    duration = Time.now - connection[:start_time]
    
    @load_balancer.decrement_connections(worker)
    @load_balancer.record_request(worker, duration * 1000, true)
    
    connection[:client].close rescue nil
    connection[:backend].close rescue nil
  end
end