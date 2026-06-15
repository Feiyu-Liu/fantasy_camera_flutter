import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:push/push.dart';

class GenerationNotificationPayload {
  const GenerationNotificationPayload({required this.taskId, this.status});

  final String taskId;
  final String? status;

  static GenerationNotificationPayload? tryParse(Map<Object?, Object?> data) {
    final Object? taskId = data['taskId'] ?? data['task_id'];
    if (taskId is! String || taskId.isEmpty) {
      return null;
    }
    final Object? status = data['status'];
    return GenerationNotificationPayload(
      taskId: taskId,
      status: status is String && status.isNotEmpty ? status : null,
    );
  }
}

abstract interface class PushNotificationGateway {
  VoidCallback addTokenListener(FutureOr<void> Function(String token) handler);

  VoidCallback addForegroundMessageListener(
    FutureOr<void> Function(GenerationNotificationPayload payload) handler,
  );

  VoidCallback addNotificationTapListener(
    FutureOr<void> Function(GenerationNotificationPayload payload) handler,
  );

  Future<GenerationNotificationPayload?> notificationTapWhichLaunchedApp();

  Future<bool> requestPermission();

  Future<bool> areNotificationsEnabled();

  Future<String?> token();

  void registerForRemoteNotifications();

  void unregisterForRemoteNotifications();
}

class PushPackageNotificationGateway implements PushNotificationGateway {
  const PushPackageNotificationGateway();

  @override
  VoidCallback addTokenListener(FutureOr<void> Function(String token) handler) {
    return Push.instance.addOnNewToken(handler);
  }

  @override
  VoidCallback addForegroundMessageListener(
    FutureOr<void> Function(GenerationNotificationPayload payload) handler,
  ) {
    return Push.instance.addOnMessage((RemoteMessage message) async {
      final GenerationNotificationPayload? payload =
          GenerationNotificationPayload.tryParse(_messageData(message.data));
      if (payload != null) {
        await handler(payload);
      }
    });
  }

  @override
  VoidCallback addNotificationTapListener(
    FutureOr<void> Function(GenerationNotificationPayload payload) handler,
  ) {
    return Push.instance.addOnNotificationTap((Map<String?, Object?> data) async {
      final GenerationNotificationPayload? payload =
          GenerationNotificationPayload.tryParse(data);
      if (payload != null) {
        await handler(payload);
      }
    });
  }

  @override
  Future<GenerationNotificationPayload?> notificationTapWhichLaunchedApp()
  async {
    final Map<String?, Object?>? data =
        await Push.instance.notificationTapWhichLaunchedAppFromTerminated;
    if (data == null) {
      return null;
    }
    return GenerationNotificationPayload.tryParse(_messageData(data));
  }

  @override
  Future<bool> requestPermission() {
    if (!Platform.isIOS && !Platform.isMacOS && !Platform.isAndroid) {
      return Future<bool>.value(false);
    }
    return Push.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      providesAppNotificationSettings: false,
      announcement: false,
    );
  }

  @override
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      return Push.instance.areNotificationsEnabled();
    }
    if (Platform.isIOS || Platform.isMacOS) {
      final UNNotificationSettings settings = await Push.instance
          .getNotificationSettings();
      return switch (settings.authorizationStatus) {
        UNAuthorizationStatus.authorized ||
        UNAuthorizationStatus.provisional ||
        UNAuthorizationStatus.ephemeral => true,
        _ => false,
      };
    }
    if (!Platform.isIOS && !Platform.isMacOS && !Platform.isAndroid) {
      return Future<bool>.value(false);
    }
    return false;
  }

  @override
  Future<String?> token() {
    if (!Platform.isIOS && !Platform.isMacOS && !Platform.isAndroid) {
      return Future<String?>.value(null);
    }
    return Push.instance.token;
  }

  @override
  void registerForRemoteNotifications() {
    if (Platform.isIOS || Platform.isMacOS) {
      Push.instance.registerForRemoteNotifications();
    }
  }

  @override
  void unregisterForRemoteNotifications() {
    if (Platform.isIOS || Platform.isMacOS) {
      Push.instance.unregisterForRemoteNotifications();
    }
  }
}

Map<Object?, Object?> _messageData(Map<Object?, Object?>? data) {
  return data ?? const <Object?, Object?>{};
}
