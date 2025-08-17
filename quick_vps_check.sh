#!/bin/bash

# Script de vérification rapide pour diagnostiquer le problème VPS
# Usage: bash quick_vps_check.sh

echo "🚀 DIAGNOSTIC RAPIDE VPS - PERMISSIONS ADMINISTRATEUR"
echo "===================================================="

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher les résultats
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
    fi
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# 1. Vérification de l'environnement
echo -e "\n${BLUE}1. VÉRIFICATION DE L'ENVIRONNEMENT${NC}"
echo "----------------------------------"

print_info "Répertoire actuel: $(pwd)"
print_info "Utilisateur: $(whoami)"
print_info "Date: $(date)"

# Vérifier si on est dans le bon répertoire
if [ -f "srv_message.rb" ]; then
    print_result 0 "Répertoire STORM détecté"
else
    print_result 1 "Répertoire STORM non détecté - Naviguez vers le bon répertoire"
    echo "Usage: cd /path/to/STORM && bash quick_vps_check.sh"
    exit 1
fi

# 2. Vérification Git
echo -e "\n${BLUE}2. VÉRIFICATION GIT${NC}"
echo "-------------------"

# Branche actuelle
current_branch=$(git branch --show-current 2>/dev/null)
if [ $? -eq 0 ]; then
    print_info "Branche actuelle: $current_branch"
    if [ "$current_branch" = "1.6.7" ]; then
        print_result 0 "Branche correcte (1.6.7)"
    else
        print_warning "Branche différente de 1.6.7"
    fi
else
    print_result 1 "Impossible de déterminer la branche Git"
fi

# Dernier commit
last_commit=$(git log --oneline -1 2>/dev/null)
if [ $? -eq 0 ]; then
    print_info "Dernier commit: $last_commit"
else
    print_result 1 "Impossible de récupérer l'historique Git"
fi

# Statut Git
git_status=$(git status --porcelain 2>/dev/null)
if [ -z "$git_status" ]; then
    print_result 0 "Répertoire de travail propre"
else
    print_warning "Modifications non commitées détectées"
    echo "$git_status"
fi

# 3. Vérification des fichiers critiques
echo -e "\n${BLUE}3. VÉRIFICATION DES FICHIERS CRITIQUES${NC}"
echo "--------------------------------------"

# chat_room.rb
if [ -f "Message/models/chat_room.rb" ]; then
    print_result 0 "chat_room.rb trouvé"
    
    # Vérifier ADMIN_USERS
    if grep -q "ADMIN_USERS" "Message/models/chat_room.rb"; then
        admin_users=$(grep "ADMIN_USERS" "Message/models/chat_room.rb" | head -1)
        print_result 0 "ADMIN_USERS défini: $admin_users"
    else
        print_result 1 "ADMIN_USERS non trouvé"
    fi
    
    # Vérifier les méthodes
    if grep -q "def is_admin?" "Message/models/chat_room.rb"; then
        print_result 0 "Méthode is_admin? trouvée"
    else
        print_result 1 "Méthode is_admin? manquante"
    fi
    
    if grep -q "def can_modify_room_theme?" "Message/models/chat_room.rb"; then
        print_result 0 "Méthode can_modify_room_theme? trouvée"
    else
        print_result 1 "Méthode can_modify_room_theme? manquante"
    fi
    
    if grep -q "def system_room?" "Message/models/chat_room.rb"; then
        print_result 0 "Méthode system_room? trouvée"
    else
        print_result 1 "Méthode system_room? manquante"
    fi
else
    print_result 1 "chat_room.rb non trouvé"
fi

# background_command.rb
if [ -f "Message/commands/Appearance/background_command.rb" ]; then
    print_result 0 "background_command.rb trouvé"
    
    # Vérifier l'utilisation de can_modify_room_theme
    if grep -q "can_modify_room_theme" "Message/commands/Appearance/background_command.rb"; then
        print_result 0 "Utilisation de can_modify_room_theme? détectée"
    else
        print_result 1 "can_modify_room_theme? non utilisé"
    fi
    
    # Vérifier le message d'erreur admin
    if grep -q "administrateurs peuvent modifier" "Message/commands/Appearance/background_command.rb"; then
        print_result 0 "Message d'erreur administrateur présent"
    else
        print_result 1 "Message d'erreur administrateur manquant"
    fi
