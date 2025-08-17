require 'sqlite3'
require 'bcrypt'
require_relative '../models/chat_room'
require_relative './command_handler'
require_relative './user_manager'
require_relative './preference_manager'
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
    
    # Create command handler without UserManager for now
    @command_handler = CommandHandler.new(self, nil, @preference_manager, @language_manager)
    
    # Now that ChatController is initialized, we can create UserManager
    @user_manager = UserManager.new(self)
    
    # Update the command handler with the user manager
    @command_handler.instance_variable_set(:@user_manager, @user_manager)
    
    # Set the user_manager in the preference_manager
    @preference_manager.set_user_manager(@user_manager)
    
    # Setup database first
    setup_database
    
    # Now that database is set up, initialize languages
    @language_manager.initialize_languages
    
    # Load rooms from database
    load_rooms_from_db
    
    # Create Main room if it doesn't exist
    create_room("Main") unless @chat_rooms.key?("Main")
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
      setup_friends_tables
      create_rooms_table(db)
      
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
      
      # Initialize room themes table via preference manager
      @preference_manager.create_room_themes_table if @preference_manager
      
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

  # Correction de la méthode create_room qui est définie deux fois
  def create_room(name, password=nil, creator=nil)
    name = name.to_s.force_encoding('UTF-8')
    creator = creator.to_s.force_encoding('UTF-8') if creator
    
    return nil if @chat_rooms.key?(name)
    
    room = ChatRoom.new(name, password, creator)
    room.controller = self  # Set the controller reference
    @chat_rooms[name] = room
    @chat_rooms[name].created_at = Time.now
    
    # Save to database if it's not a temporary room
    save_room_to_db(name, password, creator)
    
    # Load room theme if it exists
    room.load_room_theme
    
    return room
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

  # Correction: Indentation correcte pour cette méthode
  def global_direct_message(sender, recipient, message)
    # Vérifier s'ils sont amis
    unless are_friends(sender, recipient)
      sender_driver = nil
      @chat_rooms.each do |_, room|
        if room.clients.key?(sender)
          sender_driver = room.clients[sender]
          break
        end
      end
      
      if sender_driver
        sender_driver.text(translate('not_friends', sender, [recipient]))
      end
      return false
    end
    
    # Chercher le destinataire dans toutes les rooms
    recipient_found = false
    recipient_driver = nil
    
    @chat_rooms.each do |room_name, room|
      if room.clients.key?(recipient)
        recipient_driver = room.clients[recipient]
        recipient_found = true
        break
      end
    end
    
    # Trouver la room de l'expéditeur pour lui envoyer une confirmation
    sender_driver = nil
    
    @chat_rooms.each do |room_name, room|
      if room.clients.key?(sender)
        sender_driver = room.clients[sender]
        break
      end
    end
    
    if recipient_found && sender_driver && recipient_driver
      # Format pour le destinataire
      recipient_driver.text(translate('gdm_received', recipient, [sender, message]))
      # Format pour l'expéditeur
      sender_driver.text(translate('gdm_sent', sender, [recipient, message]))
      return true
    else
      sender_driver.text(translate('user_not_connected', sender, [recipient])) if sender_driver
      return false
    end
  end

  # Correction: Indentation correcte pour cette méthode
  def setup_friends_tables
    begin
      db = db_connection
      
      # Créer la table friend_requests
      db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS friend_requests (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sender_id INTEGER NOT NULL,
          receiver_id INTEGER NOT NULL,
          status TEXT DEFAULT 'pending',
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(sender_id, receiver_id),
          FOREIGN KEY (sender_id) REFERENCES users(id),
          FOREIGN KEY (receiver_id) REFERENCES users(id)
        );
      SQL
      
      # Créer la table friends
      db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS friends (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user1_id INTEGER NOT NULL,
          user2_id INTEGER NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(user1_id, user2_id),
          FOREIGN KEY (user1_id) REFERENCES users(id),
          FOREIGN KEY (user2_id) REFERENCES users(id)
        );
      SQL
      
      db.close
    rescue => e
      puts "Error setting up friends tables: #{e.message}"
    end
  end

  # Correction: Indentation correcte pour toutes les méthodes suivantes
  def send_friend_request(sender, receiver)
    return false if sender == receiver
    
    begin
      db = db_connection
      
      sender_id = get_user_id(sender)
      receiver_id = get_user_id(receiver)
      
      return false unless sender_id && receiver_id
      
      # Vérifier s'ils sont déjà amis
      friends_check = db.execute("SELECT id FROM friends WHERE 
                              (user1_id = ? AND user2_id = ?) OR 
                              (user1_id = ? AND user2_id = ?)", 
                              [sender_id, receiver_id, receiver_id, sender_id])
      
      if !friends_check.empty?
        db.close
        return 'already_friends'
      end
      
      # Vérifier s'il y a déjà une demande en attente
      request_check = db.execute("SELECT id, status FROM friend_requests WHERE 
                              (sender_id = ? AND receiver_id = ?) OR 
                              (sender_id = ? AND receiver_id = ?)", 
                              [sender_id, receiver_id, receiver_id, sender_id])
      
      if !request_check.empty?
        status = request_check[0][1]
        if status == 'pending'
          # Si l'autre personne a déjà envoyé une demande, on l'accepte automatiquement
          if db.execute("SELECT id FROM friend_requests WHERE sender_id = ? AND receiver_id = ?", 
                      [receiver_id, sender_id]).any?
            accept_friend_request(receiver, sender)
            db.close
            return 'auto_accepted'
          else
            db.close
            return 'already_sent'
          end
        end
      end
      
      # Envoyer la demande
      db.execute("INSERT INTO friend_requests (sender_id, receiver_id, status) VALUES (?, ?, 'pending')", 
                [sender_id, receiver_id])
      
      # Notifier le destinataire s'il est connecté
      notify_user(receiver, translate('friend_request_received', receiver, [sender]))
      
      db.close
      return 'sent'
    rescue => e
      puts "Error sending friend request: #{e.message}"
      return false
    end
  end

  def accept_friend_request(receiver, sender)
    begin
      db = db_connection
      
      receiver_id = get_user_id(receiver)
      sender_id = get_user_id(sender)
      
      return false unless receiver_id && sender_id
      
      # Vérifier si la demande existe
      request = db.execute("SELECT id FROM friend_requests WHERE 
                        sender_id = ? AND receiver_id = ? AND status = 'pending'", 
                        [sender_id, receiver_id])
      
      if request.empty?
        db.close
        return false
      end
      
      # Mettre à jour le statut de la demande
      db.execute("UPDATE friend_requests SET status = 'accepted', updated_at = CURRENT_TIMESTAMP 
                WHERE sender_id = ? AND receiver_id = ?", 
                [sender_id, receiver_id])
      
      # Ajouter l'amitié (toujours stocker avec l'ID le plus petit en premier pour faciliter les requêtes)
      if sender_id < receiver_id
        db.execute("INSERT OR IGNORE INTO friends (user1_id, user2_id) VALUES (?, ?)", 
                  [sender_id, receiver_id])
      else
        db.execute("INSERT OR IGNORE INTO friends (user1_id, user2_id) VALUES (?, ?)", 
                  [receiver_id, sender_id])
      end
      
      # Notifier l'expéditeur s'il est connecté
      notify_user(sender, translate('friend_request_accepted', sender, [receiver]))
      
      db.close
      return true
    rescue => e
      puts "Error accepting friend request: #{e.message}"
      return false
    end
  end

  def decline_friend_request(receiver, sender)
    begin
      db = db_connection
      
      receiver_id = get_user_id(receiver)
      sender_id = get_user_id(sender)
      
      return false unless receiver_id && sender_id
      
      # Vérifier si la demande existe
      request = db.execute("SELECT id FROM friend_requests WHERE 
                        sender_id = ? AND receiver_id = ? AND status = 'pending'", 
                        [sender_id, receiver_id])
      
      if request.empty?
        db.close
        return false
      end
      
      # Mettre à jour le statut de la demande
      db.execute("UPDATE friend_requests SET status = 'declined', updated_at = CURRENT_TIMESTAMP 
                WHERE sender_id = ? AND receiver_id = ?", 
                [sender_id, receiver_id])
      
      db.close
      return true
    rescue => e
      puts "Error declining friend request: #{e.message}"
      return false
    end
  end

  def remove_friend(user1, user2)
    begin
      db = db_connection
      
      user1_id = get_user_id(user1)
      user2_id = get_user_id(user2)
      
      return false unless user1_id && user2_id
      
      # Supprimer l'amitié (dans les deux sens)
      db.execute("DELETE FROM friends WHERE 
                (user1_id = ? AND user2_id = ?) OR 
                (user1_id = ? AND user2_id = ?)", 
                [user1_id, user2_id, user2_id, user1_id])
      
      # Supprimer les demandes d'ami (dans les deux sens)
      db.execute("DELETE FROM friend_requests WHERE 
                (sender_id = ? AND receiver_id = ?) OR 
                (sender_id = ? AND receiver_id = ?)", 
                [user1_id, user2_id, user2_id, user1_id])
      
      db.close
      return true
    rescue => e
      puts "Error removing friend: #{e.message}"
      return false
    end
  end

  def get_friends(username)
    begin
      db = db_connection
      
      user_id = get_user_id(username)
      return [] unless user_id
      
      # Récupérer la liste des amis
      result = db.execute(<<-SQL, [user_id, user_id])
        SELECT u.username 
        FROM friends f
        JOIN users u ON (f.user1_id = u.id OR f.user2_id = u.id)
        WHERE (f.user1_id = ? OR f.user2_id = ?) 
        AND u.id != ?
      SQL
      
      db.close
      return result.flatten
    rescue => e
      puts "Error getting friends: #{e.message}"
      return []
    end
  end

  def get_pending_requests(username)
    begin
      db = db_connection
      
      user_id = get_user_id(username)
      return [] unless user_id
      
      # Récupérer les demandes en attente
      result = db.execute(<<-SQL, [user_id])
        SELECT u.username 
        FROM friend_requests fr
        JOIN users u ON fr.sender_id = u.id
        WHERE fr.receiver_id = ? AND fr.status = 'pending'
      SQL
      
      db.close
      return result.flatten
    rescue => e
      puts "Error getting pending requests: #{e.message}"
      return []
    end
  end

  def are_friends(user1, user2)
    begin
      db = db_connection
      
      user1_id = get_user_id(user1)
      user2_id = get_user_id(user2)
      
      return false unless user1_id && user2_id
      
      # Vérifier s'ils sont amis
      result = db.execute("SELECT id FROM friends WHERE 
                        (user1_id = ? AND user2_id = ?) OR 
                        (user1_id = ? AND user2_id = ?)", 
                        [user1_id, user2_id, user2_id, user1_id])
      
      db.close
      return !result.empty?
    rescue => e
      puts "Error checking friendship: #{e.message}"
      return false
    end
  end

  def notify_user(username, message)
    # Trouver l'utilisateur dans toutes les rooms et lui envoyer un message
    @chat_rooms.each do |_, room|
      if room.clients.key?(username)
        room.clients[username].text(message)
        return true
      end
    end
    return false
  end

  # Modifier la méthode global_direct_message pour vérifier l'amitié
  def global_direct_message(sender, recipient, message)
    # Chercher le destinataire dans toutes les rooms
    recipient_found = false
    recipient_driver = nil
    
    @chat_rooms.each do |room_name, room|
      if room.clients.key?(recipient)
        recipient_driver = room.clients[recipient]
        recipient_found = true
        break
      end
    end
    
    # Trouver la room de l'expéditeur pour lui envoyer une confirmation
    sender_driver = nil
    
    @chat_rooms.each do |room_name, room|
      if room.clients.key?(sender)
        sender_driver = room.clients[sender]
        break
      end
    end
    
    if recipient_found && sender_driver && recipient_driver
      # Format pour le destinataire
      recipient_driver.text(translate('gdm_received', recipient, [sender, message]))
      # Format pour l'expéditeur
      sender_driver.text(translate('gdm_sent', sender, [recipient, message]))
      return true
    else
      sender_driver.text(translate('user_not_connected', sender, [recipient])) if sender_driver
      return false
    end
  end

  # Move this method inside the ChatController class, before the final end
  def get_public_rooms
    begin
      db = db_connection
      
      # Get all public rooms from database
      rooms = db.execute("SELECT name, creator FROM rooms WHERE password IS NULL OR password = ''")
      
      public_rooms = []
      
      rooms.each do |room_data|
        name, creator = room_data
        
        # Get current user count if room is active
        users_count = @chat_rooms.key?(name) ? @chat_rooms[name].clients.size : 0
        
        public_rooms << {
          name: name,
          users_count: users_count,
          creator: creator
        }
      end
      
      db.close
      return public_rooms
    rescue => e
      puts "Error getting public rooms: #{e.message}"
      
      # Fallback to in-memory rooms if database query fails
      public_rooms = []
      @chat_rooms.each do |name, room|
        if room.password.nil? || room.password.empty?
          public_rooms << {
            name: name,
            users_count: room.clients.size,
            creator: room.creator
          }
        end
      end
      
      return public_rooms
    end
  end

  # Ajoutez ces méthodes à l'intérieur de la classe ChatController
    def create_rooms_table(db)
      db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS rooms (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT UNIQUE NOT NULL,
          password TEXT,
          creator TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          is_persistent BOOLEAN DEFAULT TRUE
        );
      SQL
    end

    def save_room_to_db(name, password=nil, creator=nil)
      begin
        db = db_connection
        
        # Check if room already exists in database
        existing = db.execute("SELECT id FROM rooms WHERE name = ?", [name])
        
        if existing.empty?
          # Insert new room
          db.execute(
            "INSERT INTO rooms (name, password, creator, created_at) VALUES (?, ?, ?, ?)",
            [name, password, creator, Time.now.to_s]
          )
        else
          # Update existing room
          db.execute(
            "UPDATE rooms SET password = ?, creator = ? WHERE name = ?",
            [password, creator, name]
          )
        end
        
        db.close
        return true
      rescue => e
        puts "Error saving room to database: #{e.message}"
        return false
      end
    end

    def load_rooms_from_db
      begin
        db = db_connection
        
        # Get all persistent rooms from database
        rooms = db.execute("SELECT name, password, creator, created_at FROM rooms WHERE is_persistent = TRUE")
        
        rooms.each do |room_data|
          name, password, creator, created_at = room_data
          
          # Skip if room already exists in memory
          next if @chat_rooms.key?(name)
          
          # Create room in memory
          @chat_rooms[name] = ChatRoom.new(name, password, creator)
          @chat_rooms[name].controller = self  # Set the controller reference
          @chat_rooms[name].created_at = Time.parse(created_at) rescue Time.now
          
          # Load room theme if it exists
          @chat_rooms[name].load_room_theme
        end
        
        db.close
        puts "Loaded #{rooms.size} rooms from database"
      rescue => e
        puts "Error loading rooms from database: #{e.message}"
      end
    end

    def get_public_rooms
      begin
        db = db_connection
        
        # Get all public rooms from database
        rooms = db.execute("SELECT name, creator FROM rooms WHERE password IS NULL OR password = ''")
        
        public_rooms = []
        
        rooms.each do |room_data|
          name, creator = room_data
          
          # Get current user count if room is active
          users_count = @chat_rooms.key?(name) ? @chat_rooms[name].clients.size : 0
          
          public_rooms << {
            name: name,
            users_count: users_count,
            creator: creator
          }
        end
        
        db.close
        return public_rooms
      rescue => e
        puts "Error getting public rooms: #{e.message}"
        
        # Fallback to in-memory rooms if database query fails
        public_rooms = []
        @chat_rooms.each do |name, room|
          if room.password.nil? || room.password.empty?
            public_rooms << {
              name: name,
              users_count: room.clients.size,
              creator: room.creator
            }
          end
        end
        
        return public_rooms
      end
    end

    def delete_room(name)
      if @chat_rooms.key?(name)
        @chat_rooms.delete(name)
        
        # Remove from database
        begin
          db = db_connection
          db.execute("DELETE FROM rooms WHERE name = ?", [name])
          db.close
          return true
        rescue => e
          puts "Error deleting room from database: #{e.message}"
          return false
        end
      end
      
      return false
    end

    # Assurez-vous que cette méthode est à l'intérieur de la classe
    def refresh_rooms
      @chat_rooms.each do |_, room|
        # Clean up any disconnected clients
        room.clients.delete_if { |_, client| client.nil? || client.socket.closed? }
      end
      
      # Remove empty rooms except 'Main'
      @chat_rooms.delete_if do |name, room| 
        if name != 'Main' && room.clients.empty?
          # Mark as non-persistent in database instead of deleting
          begin
            db = db_connection
            db.execute("UPDATE rooms SET is_persistent = FALSE WHERE name = ?", [name])
            db.close
          rescue => e
            puts "Error updating room persistence: #{e.message}"
          end
          true
        else
          false
        end
      end
    end

  # Ajoutez ce end pour fermer la classe ChatController
  end
