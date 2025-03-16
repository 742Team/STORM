# Configuration settings for the Sinatra application
module AppConfig
  def self.configure(app)
    app.set :bind, '0.0.0.0'
    app.set :port, 4567
    app.set :public_folder, File.dirname(__FILE__) + '/../../public'
    
    # Ensure uploads directory exists
    uploads_dir = File.join(app.settings.public_folder, 'uploads')
    FileUtils.mkdir_p(uploads_dir) unless Dir.exist?(uploads_dir)
    
    # Ensure metadata directory exists
    metadata_dir = File.join(app.settings.public_folder, 'metadata')
    FileUtils.mkdir_p(metadata_dir) unless Dir.exist?(metadata_dir)
    
    # Configure cache control at the application level
    app.set :static_cache_control, [:public, max_age: 0]
    app.set :protection, except: [:json_csrf]
    
    app.enable :logging
    
    # Configure CORS and cache headers
    app.before do
      response.headers['Access-Control-Allow-Origin'] = '*'
      response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
      response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
      response.headers['Access-Control-Expose-Headers'] = 'Content-Disposition'
      
      # Set cache control headers in the before filter
      response.headers['Cache-Control'] = 'no-cache, no-store'
      response.headers['Pragma'] = 'no-cache'
      response.headers['Expires'] = '0'
    
      if request.request_method == 'OPTIONS'
        halt 200
      end
    
      puts "#{request.request_method} #{request.path_info} - Params: #{params.inspect}"
    end
    
    # Start polling thread for rooms
    app.configure do
      app.set :chat_controller, ChatController.instance
      
      Thread.new do
        while true
          begin
            app.settings.chat_controller.refresh_rooms if app.settings.chat_controller
            sleep 5  # Check every 5 seconds
          rescue => e
            puts "Polling error: #{e.message}"
          end
        end
      end
    end
  end
end