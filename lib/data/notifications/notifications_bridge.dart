import 'dart:async';

import 'package:flutter/services.dart';

/// Thin platform bridge for the Notifications tab. A separate injectable
/// class (instead of statics) so widget/unit tests can override it with a
/// fake and never touch a real MethodChannel.
abstract class NotificationsBridge {
  Future<bool> hasPermission();
  Future<void> openSettings();
  Future<List<Map<String, dynamic>>> getActive();
  Future<String?> getIcon(String packageName);
  Future<void> openApp(String packageName);
  Future<void> cancel(String key);
  Future<void> cancelAll();
  Stream<Map<String, dynamic>> get events;
}

class PlatformNotificationsBridge implements NotificationsBridge {
  PlatformNotificationsBridge({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel('hermes/notifications'),
      _events = events ?? const EventChannel('hermes/notifications_events');

  final MethodChannel _methods;
  final EventChannel _events;

  @override
  Future<bool> hasPermission() async =>
      (await _methods.invokeMethod<bool>('hasPermission')) ?? false;

  @override
  Future<void> openSettings() => _methods.invokeMethod('openSettings');

  @override
  Future<List<Map<String, dynamic>>> getActive() async {
    final raw = await _methods.invokeMethod<List>('getActive');
    if (raw == null) return const [];
    return raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Future<String?> getIcon(String packageName) =>
      _methods.invokeMethod<String>('getIcon', {'packageName': packageName});

  @override
  Future<void> openApp(String packageName) =>
      _methods.invokeMethod('openApp', {'packageName': packageName});

  @override
  Future<void> cancel(String key) => _methods.invokeMethod('cancel', {'key': key});

  @override
  Future<void> cancelAll() => _methods.invokeMethod('cancelAll');

  @override
  Stream<Map<String, dynamic>> get events => _events.receiveBroadcastStream().map(
    (m) => Map<String, dynamic>.from(m as Map),
  );
}
