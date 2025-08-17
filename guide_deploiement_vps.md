# Guide de Déploiement - Correction des Permissions d'Administrateur

## Problème
Les utilisateurs invités peuvent modifier l'arrière-plan dans le salon "Main" malgré les restrictions.

## Solution
Appliquer les modifications suivantes sur votre VPS :

### 1. Modifier le fichier `chat_room.rb`

**Fichier :** `STORM/Message/models/chat_room.rb`

#### A. Ajouter la constante ADMIN_USERS (ligne 219)
```ruby
ADMIN_USERS = ['DALM1', 'admin', 'administrator'].freeze
```

#### B. Modifier la méthode `can_modify_room_theme?` (lignes 222-234)
```ruby
# Vérifier si l'utilisateur peut modifier le thème du salon
def can_modify_room_theme?(username)
  # Le créateur peut toujours modifier
  return true if @creator == username
  
  # Les administrateurs peuvent toujours modifier, même dans les salons système
  return true if is_admin?(username)
  
  # Dans les salons système (comme "Main"), seuls les admins peuvent modifier
  return false if system_room?
  
  # Dans les autres salons, seul le créateur peut modifier
  false
end
```

#### C. Ajouter la méthode `is_admin?` (lignes 236-238)
```ruby
# Vérifier si l'utilisateur est un administrateur
def is_admin?(username)
  ADMIN_USERS.include?(username)
end
```

### 2. Modifier le fichier `background_command.rb`

**Fichier :** `STORM/Message/commands/Appearance/background_command.rb`

#### Modifier le message d'erreur (lignes 25-28)
```ruby
# Dans les salons système, seuls les admins et créateurs peuvent modifier
if chat_room.system_room?
  driver.text(" ⚠️ Vous ne pouvez pas modifier l'arrière-plan dans ce salon système. Seuls les administrateurs peuvent le faire.")
  return nil
end
```

## Commandes à exécuter sur le VPS

### 1. Se connecter au VPS
```bash
ssh votre_utilisateur@votre_vps_ip
```

### 2. Aller dans le répertoire du projet
```bash
cd /chemin/vers/votre/projet/STORM
```

### 3. Sauvegarder les fichiers actuels
```bash
cp Message/models/chat_room.rb Message/models/chat_room.rb.backup
cp Message/commands/Appearance/background_command.rb Message/commands/Appearance/background_command.rb.backup
```

### 4. Appliquer les modifications
Utilisez `nano` ou `vim` pour éditer les fichiers :

```bash
nano Message/models/chat_room.rb
```

```bash
nano Message/commands/Appearance/background_command.rb
```

### 5. Redémarrer le serveur STORM
```bash
# Arrêter le serveur actuel
pkill -f srv_message
pkill -f ruby

# Redémarrer le serveur
ruby srv_message.rb
```

Ou si vous utilisez Docker :
```bash
docker-compose down
docker-compose up -d
```

## Vérification

### Test 1 : Utilisateur invité
1. Se connecter en tant qu'invité
2. Essayer `/background https://example.com/image.jpg` dans le salon Main
3. **Résultat attendu :** Message d'erreur "Vous ne pouvez pas modifier l'arrière-plan dans ce salon système"

### Test 2 : Administrateur (DALM1)
1. Se connecter en tant que DALM1
2. Essayer `/background https://example.com/image.jpg` dans le salon Main
3. **Résultat attendu :** "Arrière-plan du salon modifié"

### Test 3 : Utilisateur normal
1. Se connecter en tant qu'utilisateur normal
2. Essayer `/background https://example.com/image.jpg` dans le salon Main
3. **Résultat attendu :** Message d'erreur

## Logs à surveiller

Après le redémarrage, surveillez les logs pour vérifier que tout fonctionne :
```bash
tail -f /var/log/storm.log
# ou
journalctl -f -u storm-service
```

## Rollback en cas de problème

Si quelque chose ne fonctionne pas :
```bash
cp Message/models/chat_room.rb.backup Message/models/chat_room.rb
cp Message/commands/Appearance/background_command.rb.backup Message/commands/Appearance/background_command.rb
# Redémarrer le serveur
```

## Notes importantes

- ✅ Seuls les utilisateurs dans `ADMIN_USERS` peuvent modifier l'arrière-plan des salons système
- ✅ Les créateurs de salon peuvent toujours modifier leurs propres salons
- ✅ Les utilisateurs normaux ne peuvent plus modifier l'arrière-plan dans Main/General/users
- ✅ La liste des administrateurs peut être modifiée en éditant la constante `ADMIN_USERS`

## Support

Si vous rencontrez des problèmes :
1. Vérifiez les logs d'erreur
2. Assurez-vous que la syntaxe Ruby est correcte
3. Vérifiez que le serveur a bien redémarré
4. Testez avec différents types d'utilisateurs