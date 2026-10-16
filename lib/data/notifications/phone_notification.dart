/// A phone notification shown in the Notifications tab.
///
/// Field names match the maps sent by `NotifService` over
/// `hermes/notifications` so `fromMap` stays a plain cast.
class PhoneNotification {
  const PhoneNotification({
    required this.key,
    required this.packageName,
    required this.appName,
    required this.title,
    required this.text,
    required this.whenMs,
    this.iconB64,
  });

  final String key;
  final String packageName;
  final String appName;
  final String title;
  final String text;

  /// Post time as millis since epoch (from `StatusBarNotification.postTime`).
  final int whenMs;

  /// PNG of the app icon as base64, fetched lazily via `getIcon`. Null until
  /// loaded or when the package has no icon.
  final String? iconB64;

  factory PhoneNotification.fromMap(Map<String, dynamic> m) => PhoneNotification(
    key: m['key'] as String,
    packageName: (m['packageName'] as String?) ?? '',
    appName: (m['appName'] as String?)?.trim().isNotEmpty == true
        ? (m['appName'] as String)
        : (m['packageName'] as String? ?? ''),
    title: (m['title'] as String?) ?? '',
    text: (m['text'] as String?) ?? '',
    whenMs: switch (m['whenMs']) {
      final int v => v,
      final num v => v.toInt(),
      _ => 0,
    },
    iconB64: m['iconB64'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'key': key,
    'packageName': packageName,
    'appName': appName,
    'title': title,
    'text': text,
    'whenMs': whenMs,
    'iconB64': iconB64,
  };

  PhoneNotification copyWith({String? iconB64}) => PhoneNotification(
    key: key,
    packageName: packageName,
    appName: appName,
    title: title,
    text: text,
    whenMs: whenMs,
    iconB64: iconB64 ?? this.iconB64,
  );

  /// Display line when title is empty (e.g. progress-style posts).
  String get displayTitle => title.isEmpty ? appName : title;
}

/// Packages that are never shown even when clearable (shade chrome itself).
const _systemPackages = {'android', 'com.android.systemui', 'dev.gilang.hermes_companion'};

/// Hide ongoing/system noise: ongoing posts, non-clearable posts, group
/// summaries (their children are listed individually), the shade's own
/// packages, and this app. Pure so it can be unit-tested without a device.
bool isUserNotification(Map<String, dynamic> m) {
  if (m['ongoing'] == true) return false;
  if (m['groupSummary'] == true) return false;
  if (m.containsKey('clearable') && m['clearable'] == false) return false;
  final pkg = (m['packageName'] as String?) ?? '';
  if (_systemPackages.contains(pkg)) return false;
  return true;
}
