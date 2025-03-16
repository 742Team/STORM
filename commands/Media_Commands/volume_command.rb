class VolumeCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Volume"
    @description = "Adjust the music volume (0-100)"
    @command = "/volume"
    @aliases = ["/vol"]
  end
  
  def execute(parts, driver, chat_room, username)
    volume_level = parts[1]
    if volume_level.nil?
      driver.text("Usage /volume <niveau> (0-100)")
      return nil
    end

    begin
      volume = Integer(volume_level)
      if volume < 0 || volume > 100
        driver.text("⚠️ Le volume doit être entre 0 et 100")
        return nil
      end

      special_msg = "SET_VOLUME|#{volume}"
      driver.special(special_msg)
      driver.text("Volume réglé à #{volume}%")
    rescue ArgumentError
      driver.text("⚠️ Le volume doit être un nombre entre 0 et 100")
    end
    
    nil
  end
end