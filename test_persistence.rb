#!/usr/bin/env ruby
# test_persistence.rb - Test de la persistance des données

require_relative 'config/database_config'

class PersistenceTest
  def self.run_tests
    tester = new
    tester.run_all_tests
  end
  
  def run_all_tests
    puts "🧪 [TEST] Début des tests de persistance..."
    
    test_database_creation
    test_data_insertion
    test_data_persistence
    test_database_integrity
    
    puts "✅ [TEST] Tous les tests de persistance ont réussi!"
  end
  
  private
  
  def test_database_creation
    puts "📝 [TEST] Test de création de la base de données..."
    
    # Vérifier que la base de données existe
    unless File.exist?(DatabaseConfig::DB_PATH)
      DatabaseConfig.setup_database
    end
    
    assert File.exist?(DatabaseConfig::DB_PATH), "Base de données créée"
    puts "✅ [TEST] Base de données créée avec succès"
  end
  
  def test_data_insertion
    puts "📝 [TEST] Test d'insertion de données..."
    
    DatabaseConfig.with_connection do |db|
      # Insérer un utilisateur de test
      db.execute(
        "INSERT OR REPLACE INTO users (id, username, email, created_at) VALUES (?, ?, ?, ?)",
        [999, 'test_user_persistence', 'test@persistence.com', Time.now.to_s]
      )
      
      # Insérer un message de test
      db.execute(
        "INSERT OR REPLACE INTO messages (id, user_id, content, created_at) VALUES (?, ?, ?, ?)",
        [999, 999, 'Message de test de persistance', Time.now.to_s]
      )
      
      # Insérer une préférence de test
      db.execute(
        "INSERT OR REPLACE INTO user_preferences (id, user_id, preference_key, preference_value, created_at) VALUES (?, ?, ?, ?, ?)",
        [999, 999, 'test_persistence', 'true', Time.now.to_s]
      )
    end
    
    puts "✅ [TEST] Données de test insérées"
  end
  
  def test_data_persistence
    puts "📝 [TEST] Test de persistance des données..."
    
    DatabaseConfig.with_connection do |db|
      # Vérifier l'utilisateur
      user = db.execute("SELECT * FROM users WHERE id = 999").first
      assert user, "Utilisateur de test trouvé"
      assert user['username'] == 'test_user_persistence', "Username correct"
      
      # Vérifier le message
      message = db.execute("SELECT * FROM messages WHERE id = 999").first
      assert message, "Message de test trouvé"
      assert message['content'] == 'Message de test de persistance', "Contenu du message correct"
      
      # Vérifier la préférence
      preference = db.execute("SELECT * FROM user_preferences WHERE id = 999").first
      assert preference, "Préférence de test trouvée"
      assert preference['preference_value'] == 'true', "Valeur de préférence correcte"
    end
    
    puts "✅ [TEST] Toutes les données persistent correctement"
  end
  
  def test_database_integrity
    puts "📝 [TEST] Test d'intégrité de la base de données..."
    
    DatabaseConfig.with_connection do |db|
      result = db.execute("PRAGMA integrity_check")
      assert result.first['integrity_check'] == 'ok', "Intégrité de la base de données"
      
      # Vérifier les index
      indexes = db.execute("SELECT name FROM sqlite_master WHERE type='index'")
      assert indexes.length > 0, "Index créés"
      
      # Vérifier les tables
      tables = db.execute("SELECT name FROM sqlite_master WHERE type='table'")
      expected_tables = ['users', 'messages', 'rooms', 'user_preferences', 'user_sessions']
      expected_tables.each do |table|
        assert tables.any? { |t| t['name'] == table }, "Table #{table} existe"
      end
    end
    
    puts "✅ [TEST] Intégrité de la base de données vérifiée"
  end
  
  def assert(condition, message)
    unless condition
      puts "❌ [TEST] ÉCHEC: #{message}"
      exit(1)
    end
  end
end

# Fonction utilitaire pour afficher les statistiques
def display_stats
  puts "\n📊 [STATS] Statistiques actuelles de la base de données:"
  
  DatabaseConfig.with_connection do |db|
    stats = {
      'users' => db.execute("SELECT COUNT(*) as count FROM users").first['count'],
      'messages' => db.execute("SELECT COUNT(*) as count FROM messages").first['count'],
      'rooms' => db.execute("SELECT COUNT(*) as count FROM rooms").first['count'],
      'user_preferences' => db.execute("SELECT COUNT(*) as count FROM user_preferences").first['count'],
      'user_sessions' => db.execute("SELECT COUNT(*) as count FROM user_sessions").first['count']
    }
    
    stats.each do |table, count|
      puts "   - #{table}: #{count} enregistrements"
    end
    
    # Taille du fichier
    if File.exist?(DatabaseConfig::DB_PATH)
      db_size = File.size(DatabaseConfig::DB_PATH)
      puts "   - Taille: #{(db_size / 1024.0 / 1024.0).round(2)} MB"
    end
    
    # Mode WAL
    wal_mode = db.execute("PRAGMA journal_mode").first['journal_mode']
    puts "   - Mode journal: #{wal_mode}"
  end
end

# Fonction pour nettoyer les données de test
def cleanup_test_data
  puts "\n🧹 [CLEANUP] Nettoyage des données de test..."
  
  DatabaseConfig.with_connection do |db|
    db.execute("DELETE FROM user_preferences WHERE id = 999")
    db.execute("DELETE FROM messages WHERE id = 999")
    db.execute("DELETE FROM users WHERE id = 999")
  end
  
  puts "✅ [CLEANUP] Données de test supprimées"
end

# Exécuter les tests si le script est appelé directement
if __FILE__ == $0
  case ARGV[0]
  when 'test'
    PersistenceTest.run_tests
  when 'stats'
    display_stats
  when 'cleanup'
    cleanup_test_data
  else
    puts "Usage:"
    puts "  ruby test_persistence.rb test     # Exécuter les tests"
    puts "  ruby test_persistence.rb stats    # Afficher les statistiques"
    puts "  ruby test_persistence.rb cleanup  # Nettoyer les données de test"
    puts ""
    puts "Exécution des tests par défaut..."
    PersistenceTest.run_tests
    display_stats
  end
end