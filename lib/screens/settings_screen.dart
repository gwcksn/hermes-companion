import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../avatar/avatar_state.dart';
import '../data/auth/credential_store.dart';
import '../data/connection.dart';
import '../data/google/google_client.dart';
import '../data/google/workspace_provider.dart';
import '../data/hermes_client.dart';
import '../data/notifications/notifications_provider.dart';
import '../data/settings_store.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/frame.dart';
import '../widgets/icons.dart';
import 'home_shell.dart';
import 'setup/setup1_server.dart';

/// Connection settings: server, account, profile, screen switches.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final AppSettings _initial = ref.read(settingsProvider);
  late final _url = TextEditingController(text: _initial.serverUrl);
  final _account = TextEditingController(text: '…');
  late final _profile = TextEditingController(text: _initial.profile);
  late bool _keepOn = _initial.keepScreenOn;
  late bool _dim = _initial.dimAtNight;
  late bool _readAloud = _initial.readAloud;
  List<String> _profiles = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    final creds = await ref.read(credentialStoreProvider).read(_initial.serverUrl);
    if (mounted) _account.text = creds == null ? 'Signed out' : 'Signed in as ${creds.username}';
    try {
      final status = await ref.read(hermesClientProvider)?.status();
      if (mounted && status != null) setState(() => _profiles = status.profiles);
    } on HermesError {
      // Profile list stays as-is; the field still shows the saved profile.
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _account.dispose();
    _profile.dispose();
    super.dispose();
  }

  void _toast(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: HColors.surfaceActive,
          content: Text(text, style: hText(14, color: error ? HColors.coral : HColors.mint)),
        ),
      );
  }

  Future<void> _pickProfile() async {
    final options = _profiles.isEmpty ? [_profile.text] : _profiles;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final picked = await showMenu<String>(
      context: context,
      color: HColors.surfaceActive,
      position: RelativeRect.fromLTRB(box.size.width - 200, 150, 20, 0),
      items: [
        for (final p in options)
          PopupMenuItem(
            value: p,
            child: Text(p, style: hText(15)),
          ),
      ],
    );
    if (picked != null) setState(() => _profile.text = picked);
  }

  Future<void> _test() async {
    final url = normalizeServerUrl(_url.text);
    if (url == null) return _toast(const HermesError(HermesErrorKind.invalidUrl).message, error: true);
    setState(() => _busy = true);
    try {
      final client = ref.read(hermesClientFactoryProvider)(url);
      final status = await client.status();
      if (url != _initial.serverUrl) {
        _toast('${status.summary}. Save to sign in to it');
      } else {
        final model = await client.modelName(_profile.text);
        _toast('Connected to ${_profile.text}${model == null ? '' : ', model $model'}');
      }
    } on HermesError catch (e) {
      _toast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final url = normalizeServerUrl(_url.text);
    if (url == null) return _toast(const HermesError(HermesErrorKind.invalidUrl).message, error: true);
    final notifier = ref.read(settingsProvider.notifier);
    final next = ref
        .read(settingsProvider)
        .copyWith(serverUrl: url, profile: _profile.text, keepScreenOn: _keepOn, dimAtNight: _dim, readAloud: _readAloud);
    if (url != _initial.serverUrl) {
      // New server: its login differs, so walk through setup again.
      await ref.read(credentialStoreProvider).clear();
      await notifier.update(next.copyWith(setupComplete: false));
      if (mounted) await Navigator.of(context).pushAndRemoveUntil(fadeRoute(const Setup1Server()), (_) => false);
      return;
    }
    await notifier.update(next);
    ref.read(connectionProvider.notifier).check();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _signOut() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: HColors.surface,
        title: Text('Sign out?', style: hDisplay(20)),
        content: Text(
          'The saved username and password are removed from this phone.',
          style: hText(15, weight: FontWeight.w600, color: HColors.body),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Cancel', style: hText(15)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Sign out', style: hText(15, color: HColors.coral)),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await ref.read(credentialStoreProvider).clear();
    await ref.read(settingsProvider.notifier).update(ref.read(settingsProvider).copyWith(setupComplete: false));
    if (mounted) await Navigator.of(context).pushAndRemoveUntil(fadeRoute(const Setup1Server()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    void back() => Navigator.of(context).pop();
    return ScreenFrame(
      state: AvatarState.idle,
      caption: "Let's connect",
      panelPadding: const EdgeInsets.fromLTRB(8, 0, 20, 12),
      panel: Column(
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                IconTap(icon: HIcon.arrowLeft, color: HColors.text, semanticLabel: 'Back to chat', onPressed: back),
                const SizedBox(width: 4),
                Text('Connection', style: hDisplay(20)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: FlexibleScroll(
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Column(
                  children: [
                    LabeledField(label: 'Server URL', controller: _url, keyboardType: TextInputType.url),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: LabeledField(label: 'Account', controller: _account, readOnly: true, onTap: _signOut),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: LabeledField(
                            label: 'Profile',
                            controller: _profile,
                            readOnly: true,
                            onTap: _pickProfile,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SwitchPill(
                            label: 'Keep screen on',
                            value: _keepOn,
                            onChanged: (v) => setState(() => _keepOn = v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SwitchPill(
                            label: 'Dim at night',
                            value: _dim,
                            onChanged: (v) => setState(() => _dim = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SwitchPill(
                            label: 'Read replies aloud',
                            value: _readAloud,
                            onChanged: (v) => setState(() => _readAloud = v),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: PillButton(
                            'Notification access',
                            style: PillStyle.secondaryMint,
                            expand: true,
                            onPressed: () async {
                              try {
                                await ref.read(notificationsBridgeProvider).openSettings();
                              } catch (_) {}
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: PillButton(
                            _busy ? 'Testing…' : 'Test connection',
                            style: PillStyle.secondaryMint,
                            expand: true,
                            onPressed: _busy ? null : _test,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Builder(
                            builder: (_) {
                              final ws = ref.watch(workspaceProvider);
                              final connected = !(ws is AsyncError && ws.error is GoogleSignedOut);
                              return PillButton(
                                connected ? 'Disconnect Google' : 'Connect Google',
                                style: PillStyle.secondaryMint,
                                expand: true,
                                onPressed: () async {
                                  final n = ref.read(workspaceProvider.notifier);
                                  try {
                                    await (connected ? n.disconnect() : n.connect());
                                  } catch (_) {}
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [Expanded(child: PillButton('Save and connect', expand: true, onPressed: _save))],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
