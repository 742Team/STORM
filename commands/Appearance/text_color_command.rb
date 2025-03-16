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

    special_msg = "CHANGE_TEXTCOLOR|#{hex_color}"
    chat_room.broadcast_special(special_msg)
    
    # Save preference if user is logged in
    preference_manager = @controller.instance_variable_get(:@preference_manager)
    if preference_manager
      preference_manager.save_user_preference(username, 'text_color', hex_color)
    end

    driver.text(@controller.translate('text_color_changed', username, [new_txt_color, hex_color]))
    nil
  end
end