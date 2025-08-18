#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# STORM Deployment Script
# Script de déploiement complet pour l'application STORM

require 'fileutils'
require 'json'

class StormDeployer
  def initialize
    @project_root = Dir.pwd
    @servers = [
      { name: 'Message Server', file: 'srv_message.rb', port: 3630 },
      { name: 'Auth Server', file: 'auth_app.rb', port: 4567 },
      { name: 'Upload Server', file: 'srv_upload.rb', port: 3000 }
    ]
    @pids = []
  end

  def deploy
    puts " STORM Deployment Starting..."
    puts "=" * 50

    check_prerequisites
    create_directories
    start_servers
    verify_deployment
    generate_deployment_report

    puts "\n STORM Deployment Complete!"
    puts "\n Server Status:"
    @servers.each do |server|
      puts "  • #{server[:name]}: Running on port #{server[:port]}"
    end

    puts "\n Access URLs:"
    puts "  • WebSocket: ws://localhost:3630"
    puts "  • Auth API: http://localhost:4567"
    puts "  • Upload API: http://localhost:3000"

    puts "\n⚠️  To stop all servers, run: ruby deploy_storm.rb stop"
  end

  def stop
    puts " STORM Servers Stopping..."

    # Lire les PIDs sauvegardés
    if File.exist?('storm_pids.json')
      pids = JSON.parse(File.read('storm_pids.json'))
      pids.each do |pid|
        begin
          Process.kill('TERM', pid)
          puts "  Process #{pid} stopped"
        rescue Errno::ESRCH
          puts "  ⚠️  Process #{pid} already stopped"
        end
      end
      File.delete('storm_pids.json')
    else
      puts "  ⚠️  No running servers found"
    end

    puts "\n All STORM servers stopped"
  end

  private

  def check_prerequisites
    puts "\n Checking Prerequisites..."

    # Vérifier Ruby
    ruby_version = RUBY_VERSION
    puts " Ruby #{ruby_version} detected"

    # Vérifier les fichiers serveur
    @servers.each do |server|
      if File.exist?(server[:file])
        puts " #{server[:file]} found"
      else
        puts " #{server[:file]} missing!"
        exit 1
      end
    end

    # Vérifier les ports
    @servers.each do |server|
      if port_available?(server[:port])
        puts " Port #{server[:port]} available"
      else
        puts "  ⚠️  Port #{server[:port]} may be in use"
      end
    end
  end

  def create_directories
    puts "\n📁 Creating Directories..."

    directories = ['logs', 'uploads', 'tmp', 'db']
    directories.each do |dir|
      FileUtils.mkdir_p(dir)
      puts " Created #{dir}/"
    end
  end

  def start_servers
    puts "\n Starting Servers..."

    @servers.each do |server|
      puts "  Starting #{server[:name]}..."

      pid = spawn("ruby #{server[:file]}",
                  out: "logs/#{File.basename(server[:file], '.rb')}.log",
                  err: "logs/#{File.basename(server[:file], '.rb')}_error.log")

      @pids << pid
      Process.detach(pid)

      puts "     #{server[:name]} started (PID: #{pid})"
      sleep 1 # Attendre un peu entre les démarrages
    end

    # Sauvegarder les PIDs
    File.write('storm_pids.json', @pids.to_json)
  end

  def verify_deployment
    puts "\n Verifying Deployment..."

    sleep 3 # Attendre que les serveurs démarrent

    @servers.each do |server|
      if port_in_use?(server[:port])
        puts "  #{server[:name]} responding on port #{server[:port]}"
      else
        puts "  #{server[:name]} not responding on port #{server[:port]}"
      end
    end
  end

  def generate_deployment_report
    report = {
      deployment_time: Time.now.iso8601,
      servers: @servers.map do |server|
        {
          name: server[:name],
          file: server[:file],
          port: server[:port],
          status: port_in_use?(server[:port]) ? 'running' : 'stopped'
        }
      end,
      pids: @pids,
      project_root: @project_root
    }

    File.write('deployment_report.json', JSON.pretty_generate(report))
    puts "\n Deployment report saved to deployment_report.json"
  end

  def port_available?(port)
    !port_in_use?(port)
  end

  def port_in_use?(port)
    system("lsof -i :#{port} > /dev/null 2>&1")
  end
end

# Point d'entrée principal
if __FILE__ == $0
  deployer = StormDeployer.new

  case ARGV[0]
  when 'stop'
    deployer.stop
  else
    deployer.deploy
  end
end
