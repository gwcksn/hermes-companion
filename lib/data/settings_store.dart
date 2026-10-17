import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loaded once in main() so settings are available synchronously at startup.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('override in main()'),
);

class AppSettings {
  const AppSettings({
    this.serverUrl = '',
    this.profile = 'default',
    this.keepScreenOn = true,
    this.dimAtNight = true,
    this.readAloud = false,
    this.setupComplete = false,
    this.fullscreenPanel = false,
    this.quietPet = false,
    this.avatarPosX,
    this.avatarPosY,
  });

  final String serverUrl;
  final String profile;
  final bool keepScreenOn;
  final bool dimAtNight;
  final bool readAloud;
  final bool setupComplete;

  /// Panel fills the screen and the avatar floats over it.
  final bool fullscreenPanel;

  /// Hides all pet UI (stats strip, care sheet) so the screen stays a clean clock.
  final bool quietPet;

  /// Floating avatar position as a 0..1 fraction of the free area; null = default spot.
  final double? avatarPosX;
  final double? avatarPosY;

  AppSettings copyWith({
    String? serverUrl,
    String? profile,
    bool? keepScreenOn,
    bool? dimAtNight,
    bool? readAloud,
    bool? setupComplete,
    bool? fullscreenPanel,
    bool? quietPet,
  }) => AppSettings(
    serverUrl: serverUrl ?? this.serverUrl,
    profile: profile ?? this.profile,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    dimAtNight: dimAtNight ?? this.dimAtNight,
    readAloud: readAloud ?? this.readAloud,
    setupComplete: setupComplete ?? this.setupComplete,
    fullscreenPanel: fullscreenPanel ?? this.fullscreenPanel,
    quietPet: quietPet ?? this.quietPet,
    avatarPosX: avatarPosX,
    avatarPosY: avatarPosY,
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
  static const _fullscreen = 'settings.fullscreenPanel';
  static const _quietPet = 'settings.quietPet';
  static const _avatarX = 'settings.avatarPosX';
  static const _avatarY = 'settings.avatarPosY';

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
      fullscreenPanel: p.getBool(_fullscreen) ?? false,
      quietPet: p.getBool(_quietPet) ?? false,
      avatarPosX: p.getDouble(_avatarX),
      avatarPosY: p.getDouble(_avatarY),
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

  Future<void> setFullscreen(bool on) async {
    state = state.copyWith(fullscreenPanel: on);
    await _prefs.setBool(_fullscreen, on);
  }

  Future<void> setQuietPet(bool on) async {
    state = state.copyWith(quietPet: on);
    await _prefs.setBool(_quietPet, on);
  }

  Future<void> setAvatarPos(double x, double y) async {
    state = AppSettings(
      serverUrl: state.serverUrl,
      profile: state.profile,
      keepScreenOn: state.keepScreenOn,
      dimAtNight: state.dimAtNight,
      readAloud: state.readAloud,
      setupComplete: state.setupComplete,
      fullscreenPanel: state.fullscreenPanel,
      quietPet: state.quietPet,
      avatarPosX: x,
      avatarPosY: y,
    );
    await Future.wait([_prefs.setDouble(_avatarX, x), _prefs.setDouble(_avatarY, y)]);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
