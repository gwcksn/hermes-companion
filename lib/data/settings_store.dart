import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loaded once in main() so settings are available synchronously at startup.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('override in main()'));

class AppSettings {
  const AppSettings({
    this.serverUrl = '',
    this.profile = 'default',
    this.keepScreenOn = true,
    this.dimAtNight = true,
    this.readAloud = false,
    this.setupComplete = false,
  });

  final String serverUrl;
  final String profile;
  final bool keepScreenOn;
  final bool dimAtNight;
  final bool readAloud;
  final bool setupComplete;

  AppSettings copyWith({
    String? serverUrl,
    String? profile,
    bool? keepScreenOn,
    bool? dimAtNight,
    bool? readAloud,
    bool? setupComplete,
  }) => AppSettings(
    serverUrl: serverUrl ?? this.serverUrl,
    profile: profile ?? this.profile,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    dimAtNight: dimAtNight ?? this.dimAtNight,
    readAloud: readAloud ?? this.readAloud,
    setupComplete: setupComplete ?? this.setupComplete,
  );
}

/// Non-secret settings in SharedPreferences. Credentials live in [CredentialStore].
class SettingsNotifier extends Notifier<AppSettings> {
  static const _url = 'settings.serverUrl';
  static const _profile = 'settings.profile';
  static const _keepOn = 'settings.keepScreenOn';
  static const _dim = 'settings.dimAtNight';
  static const _readAloud = 'settings.readAloud';
  static const _done = 'settings.setupComplete';

  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  @override
  AppSettings build() {
    final p = _prefs;
    return AppSettings(
      serverUrl: p.getString(_url) ?? '',
      profile: p.getString(_profile) ?? 'default',
      keepScreenOn: p.getBool(_keepOn) ?? true,
      dimAtNight: p.getBool(_dim) ?? true,
      readAloud: p.getBool(_readAloud) ?? false,
      setupComplete: p.getBool(_done) ?? false,
    );
  }

  Future<void> update(AppSettings next) async {
    state = next;
    final p = _prefs;
    await Future.wait([
      p.setString(_url, next.serverUrl),
      p.setString(_profile, next.profile),
      p.setBool(_keepOn, next.keepScreenOn),
      p.setBool(_dim, next.dimAtNight),
      p.setBool(_readAloud, next.readAloud),
      p.setBool(_done, next.setupComplete),
    ]);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
