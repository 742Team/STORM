class CreateRoomCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Create Room"
    @description = "Create a new thread"
    @command = "/cr"
    @aliases = ["/createroom", "/newroom"]
  end
  
  def execute(parts, driver, chat_room, username)
    def _execute(parts, driver, chat_room, username)
      room_name = parts[1]
      room_pass = parts[2]
      if room_name.nil?
        driver.text("Usage /cr <nom> <password>")
        return nil
      end

      new_room = @controller.create_room(room_name, room_pass, username)
      if new_room.nil?
        driver.text("⚠️ Le thread #{room_name} existe déjà")
        return nil
      end

      driver.text("Thread #{room_name} créé.")
      chat_room.remove_client(username)
      new_room.add_client(driver, username)
      return new_room
    end
    
    # Call the extracted method
    result = _execute(parts, driver, chat_room, username)
    
    # Return the result (important for room changes)
    result
  end
end