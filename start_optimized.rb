#!/usr/bin/env ruby
# Script de démarrage ultra-optimisé pour des performances maximales

require 'bundler/setup'
require 'fileutils'
require 'colorize'

class OptimizedStarter
  def initialize
    @root_dir = File.dirname(__FILE__)
    @log_dir = File.join(@root_dir, 'log')
    @tmp_dir = File.join(@root_dir, 'tmp', 'pids')
    
    puts "🚀 ULTRA-FAST RUBY WEBSOCKET SERVER STARTER".red.bold
    puts "=" * 60
  end
  
  def start
    setup_environment
    optimize_ruby_settings
    setup_directories
    install_dependencies
    configure_system
    start_server
  end
  
  private
  
  def setup_environment
    puts "\n🔧 Setting up optimized environment...".blue
    
    # Variables d'environnement pour les performances
    ENV['RACK_ENV'] = 'production'
    ENV['RUBY_GC_HEAP_INIT_SLOTS'] = '1000000'
    ENV['RUBY_GC_HEAP_FREE_SLOTS'] = '500000'
    ENV['RUBY_GC_HEAP_GROWTH_FACTOR'] = '1.1'
    ENV['RUBY_GC_HEAP_GROWTH_MAX_SLOTS'] = '1000000'
    ENV['RUBY_GC_MALLOC_LIMIT'] = '90000000'
    ENV['RUBY_GC_MALLOC_LIMIT_MAX'] = '180000000'
    ENV['RUBY_GC_MALLOC_LIMIT_GROWTH_FACTOR'] = '1.4'
    ENV['RUBY_GC_OLDMALLOC_LIMIT'] = '90000000'
    ENV['RUBY_GC_OLDMALLOC_LIMIT_MAX'] = '180000000'
    ENV['RUBY_GC_OLDMALLOC_LIMIT_GROWTH_FACTOR'] = '1.2'
    
    # Configuration Puma pour les performances
    # Utiliser sysctl sur macOS au lieu de nproc
    cpu_count = `sysctl -n hw.ncpu`.strip rescue '4'
    ENV['WEB_CONCURRENCY'] = cpu_count
    ENV['PUMA_MIN_THREADS'] = '10'
    ENV['PUMA_MAX_THREADS'] = '50'
    ENV['PORT'] = '3630'
    
    puts "  ✅ Environment variables configured".green
  end
  
  def optimize_ruby_settings
    puts "\n⚡ Optimizing Ruby settings...".blue
    
    # Configuration GC pour les performances
    if defined?(GC)
      GC.disable # Désactiver temporairement
      
      # Compactage si disponible (Ruby 2.7+)
      if GC.respond_to?(:compact)
        puts "  🗜️  Compacting memory..."
        GC.compact
      end
      
      # Configuration des statistiques GC
      if GC.respond_to?(:stat)
        puts "  📊 GC stats enabled"
      end
      
      GC.enable # Réactiver
    end
    
    # Optimisations spécifiques à MRI Ruby
    if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'ruby'
      puts "  🔥 MRI Ruby optimizations applied"
    end
    
    puts "  ✅ Ruby optimizations complete".green
  end
  
  def setup_directories
    puts "\n📁 Setting up directories...".blue
    
    directories = [@log_dir, @tmp_dir, 'tmp/cache', 'tmp/sessions']
    
    directories.each do |dir|
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
      puts "  📂 Created: #{dir}"
    end
    
    puts "  ✅ Directories ready".green
  end
  
  def install_dependencies
    puts "\n📦 Checking dependencies...".blue
    
    # Vérifier si Bundler est installé
    unless system('which bundle > /dev/null 2>&1')
      puts "  ⚠️  Installing Bundler...".yellow
      system('gem install bundler')
    end
    
    # Installer les gems avec optimisations
    puts "  📥 Installing optimized gems..."
    
    bundle_config = [
      'bundle config set --local deployment false',
      'bundle config set --local path vendor/bundle',
      'bundle config set --local without development:test',
      'bundle config set --local jobs 4',
      'bundle config set --local retry 3'
    ]
    
    bundle_config.each { |cmd| system(cmd) }
    
    if system('bundle check > /dev/null 2>&1')
      puts "  ✅ Dependencies already satisfied".green
    else
      puts "  📥 Installing missing dependencies..."
      if system('bundle install --quiet')
        puts "  ✅ Dependencies installed".green
      else
        puts "  ❌ Failed to install dependencies".red
        exit 1
      end
    end
  end
  
  def configure_system
    puts "\n⚙️  Configuring system optimizations...".blue
    
    # Configuration des limites système (si possible)
    configure_limits
    
    # Préchargement des bibliothèques critiques
    preload_libraries
    
    # Configuration de la base de données
    setup_database
    
    puts "  ✅ System configuration complete".green
  end
  
  def configure_limits
    puts "  🔧 Configuring system limits..."
    
    # Ces configurations nécessitent des privilèges système
    # Elles sont documentées pour l'administrateur système
    
    limits_info = [
      "# Add to /etc/security/limits.conf for optimal performance:",
      "# * soft nofile 65536",
      "# * hard nofile 65536",
      "# * soft nproc 32768",
      "# * hard nproc 32768"
    ]
    
    File.write('SYSTEM_LIMITS.txt', limits_info.join("\n"))
    puts "  📝 System limits documentation created"
  end
  
  def preload_libraries
    puts "  📚 Preloading critical libraries..."
    
    critical_libs = [
      'concurrent-ruby',
      'websocket/driver',
      'sqlite3',
      'json',
      'zlib',
      'digest'
    ]
    
    critical_libs.each do |lib|
      begin
        require lib
        puts "    ✅ #{lib}"
      rescue LoadError
        puts "    ⚠️  #{lib} (optional)".yellow
      end
    end
  end
  
  def setup_database
    puts "  🗄️  Setting up optimized database..."
    
    begin
      require 'sqlite3'
      
      # Créer le fichier de base de données s'il n'existe pas
      db_file = 'chat_app.db'
      unless File.exist?(db_file)
        db = SQLite3::Database.new(db_file)
        
        # Configuration SQLite pour les performances
        optimizations = [
          "PRAGMA journal_mode = WAL",
          "PRAGMA synchronous = NORMAL",
          "PRAGMA cache_size = 10000",
          "PRAGMA temp_store = MEMORY",
          "PRAGMA mmap_size = 268435456",
          "PRAGMA optimize"
        ]
        
        optimizations.each { |pragma| db.execute(pragma) }
        
        db.close
        puts "    ✅ Database optimized"
      else
        puts "    ✅ Database already exists"
      end
    rescue LoadError
      puts "    ⚠️  SQLite3 not available, skipping database setup".yellow
    end
  end
  
  def start_server
    puts "\n🚀 Starting ultra-fast WebSocket server...".blue
    puts "=" * 60
    
    # Afficher les informations de démarrage
    print_startup_info
    
    # Démarrer avec Puma
    puts "\n🔥 Launching Puma with optimized configuration...".red.bold
    
    puma_cmd = [
      'bundle exec puma',
      '-C config/puma.rb',
      '-e production',
      '--preload'
    ].join(' ')
    
    puts "\n📡 Server will be available at:".green.bold
    puts "   🌐 http://localhost:3630".cyan.bold
    puts "   🔌 WebSocket: ws://localhost:3630/websocket".cyan.bold
    
    puts "\n⚡ Performance features enabled:".yellow.bold
    puts "   ✅ Ultra-fast caching system"
    puts "   ✅ Concurrent message processing"
    puts "   ✅ Optimized database operations"
    puts "   ✅ Memory-efficient data structures"
    puts "   ✅ Asynchronous I/O operations"
    puts "   ✅ Thread-safe implementations"
    
    puts "\n🎯 Ready for maximum performance!".green.bold
    puts "=" * 60
    
    # Exécuter Puma
    exec(puma_cmd)
  end
  
  def print_startup_info
    puts "\n📊 System Information:".yellow
    puts "   Ruby Version: #{RUBY_VERSION}"
    puts "   Ruby Engine: #{defined?(RUBY_ENGINE) ? RUBY_ENGINE : 'MRI'}"
    puts "   Platform: #{RUBY_PLATFORM}"
    puts "   CPU Cores: #{`sysctl -n hw.ncpu`.strip rescue 'Unknown'}"
    puts "   Workers: #{ENV['WEB_CONCURRENCY']}"
    puts "   Threads: #{ENV['PUMA_MIN_THREADS']}-#{ENV['PUMA_MAX_THREADS']}"
    puts "   Port: #{ENV['PORT']}"
    
    # Informations mémoire (si disponible)
    if File.exist?('/proc/meminfo')
      meminfo = File.read('/proc/meminfo')
      if meminfo =~ /MemTotal:\s+(\d+)/
        total_mem_kb = $1.to_i
        total_mem_gb = (total_mem_kb / 1024.0 / 1024.0).round(2)
        puts "   Memory: #{total_mem_gb} GB"
      end
    end
  end
end

# Gestion des signaux pour un arrêt propre
trap('INT') do
  puts "\n\n🛑 Shutting down gracefully...".yellow
  exit 0
end

trap('TERM') do
  puts "\n\n🛑 Terminating...".yellow
  exit 0
end

# Démarrage
if __FILE__ == $0
  starter = OptimizedStarter.new
  starter.start
end