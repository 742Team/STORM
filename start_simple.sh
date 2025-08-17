#!/bin/bash

# Script de démarrage simplifié pour STORM avec sauvegarde automatique
echo "[SIMPLE] Démarrage simplifié du serveur STORM..."
echo ""

# Configuration
BACKUP_DIR="data/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"

# Créer le répertoire de sauvegarde
echo "[SAUVEGARDE] Création du répertoire de sauvegarde..."
mkdir -p "$BACKUP_PATH"
echo "   Répertoire: $BACKUP_PATH"
echo ""

# Sauvegarder les bases de données existantes
echo "[SAUVEGARDE] Sauvegarde des bases de données existantes..."
for db in chat_app.db storm.db chat.db users.db storm_persistent.db; do
    if [ -f "$db" ]; then
        cp "$db" "$BACKUP_PATH/"
        echo "   $db sauvegardé"
    fi
done

# Sauvegarder les fichiers associés (WAL, SHM)
for ext in shm wal; do
    for db in chat_app storm chat users storm_persistent; do
        if [ -f "${db}.db-${ext}" ]; then
            cp "${db}.db-${ext}" "$BACKUP_PATH/"
            echo "   ${db}.db-${ext} sauvegardé"
        fi
    done
done

# Créer le fichier d'information de sauvegarde
echo "Sauvegarde automatique créée le $(date)" > "$BACKUP_PATH/backup_info.txt"
echo "Script utilisé: start_simple.sh" >> "$BACKUP_PATH/backup_info.txt"
echo "Configuration détectée: $([ -f 'config/persistence.yml' ] || [ -f 'persistence.yml' ] && echo 'Persistance activée' || echo 'Mode standard')" >> "$BACKUP_PATH/backup_info.txt"
echo ""

# Fonction pour corriger les problèmes de bundler
fix_bundler_issues() {
    echo "[BUNDLER] Vérification et correction de bundler..."
    
    # Vérifier si bundler est disponible
    if ! command -v bundle &> /dev/null; then
        echo "   ATTENTION: Bundler non trouvé, installation..."
        gem install bundler --no-document
    fi
    
    # Vérifier la version requise dans Gemfile.lock
    if [ -f "Gemfile.lock" ]; then
        REQUIRED_VERSION=$(grep -A 1 "BUNDLED WITH" Gemfile.lock | tail -1 | tr -d ' ')
        if [ ! -z "$REQUIRED_VERSION" ]; then
            echo "   Version requise détectée: $REQUIRED_VERSION"
            if ! gem list bundler | grep -q "$REQUIRED_VERSION"; then
                echo "   Installation de bundler:$REQUIRED_VERSION..."
                gem install bundler:$REQUIRED_VERSION --no-document
            fi
        fi
    fi
    
    # Installer les gems du projet
    echo "   Installation des gems du projet..."
    if ! bundle install --retry=3; then
        echo "   ATTENTION: bundle install échoué, tentative de correction..."
        rm -rf .bundle/
        rm -f Gemfile.lock
        bundle install --retry=3 || {
            echo "   ERREUR: Échec de l'installation des gems"
            echo "   Installation manuelle des gems critiques..."
            gem install sqlite3 sinatra bcrypt colorize websocket-driver webrick rack mini_magick --no-document
        }
    fi
    echo ""
}

# Arrêter les processus existants
echo "[NETTOYAGE] Arrêt des processus Ruby existants..."
pkill -f "ruby.*start" 2>/dev/null || true
pkill -f "puma" 2>/dev/null || true
sleep 2
echo ""

# Corriger les problèmes de bundler
fix_bundler_issues

# Détecter la configuration de persistance
echo "[DETECTION] Vérification de la configuration..."
if [ -f "config/persistence.yml" ] || [ -f "persistence.yml" ]; then
    echo "   Configuration de persistance trouvée"
    echo "   Démarrage avec persistance..."
    echo ""
    ruby start_with_persistence.rb
elif [ -f "start_with_persistence.rb" ]; then
    echo "   ATTENTION: Fichier de persistance trouvé mais pas de config"
    echo "   Tentative de démarrage avec persistance..."
    echo ""
    ruby start_with_persistence.rb
else
    echo "   ATTENTION: Pas de configuration de persistance détectée"
    if [ -f "start.rb" ]; then
        echo "   Démarrage du serveur standard..."
        echo ""
        ruby start.rb
    elif [ -f "srv_message.rb" ]; then
        echo "   Démarrage du serveur de messages..."
        echo ""
        ruby srv_message.rb
    else
        echo "   ERREUR: Aucun serveur trouvé"
        echo "   Tentative avec Docker..."
        if command -v docker &> /dev/null; then
            docker-compose up --build
        else
            echo "   ERREUR: Docker non disponible"
            exit 1
        fi
    fi
fi