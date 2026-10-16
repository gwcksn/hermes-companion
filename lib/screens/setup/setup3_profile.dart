import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/hermes_client.dart';
import '../../data/settings_store.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../home_shell.dart';
import 'setup_frame.dart';

/// Step 3: profile picker. The list comes from /api/status; picking one confirms
/// the session with an authenticated model-info call.
class Setup3Profile extends ConsumerStatefulWidget {
  const Setup3Profile({super.key, required this.client, required this.status});

  final HermesClient client;
  final HermesStatus status;

  @override
  ConsumerState<Setup3Profile> createState() => _Setup3ProfileState();
}

class _Setup3ProfileState extends ConsumerState<Setup3Profile> {
  late final List<String> _profiles = widget.status.profiles.isEmpty ? const ['default'] : widget.status.profiles;
  late String _selected = _profiles.contains('default') ? 'default' : _profiles.first;
  String? _line;
  bool _ok = false;
  int _checkId = 0;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final id = ++_checkId;
    final profile = _selected;
    setState(() {
      _line = null;
      _ok = false;
    });
    try {
      final model = await widget.client.modelName(profile);
      if (!mounted || id != _checkId) return;
      setState(() {
        _ok = true;
        _line = 'Connected. Talking to $profile${model == null ? '' : ', model $model'}';
      });
    } on HermesError catch (e) {
      if (mounted && id == _checkId) setState(() => _line = e.message);
    }
  }

  Future<void> _finish() async {
    final settings = ref.read(settingsProvider.notifier);
    await settings.update(
      ref.read(settingsProvider).copyWith(serverUrl: widget.client.baseUrl, profile: _selected, setupComplete: true),
    );
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(fadeRoute(const HomeShell()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return SetupFrame(
      step: 3,
      caption: 'All set',
      captionColor: HColors.mint,
      glow: HColors.mintGlow,
      title: 'Choose a profile',
      body: 'Pick the Hermes profile this screen talks to. You can change it later in Connection.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            // A Wrap here over-reports its intrinsic height inside FlexibleScroll; scroll sideways instead.
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (i, p) in _profiles.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    ChoiceChipPill(
                      label: p,
                      selected: p == _selected,
                      onTap: () {
                        setState(() => _selected = p);
                        _check();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_line == null)
            StatusLine('Checking $_selected…', dotColor: HColors.muted)
          else if (_ok)
            StatusLine(_line!, textColor: HColors.mint)
          else
            StatusLine(_line!, dotColor: HColors.coral, textColor: HColors.coral),
        ],
      ),
      actions: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PillButton('Back', style: PillStyle.secondary, onPressed: () => Navigator.of(context).pop()),
          PillButton(
            'Start chatting',
            padding: const EdgeInsets.symmetric(horizontal: 32),
            onPressed: _ok ? _finish : null,
          ),
        ],
      ),
    );
  }
}
