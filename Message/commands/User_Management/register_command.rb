class RegisterCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Register"
    @description = "Register a new account"
    @command = "/register"
    @aliases = ["/signup"]
  end
  
  def execute(parts, driver, chat_room, username)
    email = parts[1]&.strip
    pass = parts[2]
    new_user = parts[3]&.strip
    
    if email.nil? || pass.nil? || new_user.nil?
      driver.text("Usage /register <email> <password> <pseudo>")
      return nil
    end
    
    user_manager = @controller.instance_variable_get(:@user_manager)
    register_result = user_manager.register_account(email, pass, new_user)
    driver.text(register_result)
    nil
  end
end