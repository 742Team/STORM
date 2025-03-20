class PendingRequestsCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Pending Requests"
    @description = "Show pending friend requests"
    @command = "/pendingrequests"
    @aliases = ["/requests", "/pendings"]
  end
  
  def execute(parts, driver, chat_room, username)
    requests = @controller.get_pending_requests(username)
    
    if requests.empty?
      driver.text(@controller.translate('no_pending_requests', username))
    else
      driver.text(@controller.translate('pending_requests', username, [requests.join(", ")]))
    end
    
    nil
  end
end