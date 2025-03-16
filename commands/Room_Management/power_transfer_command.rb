class PowerTransferCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Power Transfer"
    @description = "Transfer thread ownership to another user"
    @command = "/powerto"
    @aliases = ["/transfer", "/givepower"]
  end
  
  def execute(parts, driver, chat_room, username)
    target = parts[1]
    if target.nil?
      driver.text("Usage /powerto <pseudo>")
      return nil
    end
    
    if chat_room.creator != username
      driver.text(@controller.translate('only_creator_power', username))
      return nil
    end
    
    unless chat_room.clients.key?(target)
      driver.text(@controller.translate('user_not_in_thread', username, [target]))
      return nil
    end
    
    chat_room.creator = target
    chat_room.broadcast_message("#{username} a donné le rôle de créateur à #{target}", 'Server')
    nil
  end
end