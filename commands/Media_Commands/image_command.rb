class ImageCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Image"
    @description = "Share an image in the chat"
    @command = "/image"
    @aliases = ["/img", "/picture"]
  end
  
  def execute(parts, driver, chat_room, username)
    image_url = parts[1]&.strip
    if image_url.nil?
      driver.text("Usage /image <url>")
      return nil
    end

    unless image_url =~ /\A(http|https):\/\//i
      driver.text("⚠️ Format d'URL invalide. L'URL doit commencer par http:// ou https://")
      return nil
    end

    # Create an embedded image with proper styling
    safe_html = "<div class='media-embed'><img src=\"#{image_url}\" alt=\"image\" class=\"embedded-image\" style=\"max-width: 500px; max-height: 400px;\"></div>"
    chat_room.broadcast_formatted_message(safe_html, username)
    
    nil
  end
end