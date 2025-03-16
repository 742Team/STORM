class StopMusicCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Stop Music"
    @description = "Stop playing the current music"
    @command = "/stopmusic"
    @aliases = ["/stop"]
  end
  
  def execute(parts, driver, chat_room, username)
    special_msg = "STOP_MUSIC|"
    driver.special(special_msg)
    driver.text("🎵 Lecture de la musique arrêtée")
    nil
  end
end