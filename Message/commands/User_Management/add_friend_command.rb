class AddFriendCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Add Friend"
    @description = "Send a friend request to a user"
    @command = "/addfriend"
    @aliases = ["/friend", "/addbuddy"]
  end
  
  def execute(parts, driver, chat_room, username)
    friend_username = parts[1]
    
    if friend_username.nil?
      driver.text("Usage /addfriend <username>")
      return nil
    end
    
    if friend_username == username
      driver.text(@controller.translate('cannot_friend_self', username))
      return nil
    end
    
    result = @controller.send_friend_request(username, friend_username)
    
    case result
    when 'sent'
      driver.text(@controller.translate('friend_request_sent', username, [friend_username]))
    when 'already_friends'
      driver.text(@controller.translate('already_friends', username, [friend_username]))
    when 'already_sent'
      driver.text(@controller.translate('friend_request_already_sent', username, [friend_username]))
    when 'auto_accepted'
      driver.text(@controller.translate('friend_request_accepted', username, [friend_username]))
    else
      driver.text(@controller.translate('friend_request_failed', username, [friend_username]))
    end
    
    nil
  end
end