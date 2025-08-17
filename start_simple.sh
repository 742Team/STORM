#!/bin/bash

# Script de démarrage simplifié pour STORM
# Sauvegarde automatique des BDD + démarrage avec persistance

CURRENT_DIR=$(pwd)

echo "STORM - Démarrage simplifié"
echo "=============================="

# Fonction pour sauvegarder les bases de données existantes
backup_databases() {
    echo "Sauvegarde automatique des bases de données."
    
    # Créer le répertoire de sauvegarde avec timestamp
    BACKUP_DIR="$CURRENT_DIR/data/backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Liste des bases de données à sauvegarder
    DB_FILES=("chat_app.db" "storm.db" "chat.db" "users.db" "storm_persistent.db")
    
    BACKUP_COUNT=0
    for db_file in "${DB_FILES[@]}"; do
        # Chercher dans le répertoire courant et data/
        for search_path in "$CURRENT_DIR" "$CURRENT_DIR/data"; do
            if [ -f "$search_path/$db_file" ]; then
                echo " Sauvegarde: $db_file"
                cp "$search_path/$db_file" "$BACKUP_DIR/"
                # Sauvegarder aussi les fichiers WAL et SHM s'ils existent
                [ -f "$search_path/$db_file-wal" ] && cp "$search_path/$db_file-wal" "$BACKUP_DIR/"
                [ -f "$search_path/$db_file-shm" ] && cp "$search_path/$db_file-shm" "$BACKUP_DIR/"
                BACKUP_COUNT=$((BACKUP_COUNT + 1))
                break
            fi
        done
    done
    
    if [ $BACKUP_COUNT -gt 0 ]; then
        echo " $BACKUP_COUNT BDD sauvegardée(s) dans: $BACKUP_DIR"
        # Créer un fichier de métadonnées
        echo "Sauvegarde automatique - $(date)" > "$BACKUP_DIR/backup_info.txt"
        echo "Source: $CURRENT_DIR" >> "$BACKUP_DIR/backup_info.txt"
        echo "Fichiers: $BACKUP_COUNT" >> "$BACKUP_DIR/backup_info.txt"
    else
        echo "  ℹ️  Aucune BDD existante trouvée"
        rmdir "$BACKUP_DIR" 2>/dev/null
    fi
    echo ""
}

# Sauvegarder automatiquement
backup_databases

# Arrêter les processus existants
echo "Arrêt des processus existants."
pkill -f "ruby.*start_with_persistence.rb" 2>/dev/null || true
pkill -f "puma" 2>/dev/null || true
pkill -f "srv_message.rb" 2>/dev/null || true
pkill -f "srv_upload.rb" 2>/dev/null || true
docker rm -f hermes_container 2>/dev/null || true
echo "Processus arrêtés."
sleep 1

# Vérifier la configuration de persistance
if [ -f "$CURRENT_DIR/start_with_persistence.rb" ] && [ -f "$CURRENT_DIR/config/database_config.rb" ]; then
    echo "Démarrage avec configuration de persistance."
    ruby start_with_persistence.rb
else
    echo "Configuration de persistance non trouvée."
    echo "Fallback vers la configuration Docker..."
    ./start_hermes.sh
fi