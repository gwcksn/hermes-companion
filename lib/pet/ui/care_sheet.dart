import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/tokens.dart';
import '../pet_actions.dart';
import '../pet_controller.dart';
import '../pet_rules.dart';

/// Long-press the avatar: Feed, Play and Tuck in.
Future<void> showCareSheet(BuildContext context) =>
    showDialog<void>(context: context, barrierColor: const Color(0x99000000), builder: (_) => const CareSheet());

class CareSheet extends ConsumerWidget {
  const CareSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pet = ref.watch(petProvider);
    final left = feedMinutesLeft(pet.lastFeedAt, ref.read(petClockProvider).now());
    final feedHint = isFull(pet)
        ? 'Full'
        : isHungry(pet)
        ? 'Hungry'
        : left > 0
        ? 'Snack'
        : 'Fun fact';

    void run(VoidCallback action) {
      Navigator.of(context).pop();
      action();
    }

    return Dialog(
      backgroundColor: HColors.panel,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HRadii.card)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CareButton(
              icon: Icons.lightbulb_rounded,
              label: 'Feed',
              hint: feedHint,
              color: HColors.sky,
              enabled: !isFull(pet),
              onTap: () => run(() => feedPet(ref)),
            ),
            const SizedBox(width: 12),
            _CareButton(
              icon: Icons.sports_baseball_rounded,
              label: 'Play',
              hint: 'Mood up',
              color: HColors.pink,
              onTap: () => run(() => playWithPet(ref)),
            ),
            const SizedBox(width: 12),
            _CareButton(
              icon: Icons.cleaning_services_rounded,
              label: 'Clean',
              hint: pet.poops > 0 ? 'Poop!' : 'All tidy',
              color: HColors.mint,
              enabled: pet.poops > 0,
              onTap: () => run(() => cleanPet(ref)),
            ),
            const SizedBox(width: 12),
            _CareButton(
              icon: Icons.bedtime_rounded,
              label: 'Tuck in',
              hint: 'Rest',
              color: HColors.lavender,
              onTap: () => run(() => tuckInPet(ref)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CareButton extends StatelessWidget {
  const _CareButton({
    required this.icon,
    required this.label,
    required this.hint,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String hint;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = enabled ? color : HColors.dim;
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$label, $hint',
      child: Material(
        color: HColors.surface,
        borderRadius: BorderRadius.circular(HRadii.input),
        child: InkWell(
          borderRadius: BorderRadius.circular(HRadii.input),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 88,
            height: 96,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 30, color: c),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: enabled ? HColors.text : HColors.dim,
                  ),
                ),
                Text(hint, style: const TextStyle(fontSize: 11, color: HColors.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
