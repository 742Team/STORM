class RemoveFriendCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Remove Friend"
    @description = "Remove a user from your friends list"
    @command = "/removefriend"
    @aliases = ["/unfriend", "/deletefriend"]
  end
  
  def execute(parts, driver, chat_room, username)
    friend_username = parts[1]
    
    if friend_username.nil?
      driver.text("Usage /removefriend <username>")
      return nil
    end
    
    if !@controller.are_friends(username, friend_username)
      driver.text(@controller.translate('not_friends', username, [friend_username]))
      return nil
    end
    
    success = @controller.remove_friend(username, friend_username)
    
    if success
      driver.text(@controller.translate('friend_removed', username, [friend_username]))
    else
      driver.text(@controller.translate('friend_remove_failed', username, [friend_username]))
    end
    
    nil
  end
end