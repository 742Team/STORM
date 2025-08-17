# 🔧 Solution pour les Permissions d'Administrateur sur VPS

## 📋 Diagnostic du Problème

Les tests locaux confirment que les modifications de permissions fonctionnent correctement :
- ✅ Constante `ADMIN_USERS` définie avec `['DALM1', 'admin', 'administrator']`
- ✅ Méthode `is_admin?()` fonctionnelle
- ✅ Méthode `can_modify_room_theme?()` fonctionnelle
- ✅ Méthode `system_room?()` fonctionnelle
- ✅ Logique de permissions correcte dans `background_command.rb`

**Le problème : Le serveur VPS n'utilise pas la version mise à jour du code.**

## 🚀 Solution Étape par Étape

### Étape 1: Diagnostic sur le VPS

```bash
# Se connecter au VPS
ssh votre_utilisateur@votre_vps

# Aller dans le répertoire STORM
cd /chemin/vers/votre/projet/STORM

# Copier et exécuter le script de diagnostic
# (copiez le contenu de check_vps_permissions.sh)
./check_vps_permissions.sh
```

### Étape 2: Mise à Jour du Code

```bash
# Sauvegarder la version actuelle
cp Message/models/chat_room.rb Message/models/chat_room.rb.backup
cp Message/commands/Appearance/background_command.rb Message/commands/Appearance/background_command.rb.backup

# Mettre à jour depuis Git
git stash  # Sauvegarder les modifications locales si nécessaire
git pull origin main  # ou votre branche principale

# Vérifier que les modifications sont présentes
grep -n "ADMIN_USERS" Message/models/chat_room.rb
grep -n "def is_admin?" Message/models/chat_room.rb
grep -n "def can_modify_room_theme?" Message/models/chat_room.rb
```

### Étape 3: Modifications Manuelles (si nécessaire)

Si les modifications ne sont pas présentes après le `git pull`, appliquez-les manuellement :

#### A. Modifier `Message/models/chat_room.rb`

```ruby
# Ajouter après la ligne ~194, AVANT le modificateur 'private'

# Liste des administrateurs du système
ADMIN_USERS = ['DALM1', 'admin', 'administrator'].freeze

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

# Vérifier si l'utilisateur est un administrateur
def is_admin?(username)
  ADMIN_USERS.include?(username)
end

# Vérifier si c'est un salon système
def system_room?
  ['Main', 'General', 'users'].include?(@name)
end
```

#### B. Modifier `Message/commands/Appearance/background_command.rb`

```ruby
# Remplacer le message d'erreur vers la ligne 26
if chat_room.system_room?
  driver.text(" ⚠️ Vous ne pouvez pas modifier l'arrière-plan dans ce salon système. Seuls les administrateurs peuvent le faire.")
  return nil
end
```

### Étape 4: Redémarrage du Serveur

```bash
# Arrêter le serveur STORM
pkill -f storm  # ou votre méthode habituelle

# Ou si vous utilisez un script spécifique
./stop_hermes  # si disponible

# Attendre quelques secondes
sleep 3

# Redémarrer le serveur
./start_hermes

# Vérifier que le processus est actif
ps aux | grep -i storm
```

### Étape 5: Test des Permissions

#### Test 1: Utilisateur Normal dans Salon Main
```
1. Se connecter avec un utilisateur normal (pas DALM1/admin/administrator)
2. Aller dans le salon "Main"
3. Essayer la commande: /bg https://example.com/image.jpg
4. Résultat attendu: "⚠️ Vous ne pouvez pas modifier l'arrière-plan dans ce salon système. Seuls les administrateurs peuvent le faire."
```

#### Test 2: Administrateur dans Salon Main
```
1. Se connecter avec DALM1, admin, ou administrator
2. Aller dans le salon "Main"
3. Essayer la commande: /bg https://example.com/image.jpg
4. Résultat attendu: "⚪️ Arrière-plan du salon modifié"
```

#### Test 3: Utilisateur Normal dans Salon Privé
```
1. Créer un salon privé avec un utilisateur normal
2. Essayer la commande: /bg https://example.com/image.jpg
3. Résultat attendu: "⚪️ Arrière-plan du salon modifié" (car créateur)
```

## 🔍 Dépannage

### Problème: Les modifications ne sont pas visibles après git pull

**Solution:**
```bash
# Vérifier la branche actuelle
git branch

# Vérifier les commits récents
git log --oneline -5

# Forcer la mise à jour
git reset --hard origin/main
```

### Problème: Le serveur ne redémarre pas

**Solution:**
```bash
# Trouver tous les processus STORM
ps aux | grep storm

# Tuer tous les processus (remplacer PID par les vrais numéros)
kill -9 PID1 PID2 PID3

# Redémarrer
./start_hermes
```

### Problème: Erreurs de syntaxe Ruby

**Solution:**
```bash
# Vérifier la syntaxe
ruby -c Message/models/chat_room.rb
ruby -c Message/commands/Appearance/background_command.rb

# Si erreur, restaurer la sauvegarde et recommencer
cp Message/models/chat_room.rb.backup Message/models/chat_room.rb
```

## 📊 Vérification Finale

Après avoir appliqué toutes les modifications :

1. ✅ Le serveur STORM redémarre sans erreur
2. ✅ Les utilisateurs normaux ne peuvent pas modifier les thèmes dans Main/General/users
3. ✅ DALM1, admin, administrator peuvent modifier les thèmes partout
4. ✅ Les créateurs de salons peuvent modifier leurs propres salons
5. ✅ Les messages d'erreur sont appropriés

## 🎯 Points Clés

- **IMPORTANT**: Les méthodes `is_admin?`, `can_modify_room_theme?`, et `system_room?` doivent être **publiques** (avant le modificateur `private`)
- La constante `ADMIN_USERS` doit être définie au niveau de la classe
- Le serveur doit être complètement redémarré pour prendre en compte les modifications
- Testez avec différents types d'utilisateurs pour confirmer le bon fonctionnement

---

*Si le problème persiste après avoir suivi toutes ces étapes, vérifiez que vous modifiez bien les bons fichiers et que le serveur utilise le bon répertoire de code.*