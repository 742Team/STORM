class InfoCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Info"
    @description = "Display information about the current thread"
    @command = "/info"
    @aliases = ["/threadinfo", "/roominfo"]
  end
  
  def execute(parts, driver, chat_room, username)
    driver.text("Thread | #{chat_room.name} | creator | #{chat_room.creator} | users | #{chat_room.list_users}")
    nil
  end
end