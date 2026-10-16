import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/tokens.dart';
import 'hermes_client.dart';
import 'settings_store.dart';

enum LinkState { checking, connected, offline, signedOut }

class Link {
  const Link(this.state, {this.model, this.error});

  final LinkState state;
  final String? model;
  final HermesError? error;

  String get label => switch (state) {
    LinkState.checking => 'Connecting…',
    LinkState.connected => 'Connected',
    LinkState.offline => 'Offline',
    LinkState.signedOut => 'Signed out',
  };

  Color get color => switch (state) {
    LinkState.checking => HColors.muted,
    LinkState.connected => HColors.mint,
    LinkState.offline => HColors.coral,
    LinkState.signedOut => HColors.amber,
  };
}

const _checkEvery = Duration(minutes: 1);

/// Keeps a live view of the dashboard link: public /api/status for reachability,
/// then an authenticated call (model info for the chosen profile) for the session.
class ConnectionNotifier extends Notifier<Link> {
  Timer? _timer;

  @override
  Link build() {
    final client = ref.watch(hermesClientProvider);
    ref.watch(settingsProvider.select((s) => s.profile));
    _timer?.cancel();
    ref.onDispose(() => _timer?.cancel());
    if (client == null) return const Link(LinkState.signedOut);
    _timer = Timer.periodic(_checkEvery, (_) => check());
    Future.microtask(check);
    return const Link(LinkState.checking);
  }

  Future<Link> check() async {
    final client = ref.read(hermesClientProvider);
    if (client == null) return state = const Link(LinkState.signedOut);
    final profile = ref.read(settingsProvider).profile;
    try {
      await client.status();
      final model = await client.modelName(profile);
      return state = Link(LinkState.connected, model: model);
    } on HermesError catch (e) {
      final s = e.kind == HermesErrorKind.signedOut ? LinkState.signedOut : LinkState.offline;
      return state = Link(s, error: e);
    }
  }
}

final connectionProvider = NotifierProvider<ConnectionNotifier, Link>(ConnectionNotifier.new);
