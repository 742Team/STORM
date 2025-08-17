#!/usr/bin/env puma

# Configuration Puma simplifiée et compatible

# Nombre de workers (processus)
# Utiliser le nombre de CPU disponibles (macOS compatible)
cpu_count = begin
  `sysctl -n hw.ncpu`.strip.to_i
rescue
  4 # Fallback par défaut
end
workers ENV.fetch('WEB_CONCURRENCY', cpu_count).to_i

# Nombre de threads par worker
min_threads_count = ENV.fetch('PUMA_MIN_THREADS', 5).to_i
max_threads_count = ENV.fetch('PUMA_MAX_THREADS', 20).to_i
threads min_threads_count, max_threads_count

# Port d'écoute
port ENV.fetch('PORT', 3630)

# Environnement
environment ENV.fetch('RACK_ENV', 'development')

# Préchargement de l'application
preload_app!

# Configuration des timeouts
worker_timeout 60
worker_boot_timeout 30
worker_shutdown_timeout 15

# Logging
quiet false

# PID et state files
pidfile 'tmp/pids/puma.pid'
state_path 'tmp/pids/puma.state'

# Bind configuration
if ENV['RACK_ENV'] == 'production'
  bind 'tcp://0.0.0.0:3630'
else
  bind 'tcp://127.0.0.1:3630'
end

# Hooks
before_fork do
  puts "🚀 Puma master process starting..."
end

on_worker_boot do
  puts "⚡ Puma worker #{Process.pid} booted"
end

on_worker_shutdown do
  puts "🛑 Puma worker #{Process.pid} shutting down"
end

print "🎯 Puma configuration loaded\n"
print "   Workers: #{ENV.fetch('WEB_CONCURRENCY', cpu_count)}\n"
print "   Threads: #{min_threads_count}-#{max_threads_count}\n"
print "   Environment: #{ENV.fetch('RACK_ENV', 'development')}\n"
print "   Port: #{ENV.fetch('PORT', 3630)}\n"