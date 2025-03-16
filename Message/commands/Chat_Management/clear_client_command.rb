class ClearClientCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Clear Client"
    @description = "Clear chat history for your client only"
    @command = "/clearclient"
    @aliases = ["/clsclient"]
  end
  
  def execute(parts, driver, chat_room, username)
    driver.text("CLEAR_LOGS_CLIENT|")
    nil
  end
end