# config/database_config.rb
require 'sqlite3'
require 'fileutils'

class DatabaseConfig
  # Configuration centralisée de la base de données
  DB_NAME = 'storm_persistent.db'
  DB_PATH = File.join(Dir.pwd, 'data', DB_NAME)
  
  class << self
    def setup_database
      # Créer le répertoire data s'il n'existe pas
      data_dir = File.dirname(DB_PATH)
      FileUtils.mkdir_p(data_dir) unless Dir.exist?(data_dir)
      
      # Créer la base de données si elle n'existe pas
      unless File.exist?(DB_PATH)
        puts "[DATABASE] Création de la base de données: #{DB_PATH}"
        create_database
      else
        puts "[DATABASE] Base de données existante trouvée: #{DB_PATH}"
      end
      
      # Vérifier l'intégrité de la base de données
      verify_database_integrity
    end
    
    def get_connection
      db = SQLite3::Database.new(DB_PATH)
      # Configuration pour la performance et la persistance
      db.execute("PRAGMA journal_mode = WAL")
      db.execute("PRAGMA synchronous = NORMAL")
      db.execute("PRAGMA cache_size = 10000")
      db.execute("PRAGMA temp_store = memory")
      db.execute("PRAGMA mmap_size = 268435456") # 256MB
      db.results_as_hash = true
      db
    end
    
    def with_connection
      db = get_connection
      begin
        yield db
      ensure
        db.close if db
      end
    end
    
    private
    
    def create_database
      with_connection do |db|
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
        
        # Index pour les performances
        db.execute "CREATE INDEX IF NOT EXISTS idx_messages_user_id ON messages (user_id)"
        db.execute "CREATE INDEX IF NOT EXISTS idx_messages_room_id ON messages (room_id)"
        db.execute "CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages (created_at)"
        db.execute "CREATE INDEX IF NOT EXISTS idx_users_username ON users (username)"
        db.execute "CREATE INDEX IF NOT EXISTS idx_users_email ON users (email)"
        db.execute "CREATE INDEX IF NOT EXISTS idx_sessions_token ON user_sessions (session_token)"
        db.execute "CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON user_sessions (user_id)"
        
        puts "[DATABASE] Tables créées avec succès"
      end
    end
    
    def verify_database_integrity
      with_connection do |db|
        result = db.execute("PRAGMA integrity_check")
        if result.first['integrity_check'] == 'ok'
          puts "[DATABASE] Intégrité vérifiée avec succès"
        else
          puts "[DATABASE] ATTENTION: Problème d'intégrité détecté"
        end
      end
    rescue => e
      puts "[DATABASE] Erreur lors de la vérification: #{e.message}"
    end
  end
end

# Configuration globale
DB_CONFIG = DatabaseConfig
DB_PATH = DatabaseConfig::DB_PATH