require 'sinatra'
require 'sqlite3'
require 'bcrypt'
require 'fileutils'
require 'json'
require 'uri'
require 'securerandom'
require_relative './controllers/chat_controller'

set :bind, '0.0.0.0'
set :port, 4567
set :public_folder, File.dirname(__FILE__) + '/public'

# Configure cache control at the application level
configure do
  set :static_cache_control, [:public, max_age: 0]
  set :protection, :except => [:json_csrf]
end

enable :logging

# Update the before filter to include more CORS headers
before do
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

# Update the upload endpoint to use the correct host
post '/upload' do
  content_type :json

  puts ChatController.instance.translate('upload_starting')

  begin
    unless params[:file] && params[:file][:tempfile] && params[:file][:filename]
      puts ChatController.instance.translate('no_file_received')
      return { success: false, error: ChatController.instance.translate('no_file_received') }.to_json
    end

    file = params[:file]
    filename = file[:filename]
    tempfile = file[:tempfile]

    puts ChatController.instance.translate('file_received', nil, [filename, file[:type], File.size(tempfile.path)])

    safe_filename = sanitize_filename(filename)
    path = File.join(settings.public_folder, 'uploads', safe_filename)

    # Copy the file first
    FileUtils.cp(tempfile.path, path)
    puts ChatController.instance.translate('file_saved', nil, [path])

    # Compress the file
    puts ChatController.instance.translate('compressing_file', nil, [path])
    ChatController.instance.compress_file(path)

    if File.exist?(path)
      puts ChatController.instance.translate('file_verified', nil, [path])
    else
      puts ChatController.instance.translate('file_save_error', nil, [path])
    end

    # Use request.host instead of hardcoded IP
    file_url = "http://#{request.host}:#{request.port}/uploads/#{URI.encode_www_form_component(safe_filename)}"

    puts ChatController.instance.translate('file_url_generated', nil, [file_url])

    response = {
      success: true,
      url: file_url,
      filename: filename,
      type: file[:type] || detect_mime_type(path),
      path: path,
      size: File.size(path)
    }

    puts ChatController.instance.translate('json_response', nil, [response.to_json])
    return response.to_json

  rescue => e
    puts ChatController.instance.translate('upload_error', nil, [e.message])
    puts e.backtrace.join("\n")
    { success: false, error: e.message }.to_json
  end
end

get '/check-file' do
  content_type :json

  path = params[:path]

  unless path
    return { success: false, error: ChatController.instance.translate('path_not_specified') }.to_json
  end

  begin
    full_path = File.join(settings.public_folder, path)
    exists = File.exist?(full_path)

    {
      success: true,
      path: full_path,
      exists: exists,
      size: exists ? File.size(full_path) : nil,
      readable: exists ? File.readable?(full_path) : false
    }.to_json
  rescue => e
    { success: false, error: e.message }.to_json
  end
end

