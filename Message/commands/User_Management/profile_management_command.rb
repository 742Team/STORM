class ProfilePicture < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Profile Picture"
    @description = "Change your profile picture"
    @command = "/pp"
    @aliases = ["/profilepicture"]
  end
  
  def execute(parts, driver, chat_room, username)
    bg_url = parts[1]&.strip
    if bg_url.nil?
      driver.text("Usage /pp")
      return nil
    end

    special_msg = "REQUEST_FILE_UPLOAD|"
    driver.special(special_msg)
    
    # Save preference if user is logged in
    preference_manager = @controller.instance_variable_get(:@preference_manager)
    if preference_manager
      preference_manager.save_user_preference(username, 'background_url', bg_url)
    end
    
    nil
  end
end