import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<void> initialize() async {
    // 1. Request Permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
      await _saveToken();
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      debugPrint('User granted provisional permission');
      await _saveToken();
    } else {
      debugPrint('User declined or has not accepted permission');
    }

    // 2. Setup Listeners
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint(
          'Message also contained a notification: ${message.notification}',
        );
      }
    });

    // 3. Token Refresh
    _firebaseMessaging.onTokenRefresh.listen(_saveTokenToDatabase);
  }

  Future<void> _saveToken() async {
    String? token;
    if (kIsWeb) {
      token = await _firebaseMessaging.getToken(
        vapidKey:
            'BHoqynCk6-e2NxRKC6MfY2qcDKq4M8xs7Y7V6EzXqFuk1vDDXLjdCw6QfK6OIu-PyKjhVsBXIWniwd_CSuhLLuY',
      );
    } else {
      token = await _firebaseMessaging.getToken();
    }

    if (token != null) {
      await _saveTokenToDatabase(token);
    }
  }

  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_unique_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_unique_id', deviceId);
    }
    return deviceId;
  }

  Future<String> _getDeviceName() async {
    if (kIsWeb) return 'Web Browser';
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        return '${info.brand} ${info.model}';
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return info.name;
      }
    } catch (e) {
      return 'Unknown Device';
    }
    return 'Unknown Platform';
  }

  Future<void> _saveTokenToDatabase(String token) async {
    User? user = _auth.currentUser;
    if (user == null) {
      debugPrint('No user logged in, cannot save FCM token.');
      return;
    }

    try {
      final deviceId = await _getDeviceId();
      final deviceName = await _getDeviceName();

      await _firestore.collection('users').doc(user.uid).set({
        'fcmTokens': {
          deviceId: {
            'token': token,
            'name': deviceName,
            'lastSeen': FieldValue.serverTimestamp(),
            'platform': kIsWeb ? 'web' : Platform.operatingSystem,
          },
        },
        'dailyNotificationsEnabled': true,
        // Legacy support: map 'fcmToken' to this device's token temporarily
        'fcmToken': token,
      }, SetOptions(merge: true));
      debugPrint('FCM Token saved for user: ${user.uid} ($deviceName)');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }
}

final notificationService = NotificationService();
