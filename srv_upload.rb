require 'sinatra'
require 'sqlite3'
require 'bcrypt'
require 'fileutils'
require 'json'
require 'uri'
require 'securerandom'
require_relative './Message/controllers/chat_controller'

# Add these gems for metadata extraction
begin
  require 'mini_magick'
rescue LoadError
  puts "MiniMagick not available - limited metadata extraction"
end

begin
  require 'taglib'
rescue LoadError
  puts "TagLib not available - using basic audio metadata"
end

# Load all helper modules from the Upload directory
Dir.glob(File.join(File.dirname(__FILE__), 'Upload', 'helpers', '*.rb')).each do |file|
  require file
  puts "Loaded helper: #{File.basename(file)}"
end

# Load all controllers from the Upload directory
Dir.glob(File.join(File.dirname(__FILE__), 'Upload', 'controllers', '*.rb')).each do |file|
  require file
  puts "Loaded controller: #{File.basename(file)}"
end

# Load configuration
require_relative './Upload/config/app_config'

class App < Sinatra::Base
  # Include all helper modules
  helpers FileHelpers if defined?(FileHelpers)
  helpers MetadataHelpers if defined?(MetadataHelpers)
  
  # Apply configuration
  AppConfig.configure(self)
  
  # Register all controllers
  UploadController.register(self) if defined?(UploadController)
  FileController.register(self) if defined?(FileController)
  
  # Add a debug endpoint to check if the server is running
  get '/ping' do
    content_type :json
    { status: 'ok', time: Time.now.to_s }.to_json
  end
  
  # Start the application if this file is executed directly
  run! if app_file == $0
end

puts "Upload server started on port 4567"