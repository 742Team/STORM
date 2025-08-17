#!/usr/bin/env ruby

# Script de test pour vérifier les permissions d'administrateur
require_relative 'Message/models/chat_room'

puts "🔍 Test des permissions d'administrateur"
puts "="*50

# Créer une instance de ChatRoom pour tester
room = ChatRoom.new("Main")

# Tester différents utilisateurs
test_users = [
  { username: "DALM1", expected: true, description: "Utilisateur admin DALM1" },
  { username: "admin", expected: true, description: "Utilisateur admin générique" },
  { username: "testuser", expected: false, description: "Utilisateur normal" },
  { username: "User_1234", expected: false, description: "Utilisateur temporaire" }
]

puts "📋 Test de la méthode is_admin?:"
test_users.each do |user|
  result = room.is_admin?(user[:username])
  status = result == user[:expected] ? "✅" : "❌"
  puts "#{status} #{user[:description]}: #{result} (attendu: #{user[:expected]})"
end

puts "\n📋 Test de la méthode can_modify_room_theme? (salon Main):"
test_users.each do |user|
  result = room.can_modify_room_theme?(user[:username])
  # Dans le salon Main (système), seuls les admins peuvent modifier
  expected = user[:expected] # Même logique que is_admin? pour le salon Main
  status = result == expected ? "✅" : "❌"
  puts "#{status} #{user[:description]}: #{result} (attendu: #{expected})"
end

puts "\n📋 Test de la méthode system_room?:"
system_rooms = ["Main", "General", "users", "CustomRoom"]
system_rooms.each do |room_name|
  test_room = ChatRoom.new(room_name)
  result = test_room.system_room?
  expected = ["Main", "General", "users"].include?(room_name)
  status = result == expected ? "✅" : "❌"
  puts "#{status} Salon '#{room_name}': #{result} (attendu: #{expected})"
end

puts "\n🎯 Test terminé"
puts "="*50