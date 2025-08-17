#!/bin/bash

# Script d'application automatique des corrections de permissions d'administrateur
# Usage: ./apply_admin_fix.sh

set -e  # Arrêter en cas d'erreur

echo "Application des corrections de permissions d'administrateur..."

# Vérifier que nous sommes dans le bon répertoire
if [ ! -f "srv_message.rb" ]; then
    echo "⚫️ Erreur: Ce script doit être exécuté depuis le répertoire STORM"
    exit 1
fi

# Créer des sauvegardes
echo "Création des sauvegardes..."
cp Message/models/chat_room.rb Message/models/chat_room.rb.backup.$(date +%Y%m%d_%H%M%S)
cp Message/commands/Appearance/background_command.rb Message/commands/Appearance/background_command.rb.backup.$(date +%Y%m%d_%H%M%S)

# Appliquer les modifications à chat_room.rb
echo "Modification de chat_room.rb..."

# Vérifier si ADMIN_USERS existe déjà
if ! grep -q "ADMIN_USERS" Message/models/chat_room.rb; then
    # Ajouter ADMIN_USERS après la ligne de classe
    sed -i.tmp '/^class ChatRoom/a\
  ADMIN_USERS = ["DALM1", "admin", "administrator"].freeze' Message/models/chat_room.rb
    rm Message/models/chat_room.rb.tmp
    echo "ADMIN_USERS ajouté"
else
    echo "ADMIN_USERS existe déjà"
fi

# Vérifier si is_admin? existe déjà
if ! grep -q "def is_admin?" Message/models/chat_room.rb; then
    # Ajouter la méthode is_admin?
    cat >> Message/models/chat_room.rb << 'EOF'

  # Vérifier si l'utilisateur est un administrateur
  def is_admin?(username)
    ADMIN_USERS.include?(username)
  end
EOF
    echo "Méthode is_admin? ajoutée"
else
    echo "Méthode is_admin? existe déjà"
fi

# Modifier can_modify_room_theme? si nécessaire
if ! grep -q "is_admin?(username)" Message/models/chat_room.rb; then
    echo "Mise à jour de can_modify_room_theme?..."
    
    # Créer un fichier temporaire avec la nouvelle méthode
    cat > /tmp/new_can_modify_room_theme.rb << 'EOF'
  # Vérifier si l'utilisateur peut modifier le thème du salon
  def can_modify_room_theme?(username)
    # Le créateur peut toujours modifier
    return true if @creator == username
    
    # Les administrateurs peuvent toujours modifier, même dans les salons système
    return true if is_admin?(username)
    
    # Dans les salons système (comme "Main"), seuls les admins peuvent modifier
    return false if system_room?
    
    # Dans les autres salons, seul le créateur peut modifier
    false
  end
EOF

    # Remplacer l'ancienne méthode
    sed -i.tmp '/def can_modify_room_theme?/,/^  end$/c\
' Message/models/chat_room.rb
    
    # Insérer la nouvelle méthode
    sed -i.tmp '/# Vérifier si l\'utilisateur peut modifier le thème du salon/r /tmp/new_can_modify_room_theme.rb' Message/models/chat_room.rb
    
    rm Message/models/chat_room.rb.tmp
    rm /tmp/new_can_modify_room_theme.rb
    echo "can_modify_room_theme? mise à jour"
else
    echo "can_modify_room_theme? semble déjà à jour"
fi

# Modifier background_command.rb
echo "Modification de background_command.rb..."

if ! grep -q "Seuls les administrateurs peuvent le faire" Message/commands/Appearance/background_command.rb; then
    sed -i.tmp 's/Vous ne pouvez pas modifier l.arrière-plan dans ce salon système/Vous ne pouvez pas modifier l'arrière-plan dans ce salon système. Seuls les administrateurs peuvent le faire/' Message/commands/Appearance/background_command.rb
    rm Message/commands/Appearance/background_command.rb.tmp
    echo "Message d'erreur mis à jour"
else
    echo "Message d'erreur déjà à jour"
fi

# Vérifier la syntaxe Ruby
echo "Vérification de la syntaxe..."
if ruby -c Message/models/chat_room.rb > /dev/null 2>&1; then
    echo "chat_room.rb syntaxe OK"
else
    echo "⚫️ Erreur de syntaxe dans chat_room.rb"
    exit 1
fi

if ruby -c Message/commands/Appearance/background_command.rb > /dev/null 2>&1; then
    echo "background_command.rb syntaxe OK"
else
    echo "⚫️ Erreur de syntaxe dans background_command.rb"
    exit 1
fi

# Redémarrer le serveur
echo "Redémarrage du serveur STORM..."

# Arrêter les processus existants
echo "Arrêt des processus existants..."
pkill -f srv_message || true
pkill -f "ruby.*storm" || true
sleep 2

# Redémarrer en arrière-plan
echo "Redémarrage du serveur..."
nohup ruby srv_message.rb > storm.log 2>&1 &

# Attendre un peu pour vérifier que le serveur démarre
sleep 3

if pgrep -f srv_message > /dev/null; then
    echo "Serveur STORM redémarré avec succès"
    echo "PID du serveur: $(pgrep -f srv_message)"
else
    echo "⚫️ Échec du redémarrage du serveur"
    echo "Vérifiez les logs: tail -f storm.log"
    exit 1
fi

echo ""
echo "Corrections appliquées avec succès !"
echo ""
echo "Résumé des modifications:"
echo "   ADMIN_USERS = ['DALM1', 'admin', 'administrator']"
echo "   Méthode is_admin?() ajoutée"
echo "   can_modify_room_theme?() mise à jour"
echo "   Message d'erreur amélioré"
echo "   Serveur redémarré"
echo ""
echo "Tests à effectuer:"
echo "   1. Connectez-vous en tant qu'invité et testez /background dans Main"
echo "   2. Connectez-vous en tant que DALM1 et testez /background dans Main"
echo "   3. Vérifiez que seuls les admins peuvent modifier les salons système"
echo ""
echo "Logs du serveur: tail -f storm.log"