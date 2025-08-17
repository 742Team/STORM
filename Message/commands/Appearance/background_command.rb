class BackgroundCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Background"
    @description = "Change the chat background image"
    @command = "/background"
    @aliases = ["/bg", "/wallpaper"]
  end
  
  def execute(parts, driver, chat_room, username)
    bg_url = parts[1]&.strip
    if bg_url.nil?
      driver.text("Usage /background <url>")
      return nil
    end
    
    # Vérifier si l'utilisateur est connecté
    unless chat_room.is_user_logged_in?(username)
      driver.text(" Vous devez être connecté pour modifier l'arrière-plan")
      return nil
    end
    
    # Vérifier si l'utilisateur peut modifier le thème du salon
    can_modify_room = chat_room.can_modify_room_theme?(username)
    
    if can_modify_room
      # Modifier le thème du salon (créateur ou admin)
      chat_room.broadcast_background(bg_url, true, username)
      driver.text(" Arrière-plan du salon modifié")
    else
      # Dans les salons système, permettre à tous les utilisateurs connectés d'avoir leur propre arrière-plan
      if chat_room.system_room?
        # Modifier seulement pour l'utilisateur connecté
        driver.special("CHANGE_BG|#{bg_url}")
        
        # Sauvegarder comme préférence utilisateur
        preference_manager = @controller.instance_variable_get(:@preference_manager)
        if preference_manager
          preference_manager.save_user_preference(username, 'background_url', bg_url)
        end
        
        driver.text(" Votre arrière-plan personnel a été modifié")
      else
        # Dans les autres salons, modifier seulement si pas de thème de salon
        if chat_room.has_room_theme?
          driver.text(" Vous ne pouvez pas modifier l'arrière-plan dans ce salon")
          return nil
        else
          # Modifier seulement pour l'utilisateur
          driver.special("CHANGE_BG|#{bg_url}")
          
          # Sauvegarder comme préférence utilisateur
          preference_manager = @controller.instance_variable_get(:@preference_manager)
          if preference_manager
            preference_manager.save_user_preference(username, 'background_url', bg_url)
          end
          
          driver.text(" Votre arrière-plan personnel a été modifié")
        end
      end
    end
    
    nil
  end
end