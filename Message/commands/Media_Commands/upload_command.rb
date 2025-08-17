class UploadCommand < BaseCommand
  def initialize(controller)
    super(controller)
    @name = "Upload"
    @description = "Upload a file to the server"
    @command = "/upload"
    @aliases = ["/up"]
  end
  
  def execute(parts, driver, chat_room, username)
    driver.text(" 📁 Demande d'upload de fichier")
    special_msg = "REQUEST_FILE_UPLOAD|"
    driver.special(special_msg)
    nil
  end
end