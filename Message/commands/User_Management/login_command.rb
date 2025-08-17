class LoginCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Login"
    @description = "Login to an existing account"
    @command = "/login"
    @aliases = ["/signin"]
  end
  
  def execute(parts, driver, chat_room, username)
    email = parts[1]&.strip
    pass = parts[2]
    
    if email.nil? || pass.nil?
      driver.text("Usage /login <email> <password>")
      return nil
    end
    
    user_manager = @controller.instance_variable_get(:@user_manager)
    login_result = user_manager.login_account(email, pass)
    
    if login_result.start_with?(" Logged in as")
      new_pseudo = login_result.split("as ")[1]

      chat_room.remove_client(username)
      chat_room.add_client(driver, new_pseudo)
      driver.instance_variable_set(:@username, new_pseudo)

      if username.is_a?(String) && username.respond_to?(:replace)
        username.replace(new_pseudo)
      end

      preference_manager = @controller.instance_variable_get(:@preference_manager)
      preference_manager.apply_user_preferences(driver, chat_room, new_pseudo)
    end
    
    driver.text(login_result)
    nil
  end
end