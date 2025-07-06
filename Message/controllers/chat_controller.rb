require 'sqlite3'
require 'bcrypt'
require_relative '../models/chat_room'
require_relative './command_handler'
require_relative './user_manager'
require_relative './preference_manager'
require_relative './profile_manager'
require_relative './language_manager'
require 'singleton'
require 'fileutils'
require 'mini_magick' # For image compression
require 'zlib' # For general file compression

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
    
    # Break the circular dependency by deferring UserManager initialization
    # We'll initialize it after the ChatController instance is fully created
    @user_manager = nil

    @profile_manager = nil
    
    # Create command handler without UserManager for now
    @command_handler = CommandHandler.new(self, nil, @preference_manager, @language_manager)
    
    # Now that ChatController is initialized, we can create UserManager
    @user_manager = UserManager.new(self)
    
    # Update the command handler with the user manager
    @command_handler.instance_variable_set(:@user_manager, @user_manager)
    
    # Set the user_manager in the preference_manager
    @preference_manager.set_user_manager(@user_manager)

    @profile_manager = ProfileManager.new(self)
    
    # Setup database first
    setup_database
    
    # Now that database is set up, initialize languages
    @language_manager.initialize_languages
  end

  def setup_database
    begin
      # Ensure the database directory exists
      db_path = ENV['DB_PATH'] || 'chat_app.db'
      db_dir = File.dirname(db_path)
      FileUtils.mkdir_p(db_dir) unless db_dir == '.' || File.directory?(db_dir)
      
      # Create the database file if it doesn't exist
      db = db_connection
      
      # Create tables with proper error handling
      create_users_table(db)
      create_preferences_table(db)
      
      # Create translations table if needed
      db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS translations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          language TEXT NOT NULL,
          key TEXT NOT NULL,
          value TEXT NOT NULL,
          UNIQUE(language, key)
        );
      SQL
      
      db.close
      puts "Database initialized successfully"
    rescue => ex
      puts translate('database_init_error', nil, [ex.message])
    end
  end

  def create_users_table(db)
    db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        username TEXT UNIQUE NOT NULL,
        password_digest TEXT NOT NULL
      );
    SQL
  end

  def create_preferences_table(db)
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
  end

  def create_room(name, password=nil, creator=nil)
    name = name.to_s.force_encoding('UTF-8')
    creator = creator.to_s.force_encoding('UTF-8') if creator
    
    return nil if @chat_rooms.key?(name)
    
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

  def translate(key, username = nil, params = [])
    if username
      language = @language_manager.get_user_language(username)
      @language_manager.translate(key, language, params)
    else
      @language_manager.translate(key, nil, params)
    end
  end

  def convert_color(color_input)
    return color_input if color_input.start_with?('#')

    color_name = color_input.downcase
    return COLOR_NAMES.fetch(color_name, color_input)
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

  def refresh_rooms
    @chat_rooms.each do |_, room|
      # Clean up any disconnected clients
      room.clients.delete_if { |_, client| client.nil? || client.socket.closed? }
    end
    
    # Remove empty rooms except 'Main'
    @chat_rooms.delete_if { |name, room| name != 'Main' && room.clients.empty? }
  end

  def db_connection
    db_path = ENV['DB_PATH'] || 'chat_app.db'
    db = SQLite3::Database.new(db_path)
    
    # Set timeout to wait for locks to clear (5000ms = 5 seconds)
    db.busy_timeout = 5000
    
    # Enable WAL mode for better concurrency
    db.execute("PRAGMA journal_mode = WAL;")
    
    return db
  end

  def compress_file(file_path)
    extension = File.extname(file_path).downcase
    
    case extension
    when '.jpg', '.jpeg', '.png', '.gif', '.webp'
      compress_image(file_path)
    when '.mp4', '.avi', '.mov', '.wmv'
      compress_video(file_path)
    when '.mp3', '.wav', '.ogg'
      compress_audio(file_path)
    else
      compress_generic_file(file_path)
    end
  end

  def compress_image(file_path)
    begin
      image = MiniMagick::Image.open(file_path)
      
      # Don't compress if already small
      return file_path if image.size < 500_000 # 500KB
      
      # Calculate new dimensions while maintaining aspect ratio
      width = image.width
      height = image.height
      
      if width > 1920 || height > 1080
        image.resize "1920x1080>"
      end
      
      # Compress with quality reduction
      image.quality "80"
      image.write file_path
      
      puts translate('image_compressed', nil, [File.basename(file_path), image.size])
      return file_path
    rescue => e
      puts translate('image_compression_error', nil, [e.message])
      return file_path # Return original if compression fails
    end
  end

  def compress_video(file_path)
    begin
      output_path = "#{file_path}.compressed#{File.extname(file_path)}"
      
      # Check if ffmpeg is available
      ffmpeg_available = system("where ffmpeg > nul 2>&1")
      
      if ffmpeg_available
        # Use AV1 if possible, fallback to h264
        av1_available = system("ffmpeg -codecs 2>&1 | findstr av1")
        
        if av1_available
          # AV1 compression (high quality, smaller size)
          system("ffmpeg -i \"#{file_path}\" -c:v libaom-av1 -crf 30 -b:v 0 -strict experimental \"#{output_path}\"")
        else
          # H264 compression (more compatible)
          system("ffmpeg -i \"#{file_path}\" -c:v libx264 -crf 23 -preset medium -c:a aac -b:a 128k \"#{output_path}\"")
        end
        
        if File.exist?(output_path) && File.size(output_path) < File.size(file_path)
          FileUtils.mv(output_path, file_path)
          puts translate('video_compressed', nil, [File.basename(file_path), File.size(file_path)])
        else
          FileUtils.rm(output_path) if File.exist?(output_path)
          puts translate('video_compression_skipped', nil, [File.basename(file_path)])
        end
      else
        puts translate('ffmpeg_not_available')
      end
      
      return file_path
    rescue => e
      puts translate('video_compression_error', nil, [e.message])
      FileUtils.rm(output_path) if File.exist?(output_path)
      return file_path
    end
  end

  def compress_audio(file_path)
    begin
      output_path = "#{file_path}.compressed#{File.extname(file_path)}"
      
      # Check if ffmpeg is available
      ffmpeg_available = system("where ffmpeg > nul 2>&1")
      
      if ffmpeg_available
        # Compress audio to AAC with reasonable bitrate
        system("ffmpeg -i \"#{file_path}\" -c:a aac -b:a 128k \"#{output_path}\"")
        
        if File.exist?(output_path) && File.size(output_path) < File.size(file_path)
          FileUtils.mv(output_path, file_path)
          puts translate('audio_compressed', nil, [File.basename(file_path), File.size(file_path)])
        else
          FileUtils.rm(output_path) if File.exist?(output_path)
          puts translate('audio_compression_skipped', nil, [File.basename(file_path)])
        end
      else
        puts translate('ffmpeg_not_available')
      end
      
      return file_path
    rescue => e
      puts translate('audio_compression_error', nil, [e.message])
      FileUtils.rm(output_path) if File.exist?(output_path)
      return file_path
    end
  end

  def compress_generic_file(file_path)
    begin
      # Skip if file is already small
      return file_path if File.size(file_path) < 100_000 # 100KB
      
      output_path = "#{file_path}.gz"
      
      Zlib::GzipWriter.open(output_path) do |gz|
        gz.write(File.read(file_path))
      end
      
      if File.exist?(output_path) && File.size(output_path) < File.size(file_path)
        FileUtils.mv(output_path, file_path)
        puts translate('file_compressed', nil, [File.basename(file_path), File.size(file_path)])
      else
        FileUtils.rm(output_path) if File.exist?(output_path)
        puts translate('file_compression_skipped', nil, [File.basename(file_path)])
      end
      
      return file_path
    rescue => e
      puts translate('file_compression_error', nil, [e.message])
      FileUtils.rm(output_path) if File.exist?(output_path)
      return file_path
    end
  end
end
