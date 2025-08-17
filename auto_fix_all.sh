#!/bin/bash

# Script de résolution automatique complète
# Usage: bash auto_fix_all.sh
# Ce script diagnostique et corrige automatiquement le problème de permissions

echo "🚀 RÉSOLUTION AUTOMATIQUE COMPLÈTE - PERMISSIONS ADMINISTRATEUR"
echo "================================================================"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_step() {
    echo -e "\n${PURPLE}📋 ÉTAPE $1: $2${NC}"
    echo "$(printf '=%.0s' {1..50})"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Variables
ERRORS=0
WARNINGS=0
FIXES_APPLIED=0

# Fonction pour incrémenter les compteurs
log_error() {
    ((ERRORS++))
    print_error "$1"
}

log_warning() {
    ((WARNINGS++))
    print_warning "$1"
}

log_fix() {
    ((FIXES_APPLIED++))
    print_success "$1"
}

# Vérifier si on est dans le bon répertoire
if [ ! -f "srv_message.rb" ]; then
    log_error "Répertoire STORM non détecté"
    echo "Usage: cd /path/to/STORM && bash auto_fix_all.sh"
    exit 1
fi

print_step "1" "DIAGNOSTIC INITIAL"

# Vérification Git
print_info "Vérification de l'état Git..."
current_branch=$(git branch --show-current 2>/dev/null)
if [ $? -eq 0 ]; then
    print_info "Branche actuelle: $current_branch"
    if [ "$current_branch" != "1.6.7" ]; then
        log_warning "Branche différente de 1.6.7"
    fi
else
    log_error "Impossible de déterminer la branche Git"
fi

# Vérification des fichiers critiques
print_info "Vérification des fichiers critiques..."
if [ ! -f "Message/models/chat_room.rb" ]; then
    log_error "chat_room.rb manquant"
    exit 1
fi

if [ ! -f "Message/commands/Appearance/background_command.rb" ]; then
    log_error "background_command.rb manquant"
    exit 1
fi

print_step "2" "MISE À JOUR DEPUIS GIT"

print_info "Récupération des dernières modifications..."
if git fetch origin >/dev/null 2>&1; then
    print_success "Fetch réussi"
    
    # Vérifier s'il y a des mises à jour
    if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/$current_branch)" ]; then
        print_info "Mises à jour disponibles, application..."
        if git pull origin "$current_branch" >/dev/null 2>&1; then
            log_fix "Code mis à jour depuis Git"
        else
            log_warning "Échec du pull Git"
        fi
    else
        print_info "Code déjà à jour"
    fi
else
    log_warning "Échec du fetch Git"
fi

print_step "3" "DIAGNOSTIC DES PERMISSIONS"

# Vérifier ADMIN_USERS
print_info "Vérification de ADMIN_USERS..."
if grep -q "ADMIN_USERS" "Message/models/chat_room.rb"; then
    admin_users_line=$(grep "ADMIN_USERS" "Message/models/chat_room.rb" | head -1)
    print_success "ADMIN_USERS trouvé: $admin_users_line"
else
    log_error "ADMIN_USERS manquant"
fi

# Vérifier les méthodes
print_info "Vérification des méthodes de permissions..."
methods_ok=true

if ! grep -q "def is_admin?" "Message/models/chat_room.rb"; then
    log_error "Méthode is_admin? manquante"
    methods_ok=false
fi

if ! grep -q "def can_modify_room_theme?" "Message/models/chat_room.rb"; then
    log_error "Méthode can_modify_room_theme? manquante"
    methods_ok=false
fi

if ! grep -q "def system_room?" "Message/models/chat_room.rb"; then
    log_error "Méthode system_room? manquante"
    methods_ok=false
fi

if $methods_ok; then
    print_success "Toutes les méthodes de permissions sont présentes"
fi

print_step "4" "APPLICATION DES CORRECTIONS"

if [ $ERRORS -gt 0 ]; then
    print_info "$ERRORS erreur(s) détectée(s), application des corrections..."
    
    # Exécuter le script de correction
    if [ -f "fix_vps_permissions.sh" ]; then
        print_info "Exécution du script de correction..."
        if bash fix_vps_permissions.sh >/dev/null 2>&1; then
            log_fix "Script de correction exécuté avec succès"
        else
            log_error "Échec du script de correction"
        fi
    else
        log_warning "Script fix_vps_permissions.sh non trouvé"
    fi
else
    print_success "Aucune correction nécessaire"
fi

print_step "5" "GESTION DES PROCESSUS"

# Vérifier les processus en cours
print_info "Vérification des processus STORM..."
storm_processes=$(ps aux | grep -v grep | grep srv_message | wc -l)

