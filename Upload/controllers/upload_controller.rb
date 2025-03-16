# Controller for handling file uploads
class UploadController
  def self.register(app)
    app.post '/upload' do
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
        
        # Create metadata directory if it doesn't exist
        metadata_dir = File.join(settings.public_folder, 'metadata')
        FileUtils.mkdir_p(metadata_dir) unless Dir.exist?(metadata_dir)
    
        # Copy the file first
        FileUtils.cp(tempfile.path, path)
        puts ChatController.instance.translate('file_saved', nil, [path])
        
        # Extract and save metadata for media files
        file_type = detect_mime_type(path)
        if file_type.start_with?('image/') || file_type.start_with?('video/') || file_type.start_with?('audio/')
          metadata = extract_file_metadata(path, file_type)
          metadata_path = File.join(metadata_dir, "#{safe_filename}.json")
          File.write(metadata_path, JSON.pretty_generate(metadata))
          puts "Metadata saved to #{metadata_path}"
        end
    
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
    
    # Add a direct file access route
    app.get '/uploads/:filename' do
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
    
    # Add a new endpoint to access metadata
    app.get '/metadata/:filename' do
      filename = params[:filename]
      metadata_path = File.join(settings.public_folder, 'metadata', "#{filename}.json")
      
      if File.exist?(metadata_path)
        content_type :json
        File.read(metadata_path)
      else
        status 404
        { error: "Metadata not found for #{filename}" }.to_json
      end
    end
    
    # Add file checking endpoint
    app.get '/check-file' do
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
    
    # Add upload access test endpoint
    app.get '/test-upload-access' do
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
        <div>#{ChatController.instance.translate('base_url')}: http://#{request.host}:#{request.port}/uploads/</div>
        <hr>
      HTML

      files.each do |filename|
        file_path = File.join(upload_dir, filename)
        file_url = "http://#{request.host}:#{request.port}/uploads/#{URI.encode_www_form_component(filename)}"
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
  end
end