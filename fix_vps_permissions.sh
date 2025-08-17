#!/bin/bash

# Script automatisé pour corriger les permissions d'administrateur sur le VPS
# Ce script doit être exécuté sur le VPS après avoir fait git pull

echo "🔧 Correction automatique des permissions d'administrateur sur VPS"
echo "================================================================="

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages colorés
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Vérifier que nous sommes dans le bon répertoire
if [ ! -f "srv_message.rb" ]; then
    log_error "Ce script doit être exécuté depuis le répertoire STORM"
    exit 1
fi

log_info "Début de la correction des permissions..."

# Étape 1: Sauvegarder les fichiers actuels
log_info "Sauvegarde des fichiers actuels..."
cp Message/models/chat_room.rb Message/models/chat_room.rb.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null
cp Message/commands/Appearance/background_command.rb Message/commands/Appearance/background_command.rb.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null
log_success "Fichiers sauvegardés"

# Étape 2: Vérifier l'état actuel
log_info "Vérification de l'état actuel..."

# Vérifier chat_room.rb
if [ -f "Message/models/chat_room.rb" ]; then
    if grep -q "ADMIN_USERS" Message/models/chat_room.rb; then
        log_success "ADMIN_USERS trouvé dans chat_room.rb"
    else
        log_error "ADMIN_USERS manquant dans chat_room.rb"
        NEED_CHAT_ROOM_FIX=1
    fi
    
    if grep -q "def is_admin?" Message/models/chat_room.rb; then
        log_success "Méthode is_admin? trouvée"
    else
        log_error "Méthode is_admin? manquante"
        NEED_CHAT_ROOM_FIX=1
    fi
    
    if grep -q "def can_modify_room_theme?" Message/models/chat_room.rb; then
        log_success "Méthode can_modify_room_theme? trouvée"
    else
        log_error "Méthode can_modify_room_theme? manquante"
        NEED_CHAT_ROOM_FIX=1
    fi
else
    log_error "Fichier chat_room.rb non trouvé"
    exit 1
fi

# Vérifier background_command.rb
if [ -f "Message/commands/Appearance/background_command.rb" ]; then
    if grep -q "Seuls les administrateurs peuvent le faire" Message/commands/Appearance/background_command.rb; then
        log_success "Message d'erreur administrateur trouvé"
    else
        log_warning "Message d'erreur administrateur manquant"
        NEED_BACKGROUND_FIX=1
    fi
else
    log_error "Fichier background_command.rb non trouvé"
    exit 1
fi

# Étape 3: Appliquer les corrections si nécessaire
if [ "$NEED_CHAT_ROOM_FIX" = "1" ]; then
    log_warning "Correction de chat_room.rb nécessaire"
    log_info "Application du correctif chat_room.rb..."
    
    # Ajouter ADMIN_USERS si manquant
    if ! grep -q "ADMIN_USERS" Message/models/chat_room.rb; then
        sed -i '/class ChatRoom/a\  # Liste des administrateurs du système\n  ADMIN_USERS = ["DALM1", "admin", "administrator"].freeze' Message/models/chat_room.rb
    fi
    
    # Ajouter les méthodes si manquantes
    if ! grep -q "def can_modify_room_theme?" Message/models/chat_room.rb; then
        cat >> Message/models/chat_room.rb << 'EOF'

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
    fi
    
    if ! grep -q "def is_admin?" Message/models/chat_room.rb; then
        cat >> Message/models/chat_room.rb << 'EOF'

  # Vérifier si l'utilisateur est un administrateur
  def is_admin?(username)
    ADMIN_USERS.include?(username)
  end
EOF
    fi
    
    if ! grep -q "def system_room?" Message/models/chat_room.rb; then
        cat >> Message/models/chat_room.rb << 'EOF'

  # Vérifier si c'est un salon système
  def system_room?
    ['Main', 'General', 'users'].include?(@name)
  end
EOF
    fi
    
    log_success "chat_room.rb corrigé"
fi

if [ "$NEED_BACKGROUND_FIX" = "1" ]; then
    log_warning "Correction de background_command.rb nécessaire"
    log_info "Application du correctif background_command.rb..."
    
    # Corriger le message d'erreur
    sed -i 's/Vous ne pouvez pas modifier l.arrière-plan dans ce salon système/Vous ne pouvez pas modifier l'arrière-plan dans ce salon système. Seuls les administrateurs peuvent le faire/' Message/commands/Appearance/background_command.rb
    
    log_success "background_command.rb corrigé"
fi

# Étape 4: Vérifier la syntaxe
log_info "Vérification de la syntaxe..."
if ruby -c Message/models/chat_room.rb > /dev/null 2>&1; then
    log_success "chat_room.rb syntaxe OK"
else
    log_error "Erreur de syntaxe dans chat_room.rb"
    exit 1
fi

if ruby -c Message/commands/Appearance/background_command.rb > /dev/null 2>&1; then
    log_success "background_command.rb syntaxe OK"
else
    log_error "Erreur de syntaxe dans background_command.rb"
    exit 1
fi

# Étape 5: Test rapide
log_info "Test rapide des permissions..."
ruby -e "
load 'Message/models/chat_room.rb'
room = ChatRoom.new('Main')
puts 'Test DALM1 admin: ' + room.is_admin?('DALM1').to_s
puts 'Test DALM1 can modify: ' + room.can_modify_room_theme?('DALM1').to_s
puts 'Test Main system room: ' + room.system_room?.to_s
" 2>/dev/null

if [ $? -eq 0 ]; then
    log_success "Tests de base réussis"
else
    log_error "Échec des tests de base"
    exit 1
fi

# Étape 6: Instructions finales
log_success "Correction terminée avec succès!"
echo ""
log_info "Prochaines étapes:"
echo "1. Redémarrer le serveur STORM (./start_hermes.sh ou votre commande habituelle)"
echo "2. Tester avec un utilisateur DALM1 dans le salon Main"
echo "3. Vérifier que la commande /background fonctionne pour les admins"
echo ""
log_info "Si le problème persiste, vérifiez:"
echo "- Que le serveur utilise bien les nouveaux fichiers"
echo "- Que l'auto-login fonctionne correctement"
echo "- Que le nom d'utilisateur est bien 'DALM1' (sensible à la casse)"
echo ""
log_success "Script terminé!"