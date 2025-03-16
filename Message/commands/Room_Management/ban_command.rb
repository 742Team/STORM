class BanCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Ban"
    @description = "Ban a user from the current thread"
    @command = "/ban"
    @aliases = []
  end
  
  def execute(parts, driver, chat_room, username)
    target_user = parts[1]
    
    if target_user.nil?
      driver.text("Usage /ban <username>")
      return nil
    end
    
    if chat_room.creator != username
      driver.text(@controller.translate('only_creator_ban', username))
      return nil
    end
    
    if !chat_room.has_client?(target_user)
      driver.text(@controller.translate('user_not_in_thread', username, [target_user]))
      return nil
    end
    
    chat_room.ban_user(target_user)
    chat_room.broadcast_message("#{target_user} a été banni par #{username}")
    nil
  end
end