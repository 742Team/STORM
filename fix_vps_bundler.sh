#!/bin/bash

# Script de correction spécialisé pour les problèmes de bundler sur VPS
echo "🔧 [VPS] Correction des problèmes de bundler..."
echo ""

# Afficher les informations système
echo "📋 Informations système:"
echo "Ruby version: $(ruby --version)"
echo "Gem version: $(gem --version)"
echo "Bundler installé: $(bundle --version 2>/dev/null || echo 'Non trouvé')"
echo ""

# Nettoyer les installations précédentes
echo "🧹 Nettoyage des installations précédentes..."
gem uninstall bundler --all --force 2>/dev/null || true
echo ""

# Installer bundler 1.17.2 spécifiquement
echo "📦 Installation de bundler 1.17.2..."
gem install bundler:1.17.2 --no-document --force
echo ""

# Vérifier l'installation
echo "✅ Vérification de l'installation:"
bundle --version
echo ""

# Nettoyer le cache bundler
echo "🧹 Nettoyage du cache bundler..."
rm -rf .bundle/
rm -f Gemfile.lock
echo ""

# Créer un nouveau Gemfile.lock
echo "📝 Création d'un nouveau Gemfile.lock..."
bundle install --retry=3
echo ""

# Vérifier que tout fonctionne
echo "🔍 Vérification finale..."
if bundle check; then
    echo "✅ Toutes les dépendances sont satisfaites!"
    echo "🚀 Vous pouvez maintenant démarrer le serveur avec:"
    echo "   ruby start_with_persistence.rb"
else
    echo "❌ Problèmes de dépendances détectés"
    echo "🔧 Tentative d'installation manuelle des gems critiques..."
    gem install sqlite3 sinatra bcrypt colorize websocket-driver webrick rack mini_magick --no-document
    echo "⚠️  Veuillez vérifier manuellement les dépendances"
fi

echo ""
echo "📋 Commandes utiles pour le dépannage:"
echo "   gem list bundler                    # Voir les versions installées"
echo "   gem install bundler:1.17.2         # Installer version spécifique"
echo "   bundle update --bundler             # Mettre à jour bundler"
echo "   bundle install --retry=3            # Réinstaller les gems"
echo "   rm -rf .bundle/ && rm Gemfile.lock  # Reset complet"