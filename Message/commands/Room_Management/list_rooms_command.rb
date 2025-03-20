class ListRoomsCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "List Public Rooms"
    @description = "Lists all public rooms available"
    @command = "/listrooms"
    @aliases = ["/rooms", "/publicrooms"]
  end
  
  def execute(parts, driver, chat_room, username)
    # Get all public rooms
    public_rooms = @controller.get_public_rooms
    
    if public_rooms.empty?
      driver.text(@controller.translate('no_public_rooms', username))
      return nil
    end
    
    # Format the output
    message = @controller.translate('public_rooms_header', username) + "\n"
    public_rooms.each do |room|
      users_text = room[:users_count] == 1 ? 
                  @controller.translate('one_user', username) : 
                  @controller.translate('multiple_users', username, [room[:users_count]])
      
      message += "• #{room[:name]} (#{users_text}"
      message += ", #{@controller.translate('created_by', username, [room[:creator]])}" if room[:creator]
      message += ")\n"
    end
    
    driver.text(message)
    return nil
  end
end