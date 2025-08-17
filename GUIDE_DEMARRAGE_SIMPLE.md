# 🚀 Guide de Démarrage Simplifié - STORM Backend

## Scripts de Démarrage Disponibles

### 1. `./start_simple.sh` ⭐ **RECOMMANDÉ**
**Script de démarrage automatique avec sauvegarde**

```bash
./start_simple.sh
```

**Ce que fait ce script :**
- ✅ Sauvegarde automatique de toutes les BDD existantes
- ✅ Arrêt propre des processus existants
- ✅ Démarrage avec configuration de persistance si disponible
- ✅ Fallback vers Docker si nécessaire
- ✅ Aucune interaction utilisateur requise

### 2. `./start_hermes.sh`
**Script original avec sauvegarde ajoutée**

```bash
./start_hermes.sh
```

**Ce que fait ce script :**
- ✅ Sauvegarde automatique des BDD existantes
- ✅ Pull du code depuis Git
- ❓ Demande si vous voulez utiliser la persistance
- 📦 Utilise Docker par défaut

### 3. `ruby start_with_persistence.rb`
**Démarrage direct avec persistance**

```bash
ruby start_with_persistence.rb
```

**Ce que fait ce script :**
- ✅ Démarrage direct avec Puma
- ✅ Configuration de persistance complète
- ⚠️ Pas de sauvegarde automatique

## 🗄️ Sauvegarde Automatique des Bases de Données

Tous les scripts de démarrage sauvegardent automatiquement :
- `chat_app.db`
- `storm.db` 
- `chat.db`
- `users.db`
- `storm_persistent.db`
- Fichiers WAL et SHM associés

**Emplacement des sauvegardes :**
```
data/backups/YYYYMMDD_HHMMSS/
├── backup_info.txt
├── chat_app.db
├── storm_persistent.db
└── ...
```

## 🔄 Workflow Recommandé après Pull VPS

1. **Pull du code depuis le VPS**
   ```bash
   git pull origin main
   ```

2. **Démarrage automatique avec sauvegarde**
   ```bash
   ./start_simple.sh
   ```

3. **Vérification**
   - Serveur accessible sur `http://localhost:3631`
   - BDD sauvegardées dans `data/backups/`
   - Nouvelle BDD persistante créée si nécessaire

## 📊 Vérification de la Persistance

```bash
# Tester la persistance
ruby test_persistence.rb

# Voir les statistiques
ruby test_persistence.rb stats

# Nettoyer les données de test
ruby test_persistence.rb cleanup
```

## 🛠️ Dépannage

### Problème : "Permission denied"
```bash
chmod +x start_simple.sh
chmod +x start_hermes.sh
```

### Problème : "Port already in use"
```bash
# Arrêter tous les processus
pkill -f "ruby"
pkill -f "puma"
docker rm -f hermes_container
```

### Problème : "Database locked"
```bash
# Vérifier les processus utilisant la BDD
lsof data/storm_persistent.db
```

### Problèmes de Bundler (VPS)
Si vous rencontrez l'erreur `Could not find 'bundler' (1.17.2)` :

#### Solution rapide
```bash
# Exécuter le script de correction automatique
./fix_vps_bundler.sh
```

#### Solution manuelle
```bash
# Installer la version spécifique de bundler
gem install bundler:1.17.2

# Ou mettre à jour vers la dernière version
bundle update --bundler

# Réinstaller les gems
bundle install --retry=3
```

#### Reset complet (si nécessaire)
```bash
# Supprimer les fichiers de cache
rm -rf .bundle/
rm -f Gemfile.lock

# Réinstaller bundler et les gems
gem install bundler:1.17.2
bundle install
```

### Vérification du statut
```bash
# Vérifier les processus Ruby en cours
ps aux | grep ruby

# Vérifier les ports utilisés
lsof -i :3631

# Vérifier bundler
bundle --version
bundle check
```

## 📝 Notes Importantes

- **Sauvegarde automatique** : Toujours effectuée avant le démarrage
- **Persistance** : Données conservées entre les redémarrages
- **Performance** : Configuration SQLite optimisée (WAL mode)
- **Sécurité** : Pool de connexions avec gestion des erreurs

## 🎯 Utilisation Recommandée

Pour un usage quotidien après pull VPS :
```bash
./start_simple.sh
```

C'est tout ! Le script s'occupe de tout automatiquement.