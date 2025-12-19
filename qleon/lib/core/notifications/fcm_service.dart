/// FCM Service
/// ------------------------------------------------------------
/// Handles Firebase Cloud Messaging
/// - Permission request
/// - Token management
/// - Foreground / background notification handling
/// ------------------------------------------------------------

import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'local_notification_service.dart';

class FCMService {
  FCMService(this._localNotificationService);

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final LocalNotificationService _localNotificationService;

  /// -------------------------------
  /// INIT
  /// -------------------------------

  Future<void> init() async {
    await _requestPermission();
    await _setupToken();
    _listenForegroundMessages();
  }

  /// -------------------------------
  /// PERMISSION
  /// -------------------------------

  Future<void> _requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    log('FCM Permission: ${settings.authorizationStatus}');
  }

  /// -------------------------------
  /// TOKEN
  /// -------------------------------

  Future<void> _setupToken() async {
    final token = await _fcm.getToken();
    log('FCM Token: $token');

    _fcm.onTokenRefresh.listen((newToken) {
      log('FCM Token refreshed: $newToken');
      // TODO: Send token to backend / Firestore
    });
  }

  /// -------------------------------
  /// FOREGROUND HANDLER
  /// -------------------------------

  void _listenForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _localNotificationService.showNotification(
          title: message.notification?.title ?? 'Qleon',
          body: message.notification?.body ?? '',
        );
      }
    });
  }

  /// -------------------------------
  /// BACKGROUND HANDLER
  /// -------------------------------

  static Future<void> backgroundHandler(RemoteMessage message) async {
    debugPrint('FCM Background message: ${message.messageId}');
  }
}