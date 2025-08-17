#!/bin/bash

# Script de correction pour les problèmes de bundler
echo "Correction des dépendances bundler..."

# Vérifier la version de bundler installée
echo "Version de bundler installée:"
bundler --version 2>/dev/null || echo "Bundler non trouvé"

# Installer la version requise de bundler
echo "Installation de bundler 1.17.2..."
gem install bundler:1.17.2 --no-document

# Alternative: mettre à jour bundler vers la dernière version
echo "Mise à jour vers la dernière version de bundler..."
bundle update --bundler 2>/dev/null || echo "Mise à jour échouée, continuons..."

# Réinstaller les gems avec la bonne version
echo "Réinstallation des gems..."
bundle install --retry=3

# Vérifier l'installation
echo "Vérification de l'installation:"
bundle check && echo "Toutes les dépendances sont satisfaites" || echo "Problèmes de dépendances détectés"

echo "Correction terminée. Vous pouvez maintenant relancer le serveur."