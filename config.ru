#!/usr/bin/env ruby

# Configuration Rack pour le backoffice STORM

require 'bundler/setup'
require 'sinatra/base'
require 'json'
require 'logger'
require 'fileutils'
require 'time'
require 'thread'
require 'monitor'
require 'benchmark'
require 'etc'

# Configuration et optimisations de performance
require_relative 'config/performance'
require_relative 'lib/auto_scaler'
require_relative 'lib/load_balancer'
require_relative 'lib/compression_engine'
require_relative 'lib/connection_manager'
require_relative 'lib/error_handler'
require_relative 'lib/metrics_collector'

# Configuration Sinatra sera dans la classe StormApp

# Configuration des logs
FileUtils.mkdir_p('log') unless Dir.exist?('log')
$logger = Logger.new('log/storm.log', 'daily')
$logger.level = Logger::INFO
$logger.formatter = proc do |severity, datetime, progname, msg|
  "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
end

# Variables globales pour les modules d'optimisation
$auto_scaler = nil
$load_balancer = nil
$compression_engine = nil
$connection_manager = nil
$error_handler = nil
$metrics_collector = nil

# Initialisation des modules d'optimisation
begin
  puts "Initialisation des modules d'optimisation STORM..."
  
  # Gestionnaire d'erreurs global
  $error_handler = STORM::ErrorHandler.new(
    max_errors: STORM::Performance::SYSTEM_CONFIG[:error_handling][:max_errors_per_minute],
    recovery_strategies: STORM::Performance::SYSTEM_CONFIG[:error_handling][:recovery_strategies]
  )
  
  # Collecteur de métriques avec alertes
  $metrics_collector = STORM::MetricsCollector.new(
    collection_interval: STORM::Performance::SYSTEM_CONFIG[:monitoring][:metrics_interval],
    alert_thresholds: {
      cpu_usage: 80,
      memory_usage: 85,
      error_rate: 50,
      response_time: 1000
    }
  )
  
  # Configuration des callbacks pour les erreurs
  $metrics_collector.on_alert do |alert|
    $error_handler.handle_error(
      StandardError.new("Alert: #{alert[:type]} - #{alert[:message]}"),
      { context: 'metrics_alert', alert: alert }
    )
  end
  
  # Auto-scaler intelligent
  $auto_scaler = STORM::AutoScaler.new(
    min_workers: STORM::Performance::SYSTEM_CONFIG[:auto_scaling][:min_workers],
    max_workers: STORM::Performance::SYSTEM_CONFIG[:auto_scaling][:max_workers],
    cpu_threshold: STORM::Performance::SYSTEM_CONFIG[:auto_scaling][:cpu_threshold],
    memory_threshold: STORM::Performance::SYSTEM_CONFIG[:auto_scaling][:memory_threshold]
  )
  
  # Load balancer avec failover
  $load_balancer = STORM::LoadBalancer.new(
    algorithm: STORM::Performance::SYSTEM_CONFIG[:load_balancing][:algorithm],
    health_check_interval: STORM::Performance::SYSTEM_CONFIG[:load_balancing][:health_check_interval],
    enable_sticky_sessions: STORM::Performance::SYSTEM_CONFIG[:load_balancing][:sticky_sessions]
  )
  
  # Moteur de compression ultra-optimisé
  $compression_engine = STORM::CompressionEngine.new(
    default_algorithm: STORM::Performance::SYSTEM_CONFIG[:compression][:algorithm],
    compression_level: STORM::Performance::SYSTEM_CONFIG[:compression][:level],
    min_size_threshold: STORM::Performance::SYSTEM_CONFIG[:compression][:min_size],
    enable_cache: STORM::Performance::SYSTEM_CONFIG[:compression][:cache_enabled],
    enable_stats: STORM::Performance::SYSTEM_CONFIG[:compression][:stats_enabled]
  )
  
  # Gestionnaire de connexions ultra-optimisé
  $connection_manager = STORM::ConnectionManager.new(
    max_connections_per_worker: STORM::Performance::SYSTEM_CONFIG[:connections][:max_per_worker],
    rate_limit_requests: STORM::Performance::SYSTEM_CONFIG[:connections][:rate_limit_per_minute],
    session_timeout: STORM::Performance::SYSTEM_CONFIG[:connections][:session_timeout],
    cleanup_interval: STORM::Performance::SYSTEM_CONFIG[:connections][:cleanup_interval]
  )
  
  # Démarrage du monitoring
  $metrics_collector.start_monitoring
  $auto_scaler.start_monitoring
  
  # Ajout des collecteurs personnalisés
  $metrics_collector.add_custom_collector('active_connections') do
    $connection_manager&.get_comprehensive_stats&.dig(:total_connections) || 0
  end
  
  $metrics_collector.add_custom_collector('active_workers') do
    $auto_scaler&.get_statistics&.dig(:current_workers) || 0
  end
  
  $metrics_collector.add_custom_collector('compression_ratio') do
    $compression_engine&.get_statistics&.dig(:compression, :avg_ratio) || 0
  end
  
  # Ajout de workers initiaux
  3.times { $auto_scaler.add_worker }
  
  puts "Modules d'optimisation STORM initialisés avec succès!"
  $logger.info "STORM Server initialized with all optimization modules"
  
