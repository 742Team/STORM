class BannedCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Banned"
    @description = "List banned users in the current thread"
    @command = "/banned"
    @aliases = ["/banlist"]
  end
  
  def execute(parts, driver, chat_room, username)
    driver.text("Bannis | #{chat_room.banned_users.join(', ')}")
    nil
  end
end