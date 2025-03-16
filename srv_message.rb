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

      driver.on(:open) do
        puts chat_controller.translate('new_connection').green
        driver.text(chat_controller.translate('enter_username'))
      end

      driver.on(:message) do |event|
        msg = event.data.strip.force_encoding('UTF-8')
        username = driver.instance_variable_get(:@username)
        current_room = driver.instance_variable_get(:@current_room)

        if username.nil?
          if msg.empty?
            driver.text(chat_controller.translate('empty_username'))
            next
          end

          # Check if username is already in use across all rooms
          username_in_use = chat_controller.chat_rooms.any? do |_, room|
            room.clients.key?(msg)
          end

          if username_in_use
            driver.text(chat_controller.translate('username_taken'))
            next
          end

          username = msg
          driver.instance_variable_set(:@username, username)

          current_room = chat_controller.chat_rooms["Main"]
          driver.instance_variable_set(:@current_room, current_room)

          current_room.add_client(driver, username)
          driver.text(chat_controller.translate('welcome_message', username, [username]))
        else
          new_room = chat_controller.handle_message(driver, current_room, username, msg)

          if new_room && new_room != current_room
            driver.instance_variable_set(:@current_room, new_room)
          end
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
