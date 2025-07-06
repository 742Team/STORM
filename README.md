<h1 align="center">
  <img src="https://github.com/user-attachments/assets/815bd523-668d-4025-abb1-f5903e4fa1b4" alt="STORM MICRO" width="800">
  <br>
  STORM MICRO
  <br>
</h1>

<p align="center">
  <a href="#key-features">✨ Key Features</a> •
  <a href="#installation">🚀 Installation</a> •
  <a href="#how-to-use">📘 How To Use</a> •
  <a href="#commands">⌨️ Commands</a> •
  <a href="#architecture">🏗️ Architecture</a> •
  <a href="#license">📝 License</a>
</p>

<p align="center">
  A modern, feature-rich chat application with real-time messaging, file sharing, and customizable interfaces.
</p>

## 🛠️ Technologies Used
<p align="center"> <img src="https://skillicons.dev/icons?i=ruby,sqlite,docker" /> </p>

## ✨ Key Features

* **Multi-threaded Chat System** - Create and join different chat threads
* **Real-time Messaging** - WebSocket-based communication for instant messaging
* **File Sharing** - Upload and share files, images, and media
* **User Authentication** - Register and login to save your preferences
* **Customizable Interface** - Change colors, backgrounds, and fonts
* **Media Support** - Embedded players for audio and video content
* **Private Messaging** - Direct message other users
* **Role Management** - Thread creators have moderation capabilities

## 🚀 Installation

### Using Docker (Recommended)

The easiest way to run STORM is using Docker:

```bash
# Clone this repository
git clone https://github.com/742Team/STORM.git

# Go into the repository
cd STORM

# Run the start script
./start_hermes.sh
```

### Manual Installation

```bash

# Clone this repository
git clone https://github.com/742Team/STORM.git

# Go into the repository
cd STORM

# Install dependencies
bundle install

# Run the servers
ruby srv_message.rb & ruby srv_upload.rb
```

## 📘 How to Use
1. Start the servers using one of the installation methods above
2. Connect to the WebSocket server at ws://localhost:3630
3. Enter a username when prompted
4. Use /help to see available commands
5. Create a new thread with /cr thread_name password
6. Start chatting!

## ⌨️ Commands
### 🧵 Thread Management
- ```/cr <name> <password>``` - Create a new thread
- ```/cd <name> <password>``` - Join an existing thread
- ```/info``` - Display information about the current thread
- ```/list``` - List users in the current thread
### 💬 Communication
- ```/help``` - Display available commands
- ```/history``` - Show message history with timestamps
- ```/dm <username> <message>``` - Send a private message
- ```/quit``` - Disconnect from the server
### 🎨 Customization
- ```/color <color>``` - Change your username color
- ```/background <url>``` - Change the chat background
- ```/typo <font>``` - Change the chat font
- ```/textcolor <color>``` - Change the text color
### 📁 Media & File Sharing
- ```/file <url>``` [filename] - Share a file link
- ```/image <url>``` - Share an image
- ```/music <url>``` - Share music in the thread
- ```/playmusic``` - Play shared music
- ```/volume <level>``` - Adjust music volume (0-100)
- ```/upload``` - Upload a file to the server
### 👤 User Management
- ```/register <email> <password> <username>``` - Create an account
- ```/login <email> <password>``` - Login to your account
- ```/language <langCode>``` - Change interface language
### 🛡️ Moderation (Thread Creator Only)
- ```/kick <username>``` - Remove a user from the thread
- ```/ban <username>``` - Ban a user from the thread
- ```/powerto <username>``` - Transfer thread ownership

## 🏗️ Architecture
STORM consists of two main server components:

> 📨 Message Server ( srv_message.rb )
   
   - Handles WebSocket connections
   - Manages chat rooms and messaging
   - Processes commands
   - Maintains user sessions
> 📤 Upload Server ( srv_upload.rb )
   
   - Handles file uploads and storage
   - Extracts and stores file metadata
   - Serves uploaded files
   - Provides RESTful API for file operations

### 📂 Directory Structure
```plaintext
STORM/
├── Message/                # Message server components
│   ├── commands/           # Command implementations
│   ├── controllers/        # Core controllers
│   └── models/             # Data models
├── Upload/                 # Upload server components
│   ├── config/             # Configuration
│   ├── controllers/        # Upload controllers
│   └── helpers/            # Helper modules
├── public/                 # Public assets
│   ├── uploads/            # Uploaded files
│   └── metadata/           # File metadata
├── srv_message.rb          # WebSocket message server
├── srv_upload.rb           # HTTP upload server
└── start_hermes.sh         # Docker startup script
 ```

 ## 📝 License
> MIT
> 
> Made with ❤️ by STORM Team
