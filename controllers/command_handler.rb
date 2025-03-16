require 'securerandom'
require 'fileutils'

class CommandHandler
  def initialize(controller, user_manager, preference_manager, language_manager)
    @controller = controller
    @user_manager = user_manager
    @preference_manager = preference_manager
    @language_manager = language_manager
    @commands = {}
    @command_categories = {}
    
    # Load all commands
    load_commands
  end
  
  def handle_command(msg, driver, chat_room, username)
    return nil unless msg.start_with?('/')
    
    parts = msg.split(' ')
    command_str = parts[0].downcase
    
    # Find the command handler
    command = find_command(command_str)
    
    if command.nil?
      driver.text(@controller.translate('command_unknown', username))
      return nil
    end
    
    # Skip user-related commands if user_manager is not initialized yet
    if @user_manager.nil? && ['/register', '/login'].include?(command_str)
      driver.text("Command not available yet, please try again in a moment.")
      return nil
    end
    
    # Execute the command
    begin
      result = command.execute(parts, driver, chat_room, username)
      
      # Special case for commands that return a new room
      if result.is_a?(ChatRoom)
        return result
      end
      
      return nil
    rescue => e
      driver.text("Error executing command: #{e.message}")
      puts "Command error: #{e.message}\n#{e.backtrace.join("\n")}"
      return nil
    end
  end
  
  # Get all available commands for help display
  def get_commands_help(username = nil)
    @commands.values.uniq.map do |cmd|
      if cmd.respond_to?(:usage)
        cmd.usage
      else
        "#{cmd.command} - #{cmd.description}"
      end
    end.sort
  end
  
  # Get all commands with their categories
  def get_all_commands_with_categories
    @command_categories
  end
  
  # Get all commands
  def get_all_commands
    @commands.values.uniq
  end
  
  private
  
  def load_commands
    # Get the commands directory
    commands_dir = File.join(File.dirname(__FILE__), '..', 'commands')
    
    # Create the directory if it doesn't exist
    FileUtils.mkdir_p(commands_dir) unless Dir.exist?(commands_dir)
    
    # If no commands exist yet, create them from the current handlers
    if Dir.glob(File.join(commands_dir, '**', '*.rb')).empty?
      generate_command_files
    end
    
    # Load base command first
    base_command_path = File.join(commands_dir, 'base_command.rb')
    require base_command_path if File.exist?(base_command_path)
    
    # Load all command files (including those in subdirectories)
    Dir.glob(File.join(commands_dir, '**', '*.rb')).each do |file|
      next if file.end_with?('base_command.rb')
      require file
    end
    
    # Register all command classes
    register_commands
  end
  
  def register_commands
    # Find all classes that inherit from BaseCommand
    BaseCommand.descendants.each do |command_class|
      begin
        command = command_class.new(@controller)
        register_command(command)
        
        # Determine category from file path
        file_path = find_command_file_path(command_class)
        category = determine_category_from_path(file_path)
        
        # Store command with its category
        @command_categories[category] ||= []
        @command_categories[category] << command
      rescue => e
        puts "Error registering command #{command_class}: #{e.message}"
      end
    end
  end
  
  def find_command_file_path(command_class)
    # Try to find the file that defines this class
    commands_dir = File.join(File.dirname(__FILE__), '..', 'commands')
    
    # Search for the file that defines this class
    Dir.glob(File.join(commands_dir, '**', '*.rb')).each do |file|
      content = File.read(file)
      if content.include?("class #{command_class.name}")
        return file
      end
    end
    
    # Default to root commands directory if not found
    return File.join(commands_dir, "#{command_class.name.underscore}.rb")
  end
  
  def determine_category_from_path(file_path)
    commands_dir = File.join(File.dirname(__FILE__), '..', 'commands')
    relative_path = file_path.sub(commands_dir, '').sub(/^[\/\\]/, '')
    
    # If the file is directly in the commands directory, use "General"
    if relative_path.index('/').nil? && relative_path.index('\\').nil?
      return "General Commands"
    end
    
    # Otherwise, use the subdirectory name as the category
    category_path = relative_path.split(/[\/\\]/).first
    return category_path.gsub('_', ' ').split.map(&:capitalize).join(' ')
  end
  
  def register_command(command)
    @commands[command.command] = command
    
    # Register aliases
    command.aliases.each do |alias_name|
      @commands[alias_name] = command
    end
  end
  
  def find_command(command_str)
    @commands[command_str]
  end
  
  # Generate command files from existing handle_* methods
  def generate_command_files
    # Create commands directory if it doesn't exist
    commands_dir = File.join(File.dirname(__FILE__), '..', 'commands')
    FileUtils.mkdir_p(commands_dir)
    
    # Create base command file
    create_base_command_file(commands_dir)
    
    # Get all methods that start with handle_
    methods = self.class.instance_methods(false).select { |m| m.to_s.start_with?('handle_') }
    
    methods.each do |method|
      method_name = method.to_s
      command_name = method_name.sub('handle_', '')
      
      # Skip methods that don't match our pattern
      next unless command_name =~ /^[a-z_]+$/
      
      # Create the command class name
      class_name = command_name.split('_').map(&:capitalize).join + 'Command'
      
      # Create the command file
      create_command_file(commands_dir, class_name, command_name, method_name)
    end
  end
  
  def create_base_command_file(commands_dir)
    base_command_content = <<~RUBY
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
          raise NotImplementedError, "\#{self.class} must implement execute method"
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
          "\#{@command} - \#{@description}"
        end
        
        # Get detailed help information
        def help_text
          "\#{@name}: \#{@description}\\nUsage: \#{@command}"
        end
      end
      
      # Add a method to get all descendants of a class
      class Class
        def descendants
          ObjectSpace.each_object(Class).select { |klass| klass < self }
        end
      end
    RUBY
    
    File.write(File.join(commands_dir, 'base_command.rb'), base_command_content)
  end
  
  def create_command_file(commands_dir, class_name, command_name, method_name)
    command_file_content = <<~RUBY
      class #{class_name} < BaseCommand
        def initialize(controller)
          super(controller)
          @name = "#{command_name.gsub('_', ' ').capitalize}"
          @description = "#{command_name.gsub('_', ' ')} command"
          @command = "/#{command_name.gsub('_', '')}"
          @aliases = []
        end
        
        def execute(parts, driver, chat_room, username)
          # Call the original method from CommandHandler
          controller_instance = @controller.instance_variable_get(:@command_handler)
          result = controller_instance.send(:#{method_name}, parts, driver, chat_room, username)
          
          # Return the result (important for room changes)
          result
        end
      end
    RUBY
    
    File.write(File.join(commands_dir, "#{command_name}_command.rb"), command_file_content)
  end
end

# Add a method to get all descendants of a class
class Class
  def descendants
    ObjectSpace.each_object(Class).select { |klass| klass < self }
  end
  
  # Add underscore method for string conversion
  def underscore
    self.name.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
  end
end

# Add underscore method to String
class String
  def underscore
    self.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
  end
end