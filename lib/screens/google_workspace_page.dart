import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/google/google_client.dart';
import '../data/google/workspace_item.dart';
import '../data/google/workspace_provider.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// Fifth panel page: Google Calendar events and Tasks, split into Today and Next 7 days.
class GoogleWorkspacePage extends ConsumerStatefulWidget {
  const GoogleWorkspacePage({super.key});

  @override
  ConsumerState<GoogleWorkspacePage> createState() => _GoogleWorkspacePageState();
}

class _GoogleWorkspacePageState extends ConsumerState<GoogleWorkspacePage> {
  int _tab = 0;
  bool _connecting = false;
  String? _failure;

  /// Id of the task whose Done / Cancel buttons are showing.
  String? _selected;
  String? _notice;

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _failure = null;
    });
    try {
      await ref.read(workspaceProvider.notifier).connect();
    } catch (e) {
      // Cancelled or failed: stay on the Connect state and say why.
      if (mounted) setState(() => _failure = e.toString());
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _done(WorkItem task) async {
    setState(() => _selected = null);
    try {
      await ref.read(workspaceProvider.notifier).completeTask(task);
    } catch (e) {
      if (!mounted) return;
      setState(() => _notice = e is GoogleSignedOut ? 'Reconnect Google to complete tasks' : "Couldn't complete task");
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _notice = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(workspaceProvider.notifier);
    return switch (ref.watch(workspaceProvider)) {
      AsyncData(:final value) => _Content(
        data: value,
        tab: _tab,
        onTab: (i) => setState(() {
          _tab = i;
          _selected = null;
        }),
        selected: _selected,
        notice: _notice,
        onSelect: (id) => setState(() => _selected = _selected == id ? null : id),
        onDone: _done,
      ),
      AsyncError(:final error) when error is GoogleSignedOut => PanelMessage(
        title: 'Google not connected',
        detail: _failure ?? 'Connect to see your calendar and tasks',
        actionLabel: _connecting ? 'Connecting…' : 'Connect Google',
        onAction: _connecting ? null : _connect,
      ),
      AsyncError(:final error) => PanelMessage(
        title: 'Google unavailable',
        detail: error is DioException ? 'Check the connection. Tap to try again' : 'Tap to try again',
        onTap: notifier.refresh,
      ),
      _ => const PanelMessage(title: 'Loading your day…'),
    };
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.data,
    required this.tab,
    required this.onTab,
    required this.selected,
    required this.notice,
    required this.onSelect,
    required this.onDone,
  });

  final WorkspaceData data;
  final int tab;
  final ValueChanged<int> onTab;
  final String? selected;
  final String? notice;
  final ValueChanged<String> onSelect;
  final ValueChanged<WorkItem> onDone;

  Widget _row(WorkItem i, DateTime now, {bool showTime = false}) => _ItemRow(
    i,
    now: now,
    showTime: showTime,
    selected: i.id != null && i.id == selected,
    onTap: i.kind == WorkKind.task && i.id != null ? () => onSelect(i.id!) : null,
    onDone: () => onDone(i),
    onCancel: () => onSelect(i.id!),
  );

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final List<Widget> rows;
    if (tab == 0) {
      final today = data.today(now);
      rows = [for (final i in today) _row(i, now)];
    } else {
      rows = [
        for (final e in data.next(now).entries) ...[
          _DayHeader(e.key, now: now),
          for (final i in e.value) _row(i, now, showTime: true),
        ],
      ];
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: Row(
            children: [
              SegmentedPill(labels: const ['Today', 'Next'], selected: tab, onChanged: onTab),
              const Spacer(),
              Text(
                notice ?? DateFormat('EEE, d MMM').format(now),
                style: hText(13, color: notice == null ? HColors.muted : HColors.coral),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PanelMessage(
                    title: tab == 0 ? 'Nothing today' : 'Nothing coming up',
                    detail: tab == 0 ? 'No events or tasks for today' : 'The next 7 days are clear',
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => rows[i],
                ),
        ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader(this.day, {required this.now});

  final DateTime day;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final isTomorrow = day == dayOf(now).add(const Duration(days: 1));
    final label = isTomorrow ? 'Tomorrow' : DateFormat('EEEE, d MMM').format(day);
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4),
      child: Text(label, style: hText(13, color: HColors.peach)),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow(
    this.item, {
    required this.now,
    required this.selected,
    required this.onTap,
    required this.onDone,
    required this.onCancel,
    this.showTime = false,
  });

  final WorkItem item;
  final DateTime now;
  final bool showTime;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback onDone;
  final VoidCallback onCancel;

  String get _when {
    if (!item.hasDate) return 'No date';
    if (item.kind == WorkKind.task) {
      return item.start.isBefore(dayOf(now)) ? 'Overdue · ${DateFormat('d MMM').format(item.start)}' : 'Due';
    }
    if (item.allDay) return 'All day';
    final hm = DateFormat.Hm();
    final end = item.end;
    return end == null ? hm.format(item.start) : '${hm.format(item.start)} – ${hm.format(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final isEvent = item.kind == WorkKind.event;
    final color = isEvent ? HColors.lavender : HColors.mint;
    final loc = item.location;
    return Semantics(
      button: onTap != null,
      label: '${isEvent ? 'Event' : 'Task'}, ${item.title}, $_when',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? HColors.surfaceActive : HColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 36,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEvent ? _when : 'Task · $_when',
                      style: hText(
                        12,
                        color: item.kind == WorkKind.task && item.hasDate && item.start.isBefore(dayOf(now))
                            ? HColors.coral
                            : HColors.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(item.title, style: hText(14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (loc != null && loc.isNotEmpty)
                      Text(
                        loc,
                        style: hText(12, color: HColors.body, weight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Reveal from the left edge, like the notification actions.
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
                            _ActionButton('Done', color: HColors.peach, textColor: HColors.onPeach, onTap: onDone),
                            const SizedBox(width: 6),
                            _ActionButton(
                              'Cancel',
                              color: HColors.coral.withValues(alpha: 0.25),
                              textColor: HColors.coral,
                              onTap: onCancel,
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
