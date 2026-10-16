import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'google_auth.dart';
import 'google_client.dart';
import 'workspace_item.dart';

const _refreshEvery = Duration(minutes: 10);
const _cacheKey = 'google.workspace.v1';
const _connectedKey = 'google.connected';

class WorkspaceData {
  const WorkspaceData({required this.items, required this.fetchedAt});

  final List<WorkItem> items;
  final DateTime fetchedAt;

  List<WorkItem> today(DateTime now) => bucketToday(items, now);
  Map<DateTime, List<WorkItem>> next(DateTime now) => groupNext(items, now);
}

/// Calendar events + tasks for the Workspace page: cached copy first, refresh every 10 min,
/// last good data kept on failure. Throws [GoogleSignedOut] (as AsyncError) when not connected.
class WorkspaceNotifier extends AsyncNotifier<WorkspaceData> {
  Timer? _timer;

  @override
  Future<WorkspaceData> build() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_connectedKey) != true) throw const GoogleSignedOut();

    _timer?.cancel();
    _timer = Timer.periodic(_refreshEvery, (_) => refresh());
    ref.onDispose(() => _timer?.cancel());

    final cached = _readCache(prefs);
    if (cached != null) {
      if (DateTime.now().difference(cached.fetchedAt) > _refreshEvery) {
        Future.microtask(refresh);
      }
      return cached;
    }
    return _fetchAndCache(prefs);
  }

  Future<void> connect() async {
    await ref.read(googleAuthProvider).signIn();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_connectedKey, true);
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // The page shows the error state.
    }
  }

  Future<void> disconnect() async {
    await ref.read(googleAuthProvider).signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_connectedKey);
    await prefs.remove(_cacheKey);
    ref.invalidateSelf();
  }

  /// Marks a task done: it disappears right away and is restored if Google rejects the change.
  Future<void> completeTask(WorkItem task) async {
    final id = task.id;
    final previous = state.value;
    if (id == null || previous == null) return;
    state = AsyncData(
      WorkspaceData(items: [...previous.items.where((i) => i.id != id)], fetchedAt: previous.fetchedAt),
    );
    try {
      await ref.read(googleClientProvider).completeTask(id);
      final prefs = await SharedPreferences.getInstance();
      await _dropFromCache(prefs, id);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> _dropFromCache(SharedPreferences prefs, String id) async {
    try {
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      m['tasks'] = (m['tasks'] as List).where((t) => (t as Map)['id'] != id).toList();
      await prefs.setString(_cacheKey, jsonEncode(m));
    } catch (_) {
      // Caching is best-effort.
    }
  }

  Future<void> refresh() async {
    final previous = state.value;
    if (previous == null) state = const AsyncLoading();
    try {
      state = AsyncData(await _fetchAndCache(await SharedPreferences.getInstance()));
    } catch (e, st) {
      state = previous != null && e is! GoogleSignedOut ? AsyncData(previous) : AsyncError(e, st);
    }
  }

  Future<WorkspaceData> _fetchAndCache(SharedPreferences prefs) async {
    final client = ref.read(googleClientProvider);
    final now = DateTime.now();
    final from = dayOf(now);
    final to = from.add(const Duration(days: 9));
    final results = await Future.wait([client.events(from, to), client.tasks()]);
    final data = _build(results[0], results[1], now);
    try {
      await prefs.setString(
        _cacheKey,
        jsonEncode({'at': now.toIso8601String(), 'events': results[0], 'tasks': results[1]}),
      );
    } catch (_) {
      // Caching is best-effort.
    }
    return data;
  }

  WorkspaceData? _readCache(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return _build(
        (m['events'] as List).cast<Map<String, dynamic>>(),
        (m['tasks'] as List).cast<Map<String, dynamic>>(),
        DateTime.parse(m['at'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  WorkspaceData _build(List<Map<String, dynamic>> events, List<Map<String, dynamic>> tasks, DateTime at) {
    final items = <WorkItem>[
      for (final e in events) ?WorkItem.fromCalendarJson(e),
      for (final t in tasks) ?WorkItem.fromTaskJson(t, now: at),
    ];
    return WorkspaceData(items: items, fetchedAt: at);
  }
}

// Retries are ours (tap to retry, 10-min refresh), not Riverpod's automatic backoff.
final workspaceProvider = AsyncNotifierProvider<WorkspaceNotifier, WorkspaceData>(
  WorkspaceNotifier.new,
  retry: (_, _) => null,
);
