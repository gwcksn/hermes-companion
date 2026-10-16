import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_companion/data/google/google_auth.dart';
import 'package:hermes_companion/data/google/google_client.dart';
import 'package:hermes_companion/data/google/workspace_item.dart';
import 'package:hermes_companion/data/google/workspace_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuth implements GoogleAuth {
  bool signedIn = false;
  @override
  Future<void> signIn() async => signedIn = true;
  @override
  Future<void> signOut() async => signedIn = false;
  @override
  Future<String?> accessToken({bool forceRefresh = false}) async => signedIn ? 'tok' : null;
}

class _FakeClient extends GoogleWorkspaceClient {
  _FakeClient(super.auth, this.events_, this.tasks_);
  final List<Map<String, dynamic>> events_;
  final List<Map<String, dynamic>> tasks_;
  int calls = 0;
  final completed = <String>[];
  bool failComplete = false;
  @override
  Future<List<Map<String, dynamic>>> events(DateTime a, DateTime b) async {
    calls++;
    return events_;
  }

  @override
  Future<List<Map<String, dynamic>>> tasks() async => tasks_;

  @override
  Future<void> completeTask(String id) async {
    if (failComplete) throw Exception('nope');
    completed.add(id);
  }
}

void main() {
  final now = DateTime(2026, 10, 16, 14, 0);

  Map<String, dynamic> timed(String title, String start, String end) => {
    'summary': title,
    'start': {'dateTime': start},
    'end': {'dateTime': end},
  };

  group('parsing', () {
    test('timed event', () {
      final i = WorkItem.fromCalendarJson(timed('Standup', '2026-10-16T09:00:00', '2026-10-16T09:30:00'))!;
      expect(i.kind, WorkKind.event);
      expect(i.allDay, isFalse);
      expect(i.start, DateTime(2026, 10, 16, 9));
    });

    test('all-day event and cancelled event', () {
      final i = WorkItem.fromCalendarJson({
        'summary': 'Holiday',
        'start': {'date': '2026-10-17'},
        'end': {'date': '2026-10-18'},
      })!;
      expect(i.allDay, isTrue);
      expect(i.start, DateTime(2026, 10, 17));
      expect(
        WorkItem.fromCalendarJson({
          'status': 'cancelled',
          'start': {'date': '2026-10-17'},
        }),
        isNull,
      );
    });

    test('tasks with, without due and completed', () {
      final due = WorkItem.fromTaskJson({'title': 'Pay rent', 'due': '2026-10-16T00:00:00.000Z'}, now: now)!;
      expect(due.start, DateTime(2026, 10, 16));
      expect(due.hasDate, isTrue);
      final none = WorkItem.fromTaskJson({'title': 'Someday'}, now: now)!;
      expect(none.hasDate, isFalse);
      expect(WorkItem.fromTaskJson({'title': 'x', 'status': 'completed'}, now: now), isNull);
    });
  });

  group('bucketing', () {
    final items = [
      WorkItem.fromCalendarJson(timed('Morning', '2026-10-16T09:00:00', '2026-10-16T10:00:00'))!,
      WorkItem.fromCalendarJson(timed('Tomorrow', '2026-10-17T09:00:00', '2026-10-17T10:00:00'))!,
      WorkItem.fromCalendarJson(timed('Late', '2026-10-23T09:00:00', '2026-10-23T10:00:00'))!,
      WorkItem.fromCalendarJson(timed('TooFar', '2026-10-24T09:00:00', '2026-10-24T10:00:00'))!,
      WorkItem.fromCalendarJson({
        'summary': 'Yesterday allday',
        'start': {'date': '2026-10-15'},
        'end': {'date': '2026-10-16'},
      })!,
      WorkItem.fromTaskJson({'title': 'Overdue', 'due': '2026-10-14T00:00:00.000Z'}, now: now)!,
      WorkItem.fromTaskJson({'title': 'Undated'}, now: now)!,
      WorkItem.fromTaskJson({'title': 'Next week task', 'due': '2026-10-20T00:00:00.000Z'}, now: now)!,
    ];

    test('today holds today events, overdue and undated tasks', () {
      expect(bucketToday(items, now).map((i) => i.title), ['Overdue', 'Undated', 'Morning']);
    });

    test('next covers tomorrow to +7 days, grouped by day', () {
      final g = groupNext(items, now);
      expect(g.keys, [DateTime(2026, 10, 17), DateTime(2026, 10, 20), DateTime(2026, 10, 23)]);
      expect(g[DateTime(2026, 10, 20)]!.single.title, 'Next week task');
    });
  });

  group('provider', () {
    ProviderContainer rig(_FakeAuth auth, _FakeClient client) {
      final c = ProviderContainer(
        overrides: [googleAuthProvider.overrideWithValue(auth), googleClientProvider.overrideWithValue(client)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('signed out until connect, then loads and caches', () async {
      SharedPreferences.setMockInitialValues({});
      final auth = _FakeAuth();
      final client = _FakeClient(
        auth,
        [timed('Now', '2026-10-16T09:00:00', '2026-10-16T10:00:00')],
        [
          {'title': 'Task'},
        ],
      );
      final c = rig(auth, client);
      await expectLater(c.read(workspaceProvider.future), throwsA(isA<GoogleSignedOut>()));

      await c.read(workspaceProvider.notifier).connect();
      expect(c.read(workspaceProvider).value!.items, hasLength(2));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('google.workspace.v1'), isNotNull);

      await c.read(workspaceProvider.notifier).disconnect();
      await expectLater(c.read(workspaceProvider.future), throwsA(isA<GoogleSignedOut>()));
      expect(prefs.getString('google.workspace.v1'), isNull);
    });

    test('completing a task removes it, and restores it if Google rejects', () async {
      SharedPreferences.setMockInitialValues({});
      final auth = _FakeAuth();
      final client = _FakeClient(auth, [], [
        {'id': 't1', 'title': 'Pay rent'},
        {'id': 't2', 'title': 'Call mom'},
      ]);
      final c = rig(auth, client);
      await c.read(workspaceProvider.notifier).connect().catchError((_) {});
      final n = c.read(workspaceProvider.notifier);
      final rent = c.read(workspaceProvider).value!.items.firstWhere((i) => i.id == 't1');

      await n.completeTask(rent);
      expect(client.completed, ['t1']);
      expect(c.read(workspaceProvider).value!.items.map((i) => i.id), ['t2']);
      final cache = (await SharedPreferences.getInstance()).getString('google.workspace.v1')!;
      expect(cache.contains('t1'), isFalse);

      client.failComplete = true;
      final call = c.read(workspaceProvider).value!.items.single;
      await expectLater(n.completeTask(call), throwsException);
      expect(c.read(workspaceProvider).value!.items.map((i) => i.id), ['t2']);
    });
  });
}
