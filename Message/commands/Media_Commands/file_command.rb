class FileCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "File"
    @description = "Share a file in the chat"
    @command = "/file"
    @aliases = ["/document", "/attachment"]
  end
  
  def execute(parts, driver, chat_room, username)
    file_url = parts[1]&.strip
    file_name = parts[2] || "fichier partagé"
    
    if file_url.nil?
      driver.text("Usage /file <url> [nom_du_fichier]")
      return nil
    end

    unless file_url =~ /\A(http|https):\/\//i
      driver.text("⚠️ Format d'URL invalide. L'URL doit commencer par http:// ou https://")
      return nil
    end

    extension = File.extname(file_url).downcase
    
    # Determine if this is a media file that should be embedded
    is_media = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.mp4', '.webm', '.mp3', '.wav', '.ogg'].include?(extension)
    
    if is_media
      # Handle media files with proper embedding
      case extension
      when '.jpg', '.jpeg', '.png', '.gif', '.webp'
        # Image embedding
        safe_html = "<div class='media-embed'><img src=\"#{file_url}\" alt=\"#{file_name}\" class=\"embedded-image\" style=\"max-width: 500px; max-height: 400px; object-fit: contain;\"></div>"
      when '.mp4', '.webm'
        # Video embedding
        safe_html = "<div class='media-embed'><video controls class='embedded-video' style='max-width: 500px; max-height: 400px;'><source src=\"#{file_url}\" type=\"video/#{extension.sub('.', '')}\">Video not supported</video></div>"
      when '.mp3', '.wav', '.ogg'
        # Audio embedding
        safe_html = "<div class='media-embed'><audio controls class='embedded-audio' style='width: 300px;'><source src=\"#{file_url}\" type=\"audio/#{extension.sub('.', '')}\">Audio not supported</audio></div>"
      end
      
      chat_room.broadcast_formatted_message(safe_html, username)
    else
      # Handle non-media files with icon and link
      icon = case extension
        when '.pdf' then '📄'
        when '.doc', '.docx' then '📝'
        when '.xls', '.xlsx' then '📊'
        when '.ppt', '.pptx' then '📑'
        when '.zip', '.rar', '.tar', '.gz' then '🗂️'
        else '📁'
      end

      safe_html = "<div class='file-embed'>#{icon} <a href=\"#{file_url}\" target=\"_blank\" class=\"file-link\">#{file_name}</a></div>"
      chat_room.broadcast_formatted_message(safe_html, username)
    end
    
    nil
  end
end