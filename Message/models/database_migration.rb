require 'sqlite3'
require 'fileutils'

class DatabaseMigration
  def self.run
    db_dir = File.join(File.dirname(__FILE__), '..', '..', 'db')
    FileUtils.mkdir_p(db_dir) unless Dir.exist?(db_dir)
    
    db_path = File.join(db_dir, 'storm.db')
    db = SQLite3::Database.new(db_path)
    
    # Create user_profiles table
    db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS user_profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        avatar_url TEXT,
        bio TEXT,
        location TEXT,
        website TEXT,
        social_links TEXT,
        status TEXT,
        last_seen INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id)
      );
    SQL
    
    # Create chat_rooms table
    db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS chat_rooms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        password TEXT,
        creator TEXT,
        created_at INTEGER NOT NULL
      );
    SQL
    
    # Create messages table
    db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        message TEXT NOT NULL,
        attachment_url TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (room_id) REFERENCES chat_rooms(id),
        FOREIGN KEY (user_id) REFERENCES users(id)
      );
    SQL
    
    puts "Database migration completed successfully"
    db.close
  end
end

# Run the migration if this file is executed directly
DatabaseMigration.run if __FILE__ == $0