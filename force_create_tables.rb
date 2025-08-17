#!/usr/bin/env ruby
# force_create_tables.rb - Force la création des tables

require 'sqlite3'
require 'fileutils'

# Configuration de la base de données
DB_NAME = 'storm_persistent.db'
DB_PATH = File.join(Dir.pwd, 'data', DB_NAME)

# Créer le répertoire data s'il n'existe pas
data_dir = File.dirname(DB_PATH)
FileUtils.mkdir_p(data_dir) unless Dir.exist?(data_dir)

puts "[SETUP] Création forcée des tables dans #{DB_PATH}"

# Créer la connexion à la base de données
db = SQLite3::Database.new(DB_PATH)
db.results_as_hash = true

# Configuration pour la performance
db.execute("PRAGMA journal_mode = WAL")
db.execute("PRAGMA synchronous = NORMAL")
db.execute("PRAGMA cache_size = 10000")
db.execute("PRAGMA temp_store = memory")
db.execute("PRAGMA mmap_size = 268435456") # 256MB

puts "[SETUP] Configuration SQLite appliquée"

# Créer les tables
begin
  # Table des utilisateurs
  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT UNIQUE NOT NULL,
      email TEXT UNIQUE,
      password_hash TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      last_seen DATETIME,
      status TEXT DEFAULT 'offline',
      avatar_url TEXT
    )
  SQL
  puts "[SETUP] Table 'users' créée"
  
  # Table des messages
  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      room_id INTEGER,
      content TEXT NOT NULL,
      message_type TEXT DEFAULT 'text',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      is_deleted BOOLEAN DEFAULT 0,
      FOREIGN KEY (user_id) REFERENCES users (id)
    )
  SQL
  puts "[SETUP] Table 'messages' créée"
  
  # Table des salles/rooms
  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS rooms (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT,
      created_by INTEGER,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      is_private BOOLEAN DEFAULT 0,
      FOREIGN KEY (created_by) REFERENCES users (id)
    )
  SQL
  puts "[SETUP] Table 'rooms' créée"
  
  # Table des préférences utilisateur
  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS user_preferences (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      preference_key TEXT NOT NULL,
      preference_value TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users (id),
      UNIQUE(user_id, preference_key)
    )
  SQL
  puts "[SETUP] Table 'user_preferences' créée"
  
  # Table des sessions
  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS user_sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      session_token TEXT UNIQUE NOT NULL,
      expires_at DATETIME NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      last_activity DATETIME DEFAULT CURRENT_TIMESTAMP,
      ip_address TEXT,
      user_agent TEXT,
      FOREIGN KEY (user_id) REFERENCES users (id)
    )
  SQL
  puts "[SETUP] Table 'user_sessions' créée"
  
  # Créer les index pour les performances
  db.execute "CREATE INDEX IF NOT EXISTS idx_messages_user_id ON messages (user_id)"
  db.execute "CREATE INDEX IF NOT EXISTS idx_messages_room_id ON messages (room_id)"
  db.execute "CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages (created_at)"
  db.execute "CREATE INDEX IF NOT EXISTS idx_users_username ON users (username)"
  db.execute "CREATE INDEX IF NOT EXISTS idx_users_email ON users (email)"
  db.execute "CREATE INDEX IF NOT EXISTS idx_sessions_token ON user_sessions (session_token)"
  db.execute "CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON user_sessions (user_id)"
  puts "[SETUP] Index créés"
  
  # Vérifier les tables créées
  tables = db.execute("SELECT name FROM sqlite_master WHERE type='table'")
  puts "[SETUP] Tables disponibles:"
  tables.each { |table| puts "  - #{table['name']}" }
  
  # Vérifier l'intégrité
  result = db.execute("PRAGMA integrity_check")
  if result.first['integrity_check'] == 'ok'
    puts "[SETUP] Intégrité de la base de données vérifiée"
  else
    puts "[SETUP] ⚫️ Problème d'intégrité détecté"
  end
  
rescue SQLite3::Exception => e
  puts "[SETUP] ⚫️ Erreur lors de la création des tables: #{e.message}"
ensure
  db.close if db
end

puts "[SETUP] Configuration de la base de données terminée"