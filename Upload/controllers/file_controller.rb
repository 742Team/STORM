# Controller for handling file operations
class FileController
  def self.register(app)
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
  end
end