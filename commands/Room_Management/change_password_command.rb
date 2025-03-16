class ChangePasswordCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Change Password"
    @description = "Change the password of the current thread"
    @command = "/cpd"
    @aliases = ["/changepassword", "/setpassword"]
  end
  
  def execute(parts, driver, chat_room, username)
    new_password = parts[1]
    
    if chat_room.creator != username
      driver.text(@controller.translate('only_creator_password', username))
      return nil
    end
    
    chat_room.password = new_password
    driver.text(@controller.translate('password_changed', username))
    nil
  end
end