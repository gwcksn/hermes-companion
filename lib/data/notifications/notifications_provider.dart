import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notifications_bridge.dart';
import 'phone_notification.dart';

final notificationsBridgeProvider = Provider<NotificationsBridge>(
  (ref) => PlatformNotificationsBridge(),
);

class NotificationsState {
  const NotificationsState({this.granted = false, this.loading = true, this.items = const []});

  final bool granted;
  final bool loading;
  final List<PhoneNotification> items;

  NotificationsState copyWith({bool? granted, bool? loading, List<PhoneNotification>? items}) =>
      NotificationsState(
        granted: granted ?? this.granted,
        loading: loading ?? this.loading,
        items: items ?? this.items,
      );
}

/// Live phone notifications for the Notifications tab: snapshot via
/// `getActive()` plus live `posted`/`removed`/`sync` events. Ongoing and
/// system posts are dropped in [isUserNotification]. App icons are fetched
/// lazily per package and cached so rows upgrade from placeholder to icon.
class NotificationsNotifier extends Notifier<NotificationsState> {
  StreamSubscription<Map<String, dynamic>>? _sub;
  final _icons = <String, String>{};
  bool _iconsLoading = false;

  @override
  NotificationsState build() {
    final bridge = ref.watch(notificationsBridgeProvider);
    ref.onDispose(() => _sub?.cancel());
    Future.microtask(() => _start(bridge));
    return const NotificationsState();
  }

  Future<void> _start(NotificationsBridge bridge) async {
    _sub?.cancel();
    _sub = bridge.events.listen(
      (e) => _onEvent(bridge, e),
      onError: (_) {},
    );
    await refresh();
  }

  /// Re-check permission and reload the current shade. Called on start and
  /// when the app resumes (permission is granted in system settings).
  Future<void> refresh() async {
    final bridge = ref.read(notificationsBridgeProvider);
    final granted = await _granted(bridge);
    if (!granted) {
      state = state.copyWith(granted: false, loading: false, items: const []);
      return;
    }
    state = state.copyWith(granted: true, loading: state.items.isEmpty);
    try {
      final raw = await bridge.getActive();
      _replaceAll(bridge, raw);
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  Future<bool> _granted(NotificationsBridge bridge) async {
    try {
      return await bridge.hasPermission();
    } catch (_) {
      return false;
    }
  }

  Future<void> openSettings() async {
    try {
      await ref.read(notificationsBridgeProvider).openSettings();
    } catch (_) {}
  }

  Future<void> openApp(PhoneNotification n) async {
    try {
      await ref.read(notificationsBridgeProvider).openApp(n.packageName);
    } catch (_) {}
  }

  Future<void> dismiss(PhoneNotification n) async {
    state = state.copyWith(items: [for (final i in state.items) if (i.key != n.key) i]);
    try {
      await ref.read(notificationsBridgeProvider).cancel(n.key);
    } catch (_) {}
  }

  Future<void> dismissAll() async {
    state = state.copyWith(items: const []);
    try {
      await ref.read(notificationsBridgeProvider).cancelAll();
    } catch (_) {
      // The shade may still hold them; reload the real state.
      await refresh();
    }
  }

  void _onEvent(NotificationsBridge bridge, Map<String, dynamic> e) {
    switch (e['type']) {
      case 'sync':
        final raw = (e['notifications'] as List?)?.whereType<Map>() ?? const [];
        _replaceAll(
          bridge,
          raw.map((m) => Map<String, dynamic>.from(m)).toList(),
        );
      case 'posted':
        final m = e['notification'];
        if (m is Map) _upsert(bridge, Map<String, dynamic>.from(m));
      case 'removed':
        final key = e['key'] as String?;
        if (key != null) {
          state = state.copyWith(
            items: [for (final i in state.items) if (i.key != key) i],
          );
        }
    }
  }

  void _replaceAll(NotificationsBridge bridge, List<Map<String, dynamic>> raw) {
    final items = raw.where(isUserNotification).map(PhoneNotification.fromMap).toList()
      ..sort((a, b) => b.whenMs.compareTo(a.whenMs));
    state = state.copyWith(granted: true, loading: false, items: _withCachedIcons(items));
    _fillIcons(bridge);
  }

  void _upsert(NotificationsBridge bridge, Map<String, dynamic> m) {
    if (!isUserNotification(m)) return;
    final n = PhoneNotification.fromMap(m);
    final items = [for (final i in state.items) if (i.key != n.key) i, n]
      ..sort((a, b) => b.whenMs.compareTo(a.whenMs));
    state = state.copyWith(granted: true, loading: false, items: _withCachedIcons(items));
    _fillIcons(bridge);
  }

  List<PhoneNotification> _withCachedIcons(List<PhoneNotification> items) => [
    for (final i in items)
      if (i.iconB64 == null && _icons[i.packageName] != null)
        i.copyWith(iconB64: _icons[i.packageName])
      else
        i,
  ];

  void _fillIcons(NotificationsBridge bridge) {
    if (_iconsLoading) return;
    final missing = {for (final i in state.items) i.packageName}
      ..removeWhere((p) => p.isEmpty || _icons.containsKey(p));
    if (missing.isEmpty) return;
    _iconsLoading = true;
    () async {
      try {
        for (final pkg in missing) {
          try {
            final b64 = await bridge.getIcon(pkg);
            if (b64 != null && b64.isNotEmpty) _icons[pkg] = b64;
          } catch (_) {}
        }
        state = state.copyWith(items: _withCachedIcons(state.items));
      } finally {
        _iconsLoading = false;
      }
    }();
  }
}

final notificationsProvider = NotifierProvider<NotificationsNotifier, NotificationsState>(
  NotificationsNotifier.new,
);
