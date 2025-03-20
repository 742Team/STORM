class GlobalDirectMessageCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Global Direct Message"
    @description = "Send a private message to any connected user"
    @command = "/gdm"
    @aliases = ["/global", "/gmsg"]
  end
  
  def execute(parts, driver, chat_room, username)
    target_user = parts[1]
    message = parts[2..-1]&.join(' ')
    
    if target_user.nil? || message.nil? || message.empty?
      driver.text("Usage /gdm <username> <message>")
      return nil
    end
    
    # Utiliser la méthode global_direct_message du controller
    @controller.global_direct_message(username, target_user, message)
    nil
  end
end