if [ $storm_processes -gt 0 ]; then
    print_info "$storm_processes processus STORM détecté(s)"
    print_info "Redémarrage des processus..."
    
    # Arrêter les processus
    pkill -f srv_message.rb >/dev/null 2>&1
    pkill -f "ruby.*srv_message" >/dev/null 2>&1
    
    # Attendre un peu
    sleep 3
    
    # Vérifier qu'ils sont bien arrêtés
    remaining=$(ps aux | grep -v grep | grep srv_message | wc -l)
    if [ $remaining -eq 0 ]; then
        print_success "Processus arrêtés avec succès"
    else
        log_warning "$remaining processus encore actifs"
    fi
else
    print_info "Aucun processus STORM en cours"
fi

# Redémarrer le serveur
print_info "Redémarrage du serveur STORM..."
if [ -f "start_hermes.sh" ]; then
    print_info "Utilisation de start_hermes.sh..."
    if ./start_hermes.sh >/dev/null 2>&1 &; then
        log_fix "Serveur redémarré via start_hermes.sh"
    else
        log_warning "Échec avec start_hermes.sh, tentative manuelle..."
        if ruby srv_message.rb >/dev/null 2>&1 &; then
            log_fix "Serveur redémarré manuellement"
        else
            log_error "Échec du redémarrage manuel"
        fi
    fi
else
    print_info "start_hermes.sh non trouvé, redémarrage manuel..."
    if ruby srv_message.rb >/dev/null 2>&1 &; then
        log_fix "Serveur redémarré manuellement"
    else
        log_error "Échec du redémarrage"
    fi
fi

# Attendre que le serveur démarre
print_info "Attente du démarrage du serveur..."
sleep 5

# Vérifier que le serveur est démarré
new_processes=$(ps aux | grep -v grep | grep srv_message | wc -l)
if [ $new_processes -gt 0 ]; then
    print_success "Serveur démarré avec succès ($new_processes processus)"
else
    log_error "Le serveur ne semble pas avoir démarré"
fi

print_step "6" "TESTS DE VALIDATION"

# Test de syntaxe Ruby
print_info "Test de syntaxe des fichiers Ruby..."
if ruby -c "Message/models/chat_room.rb" >/dev/null 2>&1; then
    print_success "Syntaxe chat_room.rb valide"
else
    log_error "Erreur de syntaxe dans chat_room.rb"
fi

if ruby -c "Message/commands/Appearance/background_command.rb" >/dev/null 2>&1; then
    print_success "Syntaxe background_command.rb valide"
else
    log_error "Erreur de syntaxe dans background_command.rb"
fi

# Test des permissions (si le script de test existe)
if [ -f "test_admin_permissions.rb" ]; then
    print_info "Exécution des tests de permissions..."
    if ruby test_admin_permissions.rb >/dev/null 2>&1; then
        print_success "Tests de permissions réussis"
    else
        log_warning "Échec des tests de permissions"
    fi
fi

print_step "7" "RÉSUMÉ FINAL"

echo -e "\n${BLUE}📊 STATISTIQUES DE LA RÉSOLUTION :${NC}"
echo "----------------------------------"
print_info "Erreurs détectées: $ERRORS"
print_info "Avertissements: $WARNINGS"
print_info "Corrections appliquées: $FIXES_APPLIED"

echo -e "\n${BLUE}🎯 RÉSULTAT FINAL :${NC}"
echo "-------------------"

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}🎉 RÉSOLUTION RÉUSSIE !${NC}"
    echo -e "${GREEN}Le système est maintenant opérationnel.${NC}"
    echo ""
    echo -e "${BLUE}📋 PROCHAINES ÉTAPES :${NC}"
    echo "1. Testez avec un utilisateur admin (DALM1) :"
    echo "   /background https://example.com/test.jpg"
    echo "2. Testez avec un utilisateur normal dans un salon système"
    echo "3. Vérifiez que les messages d'erreur s'affichent correctement"
    echo ""
    echo -e "${BLUE}🌐 TEST FRONTEND :${NC}"
    echo "Ouvrez la console du navigateur (F12) et exécutez :"
    echo "debug_frontend_auth.js"
else
    echo -e "${RED}⚠️  RÉSOLUTION PARTIELLE${NC}"
    echo -e "${RED}$ERRORS problème(s) persistent.${NC}"
    echo ""
    echo -e "${BLUE}📋 ACTIONS RECOMMANDÉES :${NC}"
    echo "1. Consultez GUIDE_RESOLUTION_COMPLETE.md"
    echo "2. Vérifiez les logs du serveur"
    echo "3. Exécutez manuellement fix_vps_permissions.sh"
    echo "4. Redémarrez complètement le serveur VPS si nécessaire"
fi

echo ""
echo -e "${BLUE}📁 FICHIERS DE DIAGNOSTIC DISPONIBLES :${NC}"
echo "- quick_vps_check.sh : Diagnostic rapide"
echo "- check_vps_permissions.sh : Diagnostic détaillé"
echo "- debug_frontend_auth.js : Diagnostic frontend"
echo "- GUIDE_RESOLUTION_COMPLETE.md : Guide complet"

echo ""
echo "✅ Résolution automatique terminée !"
echo "Temps d'exécution: $SECONDS secondes"