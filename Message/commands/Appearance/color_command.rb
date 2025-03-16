class ColorCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Color"
    @description = "Change your username color"
    @command = "/color"
    @aliases = ["/usercolor"]
  end
  
  def execute(parts, driver, chat_room, username)
    color = parts[1]
    
    if color.nil?
      driver.text("Usage /color <color_name or #hex_code>")
      return nil
    end
    
    # Validate and normalize color
    if color.start_with?('#')
      # Hex color code
      unless color.match(/^#[0-9A-Fa-f]{6}$/)
        driver.text("⚠️ Format de couleur hexadécimal invalide. Utilisez #RRGGBB")
        return nil
      end
    else
      # Named color - convert to lowercase
      color = color.downcase
    end
    
    chat_room.set_client_color(username, color)
    
    # Save preference if user is logged in
    preference_manager = @controller.instance_variable_get(:@preference_manager)
    if preference_manager
      preference_manager.save_user_preference(username, 'color', color)
    end
    
    driver.text(@controller.translate('color_changed', username, [color, color]))
    nil
  end
end