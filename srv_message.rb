require 'socket'
require 'colorize'
require 'websocket/driver'
require 'concurrent-ruby'
require 'fiber'
require_relative './Message/controllers/chat_controller'
require_relative './lib/performance_optimizer'
require_relative './lib/ultra_fast_cache'

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

# Configuration ultra-performance
GC.disable # Désactiver GC pendant l'initialisation

# Optimisations Ruby
Thread.abort_on_exception = false
Thread.report_on_exception = false

# Pool de threads optimisé
THREAD_POOL = Concurrent::ThreadPoolExecutor.new(
  min_threads: 10,
  max_threads: 200,
  max_queue: 2000,
  fallback_policy: :caller_runs,
  auto_terminate: false
)

# Cache ultra-rapide
CACHE = UltraFastCache.instance
OPTIMIZER = PerformanceOptimizer.instance

GC.enable # Réactiver GC après initialisation

server_ip   = '0.0.0.0'
server_port = 3630
server      = TCPServer.new(server_ip, server_port)
chat_controller = ChatController.instance  # Changed from .new to .instance

puts chat_controller.translate('server_running', nil, [server_ip, server_port]).green

chat_controller.create_room("Main", nil, "Server")

# Statistiques de performance
connection_count = Concurrent::AtomicFixnum.new(0)
last_stats_time = Time.now

# Boucle principale ultra-optimisée
loop do
  socket = server.accept
  connection_count.increment
  
  # Traitement asynchrone ultra-rapide
  THREAD_POOL.post do
    begin
      # Optimisations socket
      socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
      socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, 1)
      
      driver = WebSocket::Driver.server(socket)
      
      # Méthodes optimisées avec cache
      driver.define_singleton_method(:special) do |msg|
        self.text(msg)
      end
      
      driver.define_singleton_method(:socket) { socket }
      
      driver.define_singleton_method(:close) do
        socket.close unless socket.closed?
      end
      
      # Variables d'instance avec cache
      driver.instance_variable_set(:@username, nil)
      driver.instance_variable_set(:@current_room, nil)
      driver.instance_variable_set(:@connection_id, SecureRandom.hex(8))
      driver.instance_variable_set(:@last_activity, Time.now.to_f)

      driver.on(:connect) do
        if driver.env['HTTP_UPGRADE'].to_s.downcase != 'websocket'
          puts chat_controller.translate('invalid_connection').red
          socket.close
        else
          driver.start
        end
      end

      # Gestion ultra-optimisée des nouvelles connexions
      driver.on(:open) do
        connection_id = driver.instance_variable_get(:@connection_id)
        puts "[#{connection_id}] New connection".green
        
        # Génération optimisée du nom d'utilisateur avec cache
        random_username = generate_unique_username_fast
        
        # Cache de la session utilisateur
        CACHE.set_user_session(random_username, {
          connection_id: connection_id,
          connected_at: Time.now.to_f,
          socket_info: socket.peeraddr
        })
        
        # Définir les variables avec optimisations
        driver.instance_variable_set(:@username, random_username)
        current_room = chat_controller.chat_rooms["Main"]
        driver.instance_variable_set(:@current_room, current_room)
        
        # Ajout asynchrone du client
        THREAD_POOL.post do
          current_room.add_client(driver, random_username)
          
          # Messages de bienvenue en parallèle
          welcome_msg = chat_controller.translate('auto_welcome', random_username, [random_username])
          driver.text(welcome_msg)
          driver.special("USER_ID|#{random_username}")
          
          # Précharger les données utilisateur
          OPTIMIZER.preload_popular_rooms
        end
      end
      
      # Modifier la section qui gère les messages pour supprimer la logique de définition du nom d'utilisateur
      driver.on(:message) do |event|
        begin
          username = driver.instance_variable_get(:@username)
          current_room = driver.instance_variable_get(:@current_room)
          connection_id = driver.instance_variable_get(:@connection_id)
          
          # Mise à jour de l'activité
          driver.instance_variable_set(:@last_activity, Time.now.to_f)
          
          if username && current_room
            # Traitement asynchrone ultra-rapide des messages
            THREAD_POOL.post do
              begin
                # Décompression si nécessaire
                message_data = event.data
                if message_data.start_with?('COMPRESSED:')
                  message_data = CACHE.decompress_data(message_data[11..-1])
                end
                
                # Cache du message pour éviter les doublons
                message_hash = Digest::MD5.hexdigest("#{username}:#{message_data}:#{Time.now.to_i}")
                unless CACHE.message_processed?(message_hash)
                  CACHE.mark_message_processed(message_hash)
                  
                  # Traitement optimisé du message
                  msg = message_data.strip.force_encoding('UTF-8')
                  new_room = chat_controller.handle_message(driver, current_room, username, msg)
                  
                  if new_room && new_room != current_room
                    driver.instance_variable_set(:@current_room, new_room)
                  end
                  
                  # Mise à jour des statistiques
                  CACHE.increment_user_message_count(username)
                end
              rescue => e
                puts "[#{connection_id}] Message error: #{e.message}".red
              end
            end
          end
        rescue => e
          puts "[#{connection_id}] Handler error: #{e.message}".red
        end
      end

      driver.on(:close) do
        username = driver.instance_variable_get(:@username)
        current_room = driver.instance_variable_get(:@current_room)
        connection_id = driver.instance_variable_get(:@connection_id)
        
        if username && current_room
          # Nettoyage asynchrone ultra-rapide
          THREAD_POOL.post do
            begin
              # Suppression du client de la salle
              current_room.remove_client(username)
              
              # Nettoyage du cache utilisateur
              CACHE.remove_user_session(username)
              CACHE.cleanup_user_data(username)
              
              # Décrémenter le compteur de connexions
              connection_count.decrement
              
              puts "[#{connection_id}] #{username} disconnected (#{connection_count.value} active)".yellow
              
              # Statistiques périodiques
              current_time = Time.now
              if current_time - last_stats_time > 60 # Toutes les minutes
                last_stats_time = current_time
                CACHE.print_performance_stats
                OPTIMIZER.optimize_memory if connection_count.value < 10
              end
            rescue => e
              puts "[#{connection_id}] Cleanup error: #{e.message}".red
            end
          end
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
      connection_id = driver&.instance_variable_get(:@connection_id) || 'unknown'
      puts "[#{connection_id}] WebSocket error: #{e.message}".red
      puts e.backtrace.join("\n").yellow
    ensure
      socket.close unless socket.closed?
    end
  rescue => e
    puts "Server error: #{e.message}".red
  end
end

# Fonction ultra-rapide de génération de nom d'utilisateur
def generate_unique_username_fast
  # Cache des noms utilisés pour éviter les collisions
  used_names = CACHE.get_active_usernames
  
  # Génération optimisée avec retry limité
  5.times do
    username = "User_#{SecureRandom.hex(4)}"
    return username unless used_names.include?(username)
  end
  
  # Fallback avec timestamp si collision persistante
  "User_#{Time.now.to_i}_#{SecureRandom.hex(2)}"
end

# Gestionnaire de signaux pour arrêt propre
Signal.trap('INT') do
  puts "\n⚫️ Arrêt du serveur...".red
  CACHE.print_performance_stats
  OPTIMIZER.cleanup
  THREAD_POOL.shutdown
  THREAD_POOL.wait_for_termination(5)
  exit(0)
end

Signal.trap('TERM') do
  puts "\n⚫️ Arrêt du serveur (TERM)...".red
  CACHE.cleanup_all
  OPTIMIZER.cleanup
  THREAD_POOL.kill
  exit(0)
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
