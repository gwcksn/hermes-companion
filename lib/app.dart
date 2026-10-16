import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'data/settings_store.dart';
import 'layout/ambient.dart';
import 'layout/scaled_stage.dart';
import 'screens/home_shell.dart';
import 'screens/setup/setup1_server.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

class HermesApp extends ConsumerStatefulWidget {
  const HermesApp({super.key});

  @override
  ConsumerState<HermesApp> createState() => _HermesAppState();
}

class _HermesAppState extends ConsumerState<HermesApp> {
  // Decided once at launch; later changes navigate explicitly.
  late final bool _configured = ref.read(settingsProvider).setupComplete;

  @override
  void initState() {
    super.initState();
    _applyKeepOn(ref.read(settingsProvider).keepScreenOn);
  }

  void _applyKeepOn(bool on) => (on ? WakelockPlus.enable() : WakelockPlus.disable()).catchError((_) {});

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider.select((s) => s.keepScreenOn), (_, on) => _applyKeepOn(on));
    return MaterialApp(
      title: 'Hermes Companion',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // Every route renders on the 740x360 (portrait: 360x740) design canvas, scaled to the screen.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final d = HSizes.designFor(mq.size);
        final scale = math.min(mq.size.width / d.width, mq.size.height / d.height);
        return AmbientOverlay(
          child: ScaledStage(
            size: d,
            offset: ref.watch(ambientProvider.select((a) => a.shift)),
            child: MediaQuery(
              data: mq.copyWith(
                size: d,
                viewInsets: mq.viewInsets / scale,
                padding: EdgeInsets.zero,
                viewPadding: EdgeInsets.zero,
              ),
              child: child!,
            ),
          ),
        );
      },
      home: _configured ? const HomeShell() : const Setup1Server(),
    );
  }
}
