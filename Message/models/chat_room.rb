require 'concurrent-ruby'
require 'digest'
require 'zlib'

class ChatRoom
  attr_accessor :name, :password, :clients, :creator, :history, :banned_users, :client_colors
  attr_accessor :current_music_url, :current_music_user, :created_at
  attr_accessor :controller
  # Nouvelles propriétés pour les thèmes de salon
  attr_accessor :room_background, :room_text_color, :room_font
  # Optimisations de performance
  attr_accessor :message_cache, :client_stats, :last_activity

  def initialize(name, password=nil, creator=nil)
    @name = name
    @password = password
    @creator = creator
    
    # Structures thread-safe pour les performances
    @clients = Concurrent::Hash.new
    @history = Concurrent::Array.new
    @banned_users = Concurrent::Array.new
    @client_colors = Concurrent::Hash.new
    @message_cache = Concurrent::Hash.new
    @client_stats = Concurrent::Hash.new
    
    @current_music_url = nil
    @current_music_user = nil
    @created_at = nil
    @last_activity = Time.now.to_f
    
    # Don't access ChatController.instance here - it will be set from outside
    @controller = nil
    
    # Initialiser les thèmes de salon
    @room_background = nil
    @room_text_color = nil
    @room_font = nil
    
    # Pool de threads pour les opérations asynchrones
    @thread_pool = Concurrent::ThreadPoolExecutor.new(
      min_threads: 2,
      max_threads: 20,
      max_queue: 500,
      fallback_policy: :caller_runs
    )
    
    # Statistiques de performance
    @stats = Concurrent::Hash.new(0)
    @message_buffer = Concurrent::Array.new
  end

  def add_client(driver, username)
    if @banned_users.include?(username)
      driver.text(@controller.translate('user_banned_from_thread', username))
      return false
    end
    @clients[username] = driver
    
    # Appliquer le thème du salon lors de l'entrée
    apply_room_theme_to_user(driver, username)
    
    broadcast_message(@controller.translate('user_joined_thread', nil, [username]), 'Server')
    return true
  end

  def remove_client(username)
    if @clients.key?(username)
      @clients.delete(username)
      broadcast_message(@controller.translate('user_left_thread', nil, [username]), 'Server')
    end
  end

  def ban_user(username)
    remove_client(username)
    @banned_users << username
    broadcast_message(@controller.translate('user_banned', nil, [username]), 'Server')
  end

  def kick_user(username)
    remove_client(username)
    broadcast_message(@controller.translate('user_kicked', nil, [username]), 'Server')
  end

  def direct_message(sender, recipient, message)
    if @clients.key?(recipient)
      @clients[recipient].text(@controller.translate('dm_received', recipient, [sender, message]))
      @clients[sender].text(@controller.translate('dm_sent', sender, [recipient, message]))
    else
      @clients[sender].text(@controller.translate('user_not_in_thread', sender, [recipient]))
    end
  end

  def set_color(username, color)
    @client_colors[username] = color
  end

  def get_user_color(username)
    @client_colors[username]
  end

  def broadcast_message(message, sender)
    timestamp = (Time.now + 3600).strftime('%H:%M')
    color = @client_colors[sender] || '#FFFFFF'
    message = escape_html(message)

    formatted_message = "[#{timestamp}] <span style='color: #{color}'>#{sender}</span> #{message}"
    @history << formatted_message

    @clients.each_value do |driver|
      begin
        driver.text(formatted_message)
      rescue IOError => e
        puts @controller.translate('message_send_error', nil, [e.message])
      end
    end
  end
  
  # Version ultra-optimisée du broadcast
  def broadcast_message_optimized(message, sender)
    @last_activity = Time.now.to_f
    @stats[:messages_sent] += 1
    
    # Traitement asynchrone ultra-rapide
    @thread_pool.post do
      begin
        timestamp = (Time.now + 3600).strftime('%H:%M')
        color = @client_colors[sender] || '#FFFFFF'
        
        # Décompression si nécessaire
        if message.is_a?(String) && message.start_with?('COMPRESSED:')
          message = Zlib::Inflate.inflate(Base64.decode64(message[11..-1]))
        end
        
        escaped_message = escape_html(message)
        formatted_message = "[#{timestamp}] <span style='color: #{color}'>#{sender}</span> #{escaped_message}"
        
        # Cache du message
        message_id = Digest::MD5.hexdigest("#{sender}:#{message}:#{timestamp}")
        @message_cache[message_id] = {
          formatted: formatted_message,
          sender: sender,
          timestamp: @last_activity,
          raw: message
        }
        
        # Ajouter à l'historique avec limite
        @history << formatted_message
        @history.shift if @history.size > 1000 # Limiter l'historique
        
        # Buffer pour les messages récents
        @message_buffer << {
          id: message_id,
          message: formatted_message,
          timestamp: @last_activity
        }
        @message_buffer.shift if @message_buffer.size > 100
        
        # Broadcast parallèle ultra-rapide
        client_futures = []
        @clients.each do |username, driver|
          client_futures << Concurrent::Future.execute do
            begin
              # Mise à jour des stats client
              @client_stats[username] ||= { messages_received: 0, last_seen: 0 }
              @client_stats[username][:messages_received] += 1
              @client_stats[username][:last_seen] = @last_activity
              
              # Envoi optimisé
              driver.text(formatted_message)
            rescue IOError, Errno::EPIPE => e
              # Client déconnecté, le supprimer
              @clients.delete(username)
              puts "🔌 Client #{username} disconnected from #{@name}".yellow
            rescue => e
              puts "⚫️ Broadcast error to #{username}: #{e.message}".red
            end
          end
        end
        
        # Attendre que tous les envois soient terminés (avec timeout)
        client_futures.each { |f| f.wait(0.1) rescue nil }
        
        # Nettoyage périodique
        cleanup_old_data if @stats[:messages_sent] % 100 == 0
        
      rescue => e
        puts "⚫️ Broadcast optimization error: #{e.message}".red
      end
    end
  end

  def broadcast_image(image_url, sender)
    timestamp = (Time.now + 3600).strftime('%H:%M')
    color = @client_colors[sender] || '#FFFFFF'

    # Create a proper embedded image with responsive styling
    formatted_message = "[#{timestamp}] <span style='color: #{color}'>#{sender}</span> <div class='media-embed'><img src=\"#{image_url}\" alt=\"image\" class=\"embedded-image\" style=\"max-width: 500px; max-height: 400px; object-fit: contain;\"></div>"
    @history << formatted_message

    @clients.each_value do |driver|
      begin
        driver.text(formatted_message)
      rescue IOError => e
        puts @controller.translate('image_send_error', nil, [e.message])
      end
    end
  end

  def broadcast_formatted_message(html_content, sender)
    timestamp = (Time.now + 3600).strftime('%H:%M')
    color = @client_colors[sender] || '#FFFFFF'
  
    formatted_message = "[#{timestamp}] <span style='color: #{color}'>#{sender} </span> #{html_content}"
    @history << formatted_message
  
    @clients.each_value do |driver|
      begin
        driver.text(formatted_message)
      rescue IOError => e
        puts "Error sending formatted message: #{e.message}"
      end
    end
  end

  def clear_chat(driver)
    driver.text("CLEAR_LOGS|")
  end

  def broadcast_background(url, save_to_room = false, username = nil)
    # Si c'est le créateur du salon ou un salon système, sauvegarder le thème
    if save_to_room && can_modify_room_theme?(username)
      @room_background = url
      save_room_theme
    end
    broadcast_special("CHANGE_BG|#{url}")
  end

  def broadcast_special(msg)
    @clients.each_value do |driver|
      begin
        driver.special(msg)
      rescue IOError => e
        puts @controller.translate('special_message_error', nil, [e.message])
      end
    end
  end

  def list_users
    @clients.keys.join(', ')
  end

  # In the commands method, add this line:
  def commands
    username = nil # This will use default language
    
    lines = [
      "/help                        - #{@controller.translate('cmd_help', username)}",
      "/list                        - #{@controller.translate('cmd_list', username)}",
      "/info                        - #{@controller.translate('cmd_info', username)}",
      "/history                     - #{@controller.translate('cmd_history', username)}",
      "/banned                      - #{@controller.translate('cmd_banned', username)}",
      "/cr <#{@controller.translate('name', username)}> <#{@controller.translate('password', username)}>             - #{@controller.translate('cmd_cr', username)}",
      "/cd <#{@controller.translate('name', username)}> <#{@controller.translate('password', username)}>             - #{@controller.translate('cmd_cd', username)}",
      "/cpd <#{@controller.translate('password', username)}>                  - #{@controller.translate('cmd_cpd', username)}",
      "/ban <#{@controller.translate('username', username)}>                - #{@controller.translate('cmd_ban', username)}",
      "/kick <#{@controller.translate('username', username)}>               - #{@controller.translate('cmd_kick', username)}",
      "/listrooms                  - #{@controller.translate('cmd_listrooms', username)}",
      "/gdm <#{@controller.translate('username', username)}> <#{@controller.translate('message', username)}>           - #{@controller.translate('cmd_gdm', username)}",
      "/color <#{@controller.translate('color', username)}>             - #{@controller.translate('cmd_color', username)}",
      "/background <url>            - #{@controller.translate('cmd_background', username)}",
      "/music <url>                 - #{@controller.translate('cmd_music', username)}",
      "/playmusic                   - #{@controller.translate('cmd_playmusic', username)}",
      "/stopmusic                   - #{@controller.translate('cmd_stopmusic', username)}",
      "/volume <#{@controller.translate('level', username)}>             - #{@controller.translate('cmd_volume', username)}",
      "/image <url>                 - #{@controller.translate('cmd_image', username)}",
      "/file <url> [#{@controller.translate('name', username)}]            - #{@controller.translate('cmd_file', username)}",
      "/upload                      - #{@controller.translate('cmd_upload', username)}",
      "/powerto <#{@controller.translate('username', username)}>            - #{@controller.translate('cmd_powerto', username)}",
      "/typo <font_family>          - #{@controller.translate('cmd_typo', username)}",
      "/textcolor <#{@controller.translate('color', username)}>         - #{@controller.translate('cmd_textcolor', username)}",
      "/register <email> <#{@controller.translate('password', username)}> <#{@controller.translate('username', username)}> - #{@controller.translate('cmd_register', username)}",
      "/login <email> <#{@controller.translate('password', username)}>        - #{@controller.translate('cmd_login', username)}",
      "/clear                       - #{@controller.translate('cmd_clear', username)}",
      "/listcolors                  - #{@controller.translate('cmd_listcolors', username)}",
      "/savepref                    - #{@controller.translate('cmd_savepref', username)}",
      "/language <code>             - #{@controller.translate('cmd_language', username)}",
      "/quit                        - #{@controller.translate('cmd_quit', username)}"
    ]

    lines.map { |line| " #{line}" }.join("\n")
  end

  # Liste des administrateurs du système
  ADMIN_USERS = ['DALM1', 'admin', 'administrator'].freeze
  
  # Vérifier si l'utilisateur peut modifier le thème du salon
  def can_modify_room_theme?(username)
    # Le créateur peut toujours modifier
    return true if @creator == username
    
    # Les administrateurs peuvent toujours modifier, même dans les salons système
    return true if is_admin?(username)
    
    # Dans les salons système (comme "Main"), seuls les admins peuvent modifier
    return false if system_room?
    
    # Dans les autres salons, seul le créateur peut modifier
    false
  end
  
  # Vérifier si l'utilisateur est un administrateur
  def is_admin?(username)
    ADMIN_USERS.include?(username)
  end

  # Vérifier si c'est un salon système
  def system_room?
    ['Main', 'General', 'users'].include?(@name)
  end

  # Charger le thème du salon depuis la base de données
  def load_room_theme
    return unless @controller
    
    begin
      db = @controller.db_connection
      result = db.execute("SELECT background_url, text_color, font_family FROM room_themes WHERE room_name = ?", [@name])
      db.close
      
      if !result.empty?
        theme = result[0]
        @room_background = theme[0]
        @room_text_color = theme[1]
        @room_font = theme[2]
      end
    rescue => ex
      puts "Erreur lors du chargement du thème de salon: #{ex.message}"
    end
  end

  private

  def escape_html(text)
    text.to_s.gsub(/[&<>"]/) { |match| {'&' => '&amp;', '<' => '&lt;', '>' => '&gt;', '"' => '&quot;'}[match] }
  end

  # Nouvelles méthodes pour la gestion des thèmes de salon
  def broadcast_text_color(color, username, save_to_room = false)
    if save_to_room && can_modify_room_theme?(username)
      @room_text_color = color
      save_room_theme
    end
    broadcast_special("CHANGE_TEXTCOLOR|#{color}")
  end

  def broadcast_font(font, username, save_to_room = false)
    if save_to_room && can_modify_room_theme?(username)
      @room_font = font
      save_room_theme
    end
    broadcast_special("CHANGE_FONT|#{font}")
  end

  # Appliquer le thème du salon à un utilisateur
  def apply_room_theme_to_user(driver, username)
    return unless has_room_theme?
    
    # Appliquer l'arrière-plan du salon
    if @room_background
      driver.special("CHANGE_BG|#{@room_background}")
    end
    
    # Appliquer la couleur de texte du salon
    if @room_text_color
      driver.special("CHANGE_TEXTCOLOR|#{@room_text_color}")
    end
    
    # Appliquer la police du salon
    if @room_font
      driver.special("CHANGE_FONT|#{@room_font}")
    end
    
    # Appliquer la couleur du pseudo de l'utilisateur (préférence personnelle)
    preference_manager = @controller.instance_variable_get(:@preference_manager)
    if preference_manager
      user_color = preference_manager.get_user_color_preference(username)
      if user_color
        set_color(username, user_color)
      end
    end
  end

  # Vérifier si le salon a un thème personnalisé
  def has_room_theme?
    @room_background || @room_text_color || @room_font
  end

  # Sauvegarder le thème du salon en base de données
  def save_room_theme
    return unless @controller
    
    begin
      db = @controller.db_connection
      
      # Vérifier si le salon existe déjà dans la table des thèmes
      existing = db.execute("SELECT id FROM room_themes WHERE room_name = ?", [@name])
      
      if existing.empty?
        # Créer un nouveau thème de salon
        db.execute(
          "INSERT INTO room_themes (room_name, background_url, text_color, font_family, creator) VALUES (?, ?, ?, ?, ?)",
          [@name, @room_background, @room_text_color, @room_font, @creator]
        )
      else
        # Mettre à jour le thème existant
        db.execute(
          "UPDATE room_themes SET background_url = ?, text_color = ?, font_family = ? WHERE room_name = ?",
          [@room_background, @room_text_color, @room_font, @name]
        )
      end
      
      db.close
    rescue => ex
      puts "Erreur lors de la sauvegarde du thème de salon: #{ex.message}"
    end
  end

  # Méthodes d'optimisation de performance
  def cleanup_old_data
    current_time = Time.now.to_f
    
    # Nettoyer les anciens messages du cache (plus de 1 heure)
    @message_cache.delete_if { |_, data| current_time - data[:timestamp] > 3600 }
    
    # Nettoyer les stats des clients inactifs (plus de 30 minutes)
    @client_stats.delete_if { |_, stats| current_time - stats[:last_seen] > 1800 }
    
    # Nettoyer le buffer des messages (garder seulement les 50 derniers)
    while @message_buffer.size > 50
      @message_buffer.shift
    end
    
    puts "🧹 Cleaned up old data for room #{@name}".blue if @stats[:messages_sent] % 500 == 0
  end
  
  def get_performance_stats
    {
      name: @name,
      clients: @clients.size,
      messages_sent: @stats[:messages_sent],
      cached_messages: @message_cache.size,
      buffer_size: @message_buffer.size,
      last_activity: @last_activity,
      history_size: @history.size
    }
  end
  
  def optimize_memory
    # Forcer le garbage collection
    GC.start
    
    # Compacter l'historique si trop volumineux
    if @history.size > 500
      # Garder seulement les 300 derniers messages
      @history = @history.last(300)
    end
    
    # Nettoyer les caches
    cleanup_old_data
    
    puts "Memory optimized for room #{@name}".green
  end
  
  # Ajouter cette méthode à la classe ChatRoom
  def change_username(old_username, new_username)
    if @clients.key?(old_username)
      driver = @clients.delete(old_username)
      @clients[new_username] = driver
      
      # Mettre à jour la couleur du client si elle existe
      if @client_colors.key?(old_username)
        @client_colors[new_username] = @client_colors.delete(old_username)
      end
      
      # Notifier les autres utilisateurs du changement
      broadcast_message(@controller.translate('user_renamed', nil, [old_username, new_username]), 'Server')
      
      # Si l'utilisateur est le créateur, mettre à jour le créateur
      @creator = new_username if @creator == old_username
      
      return true
    end
    return false
  end
end