get '/test-upload-access' do
  content_type :html

  upload_dir = File.join(settings.public_folder, 'uploads')

  unless Dir.exist?(upload_dir)
    return ChatController.instance.translate('upload_folder_not_exists', nil, [upload_dir])
  end

  files = Dir.entries(upload_dir).reject { |f| f == '.' || f == '..' }

  if files.empty?
    return ChatController.instance.translate('no_files_in_upload_folder')
  end

  html = <<-HTML
  <html>
  <head>
    <title>#{ChatController.instance.translate('uploaded_files_test')}</title>
    <style>
      body { font-family: sans-serif; margin: 20px; }
      .file-entry { margin: 10px 0; padding: 10px; border: 1px solid #ccc; }
      img { max-width: 300px; max-height: 200px; }
    </style>
  </head>
  <body>
    <h1>#{ChatController.instance.translate('uploaded_files', nil, [files.size])}</h1>
    <div>#{ChatController.instance.translate('full_path')}: #{File.expand_path(upload_dir)}</div>
    <div>#{ChatController.instance.translate('base_url')}: http://195.35.1.108:#{request.port}/uploads/</div>
    <hr>
  HTML

  files.each do |filename|
    file_path = File.join(upload_dir, filename)
    file_url = "http://195.35.1.108:#{request.port}/uploads/#{URI.encode_www_form_component(filename)}"
    file_size = File.size(file_path) rescue ChatController.instance.translate('unknown')
    file_type = File.extname(filename).downcase

    html += <<-HTML
    <div class="file-entry">
      <div><strong>#{ChatController.instance.translate('name')}:</strong> #{filename}</div>
      <div><strong>#{ChatController.instance.translate('size')}:</strong> #{file_size} bytes</div>
      <div><strong>URL:</strong> <a href="#{file_url}" target="_blank">#{file_url}</a></div>
      <div><strong>#{ChatController.instance.translate('accessibility_test')}:</strong>
    HTML

    if ['.jpg', '.jpeg', '.png', '.gif', '.webp'].include?(file_type)
      html += <<-HTML
        <img src="#{file_url}" alt="#{ChatController.instance.translate('preview')}">
      HTML
    end

    html += <<-HTML
      </div>
    </div>
    HTML
  end

  html += "</body></html>"

  return html
end

# Add after other requires at the top
require 'thread'

# Add after other configurations
configure do
  set :chat_controller, ChatController.instance
  
  # Start polling thread for rooms
  Thread.new do
    while true
      begin
        settings.chat_controller.refresh_rooms if settings.chat_controller
        sleep 5  # Check every 5 seconds
      rescue => e
        puts ChatController.instance.translate('polling_error', nil, [e.message])
      end
    end
  end
end

# Update the public-rooms endpoint
# Around line 348 where the error is occurring
get '/public-rooms' do
  content_type :json
  cache_control :no_cache, :no_store
  
  chat_controller = settings.chat_controller
  
  {
    success: true,
    timestamp: Time.now.to_i,
    rooms: chat_controller.chat_rooms.select { |_, room| room.password.nil? }.map { |name, room| 
      {
        name: name,
        users_count: room.clients.size,
        creator: room.creator,
        created_at: room.created_at || Time.now
      }
    }
  }.to_json
end

# Add this helper method to sanitize filenames
helpers do
  def sanitize_filename(filename)
    extension = File.extname(filename)
    basename = File.basename(filename, extension)

    uuid = SecureRandom.uuid
    timestamp = Time.now.to_i

    sanitized_basename = basename.gsub(/[^\p{Alnum}\p{L}\p{M}\s\-_]/, '_')
    sanitized_basename = sanitized_basename.gsub(/\s+/, '_')
    sanitized_basename = sanitized_basename[0, 100] if sanitized_basename.length > 100

    "#{timestamp}_#{uuid}_#{sanitized_basename}#{extension}"
  end
  
  def detect_mime_type(file_path)
    extension = File.extname(file_path).downcase
    case extension
    when '.jpg', '.jpeg'
      'image/jpeg'
    when '.png'
      'image/png'
    when '.gif'
      'image/gif'
    when '.webp'
      'image/webp'
    when '.mp4'
      'video/mp4'
    when '.webm'
      'video/webm'
    when '.mp3'
      'audio/mpeg'
    when '.wav'
      'audio/wav'
    when '.ogg'
      'audio/ogg'
    when '.pdf'
      'application/pdf'
    else
      'application/octet-stream'
    end
  end
end

# Remove this standalone cache_control call that's causing the error
# cache_control :no_cache, :no_store

# Add a direct file access route
get '/uploads/:filename' do
  filename = params[:filename]
  file_path = File.join(settings.public_folder, 'uploads', filename)
  
  if File.exist?(file_path)
    content_type detect_mime_type(file_path)
    send_file file_path
  else
    status 404
    "File not found"
  end
end
