class TypographyCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Typography"
    @description = "Change the chat font"
    @command = "/typo"
    @aliases = ["/font", "/typography"]
  end
  
  def execute(parts, driver, chat_room, username)
    new_font = parts[1]&.strip
    if new_font.nil?
      driver.text("Usage /typo <police> (ex: Arial, Helvetica, Times, etc.)")
      return nil
    end

    # Vérifier si l'utilisateur est connecté
    unless chat_room.is_user_logged_in?(username)
      driver.text(" Vous devez être connecté pour modifier la police")
      return nil
    end

    # Vérifier si l'utilisateur peut modifier le thème du salon
    can_modify_room = chat_room.can_modify_room_theme?(username)
    
    if can_modify_room
      # Modifier le thème du salon
      chat_room.broadcast_font(new_font, username, true)
      driver.text(" Police du salon modifiée")
    else
      # Dans les salons système, permettre à tous les utilisateurs connectés d'avoir leur propre police
      if chat_room.system_room?
        # Modifier seulement pour l'utilisateur connecté
        driver.special("CHANGE_FONT|#{new_font}")
        
        # Sauvegarder comme préférence utilisateur
        preference_manager = @controller.instance_variable_get(:@preference_manager)
        if preference_manager
          preference_manager.save_user_preference(username, 'font_family', new_font)
        end
        
        driver.text(" Votre police personnelle a été modifiée")
      else
        # Dans les autres salons, modifier seulement si pas de thème de salon
        if chat_room.has_room_theme?
          driver.text(" Vous ne pouvez pas modifier la police dans ce salon")
          return nil
        else
          # Modifier seulement pour l'utilisateur
          driver.special("CHANGE_FONT|#{new_font}")
          
          # Sauvegarder comme préférence utilisateur
          preference_manager = @controller.instance_variable_get(:@preference_manager)
          if preference_manager
            preference_manager.save_user_preference(username, 'font_family', new_font)
          end
          
          driver.text(" Votre police personnelle a été modifiée")
        end
      end
    end
    
    nil
  end
end