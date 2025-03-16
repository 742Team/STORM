class ListCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "List"
    @description = "List users in the current thread"
    @command = "/list"
    @aliases = ["/users", "/who"]
  end
  
  def execute(parts, driver, chat_room, username)
    driver.text("Utilisateurs dans ce thread | #{chat_room.list_users}")
    nil
  end
end