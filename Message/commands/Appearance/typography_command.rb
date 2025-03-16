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
      driver.text("Usage /typo <font_family>")
      return nil
    end
    
    special_msg = "CHANGE_FONT|#{new_font}"
    chat_room.broadcast_special(special_msg)
    
    # Save preference if user is logged in
    preference_manager = @controller.instance_variable_get(:@preference_manager)
    if preference_manager
      preference_manager.save_user_preference(username, 'font_family', new_font)
    end
    
    driver.text(@controller.translate('font_changed', username, [new_font]))
    nil
  end
end