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
    file_name = parts[2]&.strip || "fichier"
    
    if file_url.nil?
      driver.text("Usage /file <url> <nom_optionnel>")
      return nil
    end

    unless file_url =~ /\A(http|https):\/\//i
      driver.text("⚠️ Format d'URL invalide. L'URL doit commencer par http:// ou https://")
      return nil
    end

    # Create a file link with proper styling
    safe_html = "<div class='file-embed'><a href=\"#{file_url}\" target=\"_blank\" class=\"file-link\">📄 #{file_name}</a></div>"
    chat_room.broadcast_formatted_message(safe_html, username)
    
    nil
  end
end