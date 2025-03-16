require 'securerandom'

class CommandHandler
  def initialize(controller, user_manager, preference_manager, language_manager)
    @controller = controller
    @user_manager = user_manager
    @preference_manager = preference_manager
    @language_manager = language_manager
  end
  
  def handle_command(msg, driver, chat_room, username)
    parts = msg.split(' ')
    command = parts[0].downcase
    new_room = nil
  
    # Skip user-related commands if user_manager is not initialized yet
    if @user_manager.nil? && ['/register', '/login'].include?(command)
      driver.text("Command not available yet, please try again in a moment.")
      return nil
    end
  
    case command
    when '/help'
      handle_help(driver, chat_room, username)
    when '/list'
      handle_list(driver, chat_room, username)
    when '/info'
      handle_info(driver, chat_room, username)
    when '/history'
      handle_history(driver, chat_room, username)
    when '/banned'
      handle_banned(driver, chat_room, username)
    when '/cr'
      new_room = handle_create_room(parts, driver, chat_room, username)
    when '/cd'
      new_room = handle_change_room(parts, driver, chat_room, username)
    when '/cpd'
      handle_change_password(parts, driver, chat_room, username)
    when '/ban'
      handle_ban(parts, driver, chat_room, username)
    when '/kick'
      handle_kick(parts, driver, chat_room, username)
    when '/dm'
      handle_direct_message(parts, driver, chat_room, username)
    when '/qt'
      driver.text(@controller.translate('command_not_implemented', username))
    when '/quit'
      handle_quit(chat_room, username, driver)
    when '/color'
      handle_color(parts, driver, chat_room, username)
    when '/background'
      handle_background(parts, driver, chat_room, username)
    when '/music'
      handle_music(parts, driver, chat_room, username)
    when '/playmusic'
      handle_play_music(driver, chat_room, username)
    when '/stopmusic'
      handle_stop_music(driver, username)
    when '/volume'
      handle_volume(parts, driver, username)
    when '/image'
      handle_image(parts, driver, chat_room, username)
    when '/file'
      handle_file(parts, driver, chat_room, username)
    when '/upload'
      handle_upload(driver, username)
    when '/powerto'
      handle_power_transfer(parts, driver, chat_room, username)
    when '/typo'
      handle_typography(parts, driver, chat_room, username)
    when '/textcolor'
      handle_text_color(parts, driver, chat_room, username)
    when '/register'
      handle_register(parts, driver, username)
    when '/login'
      handle_login(parts, driver, chat_room, username)
    when '/clear'
      handle_clear(driver, chat_room, username)
    when '/savepref'
      handle_save_preferences(driver, chat_room, username)
    when '/listcolors'
      handle_list_colors(driver, username)
    when '/language'
      handle_language(parts, driver, chat_room, username)
    else
      driver.text(@controller.translate('command_unknown', username))
    end
  
    return new_room
  end

  private

  # New command handlers from ChatController
  def handle_help(driver, chat_room, username)
    driver.text(chat_room.commands)
    driver.text("Pour les commandes /color et /textcolor, vous pouvez utiliser les noms de couleurs (ex: /color red) ou les codes hexadécimaux (ex: /color #FF0000).")
  end

  def handle_list(driver, chat_room, username)
    driver.text("Utilisateurs dans ce thread | #{chat_room.list_users}")
  end

  def handle_info(driver, chat_room, username)
    driver.text("Thread | #{chat_room.name} | creator | #{chat_room.creator} | users | #{chat_room.list_users}")
  end

  def handle_history(driver, chat_room, username)
    chat_room.history.each { |line| driver.text(line) }
  end

  def handle_banned(driver, chat_room, username)
    driver.text("Bannis | #{chat_room.banned_users.join(', ')}")
  end

  def handle_create_room(parts, driver, chat_room, username)
    room_name = parts[1]
    room_pass = parts[2]
    if room_name.nil?
      driver.text("Usage /cr <nom> <password>")
      return nil
    end

    new_room = @controller.create_room(room_name, room_pass, username)
    if new_room.nil?
      driver.text("⚠️ Le thread #{room_name} existe déjà")
      return nil
    end

    driver.text("Thread #{room_name} créé.")
    chat_room.remove_client(username)
    new_room.add_client(driver, username)
    return new_room
  end

  def handle_change_room(parts, driver, chat_room, username)
    room_name = parts[1]
    room_pass = parts[2]
    if room_name.nil?
      driver.text("Usage /cd <nom> <password>")
      return nil
    end

    if @controller.chat_rooms.key?(room_name)
      new_room = @controller.chat_rooms[room_name]

      if new_room.password.nil? || new_room.password == room_pass
        chat_room.remove_client(username)

        if new_room.add_client(driver, username)
          return new_room
        end
      else
        driver.text("⚠️ Mot de passe incorrect pour #{room_name}")
      end
    else
      driver.text("⚠️ Le thread #{room_name} n'existe pas")
    end
    
    return nil
  end

  def handle_change_password(parts, driver, chat_room, username)
    new_password = parts[1]
    if chat_room.creator == username
      chat_room.password = new_password
      driver.text("Mot de passe du thread changé")
    else
      driver.text("⚠️ Seul le créateur peut changer le password")
    end
  end

  def handle_ban(parts, driver, chat_room, username)
    user_to_ban = parts[1]
    if user_to_ban.nil?
      driver.text("Usage /ban <pseudo>")
      return nil
    end
    if chat_room.creator == username
      chat_room.ban_user(user_to_ban)
    else
      driver.text("⚠️ Seul le créateur peut bannir")
    end
  end

  def handle_kick(parts, driver, chat_room, username)
    user_to_kick = parts[1]
    if user_to_kick.nil?
      driver.text("Usage /kick <pseudo>")
      return nil
    end
    if chat_room.creator == username
      chat_room.kick_user(user_to_kick)
    else
      driver.text("⚠️ Seul le créateur peut kick")
    end
  end

  def handle_direct_message(parts, driver, chat_room, username)
    user_to_dm = parts[1]
    dm_message = parts[2..-1].join(' ')
    if user_to_dm.nil? || dm_message.empty?
      driver.text("Usage /dm <pseudo> <message>")
      return nil
    end
    chat_room.direct_message(username, user_to_dm, dm_message)
  end

  def handle_quit(chat_room, username, driver)
    chat_room.remove_client(username)
    driver.close
  end

  def handle_color(parts, driver, chat_room, username)
    new_color = parts[1]
    if new_color.nil?
      driver.text("Usage /color <couleur> (nom de couleur ou code hexadécimal)")
      return nil
    end

    hex_color = @controller.convert_color(new_color)

    chat_room.set_color(username, hex_color)
    driver.text("Votre couleur est maintenant #{new_color} (#{hex_color})")

    @preference_manager.save_user_preference(username, 'color', hex_color)
  end

  def handle_background(parts, driver, chat_room, username)
    bg_url = parts[1]&.strip
    if bg_url.nil?
      driver.text("Usage /background <url>")
      return nil
    end
    chat_room.broadcast_background(bg_url)

    @preference_manager.save_user_preference(username, 'background_url', bg_url)
  end

  def handle_music(parts, driver, chat_room, username)
    music_url = parts[1]&.strip
    if music_url.nil?
      driver.text("Usage /music <url>")
      return nil
    end

    if chat_room.password.nil?
      driver.text("⚠️ La musique ne peut être utilisée que dans les threads privés")
      return nil
    end

    chat_room.broadcast_message("#{username} a partagé de la musique [/playmusic pour écouter]", 'Server')

    chat_room.current_music_url = music_url
    chat_room.current_music_user = username

    driver.text("🎵 Musique partagée. Les utilisateurs peuvent l'écouter avec /playmusic")
  end

  def handle_play_music(driver, chat_room, username)
    if !chat_room.respond_to?(:current_music_url) || chat_room.current_music_url.nil?
      driver.text("⚠️ Aucune musique n'a été partagée dans ce thread")
      return nil
    end

    special_msg = "PLAY_MUSIC|#{chat_room.current_music_url}"
    driver.special(special_msg)
    driver.text("🎵 Lecture de la musique partagée par #{chat_room.current_music_user}")
  end

  def handle_stop_music(driver, username)
    special_msg = "STOP_MUSIC|"
    driver.special(special_msg)
    driver.text("🎵 Lecture de la musique arrêtée")
  end

  def handle_volume(parts, driver, username)
    volume_level = parts[1]
    if volume_level.nil?
      driver.text("Usage /volume <niveau> (0-100)")
      return nil
    end

    begin
      volume = Integer(volume_level)
      if volume < 0 || volume > 100
        driver.text("⚠️ Le volume doit être entre 0 et 100")
        return nil
      end

      special_msg = "SET_VOLUME|#{volume}"
      driver.special(special_msg)
      driver.text("Volume réglé à #{volume}%")
    rescue ArgumentError
      driver.text("⚠️ Le volume doit être un nombre entre 0 et 100")
    end
  end

  def handle_image(parts, driver, chat_room, username)
    image_url = parts[1]&.strip
    if image_url.nil?
      driver.text("Usage /image <url>")
      return nil
    end

    unless image_url =~ /\A(http|https):\/\//i
      driver.text("⚠️ Format d'URL invalide. L'URL doit commencer par http:// ou https://")
      return nil
    end

    # Create an embedded image with proper styling
    safe_html = "<div class='media-embed'><img src=\"#{image_url}\" alt=\"image\" class=\"embedded-image\" style=\"max-width: 500px; max-height: 400px;\"></div>"
    chat_room.broadcast_formatted_message(safe_html, username)
  end

  def handle_file(parts, driver, chat_room, username)
    file_url = parts[1]&.strip
    file_name = parts[2] || "fichier partagé"
    if file_url.nil?
      driver.text("Usage /file <url> [nom_du_fichier]")
      return nil
    end

    unless file_url =~ /\A(http|https):\/\//i
      driver.text("⚠️ Format d'URL invalide. L'URL doit commencer par http:// ou https://")
      return nil
    end

    extension = File.extname(file_url).downcase
    
    # Determine if this is a media file that should be embedded
    is_media = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.mp4', '.webm', '.mp3', '.wav', '.ogg'].include?(extension)
    
    if is_media
      # Handle media files with proper embedding
      case extension
      when '.jpg', '.jpeg', '.png', '.gif', '.webp'
        # Image embedding
        safe_html = "<div class='media-embed'><img src=\"#{file_url}\" alt=\"#{file_name}\" class=\"embedded-image\" style=\"max-width: 500px; max-height: 400px; object-fit: contain;\"></div>"
      when '.mp4', '.webm'
        # Video embedding
        safe_html = "<div class='media-embed'><video controls class='embedded-video' style='max-width: 500px; max-height: 400px;'><source src=\"#{file_url}\" type=\"video/#{extension.sub('.', '')}\">Video not supported</video></div>"
      when '.mp3', '.wav', '.ogg'
        # Audio embedding
        safe_html = "<div class='media-embed'><audio controls class='embedded-audio' style='width: 300px;'><source src=\"#{file_url}\" type=\"audio/#{extension.sub('.', '')}\">Audio not supported</audio></div>"
      end
      
      chat_room.broadcast_formatted_message(safe_html, username)
    else
      # Handle non-media files with icon and link
      icon = case extension
        when '.pdf' then '📄'
        when '.doc', '.docx' then '📝'
        when '.xls', '.xlsx' then '📊'
        when '.ppt', '.pptx' then '📑'
        when '.zip', '.rar', '.tar', '.gz' then '🗂️'
        else '📁'
      end

      safe_html = "#{icon} <a href=\"#{file_url}\" target=\"_blank\" class=\"file-link\">#{file_name}</a>"
      chat_room.broadcast_formatted_message(safe_html, username)
    end
  end

  def handle_upload(driver, username)
    driver.text("| 📁 Demande d'upload de fichier")
    special_msg = "REQUEST_FILE_UPLOAD|"
    driver.special(special_msg)
  end

  def handle_power_transfer(parts, driver, chat_room, username)
    target = parts[1]
    if target.nil?
      driver.text("Usage /powerto <pseudo>")
      return nil
    end
    if chat_room.creator != username
      driver.text("⚠️ Seul le créateur peut donner le role")
      return nil
    end
    unless chat_room.clients.key?(target)
      driver.text("⚠️ L'utilisateur #{target} n'est pas dans ce thread")
      return nil
    end
    chat_room.creator = target
    chat_room.broadcast_message("#{username} a donné le rôle de créateur à #{target}", 'Server')
  end

  def handle_typography(parts, driver, chat_room, username)
    new_font = parts[1]&.strip
    if new_font.nil?
      driver.text("Usage /typo <font_family>")
      return nil
    end
    special_msg = "CHANGE_FONT|#{new_font}"
    chat_room.broadcast_special(special_msg)

    @preference_manager.save_user_preference(username, 'font_family', new_font)
  end

  def handle_text_color(parts, driver, chat_room, username)
    new_txt_color = parts[1]&.strip
    if new_txt_color.nil?
      driver.text("Usage /textcolor <couleur> (nom de couleur ou code hexadécimal)")
      return nil
    end

    hex_color = @controller.convert_color(new_txt_color)

    special_msg = "CHANGE_TEXTCOLOR|#{hex_color}"
    chat_room.broadcast_special(special_msg)

    driver.text("| Couleur du texte changée en #{new_txt_color} (#{hex_color})")

    @preference_manager.save_user_preference(username, 'text_color', hex_color)
  end

  def handle_register(parts, driver, username)
    email = parts[1]&.strip
    pass = parts[2]
    new_user = parts[3]&.strip
    if email.nil? || pass.nil? || new_user.nil?
      driver.text("Usage /register <email> <password> <pseudo>")
      return nil
    end
    register_result = @user_manager.register_account(email, pass, new_user)
    driver.text(register_result)
  end

  def handle_login(parts, driver, chat_room, username)
    email = parts[1]&.strip
    pass = parts[2]
    if email.nil? || pass.nil?
      driver.text("Usage /login <email> <password>")
      return nil
    end
    login_result = @user_manager.login_account(email, pass)
    if login_result.start_with?("| Logged in as")
      new_pseudo = login_result.split("as ")[1]

      chat_room.remove_client(username)
      chat_room.add_client(driver, new_pseudo)
      driver.instance_variable_set(:@username, new_pseudo)

      if username.is_a?(String) && username.respond_to?(:replace)
        username.replace(new_pseudo)
      end

      @preference_manager.apply_user_preferences(driver, chat_room, new_pseudo)
    end
    driver.text(login_result)
  end

  def handle_clear(driver, chat_room, username)
    chat_room.history.clear
    chat_room.broadcast_special("CLEAR_LOGS|")
    driver.text("|| Logs cleared.")
    driver.text("|| ⚠️ Connected to WS server")
  end

  def handle_save_preferences(driver, chat_room, username)
    driver.text("| Sauvegarde de vos préférences en cours...")
    @preference_manager.save_all_preferences(username, chat_room)
    driver.text("| Préférences sauvegardées avec succès")
  end

  def handle_list_colors(driver, username)
    color_list = @controller::COLOR_NAMES.keys.sort.join(", ")
    driver.text("| Noms de couleurs disponibles: #{color_list}")
  end
  
  def handle_language(parts, driver, chat_room, username)
    lang_code = parts[1]&.strip
    if lang_code.nil?
      driver.text(@controller.translate('language_usage', username))
      return nil
    end
    
    if @language_manager.set_language(username, lang_code)
      driver.text(@controller.translate('language_changed', username, [lang_code]))
    else
      driver.text(@controller.translate('language_invalid', username, [lang_code]))
    end
  end
end