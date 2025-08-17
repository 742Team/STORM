#!/bin/bash

# Script de démarrage d'urgence pour contourner les problèmes de dépendances
echo "[URGENCE] Démarrage du serveur STORM sans dépendances problématiques..."
echo ""

# Fonction de sauvegarde (simplifiée)
backup_databases() {
    echo "Sauvegarde rapide des bases de données..."
    
    if [ ! -d "data/backups" ]; then
        mkdir -p data/backups
    fi
    
    BACKUP_DIR="data/backups/emergency_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Sauvegarder seulement les fichiers existants
    for db in storm_persistent.db chat_app.db storm.db chat.db users.db; do
        if [ -f "data/$db" ]; then
            cp "data/$db" "$BACKUP_DIR/" 2>/dev/null
            echo "   $db sauvegardé"
        fi
    done
    
    echo "   Sauvegarde dans: $BACKUP_DIR"
    echo ""
}

# Sauvegarder les données
backup_databases

# Arrêter les processus existants
echo "Arrêt des processus existants..."
pkill -f "ruby.*start" || true
pkill -f "puma" || true
docker rm -f hermes-backend 2>/dev/null || true
echo ""

# Utiliser le Gemfile minimal
echo "Utilisation du Gemfile minimal..."
cp Gemfile.minimal Gemfile
echo ""

# Nettoyer les installations précédentes
echo "Nettoyage des gems problématiques..."
rm -rf .bundle/
rm -f Gemfile.lock
echo ""

# Installer bundler si nécessaire
echo "Vérification de bundler..."
if ! command -v bundle &> /dev/null; then
    gem install bundler --no-document
fi
echo ""

# Installer les gems essentielles
echo "Installation des gems essentielles..."
bundle install --retry=3 || {
    echo "ATTENTION: bundle install échoué, installation manuelle..."
    gem install sqlite3 sinatra bcrypt colorize webrick rack mini_magick --no-document
}
echo ""

# Vérifier la configuration de persistance
if [ -f "start_with_persistence.rb" ] && [ -f "config/database_config.rb" ]; then
    echo "Démarrage avec persistance..."
    ruby start_with_persistence.rb
else
    echo "ATTENTION: Configuration de persistance non trouvée"
    echo "Démarrage du serveur de base..."
    
    # Créer un serveur minimal si nécessaire
    if [ -f "srv_message.rb" ]; then
        ruby srv_message.rb
    else
        echo "ERREUR: Aucun serveur disponible"
        exit 1
    fi
fi