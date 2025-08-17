# Configuration de Persistance des Données STORM

## Vue d'ensemble

Le serveur STORM a été configuré avec un système de persistance des données robuste qui garantit la conservation des messages, comptes utilisateurs et préférences lors des redémarrages du serveur.

## Structure de la Base de Données

### 📍 Emplacement
- **Base de données principale**: `data/storm_persistent.db`
- **Fichiers WAL**: `data/storm_persistent.db-wal` et `data/storm_persistent.db-shm`
- **Sauvegardes**: `data/backups/`

### Tables Créées

1. **users** - Comptes utilisateurs
   - `id`, `username`, `email`, `password_hash`
   - `created_at`, `updated_at`, `last_seen`
   - `status`, `avatar_url`

2. **messages** - Messages du chat
   - `id`, `user_id`, `room_id`, `content`
   - `message_type`, `created_at`, `updated_at`
   - `is_deleted`

3. **rooms** - Salles de discussion
   - `id`, `name`, `description`, `created_by`
   - `created_at`, `is_private`

4. **user_preferences** - Préférences utilisateur
   - `id`, `user_id`, `preference_key`, `preference_value`
   - `created_at`, `updated_at`

5. **user_sessions** - Sessions utilisateur
   - `id`, `user_id`, `session_token`, `expires_at`
   - `created_at`, `last_activity`, `ip_address`, `user_agent`

## Démarrage du Serveur

### Option 1: Démarrage avec Persistance (Recommandé)
```bash
ruby start_with_persistence.rb
```

### Option 2: Démarrage Standard
```bash
bundle exec puma -p 3631 -e development
```

## Configuration Technique

### Optimisations SQLite
- **Mode WAL** (Write-Ahead Logging) pour la concurrence
- **Cache de 10 000 pages** pour les performances
- **MMAP de 256MB** pour l'accès mémoire rapide
- **Synchronisation NORMAL** pour l'équilibre performance/sécurité

### Pool de Connexions
- **25 connexions** dans le pool de performance
- **10 connexions** dans le pool standard
- **Timeout de 5 secondes** pour éviter les blocages

## Migration des Données

### Migration Automatique
Lors du premier démarrage avec persistance, le système migre automatiquement les données des anciennes bases :
- `chat_app.db`
- `storm.db`
- `chat.db`
- `users.db`

### Migration Manuelle
```bash
ruby scripts/migrate_database.rb
```

## Sécurité et Sauvegarde

### Sauvegardes Automatiques
- Les anciennes bases sont sauvegardées dans `data/backups/`
- Format: `{nom}_backup_{timestamp}.db`

### Vérification d'Intégrité
- Vérification automatique au démarrage
- Réparation automatique en cas de corruption
- Sauvegarde avant réparation

## Monitoring

### Statistiques Affichées au Démarrage
- Nombre d'utilisateurs
- Nombre de messages
- Nombre de salles
- Nombre de préférences
- Taille de la base de données

### Logs de Persistance
```
[PERSISTENCE] Vérification de la persistance des données...
[PERSISTENCE] Base de données existante trouvée
[PERSISTENCE] Intégrité de la base de données vérifiée
[PERSISTENCE] Statistiques de la base de données:
   - users: X enregistrements
   - messages: X enregistrements
   - rooms: X enregistrements
   - user_preferences: X enregistrements
   - Taille: X.XX MB
[PERSISTENCE] Persistance des données garantie!
```

## Redémarrage du Serveur

### Arrêt Propre
- `Ctrl+C` ou `SIGINT` pour un arrêt propre
- Les données sont automatiquement sauvegardées
- Aucune perte de données

### Redémarrage
1. Arrêter le serveur (`Ctrl+C`)
2. Relancer avec `ruby start_with_persistence.rb`
3. Toutes les données sont conservées

## 🚨 Dépannage

### Base de Données Corrompue
```bash
# Le système crée automatiquement une sauvegarde et répare
⚠️ [PERSISTENCE] Problème d'intégrité détecté, réparation...
[PERSISTENCE] Sauvegarde créée: data/storm_persistent.db.backup.1234567890
[PERSISTENCE] Base de données réparée
```

### Restauration Manuelle
```bash
# Restaurer depuis une sauvegarde
cp data/backups/storm_persistent_backup_YYYYMMDD_HHMMSS.db data/storm_persistent.db
```

### Réinitialisation Complète
```bash
# Supprimer la base actuelle (ATTENTION: perte de données)
rm -rf data/
# Redémarrer le serveur pour recréer
ruby start_with_persistence.rb
```

## 📝 Notes Importantes

1. **Persistance Garantie**: Les données survivent aux redémarrages
2. **Performance Optimisée**: Mode WAL pour la concurrence
3. **Sécurité**: Sauvegardes automatiques et vérification d'intégrité
4. **Migration**: Transfert automatique des anciennes données
5. **Monitoring**: Statistiques détaillées au démarrage

## Capacité

- **1 million de connexions simultanées** (théorique)
- **500 000 connexions stables** avec 10 workers
- **Auto-scaling** jusqu'à la limite maximale
- **Base de données haute performance** avec optimisations SQLite