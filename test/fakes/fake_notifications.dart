import 'dart:async';

import 'package:hermes_companion/data/notifications/notifications_bridge.dart';

/// Scripted fake for the notification platform bridge. Tests never touch a
/// real MethodChannel.
class FakeNotificationsBridge implements NotificationsBridge {
  FakeNotificationsBridge({this.granted = true, List<Map<String, dynamic>>? active})
    : _active = active ?? [];

  bool granted;
  final List<Map<String, dynamic>> _active;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final openedApps = <String>[];
  final cancelled = <String>[];
  var cancelAllCount = 0;
  bool cancelAllFails = false;
  var settingsOpened = 0;
  final icons = <String, String>{};
  final iconRequests = <String>[];

  void post(Map<String, dynamic> notification) =>
      _events.add({'type': 'posted', 'notification': notification});

  void remove(String key) => _events.add({'type': 'removed', 'key': key});

  void sync(List<Map<String, dynamic>> list) =>
      _events.add({'type': 'sync', 'notifications': list});

  @override
  Future<bool> hasPermission() async => granted;

  @override
  Future<void> openSettings() async {
    settingsOpened++;
  }

  @override
  Future<List<Map<String, dynamic>>> getActive() async => List.of(_active);

  @override
  Future<String?> getIcon(String packageName) async {
    iconRequests.add(packageName);
    return icons[packageName];
  }

  @override
  Future<void> openApp(String packageName) async {
    openedApps.add(packageName);
  }

  @override
  Future<void> cancel(String key) async {
    cancelled.add(key);
    _active.removeWhere((m) => m['key'] == key);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
    if (cancelAllFails) throw Exception('cancelAll failed');
    _active.clear();
  }

  @override
  Stream<Map<String, dynamic>> get events => _events.stream;
}

Map<String, dynamic> notif({
  required String key,
  String package = 'com.example.chat',
  String app = 'Chat',
  String title = 'Hi',
  String text = 'hello',
  int whenMs = 1000,
  bool ongoing = false,
  bool clearable = true,
}) => {
  'key': key,
  'packageName': package,
  'appName': app,
  'title': title,
  'text': text,
  'whenMs': whenMs,
  'ongoing': ongoing,
  'clearable': clearable,
};
