#!/bin/bash

# Use current directory instead of hardcoded path
CURRENT_DIR=$(pwd)

docker rm -f hermes_container 2>/dev/null

# Create Gemfile with specific sqlite3 version to avoid build issues
cat > Gemfile << EOL
source 'https://rubygems.org'
gem 'sqlite3', '~> 1.4.0'  # Using an older version that's more compatible
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
    echo "gem 'sqlite3', '~> 1.4.0'" >> /app/Gemfile && \
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
  echo "⚫️ Le conteneur fonctionne correctement."
else
  echo "⚪️ Le conteneur s'est arrêté. Vérifiez les logs pour plus de détails:"
  docker logs hermes_container

  echo "Tentative de démarrage sans le serveur d'upload..."
  cat > Dockerfile.ws << EOL
FROM ruby:3.2

WORKDIR /app

# Install system dependencies for sqlite3
RUN apt-get update && apt-get install -y sqlite3 libsqlite3-dev

# Install bundler first
RUN gem install bundler

# Create Gemfile directly in the container
RUN echo "source 'https://rubygems.org'" > /app/Gemfile && \\
    echo "gem 'sqlite3', '~> 1.4.0'" >> /app/Gemfile && \\
    echo "gem 'sinatra', '~> 3.0'" >> /app/Gemfile && \\
    echo "gem 'bcrypt'" >> /app/Gemfile && \\
    echo "gem 'colorize'" >> /app/Gemfile && \\
    echo "gem 'websocket-driver'" >> /app/Gemfile && \\
    echo "gem 'webrick'" >> /app/Gemfile && \\
    echo "gem 'rack'" >> /app/Gemfile

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
