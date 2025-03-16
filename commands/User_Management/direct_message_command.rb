class DirectMessageCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Direct Message"
    @description = "Send a private message to another user"
    @command = "/dm"
    @aliases = ["/pm", "/msg", "/whisper"]
  end
  
  def execute(parts, driver, chat_room, username)
    target_user = parts[1]
    message = parts[2..-1]&.join(' ')
    
    if target_user.nil? || message.nil?
      driver.text("Usage /dm <username> <message>")
      return nil
    end
    
    if !chat_room.has_client?(target_user)
      driver.text(@controller.translate('user_not_in_thread', username, [target_user]))
      return nil
    end
    
    # Send to recipient
    target_driver = chat_room.get_client_driver(target_user)
    target_driver.text("DM de #{username}: #{message}")
    
    # Confirmation to sender
    driver.text("DM à #{target_user}: #{message}")
    nil
  end
end