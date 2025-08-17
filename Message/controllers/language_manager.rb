require 'sqlite3'
require 'singleton'
require 'json'
require 'fileutils'

class LanguageManager
  include Singleton

  attr_reader :current_language, :available_languages

  def initialize
    @default_language = 'en'
    @available_languages = []
    @languages_dir = File.join(File.dirname(__FILE__), '../locales')

    # Ensure languages directory exists
    FileUtils.mkdir_p(@languages_dir) unless Dir.exist?(@languages_dir)

    # Create default language file if it doesn't exist
    create_default_language_file unless File.exist?(File.join(@languages_dir, 'default.json'))

    # Setup database first - but don't load languages yet
    # Languages will be loaded after ChatController completes its initialization
    setup_database
  end

  # Add a method to load languages after database is fully set up
  def initialize_languages
    load_languages
  end

  def translate(key, language = nil, params = [])
    lang = language || @default_language

    begin
      db = db_connection
      result = db.execute("SELECT value FROM translations WHERE language = ? AND key = ?", [lang, key])
      db.close

      if result.empty? && lang != @default_language
        # Fall back to default language
        return translate(key, @default_language, params)
      elsif result.empty?
        # If not found in default language either, return the key
        return key
      else
        translation = result[0][0]
        # Replace placeholders with params
        params.each_with_index do |param, index|
          translation = translation.gsub("%#{index + 1}", param.to_s)
        end
        return translation
      end
    rescue => ex
      puts "Translation error: #{ex.message}"
      return key
    end
  end

  def set_language(username, language_code)
    if @available_languages.include?(language_code)
      begin
        db = db_connection
        user_id = get_user_id(username)
        if user_id
          db.execute("UPDATE user_preferences SET language = ? WHERE user_id = ?", [language_code, user_id])
        end
        db.close
        true
      rescue => ex
        puts "Error setting language: #{ex.message}"
        false
      end
    else
      false
    end
  end

  def get_user_language(username)
    user_id = get_user_id(username)
    return @default_language unless user_id

    begin
      db = db_connection
      result = db.execute("SELECT language FROM user_preferences WHERE user_id = ?", [user_id])
      db.close

      if result.empty?
        return @default_language
      else
        return result[0][0] || @default_language
      end
    rescue => ex
      puts "Error getting user language: #{ex.message}"
      return @default_language
    end
  end

  private

  def create_default_language_file
    default_translations = {
      'en' => {
        'welcome' => 'Welcome %1! Type /help for the list of commands',
        'empty_username' => '⚠️ Empty username, please try again',
        'username_taken' => '⚠️ This username is already in use, please choose another one',
        'enter_username' => 'Enter your username',
        'command_unknown' => '⚠️ Unknown command. Type /help for the list',
        'room_created' => 'Thread %1 created.',
        'room_exists' => '⚠️ Thread %1 already exists',
        'room_not_exists' => '⚠️ Thread %1 does not exist',
        'wrong_password' => '⚠️ Wrong password for %1',
        'password_changed' => 'Thread password changed',
        'only_creator_password' => '⚠️ Only the creator can change the password',
        'only_creator_ban' => '⚠️ Only the creator can ban users',
        'only_creator_kick' => '⚠️ Only the creator can kick users',
        'only_creator_power' => '⚠️ Only the creator can transfer ownership',
        'user_not_in_thread' => '⚠️ User %1 is not in this thread',
        'color_changed' => 'Your color is now %1 (%2)',
        'text_color_changed' => 'Text color changed to %1 (%2)',
        'background_changed' => 'Background changed',
        'font_changed' => 'Font changed to %1',
        'music_shared' => '⚪️ Music shared. Users can listen to it with /playmusic',
        'music_private_only' => '⚠️ Music can only be used in private threads',
        'no_music_shared' => '⚠️ No music has been shared in this thread',
        'playing_music' => '⚪️ Playing music shared by %1',
        'music_stopped' => '⚪️ Music playback stopped',
        'volume_set' => 'Volume set to %1%%',
        'volume_invalid' => '⚠️ Volume must be a number between 0 and 100',
        'invalid_url' => '⚠️ Invalid URL format. URL must start with http:// or https://',
        'file_upload_request' => '📁 File upload request',
        'power_transferred' => '%1 has given the creator role to %2',
        'user_registered' => 'User registered',
        'missing_fields' => 'Missing fields',
        'email_username_used' => 'Email or username already in use',
        'no_account' => 'No account found',
        'invalid_password' => 'Invalid password',
        'logged_in' => 'Logged in as %1',
        'logs_cleared' => 'Logs cleared.',
        'connected_ws' => '⚠️ Connected to HERMES',
        'saving_preferences' => 'Saving your preferences...',
        'preferences_saved' => 'Preferences saved successfully',
        'preferences_restored' => '⚪️ User preferences restored',
        'text_color_restored' => '⚪️ Text color restored %1',
        'background_restored' => '⚪️ Background restored',
        'font_restored' => '⚪️ Font restored %1',
        'color_restored' => '⚪️ Username color restored %1',
        'language_changed' => 'Language changed to %1',
        'language_not_available' => '⚠️ Language not available. Available languages: %1',
        'available_languages' => 'Available languages: %1',
        'usage_language' => 'Usage /language <code> - Change language (available: %1)',
        'server_running' => 'Server running on %1:%2',

        # Friend system translations
        'cmd_gdm' => 'Send a private message to any connected user',
        'gdm_received' => 'Global DM from %1: %2',
        'gdm_sent' => 'Global DM to %1: %2',
        'user_not_connected' => '⚠️ User %1 is not connected',
        'friend_request_sent' => '⚪️ Friend request sent to %1',
        'friend_request_received' => '⚪️ %1 wants to be your friend. Type /acceptfriend %1 to accept',
        'friend_request_accepted' => '⚪️ You are now friends with %1',
        'friend_request_declined' => '⚫️ Friend request from %1 declined',
        'friend_request_not_found' => '⚠️ No friend request from %1 found',
        'already_friends' => '⚠️ You are already friends with %1',
        'not_friends' => '⚠️ You are not friends with %1',
        'friend_removed' => '⚪️ %1 removed from your friends list',
        'friends_list' => 'Your friends: %1',
        'no_friends' => 'You have no friends in your list',
        'pending_requests' => 'Pending friend requests: %1',
        'no_pending_requests' => 'No pending friend requests',
        'cmd_addfriend' => 'Send a friend request to a user',
        'cmd_acceptfriend' => 'Accept a friend request',
        'cmd_declinefriend' => 'Decline a friend request',
        'cmd_removefriend' => 'Remove a user from your friends list',
        'cmd_friends' => 'Show your friends list',
        'cmd_pendingrequests' => 'Show pending friend requests',

        # Room listing translations
        'public_rooms_header' => 'Available public rooms:',
        'no_public_rooms' => 'No public rooms available.',
        'one_user' => '1 user',
        'multiple_users' => '%1 users',
        'created_by' => 'created by %1',
        'cmd_listrooms' => 'List all public rooms'
      }
    }

    File.write(File.join(@languages_dir, 'default.json'), JSON.pretty_generate(default_translations))

    # Create individual language files
    default_translations.each do |lang_code, translations|
      File.write(File.join(@languages_dir, "#{lang_code}.json"), JSON.pretty_generate(translations))
    end
  end

  def setup_database
    begin
      # Check if database file exists, if not, just return and let ChatController create it
      db_path = ENV['DB_PATH'] || 'chat_app.db'
      unless File.exist?(db_path)
        puts "Database file doesn't exist yet, waiting for ChatController to create it"
        return
      end

      db = db_connection

      # Create translations table if it doesn't exist
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
    rescue => ex
      puts "Database setup error in LanguageManager: #{ex.message}"
    end
  end

  def load_languages
    begin
      db = db_connection

      # Check if we need to populate translations from JSON files
      count = db.get_first_value("SELECT COUNT(*) FROM translations")

      if count == 0
        # Load translations from JSON files
        Dir.glob(File.join(@languages_dir, '*.json')).each do |file|
          next if File.basename(file) == 'default.json' # Skip the template file

          lang_code = File.basename(file, '.json')
          translations = JSON.parse(File.read(file))

          # For individual language files
          if translations.is_a?(Hash) && !translations.key?('en') && !translations.key?('fr')
            insert_translations(db, lang_code, translations)
          else
            # For the default file that contains multiple languages
            translations.each do |code, trans|
              insert_translations(db, code, trans)
            end
          end
        end
      end

      # Get available languages
      @available_languages = db.execute("SELECT DISTINCT language FROM translations").flatten

      db.close
    rescue => ex
      puts "Error loading languages: #{ex.message}"
      @available_languages = [@default_language]
    end
  end

  def insert_translations(db, language_code, translations)
    translations.each do |key, value|
      db.execute("INSERT OR REPLACE INTO translations (language, key, value) VALUES (?, ?, ?)",
                [language_code, key, value])
    end
  end

  def get_user_id(username)
    begin
      db = db_connection
      result = db.execute("SELECT id FROM users WHERE username = ?", [username])
      db.close
      return result.empty? ? nil : result[0][0]
    rescue => ex
      puts "Error getting user ID: #{ex.message}"
      return nil
    end
  end

  def db_connection
    # Utiliser la configuration centralisée de la base de données
    require_relative '../../config/database_config'
    DatabaseConfig.get_connection
  end
end
