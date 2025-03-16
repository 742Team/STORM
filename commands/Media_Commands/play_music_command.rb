class PlayMusicCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Play Music"
    @description = "Play shared music in the current thread"
    @command = "/playmusic"
    @aliases = ["/play"]
  end
  
  def execute(parts, driver, chat_room, username)
    if !chat_room.respond_to?(:current_music_url) || chat_room.current_music_url.nil?
      driver.text("⚠️ Aucune musique n'a été partagée dans ce thread")
      return nil
    end

    special_msg = "PLAY_MUSIC|#{chat_room.current_music_url}"
    driver.special(special_msg)
    driver.text("🎵 Lecture de la musique partagée par #{chat_room.current_music_user}")
    nil
  end
end