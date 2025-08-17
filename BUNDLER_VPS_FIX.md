# Correction des Problèmes Bundler sur VPS

## Problème Identifié

Erreurs rencontrées :

**Erreur Bundler :**
```
Could not find 'bundler' (1.17.2) required by your /root/STORM/Gemfile.lock. (Gem::GemNotFoundException)
To update to the latest version installed on your system, run `bundle update --bundler`.
To install the missing version, run `gem install bundler:1.17.2`
```

**Erreur taglib-ruby (Nouvelle) :**
```
ERROR: Failed to build gem native extension.
checking for -ltag... no
You must have taglib installed in order to use taglib-ruby.

Debian/Ubuntu: sudo apt-get install libtag1-dev
Fedora/RHEL: sudo dnf install taglib-devel
Brew: brew install taglib
MacPorts: sudo port install taglib
```

## Solutions Rapides

### Option 1 : Démarrage d'Urgence (Nouveau - Recommandé)
```bash
# Contourne tous les problèmes de dépendances
./start_emergency.sh
```

### Option 2 : Correction des Dépendances Système
```bash
# Installer les dépendances système manquantes (nécessite sudo)
sudo ./fix_vps_dependencies.sh
```

### Option 3 : Script Bundler Automatique
```bash
# Exécuter le script de correction bundler
./fix_vps_bundler.sh
```

### Option 4 : Commandes Manuelles
```bash
# Installer la version spécifique
gem install bundler:1.17.2

# Puis relancer le serveur
ruby start_with_persistence.rb
```

### Option 5 : Mise à Jour Bundler
```bash
# Mettre à jour vers la dernière version
bundle update --bundler

# Réinstaller les gems
bundle install
```

## Diagnostic

### Vérifier l'état actuel
```bash
# Version de Ruby
ruby --version

# Version de Gem
gem --version

# Versions de Bundler installées
gem list bundler

# Version requise dans Gemfile.lock
grep -A 1 "BUNDLED WITH" Gemfile.lock
```

## Solutions Avancées

### Reset Complet
Si les solutions précédentes ne fonctionnent pas :

```bash
# 1. Supprimer toutes les versions de bundler
gem uninstall bundler --all --force

# 2. Supprimer les fichiers de cache
rm -rf .bundle/
rm -f Gemfile.lock

# 3. Installer bundler 1.17.2
gem install bundler:1.17.2 --no-document

# 4. Réinstaller les gems
bundle install --retry=3

# 5. Vérifier
bundle check
```

### Installation Alternative des Gems
Si bundler continue à poser problème :

```bash
# Installer les gems critiques manuellement
gem install sqlite3 sinatra bcrypt colorize websocket-driver webrick rack mini_magick --no-document

# Puis démarrer directement
ruby start_with_persistence.rb
```

## Scripts Disponibles

- `./fix_vps_bundler.sh` : Correction automatique complète
- `./fix_bundler.sh` : Correction générale
- `./start_simple.sh` : Démarrage avec correction automatique
- `./start_hermes.sh` : Démarrage Docker avec correction

## Vérification du Succès

Après correction, vous devriez voir :
```
[PERSISTENCE] Démarrage du serveur STORM avec persistance...
[PERSISTENCE] Base de données: /root/STORM/data/storm_persistent.db
[PERSISTENCE] Mode WAL activé pour la concurrence
[PERSISTENCE] Sauvegarde automatique des données

* Listening on http://0.0.0.0:3631
```

## Support

Si le problème persiste :
1. Vérifiez les permissions du système
2. Assurez-vous que Ruby et Gem sont à jour
3. Contactez l'administrateur système si nécessaire

---

**Note** : Ces scripts de correction sont maintenant intégrés automatiquement dans `start_simple.sh` et `start_hermes.sh` pour éviter ce problème à l'avenir.