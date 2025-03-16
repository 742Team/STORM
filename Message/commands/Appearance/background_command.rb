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
    
    chat_room.broadcast_background(bg_url)
    
    # Save preference if user is logged in
    preference_manager = @controller.instance_variable_get(:@preference_manager)
    if preference_manager
      preference_manager.save_user_preference(username, 'background_url', bg_url)
    end
    
    nil
  end
end