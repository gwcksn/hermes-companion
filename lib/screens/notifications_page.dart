import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/notifications/notifications_provider.dart';
import '../data/notifications/phone_notification.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// Fourth panel page (after Weather): live phone notifications, since the
/// immersive bedside display hides the system shade.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage>
    with WidgetsBindingObserver {
  /// Key of the row whose Open / Dismiss actions are showing.
  String? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permission is granted in system settings; re-check on return.
    if (state == AppLifecycleState.resumed) ref.read(notificationsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final notif = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);

    if (!notif.granted && !notif.loading) {
      return _Message(
        title: 'Notifications are off',
        detail: 'Allow notification access to see phone alerts here',
        actionLabel: 'Enable access',
        onAction: notifier.openSettings,
      );
    }
    if (notif.loading) return const _Message(title: 'Checking notifications…');
    if (notif.items.isEmpty) {
      return const _Message(title: 'All caught up', detail: 'New phone alerts show up here');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: Row(
            children: [
              Text('Notifications (${notif.items.length})', style: hText(15)),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: notifier.dismissAll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Semantics(
                    button: true,
                    label: 'Dismiss all notifications',
                    child: Text('Dismiss all', style: hText(13, color: HColors.peach)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: notif.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final n = notif.items[i];
              return _Row(
                n,
                selected: _selected == n.key,
                onTap: () => setState(() => _selected = _selected == n.key ? null : n.key),
                onOpen: () {
                  setState(() => _selected = null);
                  notifier.openApp(n);
                },
                onDismiss: () {
                  setState(() => _selected = null);
                  notifier.dismiss(n);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(
    this.n, {
    required this.selected,
    required this.onTap,
    required this.onOpen,
    required this.onDismiss,
  });

  final PhoneNotification n;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${n.appName}, ${n.displayTitle}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? HColors.surfaceActive : HColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              _Icon(n),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.appName,
                            style: hText(12, color: HColors.muted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          opacity: selected ? 0 : 1,
                          child: Text(_time(n.whenMs), style: hText(12, color: HColors.muted)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      n.displayTitle,
                      style: hText(14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (n.text.isNotEmpty)
                      Text(
                        n.text,
                        style: hText(12, color: HColors.body, weight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Reveal from the left edge: the slot grows rightwards while the
              // buttons fade in, so the text column shrinks smoothly.
              ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.centerLeft,
                  child: selected
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 8),
                            _ActionButton('Open', color: HColors.peach, textColor: HColors.onPeach, onTap: onOpen),
                            const SizedBox(width: 6),
                            _ActionButton(
                              'Dismiss',
                              color: HColors.coral.withValues(alpha: 0.25),
                              textColor: HColors.coral,
                              onTap: onDismiss,
                            ),
                          ],
                        )
                      : const SizedBox(width: 0, height: 0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(this.label, {required this.color, required this.textColor, required this.onTap});

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Container(
          height: HSizes.minTouch,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(HRadii.button)),
          child: Text(label, style: hText(13, color: textColor)),
        ),
      ),
    );
  }
}

class _Icon extends StatelessWidget {
  const _Icon(this.n);

  final PhoneNotification n;

  @override
  Widget build(BuildContext context) {
    final b64 = n.iconB64;
    Widget child;
    if (b64 != null && b64.isNotEmpty) {
      try {
        child = ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Image.memory(
            base64Decode(b64),
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _Fallback(n),
          ),
        );
      } catch (_) {
        child = _Fallback(n);
      }
    } else {
      child = _Fallback(n);
    }
    return SizedBox.square(dimension: 40, child: child);
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback(this.n);

  final PhoneNotification n;

  @override
  Widget build(BuildContext context) {
    final letter = n.appName.isEmpty ? '•' : n.appName.characters.first.toUpperCase();
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: HColors.surfaceActive,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(letter, style: hDisplay(18, color: HColors.peach)),
    );
  }
}

String _time(int whenMs) {
  if (whenMs <= 0) return '';
  final t = DateTime.fromMillisecondsSinceEpoch(whenMs);
  return DateFormat.Hm().format(t);
}

class _Message extends StatelessWidget {
  const _Message({required this.title, this.detail, this.actionLabel, this.onAction});

  final String title;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: hText(20)),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(detail!, style: hText(13, color: HColors.muted), textAlign: TextAlign.center),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAction,
              child: Container(
                height: HSizes.minTouch,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: HColors.peach,
                  borderRadius: BorderRadius.circular(HRadii.button),
                ),
                child: Semantics(
                  button: true,
                  label: actionLabel,
                  child: Text(actionLabel!, style: hText(15, color: HColors.onPeach)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
