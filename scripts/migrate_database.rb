#!/usr/bin/env ruby
# scripts/migrate_database.rb

require 'sqlite3'
require 'fileutils'
require_relative '../config/database_config'

class DatabaseMigrator
  OLD_DB_FILES = ['chat_app.db', 'storm.db', 'chat.db', 'users.db']
  
  def self.migrate_all
    migrator = new
    migrator.perform_migration
  end
  
  def initialize
    @migrated_data = {
      users: [],
      messages: [],
      rooms: [],
      preferences: [],
      sessions: []
    }
  end
  
  def perform_migration
    puts "[MIGRATION] Début de la migration des données..."
    
    # Initialiser la nouvelle base de données
    DatabaseConfig.setup_database
    
    # Collecter les données des anciennes bases
    collect_existing_data
    
    # Migrer vers la nouvelle base
    migrate_to_new_database
    
    # Créer des sauvegardes des anciennes bases
    backup_old_databases
    
    puts "[MIGRATION] Migration terminée avec succès!"
    puts "[MIGRATION] Nouvelle base de données: #{DatabaseConfig::DB_PATH}"
    puts "[MIGRATION] Données migrées:"
    @migrated_data.each do |table, data|
      puts "  - #{table}: #{data.length} enregistrements"
    end
  end
  
  private
  
  def collect_existing_data
    OLD_DB_FILES.each do |db_file|
      next unless File.exist?(db_file)
      
      puts "[MIGRATION] Collecte des données de #{db_file}..."
      
      begin
        db = SQLite3::Database.new(db_file)
        db.results_as_hash = true
        
        # Collecter les utilisateurs
        collect_users(db)
        
        # Collecter les messages
        collect_messages(db)
        
        # Collecter les salles
        collect_rooms(db)
        
        # Collecter les préférences
        collect_preferences(db)
        
        # Collecter les sessions
        collect_sessions(db)
        
        db.close
      rescue SQLite3::Exception => e
        puts "[MIGRATION] Erreur lors de la lecture de #{db_file}: #{e.message}"
      end
    end
  end
  
  def collect_users(db)
    begin
      users = db.execute("SELECT * FROM users")
      users.each do |user|
        # Éviter les doublons basés sur le username
        unless @migrated_data[:users].any? { |u| u['username'] == user['username'] }
          @migrated_data[:users] << user
        end
      end
    rescue SQLite3::SQLException
      # Table n'existe pas dans cette base
    end
  end
  
  def collect_messages(db)
    begin
      messages = db.execute("SELECT * FROM messages")
      @migrated_data[:messages].concat(messages)
    rescue SQLite3::SQLException
      # Table n'existe pas dans cette base
    end
  end
  
  def collect_rooms(db)
    begin
      rooms = db.execute("SELECT * FROM rooms")
      rooms.each do |room|
        # Éviter les doublons basés sur le nom
        unless @migrated_data[:rooms].any? { |r| r['name'] == room['name'] }
          @migrated_data[:rooms] << room
        end
      end
    rescue SQLite3::SQLException
      # Table n'existe pas dans cette base
    end
  end
  
  def collect_preferences(db)
    begin
      preferences = db.execute("SELECT * FROM user_preferences")
      @migrated_data[:preferences].concat(preferences)
    rescue SQLite3::SQLException
      # Table n'existe pas dans cette base
    end
  end
  
  def collect_sessions(db)
    begin
      sessions = db.execute("SELECT * FROM user_sessions")
      @migrated_data[:sessions].concat(sessions)
    rescue SQLite3::SQLException
      # Table n'existe pas dans cette base
    end
  end
  
  def migrate_to_new_database
    DatabaseConfig.with_connection do |db|
      db.execute("BEGIN TRANSACTION")
      
      begin
        # Migrer les utilisateurs
        migrate_users(db)
        
        # Migrer les salles
        migrate_rooms(db)
        
        # Migrer les messages
        migrate_messages(db)
        
        # Migrer les préférences
        migrate_preferences(db)
        
        # Migrer les sessions
        migrate_sessions(db)
        
        db.execute("COMMIT")
        puts "[MIGRATION] Transaction validée avec succès"
      rescue => e
        db.execute("ROLLBACK")
        puts "[MIGRATION] Erreur lors de la migration: #{e.message}"
        raise e
      end
    end
  end
  
  def migrate_users(db)
    @migrated_data[:users].each do |user|
      db.execute(
        "INSERT OR IGNORE INTO users (username, email, password_hash, created_at, updated_at, last_seen, status, avatar_url) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        [user['username'], user['email'], user['password_hash'], user['created_at'], user['updated_at'], user['last_seen'], user['status'], user['avatar_url']]
      )
    end
  end
  
  def migrate_rooms(db)
    @migrated_data[:rooms].each do |room|
      db.execute(
        "INSERT OR IGNORE INTO rooms (name, description, created_by, created_at, is_private) VALUES (?, ?, ?, ?, ?)",
        [room['name'], room['description'], room['created_by'], room['created_at'], room['is_private']]
      )
    end
  end
  
  def migrate_messages(db)
    @migrated_data[:messages].each do |message|
      db.execute(
        "INSERT INTO messages (user_id, room_id, content, message_type, created_at, updated_at, is_deleted) VALUES (?, ?, ?, ?, ?, ?, ?)",
        [message['user_id'], message['room_id'], message['content'], message['message_type'], message['created_at'], message['updated_at'], message['is_deleted']]
      )
    end
  end
  
  def migrate_preferences(db)
    @migrated_data[:preferences].each do |pref|
      db.execute(
        "INSERT OR REPLACE INTO user_preferences (user_id, preference_key, preference_value, created_at, updated_at) VALUES (?, ?, ?, ?, ?)",
        [pref['user_id'], pref['preference_key'], pref['preference_value'], pref['created_at'], pref['updated_at']]
      )
    end
  end
  
  def migrate_sessions(db)
    @migrated_data[:sessions].each do |session|
      db.execute(
        "INSERT OR REPLACE INTO user_sessions (user_id, session_token, expires_at, created_at, last_activity, ip_address, user_agent) VALUES (?, ?, ?, ?, ?, ?, ?)",
        [session['user_id'], session['session_token'], session['expires_at'], session['created_at'], session['last_activity'], session['ip_address'], session['user_agent']]
      )
    end
  end
  
  def backup_old_databases
    backup_dir = 'data/backups'
    FileUtils.mkdir_p(backup_dir)
    
    OLD_DB_FILES.each do |db_file|
      next unless File.exist?(db_file)
      
      backup_file = File.join(backup_dir, "#{File.basename(db_file, '.db')}_backup_#{Time.now.strftime('%Y%m%d_%H%M%S')}.db")
      FileUtils.cp(db_file, backup_file)
      puts "[MIGRATION] Sauvegarde créée: #{backup_file}"
    end
  end
end

# Exécuter la migration si le script est appelé directement
if __FILE__ == $0
  DatabaseMigrator.migrate_all
end