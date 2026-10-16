import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth/credential_store.dart';
import '../../data/hermes_client.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../home_shell.dart';
import 'setup3_profile.dart';
import 'setup_frame.dart';

/// Step 2: dashboard username and password (POST /auth/password-login).
/// Saved encrypted with an Android Keystore key so the app can sign in again by itself.
class Setup2SignIn extends ConsumerStatefulWidget {
  const Setup2SignIn({super.key, required this.client, required this.status});

  final HermesClient client;
  final HermesStatus status;

  @override
  ConsumerState<Setup2SignIn> createState() => _Setup2SignInState();
}

class _Setup2SignInState extends ConsumerState<Setup2SignIn> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final user = _user.text.trim();
    final pass = _pass.text;
    if (user.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Enter your username and password');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final store = ref.read(credentialStoreProvider);
    try {
      await store.clear();
      await store.save(Credentials(server: widget.client.baseUrl, username: user, password: pass));
      await widget.client.login(user, pass);
      if (!mounted) return;
      _pass.clear();
      await Navigator.of(context).push(fadeRoute(Setup3Profile(client: widget.client, status: widget.status)));
    } on HermesError catch (e) {
      await store.clear();
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SetupFrame(
      step: 2,
      caption: 'Almost there',
      title: 'Sign in',
      body: 'Use your Hermes dashboard login. It stays encrypted on this phone so Hermes can reconnect by itself.',
      content: AutofillGroup(
        // The app keeps the login itself (Keystore), so skip Android's "Save password?" sheet.
        // Autofill can still fill these fields from a password manager.
        onDisposeAction: AutofillContextAction.cancel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: LabeledField(
                    label: 'Username',
                    controller: _user,
                    autofillHints: const [AutofillHints.username],
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LabeledField(
                    label: 'Password',
                    controller: _pass,
                    obscure: true,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _busy ? null : _signIn(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_busy)
              const StatusLine('Signing in…', dotColor: HColors.muted)
            else if (_error != null)
              StatusLine(_error!, dotColor: HColors.coral, textColor: HColors.coral)
            else
              const SizedBox(height: 18),
          ],
        ),
      ),
      actions: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PillButton('Back', style: PillStyle.secondary, onPressed: _busy ? null : () => Navigator.of(context).pop()),
          PillButton('Sign in', padding: const EdgeInsets.symmetric(horizontal: 32), onPressed: _busy ? null : _signIn),
        ],
      ),
    );
  }
}
