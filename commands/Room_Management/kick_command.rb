class KickCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Kick"
    @description = "Kick a user from the current thread"
    @command = "/kick"
    @aliases = []
  end
  
  def execute(parts, driver, chat_room, username)
    target_user = parts[1]
    
    if target_user.nil?
      driver.text("Usage /kick <username>")
      return nil
    end
    
    if chat_room.creator != username
      driver.text(@controller.translate('only_creator_kick', username))
      return nil
    end
    
    if !chat_room.has_client?(target_user)
      driver.text(@controller.translate('user_not_in_thread', username, [target_user]))
      return nil
    end
    
    chat_room.kick_user(target_user)
    chat_room.broadcast_message("#{target_user} a été expulsé par #{username}")
    nil
  end
end