rescue => e
  puts "Erreur lors de l'initialisation: #{e.message}"
  $logger.error "Failed to initialize STORM modules: #{e.message}"
  $logger.error e.backtrace.join("\n")
end

# Helpers pour le formatage
def format_number(num)
  return '0' unless num
  if num >= 1_000_000
    "#{(num / 1_000_000.0).round(1)}M"
  elsif num >= 1_000
    "#{(num / 1_000.0).round(1)}K"
  else
    num.to_s
  end
end

def format_bytes(bytes)
  return '0 B' unless bytes
  units = ['B', 'KB', 'MB', 'GB', 'TB']
  size = bytes.to_f
  unit_index = 0
  
  while size >= 1024 && unit_index < units.length - 1
    size /= 1024
    unit_index += 1
  end
  
  "#{size.round(2)} #{units[unit_index]}"
end

def format_duration(seconds)
  return '0s' unless seconds
  if seconds >= 3600
    "#{(seconds / 3600).round(1)}h"
  elsif seconds >= 60
    "#{(seconds / 60).round(1)}m"
  else
    "#{seconds.round(1)}s"
  end
end

def generate_system_alerts(auto_stats, error_stats, metrics_stats)
  alerts = []
  
  # Vérification CPU
  cpu_usage = auto_stats[:avg_cpu_usage] || 0
  if cpu_usage > 80
    alerts << "<div class=\"alert-item alert-error\">CPU élevé: #{cpu_usage}%</div>"
  elsif cpu_usage > 60
    alerts << "<div class=\"alert-item alert-warning\">CPU modéré: #{cpu_usage}%</div>"
  else
    alerts << "<div class=\"alert-item alert-success\">CPU normal: #{cpu_usage}%</div>"
  end
  
  # Vérification erreurs
  error_rate = error_stats[:error_rate_per_minute] || 0
  if error_rate > 50
    alerts << "<div class=\"alert-item alert-error\">Taux d'erreur élevé: #{error_rate}/min</div>"
  elsif error_rate > 10
    alerts << "<div class=\"alert-item alert-warning\">Taux d'erreur modéré: #{error_rate}/min</div>"
  else
    alerts << "<div class=\"alert-item alert-success\">Taux d'erreur normal: #{error_rate}/min</div>"
  end
  
  # Vérification alertes actives
  active_alerts = metrics_stats[:active_alerts] || 0
  if active_alerts > 0
    alerts << "<div class=\"alert-item alert-error\">#{active_alerts} alertes actives</div>"
  else
    alerts << "<div class=\"alert-item alert-success\">Aucune alerte active</div>"
  end
  
  alerts.join("\n")
end

