class ChatRoom
  attr_accessor :name, :password, :clients, :creator, :history, :banned_users, :client_colors
  attr_accessor :current_music_url, :current_music_user, :created_at

  def initialize(name, password=nil, creator=nil)
    @name = name
    @password = password
    @creator = creator
    @clients = {}
    @history = []
    @banned_users = []
    @client_colors = {}
    @current_music_url = nil
    @current_music_user = nil
    @created_at = nil
    @controller = ChatController.instance
  end

  def add_client(driver, username)
    if @banned_users.include?(username)
      driver.text(@controller.translate('user_banned_from_thread', username))
      return false
    end
    @clients[username] = driver
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
  
    formatted_message = "[#{timestamp}] <span style='color: #{color}'>#{sender}</span> #{html_content}"
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

  def broadcast_background(url)
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

  private

  def escape_html(text)
    text.to_s.gsub(/[&<>"]/) { |match| {'&' => '&amp;', '<' => '&lt;', '>' => '&gt;', '"' => '&quot;'}[match] }
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
