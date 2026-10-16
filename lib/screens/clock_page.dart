import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/location.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// 24h clock in WIB (UTC+7, no DST), independent of the device's time zone.
DateTime nowWib() => DateTime.now().toUtc().add(const Duration(hours: 7));

class ClockPage extends ConsumerStatefulWidget {
  const ClockPage({super.key});

  @override
  ConsumerState<ClockPage> createState() => _ClockPageState();
}

class _ClockPageState extends ConsumerState<ClockPage> {
  late Timer _timer;
  late DateTime _now = ref.read(placeProvider).now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final n = ref.read(placeProvider).now();
      if (n.minute != _now.minute || n.day != _now.day)
        setState(() => _now = n);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final place = ref.watch(placeProvider);
    _now = place.now();
    final big = hDisplay(108, weight: FontWeight.w600, height: 1).copyWith(
      letterSpacing: 2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    String two(int v) => v.toString().padLeft(2, '0');

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: two(_now.hour)),
                const TextSpan(
                  text: ':',
                  style: TextStyle(color: HColors.mint),
                ),
                TextSpan(text: two(_now.minute)),
              ],
            ),
            style: big,
          ),
          const SizedBox(height: 10),
          Text(
            DateFormat('EEEE, d MMMM', 'en_US').format(_now),
            style: hText(20),
          ),
          const SizedBox(height: 10),
          TagChip('${place.name} · ${place.zoneLabel}'),
        ],
      ),
    );
  }
}
