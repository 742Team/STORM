class HistoryCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "History"
    @description = "Display chat history"
    @command = "/history"
    @aliases = ["/log", "/logs"]
  end
  
  def execute(parts, driver, chat_room, username)
    chat_room.history.each { |line| driver.text(line) }
    nil
  end
end