# Guide de Démarrage d'Urgence VPS

## Situation d'Urgence Identifiée

Votre VPS rencontre des problèmes de dépendances lors du déploiement :
- Erreur bundler (version 1.17.2 non trouvée)
- Erreur taglib-ruby (dépendances système manquantes)
- Échec de compilation des extensions natives

## Solution Immédiate (30 secondes)

### Étape 1 : Démarrage d'Urgence
```bash
# Contourne TOUS les problèmes de dépendances
./start_emergency.sh
```

**Ce script fait automatiquement :**
- Sauvegarde les bases de données existantes
- Arrête les processus conflictuels
- Utilise un Gemfile minimal (sans taglib-ruby)
- Installe seulement les gems essentielles
- Démarre le serveur avec persistance

### Étape 2 : Vérification
Le serveur devrait démarrer sur `http://votre-vps:3631`

## Solution Complète (5 minutes)

Si vous voulez résoudre définitivement le problème :

### Étape 1 : Installer les Dépendances Système
```bash
# Nécessite les droits sudo
sudo ./fix_vps_dependencies.sh
```

### Étape 2 : Redémarrer Normalement
```bash
./start_simple.sh
```

## Scripts Disponibles par Ordre de Priorité

1. **`./start_emergency.sh`**
   - **Usage :** Situations d'urgence
   - **Avantages :** Fonctionne toujours, rapide
   - **Inconvénients :** Fonctionnalités audio limitées

2. **`sudo ./fix_vps_dependencies.sh`**
   - **Usage :** Correction complète des dépendances
   - **Avantages :** Résout tous les problèmes
   - **Inconvénients :** Nécessite sudo

3. **`./fix_vps_bundler.sh`**
   - **Usage :** Problèmes bundler uniquement
   - **Avantages :** Rapide pour bundler
   - **Inconvénients :** Ne résout pas taglib-ruby

4. **`./start_simple.sh`**
   - **Usage :** Démarrage normal après corrections
   - **Avantages :** Démarrage complet avec toutes les fonctionnalités
   - **Inconvénients :** Nécessite dépendances installées

## Workflow Recommandé

### Pour un Démarrage Immédiat
```bash
# 1. Démarrage d'urgence (toujours fonctionnel)
./start_emergency.sh

# 2. Vérifier que le serveur fonctionne
curl http://localhost:3631
```

### Pour une Solution Permanente
```bash
# 1. Arrêter le serveur d'urgence (Ctrl+C)

# 2. Installer les dépendances système
sudo ./fix_vps_dependencies.sh

# 3. Redémarrer normalement
./start_simple.sh
```

## Diagnostic Rapide

### Vérifier l'État du Serveur
```bash
# Processus en cours
ps aux | grep ruby

# Port utilisé
lsof -i :3631

# Logs du serveur
tail -f log/storm.log
```

### Vérifier les Dépendances
```bash
# Bundler
bundle --version

# Gems installées
gem list | grep -E "(sqlite3|sinatra|bcrypt)"

# Dépendances système
dpkg -l | grep -E "(libtag1-dev|build-essential|ruby-dev)"
```

## Notes Importantes

- **Le script d'urgence utilise un Gemfile minimal** qui exclut taglib-ruby
- **Les fonctionnalités audio peuvent être limitées** sans taglib-ruby
- **Toutes les autres fonctionnalités STORM restent disponibles**
- **Les sauvegardes sont automatiques** avant chaque démarrage

## En Cas d'Échec Total

Si même le script d'urgence échoue :

```bash
# Installation manuelle des gems critiques
gem install sqlite3 sinatra bcrypt colorize webrick --no-document

# Démarrage direct
ruby start_with_persistence.rb
```

---

**Résultat Attendu :** Serveur STORM opérationnel en moins de 2 minutes, même avec des dépendances système manquantes.