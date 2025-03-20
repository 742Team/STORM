require 'socket'
require 'colorize'
require 'websocket/driver'
require_relative './Message/controllers/chat_controller'

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

server_ip   = '0.0.0.0'
server_port = 3630
server      = TCPServer.new(server_ip, server_port)
chat_controller = ChatController.instance  # Changed from .new to .instance

puts chat_controller.translate('server_running', nil, [server_ip, server_port]).green

chat_controller.create_room("Main", nil, "Server")

loop do
  socket = server.accept
  Thread.new do
    begin
      driver = WebSocket::Driver.server(socket)

      driver.define_singleton_method(:special) do |msg|
        self.text(msg)
      end

      # Add this line here, right after creating the driver
      driver.define_singleton_method(:socket) { socket }

      driver.define_singleton_method(:close) do
        socket.close unless socket.closed?
      end

      driver.instance_variable_set(:@username, nil)
      driver.instance_variable_set(:@current_room, nil)

      driver.on(:connect) do
        if driver.env['HTTP_UPGRADE'].to_s.downcase != 'websocket'
          puts chat_controller.translate('invalid_connection').red
          socket.close
        else
          driver.start
        end
      end

      # Modifier la section qui gère la connexion des nouveaux utilisateurs
      driver.on(:open) do
        puts chat_controller.translate('new_connection').green
        
        # Générer un nom d'utilisateur aléatoire
        random_username = "User_#{SecureRandom.hex(4)}"
        
        # Vérifier que le nom d'utilisateur n'est pas déjà utilisé
        while chat_controller.chat_rooms.any? { |_, room| room.clients.key?(random_username) }
          random_username = "User_#{SecureRandom.hex(4)}"
        end
        
        # Définir le nom d'utilisateur et la salle
        driver.instance_variable_set(:@username, random_username)
        current_room = chat_controller.chat_rooms["Main"]
        driver.instance_variable_set(:@current_room, current_room)
        
        # Ajouter le client à la salle
        current_room.add_client(driver, random_username)
        
        # Envoyer un message de bienvenue avec instructions pour changer de nom
        driver.text(chat_controller.translate('auto_welcome', random_username, [random_username]))
        
        # Envoyer l'identifiant au client pour qu'il le stocke
        driver.special("USER_ID|#{random_username}")
      end
      
      # Modifier la section qui gère les messages pour supprimer la logique de définition du nom d'utilisateur
      driver.on(:message) do |event|
        msg = event.data.strip.force_encoding('UTF-8')
        username = driver.instance_variable_get(:@username)
        current_room = driver.instance_variable_get(:@current_room)
        
        # Le nom d'utilisateur est déjà défini, donc on traite directement le message
        new_room = chat_controller.handle_message(driver, current_room, username, msg)
        
        if new_room && new_room != current_room
          driver.instance_variable_set(:@current_room, new_room)
        end
      end

      driver.on(:close) do
        puts chat_controller.translate('connection_closed').red

        username = driver.instance_variable_get(:@username)
        current_room = driver.instance_variable_get(:@current_room)

        if current_room && username
          current_room.remove_client(username)
        end

        socket.close
      end

      driver.on(:error) do |error|
        puts chat_controller.translate('websocket_error', nil, [error.message]).red
      end

      while (data = socket.readpartial(1024))
        driver.parse(data)
      end

    rescue EOFError
      puts chat_controller.translate('connection_eof').red
    rescue => e
      puts chat_controller.translate('error_generic', nil, [e.message]).red
      puts e.backtrace.join("\n").yellow
    ensure
      socket.close unless socket.closed?
    end
  end
end


# Ajouter cet endpoint pour récupérer les salons publics
get '/api/public_rooms' do
  content_type :json
  ChatController.instance.get_public_rooms.to_json
end


# Configurer CORS pour permettre les requêtes cross-origin
before do
  response.headers['Access-Control-Allow-Origin'] = '*'
  response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
  response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
end

# Gérer les requêtes OPTIONS pour CORS
options '*' do
  200
end
