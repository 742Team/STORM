# Documentation d'intégration - Système de notifications STORM

## Vue d'ensemble

STORM est une plateforme de chat en temps réel avec un système de notifications avancé. Cette documentation couvre tous les aspects de l'intégration, les endpoints API, et les fonctionnalités WebSocket.

## Architecture du système

### Serveurs
- **Serveur de messages** : Port 4567 (WebSocket + HTTP)
- **Serveur d'upload** : Port 4568 (HTTP REST API)
- **Base de données** : SQLite avec pool de connexions

### Structure des fichiers


## API REST - Serveur d'upload (Port 4568)

### Authentification

#### POST /register
Inscription d'un nouvel utilisateur

**Paramètres :**
```json
{
  "username": "string",
  "email": "string",
  "password": "string"
}
```

**Réponse succès (201) :**
```json
{
  "status": "success",
  "message": "Utilisateur créé avec succès",
  "user_id": "integer"
}
```

**Réponse erreur (400) :**
```json
{
  "status": "error",
  "message": "Nom d'utilisateur déjà pris"
}
```

#### POST /login
Connexion utilisateur

**Paramètres :**
```json
{
  "username": "string",
  "password": "string"
}
```

**Réponse succès (200) :**
```json
{
  "status": "success",
  "message": "Connexion réussie",
  "token": "string",
  "user_id": "integer"
}
```

### Gestion des salons

#### GET /rooms
Liste des salons publics

**Réponse (200) :**
```json
{
  "rooms": [
    {
      "name": "string",
      "users_count": "integer",
      "created_at": "timestamp"
    }
  ]
}
```

#### POST /rooms
Création d'un salon

**Paramètres :**
```json
{
  "name": "string",
  "password": "string (optionnel)",
  "is_public": "boolean"
}
```

### Upload de fichiers

#### POST /upload
Upload d'un fichier

**Headers :**
- Content-Type: multipart/form-data
- Authorization: Bearer {token}

**Paramètres :**
- file: Fichier binaire
- room: Nom du salon (optionnel)

**Réponse succès (200) :**
```json
{
  "status": "success",
  "file_url": "string",
  "file_id": "string",
  "metadata": {
    "size": "integer",
    "type": "string",
    "name": "string"
  }
}
```

## WebSocket - Serveur de messages (Port 4567)

### Connexion WebSocket

**URL :** `ws://localhost:4567`

### Messages d'authentification

#### Authentification
```json
{
  "type": "auth",
  "username": "string",
  "password": "string"
}
```

**Réponse succès :**
```json
{
  "type": "auth_success",
  "message": "Authentification réussie",
  "user_id": "integer"
}
```

**Réponse erreur :**
```json
{
  "type": "auth_error",
  "message": "Identifiants incorrects"
}
```

### Messages de chat

#### Envoi de message
```json
{
  "type": "message",
  "content": "string",
  "room": "string (optionnel)"
}
```

#### Réception de message
```json
{
  "type": "message",
  "username": "string",
  "content": "string",
  "timestamp": "integer",
  "room": "string",
  "color": "string"
}
```

### Système de notifications

#### Réception de notification
```json
{
  "type": "notification",
  "user_id": "string",
  "notification": {
    "id": "string",
    "type": "room_invite|mention|system|message",
    "data": {
      "from_user": "string",
      "room_name": "string",
      "message": "string"
    },
    "timestamp": "integer",
    "read": "boolean"
  }
}
```

## Commandes de chat

### Commandes de notification

#### /notify
Envoyer une invitation de salon

**Syntaxe :** `/notify <utilisateur> <salon> [message]`

**Exemple :** `/notify alice general Rejoins-nous pour discuter`

**Aliases :** `/invite`, `/inviter`

#### /notifications
Gérer les notifications

**Syntaxes :**
- `/notifications` ou `/notifications list` : Lister les notifications
- `/notifications count` : Compter les notifications
- `/notifications clear` : Supprimer toutes les notifications
- `/notifications read [id]` : Marquer comme lu

**Aliases :** `/notifs`, `/notif`

### Commandes de salon

#### /create
Créer un salon

**Syntaxe :** `/create <nom> [mot_de_passe]`

#### /join
Rejoindre un salon

**Syntaxe :** `/join <nom> [mot_de_passe]`

#### /leave
Quitter le salon actuel

**Syntaxe :** `/leave`

#### /list
Lister les salons disponibles

**Syntaxe :** `/list`

### Commandes utilisateur

#### /users
Lister les utilisateurs connectés

**Syntaxe :** `/users`

#### /whisper
Message privé

**Syntaxe :** `/whisper <utilisateur> <message>`

#### /kick
Expulser un utilisateur (modérateurs)

**Syntaxe :** `/kick <utilisateur>`

#### /ban
Bannir un utilisateur (modérateurs)

**Syntaxe :** `/ban <utilisateur>`

## Types de notifications

### room_invite
Invitation à rejoindre un salon

