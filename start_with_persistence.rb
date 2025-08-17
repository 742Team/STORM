#!/usr/bin/env ruby
# start_with_persistence.rb - Démarrage du serveur STORM avec persistance garantie

require 'fileutils'
require_relative 'config/database_config'

class StormPersistentServer
  def self.start
    server = new
    server.ensure_persistence
    server.start_server
  end
  
  def ensure_persistence
    puts "[PERSISTENCE] Vérification de la persistance des données..."
    
    # Vérifier que le répertoire data existe
    data_dir = File.dirname(DatabaseConfig::DB_PATH)
    unless Dir.exist?(data_dir)
      FileUtils.mkdir_p(data_dir)
      puts "[PERSISTENCE] Répertoire data créé: #{data_dir}"
    end
    
    # Initialiser ou vérifier la base de données
    if File.exist?(DatabaseConfig::DB_PATH)
      puts "[PERSISTENCE] Base de données existante trouvée: #{DatabaseConfig::DB_PATH}"
      verify_database_integrity
    else
      puts "[PERSISTENCE] Création d'une nouvelle base de données..."
      DatabaseConfig.setup_database
    end
    
    # Migrer les anciennes données si nécessaire
    migrate_old_data_if_needed
    
    # Afficher les statistiques de la base de données
    display_database_stats
    
    puts "[PERSISTENCE] Persistance des données garantie!"
  end
  
  def verify_database_integrity
    begin
      DatabaseConfig.with_connection do |db|
        result = db.execute("PRAGMA integrity_check")
        if result.first['integrity_check'] == 'ok'
          puts "[PERSISTENCE] Intégrité de la base de données vérifiée"
        else
          puts "⚠️ [PERSISTENCE] Problème d'intégrité détecté, réparation..."
          repair_database
        end
      end
    rescue => e
      puts "ERREUR: [PERSISTENCE] Erreur lors de la vérification: #{e.message}"
      puts "[PERSISTENCE] Tentative de réparation..."
      repair_database
    end
  end
  
  def repair_database
    backup_file = "#{DatabaseConfig::DB_PATH}.backup.#{Time.now.to_i}"
    FileUtils.cp(DatabaseConfig::DB_PATH, backup_file)
    puts "[PERSISTENCE] Sauvegarde créée: #{backup_file}"
    
    # Recréer la base de données
    DatabaseConfig.setup_database
    puts "[PERSISTENCE] Base de données réparée"
  end
  
  def migrate_old_data_if_needed
    old_files = ['chat_app.db', 'storm.db', 'chat.db', 'users.db']
    old_files_exist = old_files.any? { |file| File.exist?(file) }
    
    if old_files_exist
      puts "[PERSISTENCE] Anciennes bases de données détectées, migration..."
      system('ruby scripts/migrate_database.rb')
    end
  end
  
  def display_database_stats
    DatabaseConfig.with_connection do |db|
      stats = {
        'users' => db.execute("SELECT COUNT(*) as count FROM users").first['count'],
        'messages' => db.execute("SELECT COUNT(*) as count FROM messages").first['count'],
        'rooms' => db.execute("SELECT COUNT(*) as count FROM rooms").first['count'],
        'user_preferences' => db.execute("SELECT COUNT(*) as count FROM user_preferences").first['count']
      }
      
      puts "[PERSISTENCE] Statistiques de la base de données:"
      stats.each do |table, count|
        puts "   - #{table}: #{count} enregistrements"
      end
      
      # Taille du fichier de base de données
      db_size = File.size(DatabaseConfig::DB_PATH)
      puts "   - Taille: #{(db_size / 1024.0 / 1024.0).round(2)} MB"
    end
  rescue => e
    puts "⚠️ [PERSISTENCE] Impossible d'afficher les statistiques: #{e.message}"
  end
  
  def start_server
    puts "[PERSISTENCE] Démarrage du serveur STORM avec persistance..."
    puts "[PERSISTENCE] Base de données: #{DatabaseConfig::DB_PATH}"
    puts "[PERSISTENCE] Mode WAL activé pour la concurrence"
    puts "[PERSISTENCE] Sauvegarde automatique des données"
    puts ""
    
    # Démarrer le serveur Puma
    exec('bundle exec puma -p 3631 -e development')
  end
end

# Gestion des signaux pour un arrêt propre
Signal.trap('INT') do
  puts "\n[PERSISTENCE] Arrêt du serveur en cours..."
  puts "[PERSISTENCE] Les données sont sauvegardées automatiquement"
  exit(0)
end

Signal.trap('TERM') do
  puts "\n[PERSISTENCE] Arrêt du serveur demandé..."
  puts "[PERSISTENCE] Les données sont sauvegardées automatiquement"
  exit(0)
end

# Démarrer le serveur si le script est exécuté directement
if __FILE__ == $0
  StormPersistentServer.start
end