else
    print_result 1 "background_command.rb non trouvé"
fi

# 4. Vérification des processus
echo -e "\n${BLUE}4. VÉRIFICATION DES PROCESSUS${NC}"
echo "------------------------------"

# Processus Ruby
ruby_processes=$(ps aux | grep -v grep | grep ruby | wc -l)
if [ $ruby_processes -gt 0 ]; then
    print_result 0 "$ruby_processes processus Ruby en cours"
    ps aux | grep -v grep | grep ruby | while read line; do
        print_info "$line"
    done
else
    print_result 1 "Aucun processus Ruby détecté"
fi

# Processus STORM spécifique
storm_processes=$(ps aux | grep -v grep | grep srv_message | wc -l)
if [ $storm_processes -gt 0 ]; then
    print_result 0 "$storm_processes processus STORM en cours"
    ps aux | grep -v grep | grep srv_message | while read line; do
        print_info "$line"
    done
else
    print_result 1 "Aucun processus STORM détecté"
fi

# 5. Test de syntaxe Ruby
echo -e "\n${BLUE}5. TEST DE SYNTAXE RUBY${NC}"
echo "------------------------"

if command -v ruby >/dev/null 2>&1; then
    print_info "Version Ruby: $(ruby --version)"
    
    # Test chat_room.rb
    if [ -f "Message/models/chat_room.rb" ]; then
        if ruby -c "Message/models/chat_room.rb" >/dev/null 2>&1; then
            print_result 0 "Syntaxe chat_room.rb valide"
        else
            print_result 1 "Erreur de syntaxe dans chat_room.rb"
            ruby -c "Message/models/chat_room.rb"
        fi
    fi
    
    # Test background_command.rb
    if [ -f "Message/commands/Appearance/background_command.rb" ]; then
        if ruby -c "Message/commands/Appearance/background_command.rb" >/dev/null 2>&1; then
            print_result 0 "Syntaxe background_command.rb valide"
        else
            print_result 1 "Erreur de syntaxe dans background_command.rb"
            ruby -c "Message/commands/Appearance/background_command.rb"
        fi
    fi
else
    print_result 1 "Ruby non installé ou non accessible"
fi

# 6. Résumé et recommandations
echo -e "\n${BLUE}6. RÉSUMÉ ET RECOMMANDATIONS${NC}"
echo "-----------------------------"

# Compter les problèmes
problems=0

# Vérifications critiques
if [ ! -f "Message/models/chat_room.rb" ]; then
    ((problems++))
fi

if [ ! -f "Message/commands/Appearance/background_command.rb" ]; then
    ((problems++))
fi

if ! grep -q "ADMIN_USERS" "Message/models/chat_room.rb" 2>/dev/null; then
    ((problems++))
fi

if ! grep -q "def can_modify_room_theme?" "Message/models/chat_room.rb" 2>/dev/null; then
    ((problems++))
fi

if [ $storm_processes -eq 0 ]; then
    ((problems++))
fi

if [ $problems -eq 0 ]; then
    echo -e "${GREEN}✅ AUCUN PROBLÈME CRITIQUE DÉTECTÉ${NC}"
    echo -e "${GREEN}Le système semble correctement configuré.${NC}"
    echo ""
    echo "Si le problème persiste, essayez :"
    echo "1. Redémarrer le serveur : pkill -f srv_message.rb && sleep 3 && ruby srv_message.rb &"
    echo "2. Tester avec un utilisateur admin (DALM1) : /background https://example.com/test.jpg"
else
    echo -e "${RED}❌ $problems PROBLÈME(S) CRITIQUE(S) DÉTECTÉ(S)${NC}"
    echo ""
    echo "Actions recommandées :"
    echo "1. Exécuter le script de correction : bash fix_vps_permissions.sh"
    echo "2. Ou suivre le guide complet : GUIDE_RESOLUTION_COMPLETE.md"
    echo "3. Redémarrer le serveur après correction"
fi

echo ""
echo -e "${BLUE}📋 SCRIPTS DISPONIBLES :${NC}"
echo "- fix_vps_permissions.sh : Correction automatique"
echo "- check_vps_permissions.sh : Diagnostic détaillé"
echo "- GUIDE_RESOLUTION_COMPLETE.md : Guide complet"

echo ""
echo "✅ Diagnostic rapide terminé !"