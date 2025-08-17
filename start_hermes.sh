#!/bin/bash

# Use current directory instead of hardcoded path
CURRENT_DIR=$(pwd)

# Fonction pour sauvegarder les bases de données existantes
backup_databases() {
    echo " Sauvegarde des bases de données existantes..."
    
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
                echo "  Sauvegarde de $db_file..."
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
        echo "  $BACKUP_COUNT base(s) de données sauvegardée(s) dans: $BACKUP_DIR"
        # Créer un fichier de métadonnées
        echo "Sauvegarde créée le: $(date)" > "$BACKUP_DIR/backup_info.txt"
        echo "Répertoire source: $CURRENT_DIR" >> "$BACKUP_DIR/backup_info.txt"
        echo "Nombre de fichiers: $BACKUP_COUNT" >> "$BACKUP_DIR/backup_info.txt"
    else
        echo "  Aucune base de données trouvée à sauvegarder"
        rmdir "$BACKUP_DIR" 2>/dev/null
    fi
    echo ""
}

# Sauvegarder les bases de données avant toute opération
backup_databases

# Récupérer la dernière version du code depuis Git
echo "Récupération de la dernière version du code..."
if git status >/dev/null 2>&1; then
    current_branch=$(git branch --show-current)
    echo "Branche actuelle: $current_branch"
    
    # Fetch les dernières modifications
    git fetch origin
    
    # Pull les modifications si disponibles
    if git pull origin "$current_branch" >/dev/null 2>&1; then
        echo "⚪️ Code mis à jour avec succès"
    else
        echo "⚠️  Aucune mise à jour disponible ou erreur lors du pull"
    fi
else
    echo "⚠️  Ce répertoire n'est pas un dépôt Git, pas de mise à jour automatique"
fi
echo ""

# Vérifier si la configuration de persistance existe
if [ -f "$CURRENT_DIR/start_with_persistence.rb" ] && [ -f "$CURRENT_DIR/config/database_config.rb" ]; then
    echo " Configuration de persistance détectée..."
    echo "Voulez-vous utiliser la configuration de persistance? (y/N)"
    read -t 10 -r use_persistence
    
    if [[ $use_persistence =~ ^[Yy]$ ]]; then
        echo " Démarrage avec la configuration de persistance..."
        # Arrêter le serveur actuel s'il existe
        pkill -f "ruby.*start_with_persistence.rb" 2>/dev/null
        pkill -f "puma" 2>/dev/null
        sleep 2
        
        # Démarrer avec la persistance
        ruby start_with_persistence.rb
        exit 0
    else
        echo " Utilisation de la configuration Docker standard..."
    fi
fi

docker rm -f hermes_container 2>/dev/null

# Create Gemfile with specific sqlite3 version to avoid build issues
cat > Gemfile << EOL
source 'https://rubygems.org'
gem 'sqlite3', '~> 1.6.0'  # Using a newer version that's compatible with Ruby 3.2
gem 'sinatra', '~> 3.0'
gem 'bcrypt'
gem 'colorize'
gem 'websocket-driver'
gem 'webrick'
gem 'rack'
gem 'mini_magick'  # For image processing
gem 'taglib-ruby', '~> 1.1.0'
EOL

# Create a proper Dockerfile that handles dependencies correctly
cat > Dockerfile << EOL
FROM ruby:3.2

WORKDIR /app

# Install system dependencies for sqlite3 and ffmpeg
RUN apt-get update && apt-get install -y sqlite3 libsqlite3-dev ffmpeg libtag1-dev

# Install bundler first
RUN gem install bundler

# Create Gemfile directly in the container
RUN echo "source 'https://rubygems.org'" > /app/Gemfile && \
    echo "gem 'sqlite3', '~> 1.6.0'" >> /app/Gemfile && \
    echo "gem 'sinatra', '~> 3.0'" >> /app/Gemfile && \
    echo "gem 'bcrypt'" >> /app/Gemfile && \
    echo "gem 'colorize'" >> /app/Gemfile && \
    echo "gem 'websocket-driver'" >> /app/Gemfile && \
    echo "gem 'webrick'" >> /app/Gemfile && \
    echo "gem 'rack'" >> /app/Gemfile && \
    echo "gem 'mini_magick'" >> /app/Gemfile && \
    echo "gem 'taglib-ruby', '~> 1.1.0'" >> /app/Gemfile

# Install gems
RUN bundle install

# Copy the application
COPY . /app/

# Create upload directory with proper permissions
RUN mkdir -p /app/public/uploads
RUN chmod 755 /app/public/uploads

# Expose ports
EXPOSE 3630 4567

# Start both servers - updated to use the new app.rb file instead of lib/app_config.rb
CMD ["sh", "-c", "ruby srv_message.rb & ruby srv_upload.rb"]
EOL

# Create uploads directory if it doesn't exist
mkdir -p $CURRENT_DIR/uploads

echo "Building Docker image..."
docker build -t hermes .

echo "Starting container..."
docker run -d --name hermes_container \
  -p 3630:3630 \
  -p 4567:4567 \
  -v $CURRENT_DIR/uploads:/app/public/uploads \
  -e DB_PATH=/app/chat_app.db \
  -e DB_NAME=hermes \
  -e DB_USER=user \
  -e DB_PASS=admin \
  -e DB_HOST=localhost \
  hermes

echo "Démarrage des services..."
sleep 2
docker logs hermes_container

echo "Services démarrés. Ports ouverts:"
echo "- WebSocket: 3630"
echo "- HTTP (uploads): 4567"
echo "Dossier des uploads monté dans: $CURRENT_DIR/uploads"

if docker ps | grep -q hermes_container; then
  echo "⚪️ Le conteneur fonctionne correctement."
else
  echo "⚫️ Le conteneur s'est arrêté. Vérifiez les logs pour plus de détails:"
  docker logs hermes_container

  echo "Tentative de démarrage sans le serveur d'upload..."
  cat > Dockerfile.ws << EOL
FROM ruby:3.2

WORKDIR /app

# Install system dependencies for sqlite3 and ImageMagick
RUN apt-get update && apt-get install -y sqlite3 libsqlite3-dev imagemagick libmagickwand-dev

# Install bundler first
RUN gem install bundler

# Create Gemfile directly in the container
RUN echo "source 'https://rubygems.org'" > /app/Gemfile && \\
    echo "gem 'sqlite3', '~> 1.6.0'" >> /app/Gemfile && \\
    echo "gem 'sinatra', '~> 3.0'" >> /app/Gemfile && \\
    echo "gem 'bcrypt'" >> /app/Gemfile && \\
    echo "gem 'colorize'" >> /app/Gemfile && \\
    echo "gem 'websocket-driver'" >> /app/Gemfile && \\
    echo "gem 'webrick'" >> /app/Gemfile && \\
    echo "gem 'rack'" >> /app/Gemfile && \\
    echo "gem 'mini_magick'" >> /app/Gemfile

# Install gems
RUN bundle install

# Copy the application
COPY . /app/

# Expose only WebSocket port
EXPOSE 3630

# Start only the WebSocket server
CMD ["ruby", "srv_message.rb"]
EOL

  docker build -t hermes_ws -f Dockerfile.ws .
  docker run -d --name hermes_container \
    -p 3630:3630 \
    -e DB_PATH=/app/chat_app.db \
    -e DB_NAME=hermes \
    -e DB_USER=user \
    -e DB_PASS=admin \
    -e DB_HOST=localhost \
    hermes_ws

  echo "Le serveur WebSocket devrait maintenant fonctionner sur le port 3630"
  echo "L'upload de fichiers est temporairement désactivé."
fi