# Application Sinatra
class StormApp < Sinatra::Base
  
  # Configuration Sinatra
  set :server, 'puma'
  set :bind, '0.0.0.0'
  set :port, 3631
  set :environment, :development
  set :logging, true
  set :dump_errors, true
  set :show_exceptions, true
  
  # Backoffice épuré - Dashboard principal
  get '/' do
    begin
      # Collecte des statistiques de tous les modules
      auto_stats = $auto_scaler&.get_statistics || {}
      lb_stats = $load_balancer&.get_statistics || {}
      compression_stats = $compression_engine&.get_statistics || {}
      connection_stats = $connection_manager&.get_comprehensive_stats || {}
      metrics_stats = $metrics_collector&.get_comprehensive_stats || {}
      error_stats = $error_handler&.get_stats || {}
      
      <<~HTML
        <!DOCTYPE html>
        <html lang="fr">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>STORM - Backoffice</title>
          <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
              background: #f5f5f7;
              color: #1d1d1f;
              line-height: 1.6;
            }
            .container {
              max-width: 1200px;
              margin: 0 auto;
              padding: 40px 20px;
            }
            .header {
              text-align: center;
              margin-bottom: 60px;
            }
            .header h1 {
              font-size: 48px;
              font-weight: 600;
              color: #1d1d1f;
              margin-bottom: 8px;
            }
            .header p {
              font-size: 21px;
              color: #86868b;
              font-weight: 400;
            }
            .status-bar {
              display: flex;
              justify-content: center;
              align-items: center;
              gap: 12px;
              margin: 30px 0;
              padding: 16px 24px;
              background: white;
              border-radius: 12px;
              box-shadow: 0 4px 20px rgba(0,0,0,0.08);
            }
            .status-dot {
              width: 8px;
              height: 8px;
              border-radius: 50%;
              background: #30d158;
            }
            .status-text {
              font-size: 17px;
              font-weight: 500;
              color: #1d1d1f;
            }
            .metrics-grid {
              display: grid;
              grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
              gap: 24px;
              margin-bottom: 40px;
            }
            .metric-card {
              background: white;
              border-radius: 12px;
              padding: 24px;
              box-shadow: 0 4px 20px rgba(0,0,0,0.08);
              transition: all 0.3s ease;
            }
            .metric-card:hover {
              transform: translateY(-2px);
              box-shadow: 0 8px 30px rgba(0,0,0,0.12);
            }
            .card-title {
              font-size: 19px;
              font-weight: 600;
              color: #1d1d1f;
              margin-bottom: 20px;
            }
            .metric-row {
              display: flex;
              justify-content: space-between;
              align-items: center;
              padding: 12px 0;
              border-bottom: 1px solid #f5f5f7;
            }
            .metric-row:last-child {
              border-bottom: none;
            }
            .metric-label {
              font-size: 15px;
              color: #86868b;
              font-weight: 400;
            }
            .metric-value {
              font-size: 17px;
              font-weight: 600;
              color: #1d1d1f;
            }
            .metric-value.success { color: #30d158; }
            .metric-value.warning { color: #ff9500; }
            .metric-value.error { color: #ff3b30; }
            .alert-section {
              background: white;
              border-radius: 12px;
              padding: 24px;
              margin: 24px 0;
              box-shadow: 0 4px 20px rgba(0,0,0,0.08);
            }
            .alert-title {
              font-size: 19px;
              font-weight: 600;
              color: #1d1d1f;
              margin-bottom: 16px;
            }
            .alert-item {
              padding: 12px 16px;
              margin: 8px 0;
              border-radius: 8px;
              font-size: 15px;
            }
            .alert-success {
              background: #d1f2eb;
              color: #00695c;
            }
            .alert-warning {
              background: #fff3cd;
              color: #856404;
            }
            .alert-error {
              background: #f8d7da;
              color: #721c24;
            }
            .nav-section {
              text-align: center;
              margin-top: 60px;
            }
            .nav-btn {
              display: inline-block;
              padding: 12px 24px;
              margin: 8px;
              background: #007aff;
              color: white;
              text-decoration: none;
              border-radius: 8px;
              font-size: 17px;
              font-weight: 500;
              transition: all 0.3s ease;
            }
            .nav-btn:hover {
              background: #0056cc;
              transform: translateY(-1px);
            }
            .refresh-indicator {
              position: fixed;
              bottom: 20px;
              right: 20px;
              background: white;
              padding: 12px 16px;
              border-radius: 8px;
              box-shadow: 0 4px 20px rgba(0,0,0,0.15);
              font-size: 13px;
              color: #86868b;
            }
          </style>
        </head>
        <body>
          <div class="refresh-indicator">
            Actualisation: 30s
          </div>
          
          <div class="container">
            <div class="header">
              <h1>STORM</h1>
              <p>Backoffice de monitoring</p>
              <div class="status-bar">
                <div class="status-dot"></div>
                <span class="status-text">Système opérationnel</span>
              </div>
            </div>
            
            <div class="metrics-grid">
              <div class="metric-card">
                <div class="card-title">Auto-Scaling</div>
                <div class="metric-row">
                  <span class="metric-label">Workers actifs</span>
                  <span class="metric-value">#{auto_stats[:current_workers] || 0}</span>
                </div>
                <div class="metric-row">
                  <span class="metric-label">CPU moyen</span>
                  <span class="metric-value #{(auto_stats[:avg_cpu_usage] || 0) > 80 ? 'error' : (auto_stats[:avg_cpu_usage] || 0) > 60 ? 'warning' : 'success'}">#{auto_stats[:avg_cpu_usage] || 0}%</span>
                </div>
                <div class="metric-row">
                  <span class="metric-label">Mémoire utilisée</span>
                  <span class="metric-value #{(auto_stats[:memory_usage] || 0) > 85 ? 'error' : (auto_stats[:memory_usage] || 0) > 70 ? 'warning' : 'success'}">#{auto_stats[:memory_usage] || 0}%</span>
                </div>
                <div class="metric-row">
                  <span class="metric-label">Events de scaling</span>
                  <span class="metric-value">#{auto_stats[:scaling_events] || 0}</span>
                </div>
              </div>
              
              <div class="metric-card">
                <div class="card-title">Load Balancing</div>
                <div class="metric-row">
                  <span class="metric-label">Algorithme</span>
                  <span class="metric-value">#{lb_stats[:algorithm] || 'Round Robin'}</span>
                </div>
                <div class="metric-row">
                  <span class="metric-label">Workers sains</span>
                  <span class="metric-value success">#{lb_stats[:healthy_workers] || 0}</span>
                </div>
                <div class="metric-row">
                  <span class="metric-label">Requêtes totales</span>
                  <span class="metric-value">#{format_number(lb_stats[:total_requests] || 0)}</span>
                </div>
                <div class="metric-row">
                  <span class="metric-label">Latence moyenne</span>
                  <span class="metric-value">#{lb_stats[:avg_response_time] || 0} ms</span>
                </div>
              </div>
              
              <div class="metric-card">
                <div class="card-title">Performance</div>
                <div class="metric-row">
                  <span class="metric-label">Compression</span>
                  <span class="metric-value success">#{compression_stats.dig(:compression, :avg_ratio) || 0}%</span>
                </div>
                <div class="metric-row">
                  <span class="metric-label">Connexions totales</span>
                  <span class="metric-value">#{format_number(connection_stats[:total_connections] || 0)}</span>
                </div>
                <div class="metric-row">
                  <span class="metric-label">Données économisées</span>
                  <span class="metric-value success">#{format_bytes(compression_stats.dig(:compression, :bytes_saved) || 0)}</span>
                </div>
                <div class="metric-row">
                  <span class="metric-label">Sessions actives</span>
                  <span class="metric-value">#{connection_stats[:active_sessions] || 0}</span>
                </div>
              </div>
              
              <div class="metric-card">
                <div class="card-title">Monitoring</div>
                <div class="metric-row">
                  <span class="metric-label">Points de données</span>
                  <span class="metric-value">#{format_number(metrics_stats[:total_data_points] || 0)}</span>
                </div>
                <div class="metric-row">
                  <span class="metric-label">Métriques actives</span>
                  <span class="metric-value">#{metrics_stats[:metrics_count] || 0}</span>
                </div>
                <div class="metric-row">
                  <span class="metric-label">Alertes actives</span>
                  <span class="metric-value #{(metrics_stats[:active_alerts] || 0) > 0 ? 'error' : 'success'}">#{metrics_stats[:active_alerts] || 0}</span>
                </div>
                <div class="metric-row">
                  <span class="metric-label">Collections/min</span>
                  <span class="metric-value">#{metrics_stats.dig(:collector_stats, :collections_per_minute) || 0}</span>
                </div>
              </div>
            </div>
            
            <div class="alert-section">
              <div class="alert-title">État du système</div>
              #{generate_system_alerts(auto_stats, error_stats, metrics_stats)}
            </div>
            
            <div class="nav-section">
              <a href="/logs" class="nav-btn">Logs Backend</a>
              <a href="/metrics" class="nav-btn">Métriques détaillées</a>
            </div>
          </div>
          
          <script>
            setTimeout(() => {
              window.location.reload();
            }, 30000);
          </script>
        </body>
        </html>
      HTML
      
    rescue => e
      $error_handler&.handle_error(e, { context: 'dashboard_render' })
      
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>STORM - Erreur</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; background: #f5f5f7; color: #1d1d1f; padding: 50px; text-align: center; }
            .error { background: #ff3b30; color: white; padding: 20px; border-radius: 12px; margin: 20px 0; }
          </style>
        </head>
        <body>
          <h1>Erreur système</h1>
          <div class="error">
            <p>Impossible de charger le dashboard.</p>
            <p>#{e.message}</p>
          </div>
        </body>
        </html>
      HTML
    end
  end
  
  # Page des logs backend
  get '/logs' do
    begin
      log_file = 'log/storm.log'
      logs = []
      
      if File.exist?(log_file)
        # Lire les 100 dernières lignes du log
        logs = File.readlines(log_file).last(100).reverse
      end
      
      <<~HTML
        <!DOCTYPE html>
        <html lang="fr">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>STORM - Logs Backend</title>
          <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
              background: #f5f5f7;
              color: #1d1d1f;
              line-height: 1.6;
            }
            .container {
              max-width: 1200px;
              margin: 0 auto;
              padding: 40px 20px;
            }
            .header {
              text-align: center;
              margin-bottom: 40px;
            }
            .header h1 {
              font-size: 36px;
              font-weight: 600;
              color: #1d1d1f;
              margin-bottom: 8px;
            }
            .header p {
              font-size: 17px;
              color: #86868b;
              font-weight: 400;
            }
            .logs-container {
              background: white;
              border-radius: 12px;
              padding: 24px;
              box-shadow: 0 4px 20px rgba(0,0,0,0.08);
              margin-bottom: 24px;
            }
            .logs-title {
              font-size: 19px;
              font-weight: 600;
              color: #1d1d1f;
              margin-bottom: 16px;
            }
            .log-entry {
              font-family: 'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace;
              font-size: 13px;
              padding: 8px 12px;
              margin: 4px 0;
              border-radius: 6px;
              background: #f5f5f7;
              border-left: 3px solid #86868b;
            }
            .log-entry.info {
              border-left-color: #007aff;
              background: #e3f2fd;
            }
            .log-entry.warn {
              border-left-color: #ff9500;
              background: #fff3e0;
            }
            .log-entry.error {
              border-left-color: #ff3b30;
              background: #ffebee;
            }
            .nav-section {
              text-align: center;
              margin-top: 40px;
            }
            .nav-btn {
              display: inline-block;
              padding: 12px 24px;
              margin: 8px;
              background: #007aff;
              color: white;
              text-decoration: none;
              border-radius: 8px;
              font-size: 17px;
              font-weight: 500;
              transition: all 0.3s ease;
            }
            .nav-btn:hover {
              background: #0056cc;
              transform: translateY(-1px);
            }
            .refresh-indicator {
              position: fixed;
              bottom: 20px;
              right: 20px;
              background: white;
              padding: 12px 16px;
              border-radius: 8px;
              box-shadow: 0 4px 20px rgba(0,0,0,0.15);
              font-size: 13px;
              color: #86868b;
            }
          </style>
        </head>
        <body>
          <div class="refresh-indicator">
            Actualisation: 15s
          </div>
          
          <div class="container">
            <div class="header">
              <h1>Logs Backend</h1>
              <p>Dernières entrées du système STORM</p>
            </div>
            
            <div class="logs-container">
              <div class="logs-title">Logs récents (#{logs.length} entrées)</div>
              #{logs.map { |log| 
                log_class = 'info'
                log_class = 'warn' if log.include?('WARN')
                log_class = 'error' if log.include?('ERROR')
                "<div class=\"log-entry #{log_class}\">#{log.strip}</div>"
              }.join("\n")}
            </div>
            
            <div class="nav-section">
              <a href="/" class="nav-btn">Dashboard</a>
              <a href="/metrics" class="nav-btn">Métriques</a>
            </div>
          </div>
          
          <script>
            setTimeout(() => {
              window.location.reload();
            }, 15000);
          </script>
        </body>
        </html>
      HTML
      
    rescue => e
      $error_handler&.handle_error(e, { context: 'logs_render' })
      
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>STORM - Erreur Logs</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; background: #f5f5f7; color: #1d1d1f; padding: 50px; text-align: center; }
            .error { background: #ff3b30; color: white; padding: 20px; border-radius: 12px; margin: 20px 0; }
          </style>
        </head>
        <body>
          <h1>Erreur logs</h1>
          <div class="error">
            <p>Impossible de charger les logs.</p>
            <p>#{e.message}</p>
          </div>
          <a href="/" style="color: #007aff;">Retour au dashboard</a>
        </body>
        </html>
      HTML
    end
  end
  
  # Page des métriques détaillées
  get '/metrics' do
    begin
      metrics_stats = $metrics_collector&.get_comprehensive_stats || {}
      auto_stats = $auto_scaler&.get_statistics || {}
      error_stats = $error_handler&.get_stats || {}
      
      <<~HTML
        <!DOCTYPE html>
        <html lang="fr">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>STORM - Métriques Détaillées</title>
          <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
              background: #f5f5f7;
              color: #1d1d1f;
              line-height: 1.6;
            }
            .container {
              max-width: 1200px;
              margin: 0 auto;
              padding: 40px 20px;
            }
            .header {
              text-align: center;
              margin-bottom: 40px;
            }
            .header h1 {
              font-size: 36px;
              font-weight: 600;
              color: #1d1d1f;
              margin-bottom: 8px;
            }
            .header p {
              font-size: 17px;
              color: #86868b;
              font-weight: 400;
            }
            .metrics-grid {
              display: grid;
              grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
              gap: 24px;
              margin-bottom: 40px;
            }
            .metric-card {
              background: white;
              border-radius: 12px;
              padding: 24px;
              box-shadow: 0 4px 20px rgba(0,0,0,0.08);
            }
            .card-title {
              font-size: 19px;
              font-weight: 600;
              color: #1d1d1f;
              margin-bottom: 20px;
            }
            .metric-row {
              display: flex;
              justify-content: space-between;
              align-items: center;
              padding: 12px 0;
              border-bottom: 1px solid #f5f5f7;
            }
            .metric-row:last-child {
              border-bottom: none;
            }
            .metric-label {
              font-size: 15px;
              color: #86868b;
              font-weight: 400;
            }
            .metric-value {
              font-size: 17px;
              font-weight: 600;
              color: #1d1d1f;
            }
            .metric-value.success { color: #30d158; }
            .metric-value.warning { color: #ff9500; }
            .metric-value.error { color: #ff3b30; }
            .nav-section {
              text-align: center;
              margin-top: 40px;
            }
            .nav-btn {
              display: inline-block;
              padding: 12px 24px;
              margin: 8px;
              background: #007aff;
              color: white;
              text-decoration: none;
              border-radius: 8px;
              font-size: 17px;
              font-weight: 500;
              transition: all 0.3s ease;
            }
            .nav-btn:hover {
              background: #0056cc;
              transform: translateY(-1px);
            }
            .refresh-indicator {
              position: fixed;
              bottom: 20px;
              right: 20px;
              background: white;
              padding: 12px 16px;
              border-radius: 8px;
              box-shadow: 0 4px 20px rgba(0,0,0,0.15);
              font-size: 13px;
              color: #86868b;
            }
          </style>
        </head>
        <body>
          <div class="refresh-indicator">
            Actualisation: 10s
          </div>
          
          <div class="container">
            <div class="header">
              <h1>Métriques Détaillées</h1>
              <p>Analyse approfondie des performances STORM</p>
            </div>
            
            <div class="metrics-grid">
              <div class="metric-card">
                <div class="card-title">Collecteur de Métriques</div>
                <div class="metric-row">
                  <span class="metric-label">Points de données totaux</span>
                  <span class="metric-value">#{format_number(metrics_stats[:total_data_points] || 0)}</span>
                </div>
                <div class="metric-row">
                  <span class="metric-label">Métriques actives</span>
                  <span class="metric-value">#{metrics_stats[:metrics_count] || 0}</span>
                </div>
                <div class="metric-row">
                  <span class="metric-label">Alertes actives</span>
                  <span class="metric-value #{(metrics_stats[:active_alerts] || 0) > 0 ? 'error' : 'success'}">#{metrics_stats[:active_alerts] || 0}</span>
                </div>
                <div class="metric-row">
                  <span class="metric-label">Collections par minute</span>
                  <span class="metric-value">#{metrics_stats.dig(:collector_stats, :collections_per_minute) || 0}</span>
                </div>
              </div>
              
              <div class="metric-card">
                <div class="card-title">Utilisation Système</div>
                <div class="metric-row">
                  <span class="metric-label">CPU moyen</span>
                  <span class="metric-value #{(auto_stats[:avg_cpu_usage] || 0) > 80 ? 'error' : (auto_stats[:avg_cpu_usage] || 0) > 60 ? 'warning' : 'success'}">#{auto_stats[:avg_cpu_usage] || 0}%</span>
                </div>
                <div class="metric-row">
                  <span class="metric-label">Mémoire utilisée</span>
                  <span class="metric-value #{(auto_stats[:memory_usage] || 0) > 85 ? 'error' : (auto_stats[:memory_usage] || 0) > 70 ? 'warning' : 'success'}">#{auto_stats[:memory_usage] || 0}%</span>
                </div>
                <div class="metric-row">
                  <span class="metric-label">Workers actifs</span>
                  <span class="metric-value">#{auto_stats[:current_workers] || 0}</span>
                </div>
                <div class="metric-row">
                  <span class="metric-label">Events de scaling</span>
                  <span class="metric-value">#{auto_stats[:scaling_events] || 0}</span>
                </div>
              </div>
              
              <div class="metric-card">
                <div class="card-title">Gestion d'Erreurs</div>
                <div class="metric-row">
                  <span class="metric-label">Erreurs totales</span>
                  <span class="metric-value #{(error_stats[:error_count] || 0) > 100 ? 'error' : ''}">#{error_stats[:error_count] || 0}</span>
                </div>
                <div class="metric-row">
                  <span class="metric-label">Erreurs par minute</span>
                  <span class="metric-value #{(error_stats[:error_rate_per_minute] || 0) > 50 ? 'error' : (error_stats[:error_rate_per_minute] || 0) > 10 ? 'warning' : ''}">#{error_stats[:error_rate_per_minute] || 0}</span>
                </div>
                <div class="metric-row">
                  <span class="metric-label">Récupérations réussies</span>
                  <span class="metric-value success">#{error_stats[:recovery_count] || 0}</span>
                </div>
                <div class="metric-row">
                  <span class="metric-label">Taux de succès</span>
                  <span class="metric-value success">#{error_stats[:recovery_success_rate] || 0}%</span>
                </div>
              </div>
            </div>
            
            <div class="nav-section">
              <a href="/" class="nav-btn">Dashboard</a>
              <a href="/logs" class="nav-btn">Logs Backend</a>
            </div>
          </div>
          
          <script>
            setTimeout(() => {
              window.location.reload();
            }, 10000);
          </script>
        </body>
        </html>
      HTML
      
    rescue => e
      $error_handler&.handle_error(e, { context: 'metrics_render' })
      
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>STORM - Erreur Métriques</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; background: #f5f5f7; color: #1d1d1f; padding: 50px; text-align: center; }
            .error { background: #ff3b30; color: white; padding: 20px; border-radius: 12px; margin: 20px 0; }
          </style>
        </head>
        <body>
          <h1>Erreur métriques</h1>
          <div class="error">
            <p>Impossible de charger les métriques.</p>
            <p>#{e.message}</p>
          </div>
          <a href="/" style="color: #007aff;">Retour au dashboard</a>
        </body>
        </html>
      HTML
    end
  end
end

# Configuration de l'application
run StormApp