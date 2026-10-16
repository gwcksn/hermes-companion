/// One row on the Google Workspace page: a calendar event or a task.
enum WorkKind { event, task }

class WorkItem {
  const WorkItem({
    required this.kind,
    required this.title,
    required this.start,
    this.end,
    this.allDay = false,
    this.location,
    this.hasDate = true,
    this.id,
  });

  final WorkKind kind;
  final String title;

  /// Start for events, due date for tasks. For undated tasks this is the fetch day (see [hasDate]).
  final DateTime start;
  final DateTime? end;
  final bool allDay;
  final String? location;

  /// False for tasks with no due date.
  final bool hasDate;

  /// Google Tasks id (tasks only), needed to mark one done.
  final String? id;

  /// Calendar API `events` item (single events, so recurring ones are already expanded).
  static WorkItem? fromCalendarJson(Map<String, dynamic> j) {
    if (j['status'] == 'cancelled') return null;
    final s = j['start'] as Map<String, dynamic>?;
    final e = j['end'] as Map<String, dynamic>?;
    if (s == null) return null;
    final allDay = s['date'] != null;
    final start = allDay ? _dateOnly(s['date'] as String) : DateTime.parse(s['dateTime'] as String).toLocal();
    DateTime? end;
    if (e != null) {
      end = e['date'] != null ? _dateOnly(e['date'] as String) : DateTime.parse(e['dateTime'] as String).toLocal();
    }
    final title = (j['summary'] as String?)?.trim();
    return WorkItem(
      kind: WorkKind.event,
      title: title == null || title.isEmpty ? '(No title)' : title,
      start: start,
      end: end,
      allDay: allDay,
      location: (j['location'] as String?)?.trim(),
    );
  }

  /// Tasks API item. `due` is a date at 00:00:00Z; only the calendar day matters.
  static WorkItem? fromTaskJson(Map<String, dynamic> j, {required DateTime now}) {
    if (j['status'] == 'completed' || j['deleted'] == true) return null;
    final title = (j['title'] as String?)?.trim();
    if (title == null || title.isEmpty) return null;
    final due = j['due'] as String?;
    final day = due == null ? null : _dateOnly(due.substring(0, 10));
    return WorkItem(
      kind: WorkKind.task,
      title: title,
      start: day ?? DateTime(now.year, now.month, now.day),
      allDay: true,
      hasDate: day != null,
      id: j['id'] as String?,
    );
  }

  static DateTime _dateOnly(String s) {
    final p = s.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }
}

DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

int _order(WorkItem a, WorkItem b) {
  // All-day / dateless first, then by start time; events before tasks on ties.
  if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
  final c = a.start.compareTo(b.start);
  if (c != 0) return c;
  return a.kind.index.compareTo(b.kind.index);
}

/// Today's items: events overlapping today, tasks due today, overdue tasks and undated tasks.
List<WorkItem> bucketToday(Iterable<WorkItem> items, DateTime now) {
  final today = dayOf(now);
  final tomorrow = today.add(const Duration(days: 1));
  final out = items.where((i) {
    if (i.kind == WorkKind.task) return !i.start.isAfter(today) || !i.hasDate;
    final end = i.end ?? i.start;
    final startsBeforeEnd = i.start.isBefore(tomorrow);
    // Timed events that already ended today stay listed; all-day end dates are exclusive.
    final endsAfterStart = i.allDay ? end.isAfter(today) : !end.isBefore(today);
    return startsBeforeEnd && endsAfterStart;
  }).toList()..sort(_order);
  return out;
}

/// Items from tomorrow through [days] days ahead, grouped by day (ascending).
Map<DateTime, List<WorkItem>> groupNext(Iterable<WorkItem> items, DateTime now, {int days = 7}) {
  final first = dayOf(now).add(const Duration(days: 1));
  final last = dayOf(now).add(Duration(days: days + 1)); // exclusive
  final byDay = <DateTime, List<WorkItem>>{};
  for (final i in items) {
    if (!i.hasDate) continue;
    final d = dayOf(i.start);
    if (d.isBefore(first) || !d.isBefore(last)) continue;
    byDay.putIfAbsent(d, () => []).add(i);
  }
  final keys = byDay.keys.toList()..sort();
  return {for (final k in keys) k: byDay[k]!..sort(_order)};
}
