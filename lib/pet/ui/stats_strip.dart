import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/tokens.dart';
import '../pet_controller.dart';
import '../pet_state.dart';
import '../pet_ui.dart';

/// Three small icon bars (energy, mood, curiosity) on the avatar stage. Hidden unless
/// [statsVisibleProvider]; debug builds always show it with numbers for checking the wiring.
class StatsStrip extends ConsumerWidget {
  const StatsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debug = ref.watch(petStatsDebugProvider);
    final visible = debug || ref.watch(statsVisibleProvider);
    final pet = ref.watch(petProvider);
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Stat(Icons.bolt_rounded, pet.energy, HColors.amber, 'Energy', debug),
              const SizedBox(width: 12),
              _Stat(Icons.favorite_rounded, pet.mood, HColors.pink, 'Mood', debug),
              const SizedBox(width: 12),
              _Stat(Icons.auto_awesome_rounded, pet.curiosity, HColors.sky, 'Curiosity', debug),
              const SizedBox(width: 12),
              _Stat(Icons.cookie_rounded, pet.hunger, HColors.mint, 'Hunger', debug),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.value, this.color, this.label, this.showNumber);

  final IconData icon;
  final double value;
  final Color color;
  final String label;
  final bool showNumber;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label ${value.round()} percent',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              width: 30,
              height: 6,
              child: Stack(
                children: [
                  const Positioned.fill(child: ColoredBox(color: HColors.surface)),
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: (value / maxStat).clamp(0.0, 1.0),
                        heightFactor: 1,
                        child: ColoredBox(color: color),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showNumber) ...[
            const SizedBox(width: 3),
            Text(value.round().toString(), style: const TextStyle(fontSize: 9, color: HColors.muted)),
          ],
        ],
      ),
    );
  }
}
