class PreferenceManager
  def initialize(controller = nil)
    @controller = controller
    @user_manager = nil  # Will be set later
    create_room_themes_table
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
      puts " ⚫️ Erreur lors de la sauvegarde des préférences: #{ex.message}"
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
        user_text_color = prefs[0]
        user_bg_url = prefs[1]
        user_font = prefs[2]
        user_color = prefs[3]

        # Dans un salon avec thème personnalisé, ne pas appliquer les préférences globales
        # sauf si l'utilisateur est le créateur du salon
        if chat_room.has_room_theme? && !chat_room.can_modify_room_theme?(username)
          # Appliquer seulement la couleur du pseudo (préférence personnelle)
          if user_color
            chat_room.set_color(username, user_color)
            driver.text(" ⚪️ Couleur de pseudo restaurée #{user_color}")
          end
        else
          # Appliquer toutes les préférences utilisateur
          if user_text_color && !chat_room.room_text_color
            special_msg = "CHANGE_TEXTCOLOR|#{user_text_color}"
            chat_room.broadcast_special(special_msg)
            driver.text(" ⚪️ Couleur de texte restaurée #{user_text_color}")
          end

          if user_bg_url && !chat_room.room_background
            chat_room.broadcast_background(user_bg_url)
            driver.text(" ⚪️ Arrière-plan restauré")
          end

          if user_font && !chat_room.room_font
            special_msg = "CHANGE_FONT|#{user_font}"
            chat_room.broadcast_special(special_msg)
            driver.text(" ⚪️ Police de texte restaurée #{user_font}")
          end

          if user_color
            chat_room.set_color(username, user_color)
            driver.text(" ⚪️ Couleur de pseudo restaurée #{user_color}")
          end
        end

        driver.text(" ⚪️ Préférences utilisateur appliquées")
      end
    rescue => ex
      puts "Erreur lors de l'application des préférences #{ex.message}"
    end
  end

  # Obtenir la couleur de pseudo de l'utilisateur
  def get_user_color_preference(username)
    user_id = @user_manager.get_user_id(username)
    return nil unless user_id

    begin
      db = @controller.db_connection
      result = db.execute("SELECT color FROM user_preferences WHERE user_id=?", [user_id])
      db.close
      
      return result.empty? ? nil : result[0][0]
    rescue => ex
      puts "Erreur lors de la récupération de la couleur utilisateur: #{ex.message}"
      return nil
    end
  end

  # Créer la table des thèmes de salon
  def create_room_themes_table
    begin
      db = @controller.db_connection
      db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS room_themes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          room_name TEXT UNIQUE NOT NULL,
          background_url TEXT,
          text_color TEXT,
          font_family TEXT,
          creator TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
      SQL
      db.close
    rescue => ex
      puts "Erreur lors de la création de la table room_themes: #{ex.message}"
    end
  end
end