class ListColorsCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "List Colors"
    @description = "List all available color names"
    @command = "/listcolors"
    @aliases = ["/colors"]
  end
  
  def execute(parts, driver, chat_room, username)
    color_list = @controller::COLOR_NAMES.keys.sort.join(", ")
    driver.text("| Noms de couleurs disponibles: #{color_list}")
    nil
  end
end