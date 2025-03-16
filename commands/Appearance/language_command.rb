class LanguageCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Language"
    @description = "Change your interface language"
    @command = "/language"
    @aliases = ["/lang"]
  end
  
  def execute(parts, driver, chat_room, username)
    lang_code = parts[1]&.strip
    
    if lang_code.nil?
      driver.text(@controller.translate('language_usage', username))
      return nil
    end
    
    language_manager = @controller.instance_variable_get(:@language_manager)
    
    if language_manager.set_language(username, lang_code)
      driver.text(@controller.translate('language_changed', username, [lang_code]))
    else
      driver.text(@controller.translate('language_invalid', username, [lang_code]))
    end
    
    nil
  end
end