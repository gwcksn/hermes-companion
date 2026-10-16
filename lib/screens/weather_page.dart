import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/location.dart';
import '../data/weather.dart';
import '../data/weather_provider.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/weather_icons.dart';

/// Weather page: Open-Meteo for the device's current location, °C, refreshed every 30 minutes.
class WeatherPage extends ConsumerWidget {
  const WeatherPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weather = ref.watch(weatherProvider);
    return switch (weather) {
      AsyncData(:final value) => _Forecast(
        value,
        ref.watch(placeProvider).name,
      ),
      AsyncError() => _Message(
        title: 'Weather unavailable',
        detail: 'Tap to try again',
        onTap: () => ref.read(weatherProvider.notifier).refresh(),
      ),
      _ => const _Message(title: 'Checking the sky…'),
    };
  }
}

class _Forecast extends StatelessWidget {
  const _Forecast(this.w, this.place);

  final Weather w;
  final String place;

  @override
  Widget build(BuildContext context) {
    final rainy = !w.hint.startsWith('No rain');
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              WeatherIcon(
                w.now.kind,
                size: 92,
                large: true,
                night: !w.now.isDay,
              ),
              const SizedBox(width: 18),
              Text(
                '${w.now.temp.round()}°',
                style: hDisplay(84, weight: FontWeight.w600, height: 1),
              ),
              const SizedBox(width: 18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(w.condition, style: hText(20)),
                  const SizedBox(height: 2),
                  Text(place, style: hText(13, color: HColors.muted)),
                  const SizedBox(height: 2),
                  Text(
                    w.hint,
                    style: hText(
                      13,
                      color: rainy ? HColors.mint : HColors.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (final (i, slot) in [w.now, ...w.hours].indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                _Slot(slot, current: i == 0),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot(this.slot, {required this.current});

  final WeatherSlot slot;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${slot.label}, ${conditionFor(slot.code)}, ${slot.temp.round()} degrees',
      excludeSemantics: true,
      child: Container(
        width: 76,
        height: 92,
        decoration: BoxDecoration(
          color: current ? HColors.surfaceActive : HColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              slot.label,
              style: hText(13, color: current ? HColors.text : HColors.muted),
            ),
            const SizedBox(height: 6),
            WeatherIcon(slot.kind, night: !slot.isDay),
            const SizedBox(height: 6),
            Text('${slot.temp.round()}°', style: hText(17)),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, this.detail, this.onTap});

  final String title;
  final String? detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: hText(20)),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(detail!, style: hText(13, color: HColors.muted)),
            ],
          ],
        ),
      ),
    );
  }
}
