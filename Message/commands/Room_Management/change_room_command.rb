class ChangeRoomCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Change Room"
    @description = "Join an existing thread"
    @command = "/cd"
    @aliases = ["/join", "/changeroom"]
  end
  
  def execute(parts, driver, chat_room, username)
    room_name = parts[1]
    room_pass = parts[2]
    
    if room_name.nil?
      driver.text("Usage /cd <nom> <password>")
      return nil
    end

    if @controller.chat_rooms.key?(room_name)
      new_room = @controller.chat_rooms[room_name]

      if new_room.password.nil? || new_room.password == room_pass
        chat_room.remove_client(username)

        if new_room.add_client(driver, username)
          return new_room
        end
      else
        driver.text("⚠️ Mot de passe incorrect pour #{room_name}")
      end
    else
      driver.text("⚠️ Le thread #{room_name} n'existe pas")
    end
    
    return nil
  end
end