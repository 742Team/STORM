class ChangeUsernameCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Change Username"
    @description = "Change your username"
    @command = "/nick"
    @aliases = ["/username", "/name"]
  end
  
  def execute(parts, driver, chat_room, username)
    new_username = parts[1]
    
    if new_username.nil?
      driver.text("Usage /nick <new_username>")
      return nil
    end
    
    # Vérifier si le nouveau nom d'utilisateur est déjà utilisé
    username_in_use = @controller.chat_rooms.any? do |_, room|
      room.clients.key?(new_username)
    end
    
    if username_in_use
      driver.text(@controller.translate('username_taken', username))
      return nil
    end
    
    # Changer le nom d'utilisateur dans la salle actuelle
    chat_room.change_username(username, new_username)
    
    # Mettre à jour la variable d'instance du driver
    driver.instance_variable_set(:@username, new_username)
    
    # Notifier l'utilisateur
    driver.text(@controller.translate('username_changed', new_username, [username, new_username]))
    
    # Envoyer l'identifiant mis à jour au client
    driver.special("USER_ID|#{new_username}")
    
    nil
  end
end