#!/usr/bin/env ruby

# Script de débogage simplifié pour identifier le problème sur le VPS
puts "🔍 Débogage du problème VPS - Permissions d'administrateur"
puts "="*60

# Test 1: Vérifier que les fichiers existent et leur contenu
puts "📋 Test 1: Vérification des fichiers"
files_to_check = [
  'Message/models/chat_room.rb',
  'Message/commands/Appearance/background_command.rb'
]

files_to_check.each do |file|
  if File.exist?(file)
    mtime = File.mtime(file)
    size = File.size(file)
    puts "✅ #{file}: #{mtime} (#{size} bytes)"
    
    # Vérifier le contenu spécifique
    content = File.read(file)
    if file.include?('chat_room.rb')
      has_admin_users = content.include?('ADMIN_USERS')
      has_is_admin = content.include?('def is_admin?')
      has_can_modify = content.include?('def can_modify_room_theme?')
      has_system_room = content.include?('def system_room?')
      puts "   - ADMIN_USERS: #{has_admin_users}"
      puts "   - is_admin?: #{has_is_admin}"
      puts "   - can_modify_room_theme?: #{has_can_modify}"
      puts "   - system_room?: #{has_system_room}"
      
      # Extraire la ligne ADMIN_USERS
      if has_admin_users
        admin_line = content.lines.find { |line| line.include?('ADMIN_USERS') && line.include?('=') }
        puts "   - Ligne ADMIN_USERS: #{admin_line.strip}" if admin_line
      end
      
    elsif file.include?('background_command.rb')
      has_admin_message = content.include?('Seuls les administrateurs peuvent le faire')
      has_can_modify_call = content.include?('can_modify_room_theme?')
      puts "   - Message admin: #{has_admin_message}"
      puts "   - Appel can_modify_room_theme?: #{has_can_modify_call}"
    end
  else
    puts "❌ #{file}: Fichier non trouvé"
  end
end

# Test 2: Charger seulement ChatRoom et tester
puts "\n📋 Test 2: Test isolé de ChatRoom"
begin
  # Charger seulement le fichier ChatRoom
  load 'Message/models/chat_room.rb'
  
  puts "✅ ChatRoom chargé avec succès"
  
  # Tester la constante ADMIN_USERS
  if defined?(ChatRoom::ADMIN_USERS)
    puts "✅ ADMIN_USERS défini: #{ChatRoom::ADMIN_USERS.inspect}"
  else
    puts "❌ ADMIN_USERS non défini"
  end
  
  # Créer une instance et tester
  room = ChatRoom.new("Main")
  puts "✅ Instance ChatRoom créée: #{room.name}"
  
  # Tester les méthodes
  if room.respond_to?(:is_admin?)
    admin_result = room.is_admin?("DALM1")
    puts "✅ is_admin?('DALM1'): #{admin_result}"
  else
    puts "❌ Méthode is_admin? non trouvée"
  end
  
  if room.respond_to?(:can_modify_room_theme?)
    modify_result = room.can_modify_room_theme?("DALM1")
    puts "✅ can_modify_room_theme?('DALM1'): #{modify_result}"
  else
    puts "❌ Méthode can_modify_room_theme? non trouvée"
  end
  
  if room.respond_to?(:system_room?)
    system_result = room.system_room?
    puts "✅ system_room?(): #{system_result}"
  else
    puts "❌ Méthode system_room? non trouvée"
  end
  
rescue => e
  puts "❌ Erreur lors du chargement de ChatRoom: #{e.message}"
  puts "   Backtrace: #{e.backtrace.first(5).join('\n   ')}"
end

# Test 3: Vérifier les méthodes publiques/privées
puts "\n📋 Test 3: Analyse des méthodes"
begin
  if defined?(ChatRoom)
    room = ChatRoom.new("Test")
    public_methods = room.public_methods(false).sort
    puts "✅ Méthodes publiques personnalisées:"
    public_methods.each { |m| puts "   - #{m}" }
    
    # Vérifier spécifiquement nos méthodes
    target_methods = [:is_admin?, :can_modify_room_theme?, :system_room?]
    target_methods.each do |method|
      if room.respond_to?(method)
        puts "✅ #{method}: méthode publique"
      elsif room.private_methods.include?(method)
        puts "❌ #{method}: méthode privée (PROBLÈME!)"
      else
        puts "❌ #{method}: méthode non trouvée"
      end
    end
  end
rescue => e
  puts "❌ Erreur lors de l'analyse des méthodes: #{e.message}"
end

puts "\n🎯 Débogage terminé"
puts "="*60