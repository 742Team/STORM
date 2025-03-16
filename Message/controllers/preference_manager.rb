class PreferenceManager
  def initialize(controller = nil)
    @controller = controller
    @user_manager = nil  # Will be set later
  end

  # Add a setter method for user_manager
  def set_user_manager(user_manager)
    @user_manager = user_manager
  end
  
  def save_user_preference(username, preference_key, preference_value)
    user_id = @user_manager.get_user_id(username)
    return false unless user_id

    begin
      db = @controller.db_connection
      result = db.execute("SELECT user_id FROM user_preferences WHERE user_id=?", [user_id])

      if result.empty?
        db.execute("INSERT INTO user_preferences (user_id, #{preference_key}) VALUES (?, ?)",
                  [user_id, preference_value])
      else
        db.execute("UPDATE user_preferences SET #{preference_key}=? WHERE user_id=?",
                  [preference_value, user_id])
      end
      db.close
      return true
    rescue => ex
      puts "| ⚫️ Erreur lors de la sauvegarde des préférences: #{ex.message}"
      return false
    end
  end

  def save_all_preferences(username, chat_room)
    user_color = chat_room.get_user_color(username)
    save_user_preference(username, 'color', user_color) if user_color
  end

  def apply_user_preferences(driver, chat_room, username)
    user_id = @user_manager.get_user_id(username)
    return unless user_id

    begin
      db = @controller.db_connection
      result = db.execute("SELECT text_color, background_url, font_family, color FROM user_preferences WHERE user_id=?", [user_id])
      db.close

      if !result.empty?
        prefs = result[0]
        text_color = prefs[0]
        bg_url = prefs[1]
        font = prefs[2]
        color = prefs[3]

        if text_color
          special_msg = "CHANGE_TEXTCOLOR|#{text_color}"
          chat_room.broadcast_special(special_msg)
          driver.text("| ⚪️ Couleur de texte restaurée #{text_color}")
        end

        if bg_url
          chat_room.broadcast_background(bg_url)
          driver.text("| ⚪️ Arrière-plan restauré")
        end

        if font
          special_msg = "CHANGE_FONT|#{font}"
          chat_room.broadcast_special(special_msg)
          driver.text("| ⚪️ Police de text restaurée #{font}")
        end

        if color
          chat_room.set_color(username, color)
          driver.text("| ⚪️ Couleur de pseudo restaurée #{color}")
        end

        driver.text("| ⚪️ Préférences utilisateur restaurées")
      end
    rescue => ex
      puts "Erreur lors de l'application des préférences #{ex.message}"
    end
  end
end