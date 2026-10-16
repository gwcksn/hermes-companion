import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/hermes_client.dart';
import '../../data/settings_store.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../home_shell.dart';
import 'setup2_signin.dart';
import 'setup_frame.dart';

/// Step 1: Hermes address, validated with the public GET /api/status.
class Setup1Server extends ConsumerStatefulWidget {
  const Setup1Server({super.key});

  @override
  ConsumerState<Setup1Server> createState() => _Setup1ServerState();
}

class _Setup1ServerState extends ConsumerState<Setup1Server> {
  late final _addr = TextEditingController(text: ref.read(settingsProvider).serverUrl);
  bool _busy = false;
  String? _ok;
  String? _error;

  @override
  void dispose() {
    _addr.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final url = normalizeServerUrl(_addr.text);
    if (url == null) {
      setState(() {
        _ok = null;
        _error = const HermesError(HermesErrorKind.invalidUrl).message;
      });
      return;
    }
    setState(() {
      _busy = true;
      _ok = null;
      _error = null;
    });
    try {
      final client = ref.read(hermesClientFactoryProvider)(url);
      final status = await client.status();
      if (!mounted) return;
      if (status.authRequired && !status.passwordLogin) {
        setState(() => _error = 'This dashboard has no username/password sign-in');
        return;
      }
      _addr.text = url;
      setState(() => _ok = status.summary);
      await Navigator.of(context).push(fadeRoute(Setup2SignIn(client: client, status: status)));
    } on HermesError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SetupFrame(
      step: 1,
      caption: "Let's connect",
      title: 'Find your Hermes',
      body: 'Type the address you use to open the Hermes dashboard in a browser. No port number needed.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LabeledField(
            label: 'Hermes address',
            controller: _addr,
            hint: 'https://your-hermes.ts.net',
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _busy ? null : _next(),
          ),
          const SizedBox(height: 10),
          if (_busy)
            const StatusLine('Checking…', dotColor: HColors.muted)
          else if (_error != null)
            StatusLine(_error!, dotColor: HColors.coral, textColor: HColors.coral)
          else if (_ok != null)
            StatusLine(_ok!, textColor: HColors.mint)
          else
            const SizedBox(height: 18),
        ],
      ),
      actions: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          PillButton('Next', padding: const EdgeInsets.symmetric(horizontal: 32), onPressed: _busy ? null : _next),
        ],
      ),
    );
  }
}
