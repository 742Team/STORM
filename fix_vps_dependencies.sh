#!/bin/bash

# Script de correction des dépendances système pour VPS Ubuntu/Debian
echo "[VPS] Installation des dépendances système manquantes..."
echo ""

# Détecter le système d'exploitation
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    echo "ERREUR: Impossible de détecter le système d'exploitation"
    exit 1
fi

echo "Système détecté: $OS $VER"
echo ""

# Mettre à jour les paquets
echo "Mise à jour des paquets système..."
apt-get update -qq

# Installer les dépendances pour taglib-ruby
echo "Installation des dépendances taglib..."
apt-get install -y libtag1-dev

# Installer d'autres dépendances utiles
echo "Installation des outils de développement..."
apt-get install -y build-essential ruby-dev

# Installer les dépendances pour sqlite3 (au cas où)
echo "Installation des dépendances SQLite..."
apt-get install -y libsqlite3-dev

# Installer les dépendances pour bcrypt
echo "Installation des dépendances bcrypt..."
apt-get install -y libssl-dev

echo ""
echo "Dépendances système installées!"
echo ""

# Nettoyer et réinstaller les gems
echo "Nettoyage des gems précédentes..."
rm -rf vendor/bundle/
rm -f Gemfile.lock

echo "Réinstallation des gems..."
bundle install --retry=3

if [ $? -eq 0 ]; then
    echo "Installation des gems réussie!"
    echo "Vous pouvez maintenant démarrer le serveur:"
    echo "   ruby start_with_persistence.rb"
else
    echo "ERREUR: Problème lors de l'installation des gems"
    echo "Tentative d'installation manuelle..."
    gem install sqlite3 sinatra bcrypt colorize websocket-driver webrick rack mini_magick --no-document
    
    # Essayer d'installer taglib-ruby séparément
    echo "Tentative d'installation de taglib-ruby..."
    gem install taglib-ruby --no-document
    
    if [ $? -eq 0 ]; then
        echo "taglib-ruby installé avec succès!"
    else
        echo "ATTENTION: taglib-ruby n'a pas pu être installé, mais le serveur peut fonctionner sans"
    fi
fi

echo ""
echo "Résumé des dépendances installées:"
echo "   - libtag1-dev (pour taglib-ruby)"
echo "   - build-essential (outils de compilation)"
echo "   - ruby-dev (headers Ruby)"
echo "   - libsqlite3-dev (pour sqlite3)"
echo "   - libssl-dev (pour bcrypt)"