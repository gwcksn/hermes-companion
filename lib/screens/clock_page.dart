import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/tokens.dart';
import '../widgets/common.dart';

/// 24h clock in WIB (UTC+7, no DST), independent of the device's time zone.
DateTime nowWib() => DateTime.now().toUtc().add(const Duration(hours: 7));

class ClockPage extends StatefulWidget {
  const ClockPage({super.key});

  @override
  State<ClockPage> createState() => _ClockPageState();
}

class _ClockPageState extends State<ClockPage> {
  late Timer _timer;
  DateTime _now = nowWib();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final n = nowWib();
      if (n.minute != _now.minute || n.day != _now.day) setState(() => _now = n);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final big = hDisplay(
      108,
      weight: FontWeight.w600,
      height: 1,
    ).copyWith(letterSpacing: 2, fontFeatures: const [FontFeature.tabularFigures()]);
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
          Text(DateFormat('EEEE, d MMMM', 'en_US').format(_now), style: hText(20)),
          const SizedBox(height: 10),
          const TagChip('Yogyakarta · WIB'),
        ],
      ),
    );
  }
}
