class TextColorCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Text Color"
    @description = "Change the chat text color"
    @command = "/textcolor"
    @aliases = ["/txtcolor", "/messagecolor"]
  end
  
  def execute(parts, driver, chat_room, username)
    new_txt_color = parts[1]&.strip
    if new_txt_color.nil?
      driver.text("Usage /textcolor <couleur> (nom de couleur ou code hexadécimal)")
      return nil
    end

    hex_color = @controller.convert_color(new_txt_color)

    # Vérifier si l'utilisateur peut modifier le thème du salon
    can_modify_room = chat_room.can_modify_room_theme?(username)
    
    if can_modify_room
      # Modifier le thème du salon
      chat_room.broadcast_text_color(hex_color, username, true)
      driver.text(" ⚪️ Couleur de texte du salon modifiée")
    else
      # Dans les salons système, ne pas permettre aux invités de changer la couleur de texte pour tous
      if chat_room.system_room?
        driver.text(" ⚠️ Vous ne pouvez pas modifier la couleur de texte dans ce salon système")
        return nil
      end
      
      # Modifier seulement pour l'utilisateur (si pas de thème de salon)
      if chat_room.has_room_theme?
        driver.text(" ⚠️ Vous ne pouvez pas modifier la couleur de texte dans ce salon")
        return nil
      else
        special_msg = "CHANGE_TEXTCOLOR|#{hex_color}"
        chat_room.broadcast_special(special_msg)
        
        # Sauvegarder comme préférence utilisateur
        preference_manager = @controller.instance_variable_get(:@preference_manager)
        if preference_manager
          preference_manager.save_user_preference(username, 'text_color', hex_color)
        end
        
        driver.text(@controller.translate('text_color_changed', username, [new_txt_color, hex_color]))
      end
    end
    
    nil
  end
end