**Structure :**
```json
{
  "type": "room_invite",
  "data": {
    "from_user": "string",
    "room_name": "string",
    "message": "string"
  }
}
```

### mention
Mention dans un message (@utilisateur)

**Structure :**
```json
{
  "type": "mention",
  "data": {
    "from_user": "string",
    "room_name": "string",
    "message": "string"
  }
}
```

### system
Notification système

**Structure :**
```json
{
  "type": "system",
  "data": {
    "message": "string"
  }
}
```

## Intégration côté client

### Connexion WebSocket JavaScript

```javascript
const ws = new WebSocket('ws://localhost:4567');

ws.onopen = function() {
    // Authentification
    ws.send(JSON.stringify({
        type: 'auth',
        username: 'votre_username',
        password: 'votre_password'
    }));
};

ws.onmessage = function(event) {
    const data = JSON.parse(event.data);
    
    switch(data.type) {
        case 'notification':
            handleNotification(data.notification);
            break;
        case 'message':
            displayMessage(data);
            break;
        case 'auth_success':
            console.log('Connecté avec succès');
            break;
    }
};

function handleNotification(notification) {
    // Afficher la notification
    if (notification.type === 'room_invite') {
        showRoomInvite(notification.data);
    } else if (notification.type === 'mention') {
        showMention(notification.data);
    }
    
    // Notification navigateur
    if (Notification.permission === 'granted') {
        new Notification('STORM', {
            body: notification.data.message,
            icon: '/icon.png'
        });
    }
}
```

### Requêtes HTTP JavaScript

```javascript
// Inscription
async function register(username, email, password) {
    const response = await fetch('http://localhost:4568/register', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ username, email, password })
    });
    return await response.json();
}

// Upload de fichier
async function uploadFile(file, token) {
    const formData = new FormData();
    formData.append('file', file);
    
    const response = await fetch('http://localhost:4568/upload', {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${token}`
        },
        body: formData
    });
    return await response.json();
}
```

## Configuration et déploiement

### Prérequis
- Ruby 2.7+
- Gems : sinatra, websocket, sqlite3, bcrypt, json

### Installation

```bash
# Installer les dépendances
bundle install

# Créer la base de données
ruby -e "require './config/database_pool.rb'; DatabasePool.instance.setup_database"
```

### Lancement des serveurs

```bash
# Terminal 1 : Serveur de messages
ruby srv_message.rb

# Terminal 2 : Serveur d'upload
ruby srv_upload.rb

# Ou utiliser le script de démarrage
./start_hermes.sh
```

### Variables d'environnement

```bash
# Port du serveur de messages (défaut: 4567)
export MESSAGE_PORT=4567

# Port du serveur d'upload (défaut: 4568)
export UPLOAD_PORT=4568

# Chemin de la base de données
export DATABASE_PATH=./storm.db

# Répertoire d'upload
export UPLOAD_DIR=./uploads
```

## Sécurité

### Authentification
- Mots de passe hachés avec BCrypt
- Tokens JWT pour l'API REST
- Sessions WebSocket sécurisées

### Validation des données
- Sanitisation des entrées utilisateur
- Validation des types de fichiers
- Limitation de la taille des uploads
- Protection contre l'injection SQL

### Limitations
- 50 notifications maximum par utilisateur
- Taille maximale des fichiers : 10MB
- Longueur maximale des messages : 1000 caractères

## Codes d'erreur

### HTTP
- 200 : Succès
- 201 : Créé avec succès
- 400 : Requête invalide
- 401 : Non autorisé
- 403 : Interdit
- 404 : Non trouvé
- 500 : Erreur serveur

### WebSocket
- auth_error : Erreur d'authentification
- command_error : Commande invalide
- permission_error : Permissions insuffisantes
- room_error : Erreur de salon

## Monitoring et logs

### Logs serveur
- Connexions/déconnexions
- Commandes exécutées
- Erreurs système
- Uploads de fichiers

### Métriques
- Nombre d'utilisateurs connectés
- Messages par seconde
- Notifications envoyées
- Utilisation de la bande passante

## Support et maintenance

### Sauvegarde
- Base de données SQLite : `storm.db`
- Fichiers uploadés : répertoire `uploads/`
- Notifications : `data/notifications.json`

### Mise à jour
1. Arrêter les serveurs
2. Sauvegarder les données
3. Mettre à jour le code
4. Migrer la base si nécessaire
5. Redémarrer les serveurs

### Dépannage

**Problème : WebSocket ne se connecte pas**
- Vérifier que le serveur est démarré sur le bon port
- Contrôler les logs pour les erreurs
- Tester avec telnet : `telnet localhost 4567`

**Problème : Notifications non reçues**
- Vérifier la connexion WebSocket
- Contrôler les permissions de notification du navigateur
- Vérifier les logs du NotificationManager

**Problème : Upload échoue**
- Vérifier les permissions du répertoire uploads/
- Contrôler la taille du fichier
- Vérifier le token d'authentification

Cette documentation couvre tous les aspects nécessaires pour intégrer et utiliser le système de notifications STORM.