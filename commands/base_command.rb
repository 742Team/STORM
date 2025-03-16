# Base class for all commands
class BaseCommand
  attr_reader :name, :description, :command, :aliases
  
  def initialize(controller)
    @controller = controller
    @name = "Base Command"  # Full name of the command for help display
    @description = "Base command description"  # Description for help display
    @command = "/base"  # The main command with leading slash
    @aliases = []  # Alternative command names
  end
  
  # Method to be overridden by subclasses
  def execute(parts, driver, chat_room, username)
    raise NotImplementedError, "#{self.class} must implement execute method"
  end
  
  # Helper method to get translated text
  def translate(key, username = nil, params = [])
    @controller.translate(key, username, params)
  end
  
  # Method to check if this command matches the given command string
  def matches?(command_str)
    command_str = command_str.downcase
    command_str == @command || @aliases.include?(command_str)
  end
  
  # Get usage information
  def usage
    "#{@command} - #{@description}"
  end
  
  # Get detailed help information
  def help_text
    "#{@name}: #{@description}\nUsage: #{@command}"
  end
end