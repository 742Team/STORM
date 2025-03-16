class MusicCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Music"
    @description = "Share music with other users in the thread"
    @command = "/music"
    @aliases = ["/sharemusic"]
  end
  
  def execute(parts, driver, chat_room, username)
    music_url = parts[1]&.strip
    if music_url.nil?
      driver.text("Usage /music <url>")
      return nil
    end

    if chat_room.password.nil?
      driver.text(@controller.translate('music_private_only', username))
      return nil
    end

    chat_room.broadcast_message("#{username} a partagé de la musique [/playmusic pour écouter]", 'Server')

    chat_room.current_music_url = music_url
    chat_room.current_music_user = username

    driver.text(@controller.translate('music_shared', username))
    nil
  end
end