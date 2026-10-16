import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_companion/data/notifications/notifications_provider.dart';
import 'package:hermes_companion/data/notifications/phone_notification.dart';
import 'package:hermes_companion/screens/notifications_page.dart';

import 'fakes/fake_notifications.dart';

ProviderScope _scope(FakeNotificationsBridge bridge, {Widget? child}) => ProviderScope(
  overrides: [notificationsBridgeProvider.overrideWithValue(bridge)],
  child: MaterialApp(home: Scaffold(body: child ?? const _Probe())),
);

class _Probe extends ConsumerWidget {
  const _Probe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(notificationsProvider);
    return Text('granted=${s.granted} n=${s.items.length}', textDirection: TextDirection.ltr);
  }
}

void main() {
  test('isUserNotification hides ongoing, non-clearable and system packages', () {
    expect(isUserNotification(notif(key: 'a')), isTrue);
    expect(isUserNotification(notif(key: 'b', ongoing: true)), isFalse);
    expect(isUserNotification(notif(key: 'c', clearable: false)), isFalse);
    expect(isUserNotification(notif(key: 'd', package: 'com.android.systemui')), isFalse);
    expect(isUserNotification(notif(key: 'e', package: 'android')), isFalse);
    expect(isUserNotification({...notif(key: 'f'), 'groupSummary': true}), isFalse);
    expect(isUserNotification(notif(key: 'g', package: 'dev.gilang.hermes_companion')), isFalse);
  });

  testWidgets('loads active, filters noise, sorts newest first', (tester) async {
    final bridge = FakeNotificationsBridge(
      active: [
        notif(key: 'old', title: 'Old', whenMs: 1000),
        notif(key: 'new', title: 'New', whenMs: 3000),
        notif(key: 'noise', title: 'Noise', ongoing: true, whenMs: 5000),
      ],
    );
    await tester.pumpWidget(_scope(bridge));
    await tester.pumpAndSettle();
    expect(find.text('granted=true n=2'), findsOneWidget);
    final container = ProviderScope.containerOf(tester.element(find.byType(_Probe)));
    final items = container.read(notificationsProvider).items;
    expect(items.map((i) => i.key), ['new', 'old']);
  });

  testWidgets('live posted and removed events merge', (tester) async {
    final bridge = FakeNotificationsBridge(active: [notif(key: 'a', whenMs: 1000)]);
    await tester.pumpWidget(_scope(bridge));
    await tester.pumpAndSettle();

    bridge.post(notif(key: 'b', title: 'B', whenMs: 2000));
    await tester.pumpAndSettle();
    var container = ProviderScope.containerOf(tester.element(find.byType(_Probe)));
    expect(container.read(notificationsProvider).items.map((i) => i.key), ['b', 'a']);

    bridge.remove('b');
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(tester.element(find.byType(_Probe)));
    expect(container.read(notificationsProvider).items.map((i) => i.key), ['a']);
  });

  testWidgets('dismiss, dismissAll and openApp forward to the bridge', (tester) async {
    final bridge = FakeNotificationsBridge(
      active: [notif(key: 'a', whenMs: 1000), notif(key: 'b', whenMs: 2000)],
    );
    await tester.pumpWidget(_scope(bridge));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(_Probe)));
    final notifier = container.read(notificationsProvider.notifier);

    await notifier.openApp(container.read(notificationsProvider).items.first);
    expect(bridge.openedApps, ['com.example.chat']);

    await notifier.dismiss(container.read(notificationsProvider).items.first);
    expect(bridge.cancelled, ['b']);
    expect(container.read(notificationsProvider).items.map((i) => i.key), ['a']);

    await notifier.dismissAll();
    expect(bridge.cancelAllCount, 1);
    expect(container.read(notificationsProvider).items, isEmpty);
  });

  testWidgets('dismissAll failure reloads the real shade state', (tester) async {
    final bridge = FakeNotificationsBridge(active: [notif(key: 'a'), notif(key: 'b')])
      ..cancelAllFails = true;
    await tester.pumpWidget(_scope(bridge));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(_Probe)));
    await container.read(notificationsProvider.notifier).dismissAll();
    expect(container.read(notificationsProvider).items, hasLength(2));
  });

  testWidgets('icons fill in lazily per package', (tester) async {
    final bridge = FakeNotificationsBridge(
      active: [notif(key: 'a', whenMs: 1000, package: 'com.example.chat')],
    );
    bridge.icons['com.example.chat'] = base64Encode(List.filled(10, 7));
    await tester.pumpWidget(_scope(bridge));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(_Probe)));
    expect(container.read(notificationsProvider).items.single.iconB64, isNotNull);
    expect(bridge.iconRequests, ['com.example.chat']);
  });

  testWidgets('permission off shows enable action', (tester) async {
    final bridge = FakeNotificationsBridge(granted: false);
    await tester.pumpWidget(_scope(bridge, child: const NotificationsPage()));
    await tester.pumpAndSettle();
    expect(find.text('Notifications are off'), findsOneWidget);
    await tester.tap(find.text('Enable access'));
    await tester.pumpAndSettle();
    expect(bridge.settingsOpened, 1);
  });

  testWidgets('page: tap row reveals Open/Dismiss, dismiss-all clears', (tester) async {
    final bridge = FakeNotificationsBridge(
      active: [
        notif(key: 'a', title: 'First', package: 'com.example.one', app: 'One', whenMs: 1000),
        notif(key: 'b', title: 'Second', package: 'com.example.two', app: 'Two', whenMs: 2000),
      ],
    );
    await tester.pumpWidget(_scope(bridge, child: const NotificationsPage()));
    await tester.pumpAndSettle();
    expect(find.text('Notifications (2)'), findsOneWidget);
    expect(find.text('First'), findsOneWidget);

    expect(find.text('Open'), findsNothing);
    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(bridge.openedApps, ['com.example.two']);
    expect(find.text('Open'), findsNothing);

    await tester.tap(find.text('First'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(bridge.cancelled, ['a']);
    expect(find.text('First'), findsNothing);

    await tester.tap(find.text('Dismiss all'));
    await tester.pumpAndSettle();
    expect(bridge.cancelAllCount, 1);
    expect(find.text('All caught up'), findsOneWidget);
  });
}
