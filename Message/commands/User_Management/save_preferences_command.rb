class SavePreferencesCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Save Preferences"
    @description = "Save your current preferences"
    @command = "/savepref"
    @aliases = ["/savesettings"]
  end
  
  def execute(parts, driver, chat_room, username)
    driver.text("⚪️ Sauvegarde de vos préférences en cours")
    
    preference_manager = @controller.instance_variable_get(:@preference_manager)
    preference_manager.save_all_preferences(username, chat_room)
    
    driver.text(" Préférences sauvegardées avec succès")
    nil
  end
end