require 'socket'
require 'colorize'
require 'websocket/driver'
require_relative './controllers/chat_controller'

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

server_ip   = '0.0.0.0'
server_port = 3630
server      = TCPServer.new(server_ip, server_port)
chat_controller = ChatController.new

puts "⚡️ Serveur WebSocket en cours d'exécution sur #{server_ip}:#{server_port}".green

chat_controller.create_room("Main", nil, "Server")

loop do
  socket = server.accept
  Thread.new do
    begin
      driver = WebSocket::Driver.server(socket)

      driver.define_singleton_method(:special) do |msg|
        self.text(msg)
      end

      driver.instance_variable_set(:@username, nil)
      driver.instance_variable_set(:@current_room, nil)

      driver.on(:connect) do
        if driver.env['HTTP_UPGRADE'].to_s.downcase != 'websocket'
          puts "🔴 Connection invalide".red
          socket.close
        else
          driver.start
        end
      end

      driver.on(:open) do
        puts "🟢 Nouvelle connection".green
        driver.text("| Entrez votre username ")
      end

      driver.on(:message) do |event|
        msg = event.data.strip.force_encoding('UTF-8')
        username = driver.instance_variable_get(:@username)
        current_room = driver.instance_variable_get(:@current_room)

        if username.nil?
          if msg.empty?
            driver.text("| ⚠️ Pseudo vide, réessayez")
            next
          end

          # Check if username is already in use across all rooms
          username_in_use = chat_controller.chat_rooms.any? do |_, room|
            room.clients.key?(msg)
          end

          if username_in_use
            driver.text("| ⚠️ Ce pseudo est déjà utilisé, choisissez-en un autre")
            next
          end

          username = msg
          driver.instance_variable_set(:@username, username)

          current_room = chat_controller.chat_rooms["Main"]
          driver.instance_variable_set(:@current_room, current_room)

          current_room.add_client(driver, username)
          driver.text("| Bienvenue #{username} Tapez /help pour la liste des commandes")
        else
          new_room = chat_controller.handle_message(driver, current_room, username, msg)

          if new_room && new_room != current_room
            driver.instance_variable_set(:@current_room, new_room)
          end
        end
      end

      driver.on(:close) do
        puts "🔴 Connexion WS fermée".red

        username = driver.instance_variable_get(:@username)
        current_room = driver.instance_variable_get(:@current_room)

        if current_room && username
          current_room.remove_client(username)
        end

        socket.close
      end

      driver.on(:error) do |error|
        puts "🔴 Erreur WebSocket: #{error.message}".red
      end

      while (data = socket.readpartial(1024))
        driver.parse(data)
      end

    rescue EOFError
      puts "🔴 Connection fermée (EOF)".red
    rescue => e
      puts "⚠️ Erreur: #{e.message}".red
      puts e.backtrace.join("\n").yellow
    ensure
      socket.close unless socket.closed?
    end
  end
end
