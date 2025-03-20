class AcceptFriendCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Accept Friend"
    @description = "Accept a friend request"
    @command = "/acceptfriend"
    @aliases = ["/accept"]
  end
  
  def execute(parts, driver, chat_room, username)
    friend_username = parts[1]
    
    if friend_username.nil?
      driver.text("Usage /acceptfriend <username>")
      return nil
    end
    
    success = @controller.accept_friend_request(username, friend_username)
    
    if success
      driver.text(@controller.translate('friend_request_accepted', username, [friend_username]))
    else
      driver.text(@controller.translate('friend_request_not_found', username, [friend_username]))
    end
    
    nil
  end
end