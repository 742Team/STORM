class FriendsListCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Friends List"
    @description = "Show your friends list"
    @command = "/friends"
    @aliases = ["/friendslist", "/listfriends"]
  end
  
  def execute(parts, driver, chat_room, username)
    friends = @controller.get_friends(username)
    
    if friends.empty?
      driver.text(@controller.translate('no_friends', username))
    else
      driver.text(@controller.translate('friends_list', username, [friends.join(", ")]))
    end
    
    nil
  end
end