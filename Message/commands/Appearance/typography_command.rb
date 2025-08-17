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

    # Vérifier si l'utilisateur peut modifier le thème du salon
    can_modify_room = chat_room.can_modify_room_theme?(username)
    
    if can_modify_room
      # Modifier le thème du salon
      chat_room.broadcast_font(new_font, username, true)
      driver.text(" ⚪️ Police du salon modifiée")
    else
      # Modifier seulement pour l'utilisateur (si pas de thème de salon)
      if chat_room.has_room_theme?
        driver.text(" ⚠️ Vous ne pouvez pas modifier la police dans ce salon")
        return nil
      else
        special_msg = "CHANGE_FONT|#{new_font}"
        chat_room.broadcast_special(special_msg)
        
        # Sauvegarder comme préférence utilisateur
        preference_manager = @controller.instance_variable_get(:@preference_manager)
        if preference_manager
          preference_manager.save_user_preference(username, 'font_family', new_font)
        end
        
        driver.text(@controller.translate('font_changed', username, [new_font]))
      end
    end
    
    nil
  end
end