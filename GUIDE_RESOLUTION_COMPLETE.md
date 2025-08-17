# 🚀 Guide de Résolution Complète - Problème de Permissions VPS

## 📋 Situation Actuelle

Le problème persiste sur le VPS même après :
- ✅ Push sur GitHub
- ✅ Pull sur le VPS
- ✅ Relancement du container

## 🔍 Diagnostic Complet

### 1. Vérification Backend (VPS)

#### A. Connexion au VPS et navigation
```bash
cd /path/to/your/STORM/directory
```

#### B. Vérification Git
```bash
# Vérifier la branche actuelle
git branch

# Vérifier les derniers commits
git log --oneline -5

# Vérifier l'état du repository
git status

# Forcer la mise à jour si nécessaire
git fetch origin
git reset --hard origin/1.6.7
```

#### C. Diagnostic automatique
```bash
# Exécuter le script de diagnostic
bash check_vps_permissions.sh

# Si des problèmes sont détectés, utiliser le script de correction
bash fix_vps_permissions.sh
```

#### D. Vérification manuelle des fichiers critiques
```bash
# Vérifier chat_room.rb
grep -A 10 -B 2 "ADMIN_USERS" Message/models/chat_room.rb
grep -A 5 "def is_admin?" Message/models/chat_room.rb
grep -A 5 "def can_modify_room_theme?" Message/models/chat_room.rb

# Vérifier background_command.rb
grep -A 10 -B 2 "can_modify_room_theme" Message/commands/Appearance/background_command.rb
```

### 2. Vérification Frontend

#### A. Test dans le navigateur
1. Ouvrez la console du navigateur (F12)
2. Copiez et collez le contenu du fichier `debug_frontend_auth.js`
3. Analysez les résultats

#### B. Tests manuels
1. **Test d'authentification** :
   - Connectez-vous avec `DALM1`
   - Vérifiez que le nom d'utilisateur s'affiche correctement

2. **Test de la commande** :
   - Tapez `/background https://example.com/test.jpg`
   - Observez la réponse du serveur

### 3. Redémarrage Complet du Système

#### A. Arrêt des processus
```bash
# Tuer tous les processus Ruby/STORM
pkill -f srv_message.rb
pkill -f ruby.*srv_message

# Vérifier qu'aucun processus ne reste
ps aux | grep ruby
ps aux | grep srv_message
```

#### B. Redémarrage
```bash
# Attendre quelques secondes
sleep 5

# Redémarrer le serveur
./start_hermes.sh
# OU
ruby srv_message.rb &

# Vérifier que le processus démarre
ps aux | grep srv_message
```

#### C. Si vous utilisez Docker
```bash
# Redémarrer le container
docker restart nom_du_container

# Ou reconstruire complètement
docker stop nom_du_container
docker rm nom_du_container
docker build -t storm-app .
docker run -d --name nom_du_container -p 8080:8080 storm-app
```

## 🛠️ Solutions par Ordre de Priorité

### Solution 1: Correction Automatique (Recommandée)
```bash
# Sur le VPS
cd /path/to/your/STORM/directory
git pull origin 1.6.7
bash fix_vps_permissions.sh
pkill -f srv_message.rb
sleep 3
ruby srv_message.rb &
```

### Solution 2: Correction Manuelle

#### A. Modifier chat_room.rb
```ruby
# Dans Message/models/chat_room.rb
# Ajouter après la ligne de classe :
ADMIN_USERS = ['DALM1', 'admin', 'administrator'].freeze

# S'assurer que ces méthodes sont publiques :
def is_admin?(username)
  ADMIN_USERS.include?(username)
end

def can_modify_room_theme?(username)
  return true if is_admin?(username)
  return false if system_room?
  true
end

def system_room?
  ['Main', 'General', 'users'].include?(@name)
end
```

#### B. Vérifier background_command.rb
```ruby
# Dans Message/commands/Appearance/background_command.rb
# S'assurer que cette logique est présente :
if chat_room.can_modify_room_theme?(username)
  # Modification du thème du salon
else
  return "❌ Seuls les administrateurs peuvent modifier l'arrière-plan des salons système."
end
```

### Solution 3: Redémarrage Complet du Serveur
```bash
# Si rien ne fonctionne, redémarrer le serveur VPS
sudo reboot
```

## 🧪 Tests de Validation

### Test 1: Utilisateur Administrateur
1. Connectez-vous avec `DALM1`
2. Tapez `/background https://example.com/admin-test.jpg`
3. **Résultat attendu** : ✅ Arrière-plan modifié pour tout le salon

### Test 2: Utilisateur Normal - Salon Normal
1. Connectez-vous avec un nom d'utilisateur normal
2. Créez ou rejoignez un salon non-système
3. Tapez `/background https://example.com/user-test.jpg`
4. **Résultat attendu** : ✅ Arrière-plan modifié pour tout le salon

### Test 3: Utilisateur Normal - Salon Système
1. Connectez-vous avec un nom d'utilisateur normal
2. Allez dans le salon "Main", "General" ou "users"
3. Tapez `/background https://example.com/user-test.jpg`
4. **Résultat attendu** : ❌ Message d'erreur administrateur

## 🔧 Dépannage Avancé

### Si le problème persiste :

1. **Vérifier les logs du serveur** :
```bash
tail -f /var/log/storm.log  # ou votre fichier de log
```

2. **Tester la syntaxe Ruby** :
```bash
ruby -c Message/models/chat_room.rb
ruby -c Message/commands/Appearance/background_command.rb
```

3. **Vérifier les permissions de fichiers** :
```bash
ls -la Message/models/chat_room.rb
ls -la Message/commands/Appearance/background_command.rb
chmod 644 Message/models/chat_room.rb
chmod 644 Message/commands/Appearance/background_command.rb
```

4. **Test d'intégration complet** :
```bash
ruby test_admin_permissions.rb
```

## 📞 Support

Si aucune de ces solutions ne fonctionne :

1. **Collectez les informations suivantes** :
   - Sortie de `git log --oneline -5`
   - Sortie de `bash check_vps_permissions.sh`
   - Logs du serveur
   - Résultats du diagnostic frontend

2. **Vérifiez l'environnement** :
   - Version de Ruby : `ruby --version`
   - Processus en cours : `ps aux | grep ruby`
   - Espace disque : `df -h`

## ✅ Checklist de Résolution

- [ ] Git pull effectué sur le VPS
- [ ] Script de correction exécuté
- [ ] Serveur redémarré
- [ ] Tests de validation réussis
- [ ] Frontend vérifié
- [ ] Logs vérifiés
- [ ] Problème résolu ✅

---

**Note** : Ce guide couvre tous les aspects possibles du problème. Suivez les étapes dans l'ordre pour une résolution efficace.