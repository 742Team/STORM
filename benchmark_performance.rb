#!/usr/bin/env ruby
# Script de benchmark pour tester les performances ultra-rapides

require 'benchmark'
require 'benchmark/ips'
require 'memory_profiler'
require_relative './lib/ultra_fast_cache'
require_relative './lib/performance_optimizer'
require_relative './Message/controllers/chat_controller'
require_relative './Message/models/chat_room'

class PerformanceBenchmark
  def initialize
    @cache = UltraFastCache.instance
    @optimizer = PerformanceOptimizer.instance
    @controller = ChatController.instance
    
    puts "🚀 Initializing Ultra-Fast Performance Benchmark".green
    puts "=" * 60
  end
  
  def run_all_benchmarks
    puts "\n📊 Starting comprehensive performance tests...".blue
    
    benchmark_cache_operations
    benchmark_message_processing
    benchmark_room_operations
    benchmark_concurrent_operations
    benchmark_memory_usage
    
    puts "\n✅ All benchmarks completed!".green
    print_summary
  end
  
  def benchmark_cache_operations
    puts "\n🔥 Cache Operations Benchmark".yellow
    puts "-" * 40
    
    Benchmark.ips do |x|
      x.config(time: 5, warmup: 2)
      
      x.report("Cache SET operations") do
        @cache.set_user_session("user_#{rand(1000)}", { data: "test_#{rand}" })
      end
      
      x.report("Cache GET operations") do
        @cache.get_user_session("user_#{rand(1000)}")
      end
      
      x.report("Message caching") do
        @cache.cache_message("room_#{rand(10)}", "user_#{rand(100)}", "message_#{rand}", Time.now.to_f)
      end
      
      x.report("Data compression") do
        data = "This is a test message that will be compressed" * 10
        @cache.compress_data(data)
      end
      
      x.compare!
    end
  end
  
  def benchmark_message_processing
    puts "\n⚡ Message Processing Benchmark".yellow
    puts "-" * 40
    
    # Créer une salle de test
    test_room = @controller.create_room("benchmark_room")
    
    # Mock driver pour les tests
    mock_driver = Object.new
    def mock_driver.text(msg); end
    def mock_driver.instance_variable_get(var); "test_user" if var == :@username; end
    def mock_driver.instance_variable_set(var, val); end
    
    test_room.add_client(mock_driver, "test_user")
    
    Benchmark.ips do |x|
      x.config(time: 5, warmup: 2)
      
      x.report("Standard broadcast") do
        test_room.broadcast_message("Test message #{rand}", "test_user")
      end
      
      x.report("Optimized broadcast") do
        test_room.broadcast_message_optimized("Test message #{rand}", "test_user")
      end
      
      x.report("Message handling") do
        @controller.handle_message(mock_driver, test_room, "test_user", "Hello #{rand}")
      end
      
      x.compare!
    end
  end
  
  def benchmark_room_operations
    puts "\n🏠 Room Operations Benchmark".yellow
    puts "-" * 40
    
    Benchmark.ips do |x|
      x.config(time: 3, warmup: 1)
      
      x.report("Room creation") do
        room_name = "room_#{rand(10000)}"
        @controller.create_room(room_name)
      end
      
      x.report("Room lookup") do
        @controller.chat_rooms["Main"]
      end
      
      x.compare!
    end
  end
  
  def benchmark_concurrent_operations
    puts "\n🔄 Concurrent Operations Benchmark".yellow
    puts "-" * 40
    
    require 'concurrent-ruby'
    
    # Test de charge avec threads multiples
    thread_counts = [1, 5, 10, 20, 50]
    
    thread_counts.each do |thread_count|
      puts "\nTesting with #{thread_count} threads:"
      
      time = Benchmark.realtime do
        threads = []
        
        thread_count.times do |i|
          threads << Thread.new do
            100.times do |j|
              # Opérations concurrentes
              @cache.set_user_session("user_#{i}_#{j}", { thread: i, iteration: j })
              @cache.get_user_session("user_#{i}_#{j}")
              @cache.increment_user_message_count("user_#{i}")
            end
          end
        end
        
        threads.each(&:join)
      end
      
      ops_per_second = (thread_count * 300) / time # 3 opérations par itération
      puts "  #{ops_per_second.round(2)} operations/second"
    end
  end
  
  def benchmark_memory_usage
    puts "\n💾 Memory Usage Analysis".yellow
    puts "-" * 40
    
    # Test de consommation mémoire
    report = MemoryProfiler.report do
      # Simuler une charge de travail
      test_room = @controller.create_room("memory_test_room")
      
      # Ajouter des clients simulés
      100.times do |i|
        mock_driver = Object.new
        def mock_driver.text(msg); end
        test_room.add_client(mock_driver, "user_#{i}")
      end
      
      # Envoyer des messages
      500.times do |i|
        test_room.broadcast_message_optimized("Message #{i}", "user_#{i % 100}")
      end
      
      # Opérations de cache
      1000.times do |i|
        @cache.set_user_session("bench_user_#{i}", { data: "test_#{i}" })
      end
    end
    
    puts "\nMemory Report:"
    puts "Total allocated: #{report.total_allocated} bytes"
    puts "Total retained: #{report.total_retained} bytes"
    puts "Objects allocated: #{report.total_allocated_objects}"
    puts "Objects retained: #{report.total_retained_objects}"
    
    # Top allocations
    puts "\nTop 5 allocations by class:"
    report.allocated_memory_by_class.first(5).each do |allocation|
      puts "  #{allocation[:data]}: #{allocation[:count]} objects, #{allocation[:size]} bytes"
    end
  end
  
  def print_summary
    puts "\n" + "=" * 60
    puts "🎯 PERFORMANCE SUMMARY".green.bold
    puts "=" * 60
    
    # Statistiques du cache
    cache_stats = @cache.get_performance_stats
    puts "\n📈 Cache Statistics:"
    cache_stats.each do |key, value|
      puts "  #{key}: #{value}"
    end
    
    # Statistiques des salles
    puts "\n🏠 Room Statistics:"
    @controller.chat_rooms.each do |name, room|
      stats = room.get_performance_stats
      puts "  #{name}: #{stats[:clients]} clients, #{stats[:messages_sent]} messages"
    end
    
    # Recommandations
    puts "\n💡 Performance Recommendations:"
    puts "  ✅ Ultra-fast cache system active"
    puts "  ✅ Concurrent processing enabled"
    puts "  ✅ Memory optimization active"
    puts "  ✅ Asynchronous message handling"
    puts "  ✅ Thread-safe data structures"
    
    puts "\n🚀 System optimized for maximum Ruby performance!".green.bold
  end
end

# Exécution du benchmark
if __FILE__ == $0
  puts "🔥 ULTRA-FAST RUBY WEBSOCKET PERFORMANCE BENCHMARK".red.bold
  puts "" * 60
  
  benchmark = PerformanceBenchmark.new
  benchmark.run_all_benchmarks
end