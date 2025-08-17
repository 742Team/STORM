class HelpCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Help"
    @description = "Display available commands"
    @command = "/help"
    @aliases = ["/h", "/?"]
  end
  
  def execute(parts, driver, chat_room, username)
    # Get commands from the command handler with their categories
    command_handler = @controller.instance_variable_get(:@command_handler)
    commands_by_category = command_handler.get_all_commands_with_categories
    
    # Format and display commands
    driver.text("⚪️ Available Commands")
    
    # Sort categories alphabetically
    sorted_categories = commands_by_category.keys.sort
    
    sorted_categories.each do |category|
      commands = commands_by_category[category]
      
      # Skip empty categories
      next if commands.empty?
      
      driver.text("\n#{category}:")
      
      # Format each command with its name and description
      formatted_commands = commands.map do |cmd|
        "#{cmd.command} - #{cmd.name}: #{cmd.description}"
      end.sort
      
      driver.text(formatted_commands.join("\n"))
    end
    
    # Add note about color commands
    driver.text("\nNote: Pour les commandes /color et /textcolor, vous pouvez utiliser les noms de couleurs (ex: /color red) ou les codes hexadécimaux (ex: /color #FF0000).")
    
    nil
  end
end