class DeclineFriendCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Decline Friend"
    @description = "Decline a friend request"
    @command = "/declinefriend"
    @aliases = ["/decline", "/rejectfriend"]
  end
  
  def execute(parts, driver, chat_room, username)
    friend_username = parts[1]
    
    if friend_username.nil?
      driver.text("Usage /declinefriend <username>")
      return nil
    end
    
    success = @controller.decline_friend_request(username, friend_username)
    
    if success
      driver.text(@controller.translate('friend_request_declined', username, [friend_username]))
    else
      driver.text(@controller.translate('friend_request_not_found', username, [friend_username]))
    end
    
    nil
  end
end