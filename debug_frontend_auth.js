// Script de diagnostic pour vérifier l'authentification frontend
// À exécuter dans la console du navigateur (F12)

console.log('🔍 DIAGNOSTIC FRONTEND - AUTHENTIFICATION');
console.log('==========================================');

// 1. Vérifier les informations stockées
console.log('\n📦 1. VÉRIFICATION DU STOCKAGE LOCAL:');
try {
    const storedCredentials = storageManager.getUserCredentials();
    console.log('✅ Identifiants stockés:', storedCredentials);
    
    if (storedCredentials && storedCredentials.username) {
        console.log('✅ Nom d\'utilisateur trouvé:', storedCredentials.username);
    } else {
        console.log('❌ Nom d\'utilisateur manquant dans le stockage');
    }
} catch (error) {
    console.log('❌ Erreur lors de la récupération des identifiants:', error);
}

// 2. Vérifier les variables globales
console.log('\n🌐 2. VÉRIFICATION DES VARIABLES GLOBALES:');
console.log('currentUsername:', typeof currentUsername !== 'undefined' ? currentUsername : 'NON DÉFINI');
console.log('isAuthenticated:', typeof isAuthenticated !== 'undefined' ? isAuthenticated : 'NON DÉFINI');
console.log('currentRoom:', typeof currentRoom !== 'undefined' ? currentRoom : 'NON DÉFINI');

// 3. Vérifier l'état de la connexion WebSocket
console.log('\n🔌 3. VÉRIFICATION WEBSOCKET:');
if (typeof ws !== 'undefined' && ws) {
    console.log('✅ WebSocket connecté:', ws.readyState === WebSocket.OPEN ? 'OUI' : 'NON');
    console.log('État WebSocket:', ws.readyState);
    console.log('URL WebSocket:', ws.url);
} else {
    console.log('❌ WebSocket non disponible');
}

// 4. Tester l'envoi d'une commande
console.log('\n📤 4. TEST D\'ENVOI DE COMMANDE:');
function testSendCommand() {
    if (typeof sendMessage === 'function') {
        console.log('✅ Fonction sendMessage disponible');
        
        // Simuler l'envoi d'une commande de test
        const testCommand = '/help';
        console.log('Envoi de la commande de test:', testCommand);
        
        // Intercepter temporairement l'envoi pour voir ce qui est transmis
        const originalSend = ws.send;
        ws.send = function(data) {
            console.log('📡 Données envoyées au serveur:', data);
            originalSend.call(this, data);
            // Restaurer la fonction originale
            ws.send = originalSend;
        };
        
        sendMessage(testCommand);
    } else {
        console.log('❌ Fonction sendMessage non disponible');
    }
}

// 5. Vérifier les fonctions d'authentification
console.log('\n🔐 5. VÉRIFICATION DES FONCTIONS D\'AUTHENTIFICATION:');
console.log('saveLoginInfo:', typeof saveLoginInfo === 'function' ? '✅ DISPONIBLE' : '❌ MANQUANTE');
console.log('handleWebSocketMessage:', typeof handleWebSocketMessage === 'function' ? '✅ DISPONIBLE' : '❌ MANQUANTE');
console.log('connectWebSocket:', typeof connectWebSocket === 'function' ? '✅ DISPONIBLE' : '❌ MANQUANTE');

// 6. Vérifier l'historique des messages récents
console.log('\n📜 6. HISTORIQUE DES MESSAGES RÉCENTS:');
const chatContainer = document.getElementById('chat-container');
if (chatContainer) {
    const messages = chatContainer.querySelectorAll('.message');
    console.log('Nombre de messages affichés:', messages.length);
    
    // Afficher les 3 derniers messages
    const lastMessages = Array.from(messages).slice(-3);
    lastMessages.forEach((msg, index) => {
        console.log(`Message ${index + 1}:`, msg.textContent.substring(0, 100) + '...');
    });
} else {
    console.log('❌ Container de chat non trouvé');
}

// 7. Test de la commande background
console.log('\n🎨 7. TEST DE LA COMMANDE BACKGROUND:');
function testBackgroundCommand() {
    if (typeof sendMessage === 'function') {
        const testBgCommand = '/background https://example.com/test.jpg';
        console.log('Test de la commande background:', testBgCommand);
        
        // Intercepter la réponse
        const originalOnMessage = ws.onmessage;
        ws.onmessage = function(event) {
            console.log('📨 Réponse du serveur pour /background:', event.data);
            originalOnMessage.call(this, event);
            // Restaurer après quelques secondes
            setTimeout(() => {
                ws.onmessage = originalOnMessage;
            }, 5000);
        };
        
        sendMessage(testBgCommand);
    } else {
        console.log('❌ Impossible de tester - fonction sendMessage non disponible');
    }
}

// 8. Résumé et recommandations
console.log('\n📋 8. RÉSUMÉ ET RECOMMANDATIONS:');
console.log('==========================================');

let issues = [];
let recommendations = [];

// Vérifications automatiques
try {
    const storedCredentials = storageManager.getUserCredentials();
    if (!storedCredentials || !storedCredentials.username) {
        issues.push('Nom d\'utilisateur manquant dans le stockage');
        recommendations.push('Reconnectez-vous pour sauvegarder les identifiants');
    }
} catch (error) {
    issues.push('Erreur d\'accès au stockage local');
    recommendations.push('Vérifiez les permissions du navigateur');
}

if (typeof currentUsername === 'undefined' || !currentUsername) {
    issues.push('Variable currentUsername non définie');
    recommendations.push('Vérifiez que l\'auto-login fonctionne correctement');
}

if (typeof ws === 'undefined' || !ws || ws.readyState !== WebSocket.OPEN) {
    issues.push('Connexion WebSocket fermée ou inexistante');
    recommendations.push('Rechargez la page pour rétablir la connexion');
}

if (issues.length === 0) {
    console.log('✅ AUCUN PROBLÈME DÉTECTÉ - Le frontend semble fonctionner correctement');
} else {
    console.log('❌ PROBLÈMES DÉTECTÉS:');
    issues.forEach((issue, index) => {
        console.log(`   ${index + 1}. ${issue}`);
    });
    
    console.log('\n💡 RECOMMANDATIONS:');
    recommendations.forEach((rec, index) => {
        console.log(`   ${index + 1}. ${rec}`);
    });
}

console.log('\n🔧 FONCTIONS DE TEST DISPONIBLES:');
console.log('- testSendCommand() : Teste l\'envoi d\'une commande');
console.log('- testBackgroundCommand() : Teste spécifiquement la commande /background');

console.log('\n✅ Diagnostic terminé!');