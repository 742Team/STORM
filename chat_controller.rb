require 'sqlite3'
require 'bcrypt'
require_relative '../models/chat_room'
require 'singleton'
require_relative './command_handler'
require_relative './user_manager'
require_relative './preference_manager'
require_relative './language_manager'

class ChatController
  include Singleton
  attr_accessor :chat_rooms

  COLOR_NAMES = {
    "red" => "#FF0000",
    "green" => "#008000",
    "blue" => "#0000FF",
    "yellow" => "#FFFF00",
    "orange" => "#FFA500",
    "purple" => "#800080",
    "pink" => "#FFC0CB",
    "black" => "#000000",
    "white" => "#FFFFFF",
    "gray" => "#808080",
    "grey" => "#808080",
    "brown" => "#A52A2A",
    "cyan" => "#00FFFF",
    "magenta" => "#FF00FF",
    "lime" => "#00FF00",
    "navy" => "#000080",
    "teal" => "#008080",
    "olive" => "#808000",
    "maroon" => "#800000",
    "silver" => "#C0C0C0",
    "gold" => "#FFD700",
    "indigo" => "#4B0082",
    "violet" => "#EE82EE",
    "turquoise" => "#40E0D0",
    "crimson" => "#DC143C",
    "salmon" => "#FA8072",
    "coral" => "#FF7F50",
    "tomato" => "#FF6347",
    "skyblue" => "#87CEEB",
    "steelblue" => "#4682B4",
    "royalblue" => "#4169E1",
    "darkgreen" => "#006400",
    "forestgreen" => "#228B22",
    "seagreen" => "#2E8B57",
    "darkred" => "#8B0000"
  }

  def initialize
    @chat_rooms = {}
    
    # Initialize language manager first
    @language_manager = LanguageManager.instance
    
    # Initialize preference manager
    @preference_manager = PreferenceManager.new(self)
    
    # Initialize user manager
    @user_manager = UserManager.new(self)
    
    # Set the user_manager in the preference_manager
    @preference_manager.set_user_manager(@user_manager) if @preference_manager.respond_to?(:set_user_manager)
    
    # Create command handler
    @command_handler = CommandHandler.new(self, @user_manager, @preference_manager, @language_manager)
    
    # Setup database
    setup_database
    
    # Create Main room if it doesn't exist
    create_room('Main') unless @chat_rooms.key?('Main')
  end

  def setup_database
    begin
      db = db_connection
      db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          email TEXT UNIQUE NOT NULL,
          username TEXT UNIQUE NOT NULL,
          password_digest TEXT NOT NULL
        );
      SQL

      db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS user_preferences (
          user_id INTEGER PRIMARY KEY,
          text_color TEXT,
          background_url TEXT,
          font_family TEXT,
          color TEXT,
          language TEXT DEFAULT 'en',
          FOREIGN KEY (user_id) REFERENCES users(id)
        );
      SQL
      db.close
    rescue => ex
      puts "| ⚫️ Erreur lors de l'initialisation de la base de données #{ex.message}"
    end
  end

  def create_room(name, password=nil, creator=nil)
    name = name.to_s.force_encoding('UTF-8')
    creator = creator.to_s.force_encoding('UTF-8') if creator
    
    if @chat_rooms.key?(name)
      return nil
    end
    
    @chat_rooms[name] = ChatRoom.new(name, password, creator)
    @chat_rooms[name].created_at = Time.now
    return @chat_rooms[name]
  end

  def handle_message(driver, chat_room, username, message)
    message = message.force_encoding('UTF-8')
    
    if message.start_with?('/')
      return @command_handler.handle_command(message, driver, chat_room, username)
    else
      chat_room.broadcast_message(message, username)
      return nil
    end
  end

  def sanitize_filename(filename)
    extension = File.extname(filename)
    basename = File.basename(filename, extension)

    uuid = SecureRandom.uuid
    timestamp = Time.now.to_i

    sanitized_basename = basename.gsub(/[^\p{Alnum}\p{L}\p{M}\s\-_]/, '_')
    sanitized_basename = sanitized_basename.gsub(/\s+/, '_')
    sanitized_basename = sanitized_basename[0, 100] if sanitized_basename.length > 100

    "#{timestamp}_#{uuid}_#{sanitized_basename}#{extension}"
  end

  def convert_color(color_input)
    return color_input if color_input.start_with?('#')

    color_name = color_input.downcase

    if COLOR_NAMES.key?(color_name)
      return COLOR_NAMES[color_name]
    end

    return color_input
  end

  def refresh_rooms
    # Clean up disconnected clients and update room status
    @chat_rooms.each do |name, room|
      room.clients.delete_if do |username, client|
        begin
          # Check if client is still connected
          client.socket.closed?
        rescue => e
          true # Remove client if there's any error
        end
      end
    end

    # Remove empty rooms except 'Main'
    @chat_rooms.delete_if { |name, room| name != "Main" && room.clients.empty? }
  end

  def db_connection
    db_path = ENV['DB_PATH'] || 'chat_app.db'
    db = SQLite3::Database.new(db_path)
    
    # Set timeout to wait for locks to clear
    db.busy_timeout = 5000
    
    # Enable WAL mode for better concurrency
    db.execute("PRAGMA journal_mode = WAL;")
    
    return db
  end

  def translate(key, username = nil, params = [])
    if username
      language = @language_manager.get_user_language(username)
      @language_manager.translate(key, language, params)
    else
      @language_manager.translate(key, nil, params)
    end
  end
end
