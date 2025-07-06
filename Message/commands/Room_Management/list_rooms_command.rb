class ListRoomsCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "List Rooms"
    @description = "List all threads you are currently in"
    @command = "/rooms"
    @aliases = ["/mythreads"]
  end
  
  def execute(parts, driver, chat_room, username)
    active_rooms = driver.instance_variable_get(:@active_rooms) || {}
    
    if active_rooms.empty?
      driver.text(@controller.translate('no_active_rooms', username))
    else
      room_list = active_rooms.keys.map do |room_name|
        room_name == chat_room.name ? "#{room_name} (current)" : room_name
      end.join(', ')
      
      driver.text(@controller.translate('active_rooms', username, [room_list]))
    end
    
    nil
  end
end