class ClearCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Clear"
    @description = "Clear chat history for all users"
    @command = "/clear"
    @aliases = ["/cls"]
  end
  
  def execute(parts, driver, chat_room, username)
    chat_room.history.clear
    chat_room.broadcast_special("CLEAR_LOGS|")
    driver.text(" Logs cleared.")
    driver.text(" ⚠️ Connected to ")
    nil
  end
end