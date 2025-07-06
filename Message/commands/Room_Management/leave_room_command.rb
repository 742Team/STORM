class LeaveRoomCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Leave Room"
    @description = "Leave a specific thread"
    @command = "/leave"
    @aliases = ["/exit"]
  end
  
  def execute(parts, driver, chat_room, username)
    room_name = parts[1]
    
    if room_name.nil?
      # If no room specified, leave current room
      room_name = chat_room.name
    end
    
    active_rooms = driver.instance_variable_get(:@active_rooms) || {}
    
    if active_rooms[room_name]
      target_room = active_rooms[room_name]
      target_room.remove_client(username)
      driver.text(@controller.translate('left_room', username, [room_name]))
      
      # If user left the current room, we need to handle this in the controller
      if room_name == chat_room.name
        return :leave_current
      end
    else
      driver.text(@controller.translate('not_in_room', username, [room_name]))
    end
    
    nil
  end
end