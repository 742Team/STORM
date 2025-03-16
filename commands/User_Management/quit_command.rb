class QuitCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Quit"
    @description = "Disconnect from the server"
    @command = "/quit"
    @aliases = ["/exit", "/disconnect"]
  end
  
  def execute(parts, driver, chat_room, username)
    chat_room.remove_client(username)
    driver.close
    nil
  end
end