#!/bin/bash

# Script de vérification des permissions sur le VPS
# Ce script doit être exécuté sur le VPS pour diagnostiquer le problème

echo "🔍 Diagnostic des permissions d'administrateur sur le VPS"
echo "=" | tr -d '\n' | head -c 60 && echo

# Vérifier la présence des modifications dans chat_room.rb
echo "📁 Vérification du fichier chat_room.rb:"
if [ -f "Message/models/chat_room.rb" ]; then
    echo "✅ Fichier chat_room.rb trouvé"
    
    # Vérifier la présence de ADMIN_USERS
    if grep -q "ADMIN_USERS" Message/models/chat_room.rb; then
        echo "✅ Constante ADMIN_USERS trouvée"
        grep -n "ADMIN_USERS" Message/models/chat_room.rb
    else
        echo "❌ Constante ADMIN_USERS manquante"
    fi
    
    # Vérifier la présence de is_admin?
    if grep -q "def is_admin?" Message/models/chat_room.rb; then
        echo "✅ Méthode is_admin? trouvée"
    else
        echo "❌ Méthode is_admin? manquante"
    fi
    
    # Vérifier la présence de can_modify_room_theme?
    if grep -q "def can_modify_room_theme?" Message/models/chat_room.rb; then
        echo "✅ Méthode can_modify_room_theme? trouvée"
    else
        echo "❌ Méthode can_modify_room_theme? manquante"
    fi
    
    # Vérifier la présence de system_room?
    if grep -q "def system_room?" Message/models/chat_room.rb; then
        echo "✅ Méthode system_room? trouvée"
    else
        echo "❌ Méthode system_room? manquante"
    fi
else
    echo "❌ Fichier chat_room.rb non trouvé"
fi

echo
echo "📁 Vérification du fichier background_command.rb:"
if [ -f "Message/commands/Appearance/background_command.rb" ]; then
    echo "✅ Fichier background_command.rb trouvé"
    
    # Vérifier le message d'erreur pour les salons système
    if grep -q "Seuls les administrateurs peuvent le faire" Message/commands/Appearance/background_command.rb; then
        echo "✅ Message d'erreur administrateur trouvé"
    else
        echo "❌ Message d'erreur administrateur manquant"
    fi
else
    echo "❌ Fichier background_command.rb non trouvé"
fi

echo
echo "🔄 Vérification des processus STORM:"
ps aux | grep -i storm | grep -v grep

echo
echo "📅 Dernière modification des fichiers:"
if [ -f "Message/models/chat_room.rb" ]; then
    echo "chat_room.rb: $(stat -c '%y' Message/models/chat_room.rb 2>/dev/null || stat -f '%Sm' Message/models/chat_room.rb)"
fi
if [ -f "Message/commands/Appearance/background_command.rb" ]; then
    echo "background_command.rb: $(stat -c '%y' Message/commands/Appearance/background_command.rb 2>/dev/null || stat -f '%Sm' Message/commands/Appearance/background_command.rb)"
fi

echo
echo "🌿 Informations Git:"
echo "Branche actuelle: $(git branch --show-current 2>/dev/null || echo 'Non disponible')"
echo "Dernier commit: $(git log -1 --oneline 2>/dev/null || echo 'Non disponible')"
echo "Statut: $(git status --porcelain 2>/dev/null | wc -l) fichier(s) modifié(s)"

echo
echo "💡 Instructions:"
echo "1. Si les modifications sont manquantes, faire: git pull origin main"
echo "2. Redémarrer le serveur STORM: ./start_hermes ou votre commande habituelle"
echo "3. Vérifier que le processus utilise bien les nouveaux fichiers"
echo "4. Tester avec un utilisateur non-admin dans le salon Main"

echo
echo "=" | tr -d '\n' | head -c 60 && echo
echo "🎯 Diagnostic terminé"