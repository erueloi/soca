importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-messaging.js");

// TODO: Replace with your project's config from lib/core/config/firebase_options.dart
// You can copy the 'web' options section.
firebase.initializeApp({
    apiKey: "AIzaSyDssgK-xdDHUscQi-eWwa4IkY_RlEAcgSM",
    authDomain: "soca-aacac.firebaseapp.com",
    projectId: "soca-aacac",
    storageBucket: "soca-aacac.firebasestorage.app",
    messagingSenderId: "810172062958",
    appId: "1:810172062958:web:1806aef995a491e90727ff"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
    console.log('[firebase-messaging-sw.js] Received background message ', payload);

    const notificationTitle = payload.notification.title;
    const notificationOptions = {
        body: payload.notification.body,
        icon: '/icons/Icon-192.png'
    };

    self.registration.showNotification(notificationTitle, notificationOptions);
});
