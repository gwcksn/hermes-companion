import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Dashboard login for one server, as entered by the owner.
class Credentials {
  const Credentials({required this.server, required this.username, required this.password});

  final String server;
  final String username;
  final String password;
}

/// Username, password and session cookies, encrypted with a key held in the
/// Android Keystore (flutter_secure_storage). Bound to the server they were
/// entered for: a different server URL reads as "no credentials".
class CredentialStore {
  CredentialStore([FlutterSecureStorage? storage]) : _s = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _s;

  static const _server = 'hermes.server';
  static const _username = 'hermes.username';
  static const _password = 'hermes.password';
  static const _cookies = 'hermes.cookies';

  Future<Credentials?> read(String server) async {
    final values = await _s.readAll();
    if (values[_server] != server) return null;
    final user = values[_username], pass = values[_password];
    if (user == null || pass == null) return null;
    return Credentials(server: server, username: user, password: pass);
  }

  Future<void> save(Credentials c) async {
    await _s.write(key: _server, value: c.server);
    await _s.write(key: _username, value: c.username);
    await _s.write(key: _password, value: c.password);
  }

  Future<Map<String, String>> readCookies(String server) async {
    final values = await _s.readAll();
    if (values[_server] != server || values[_cookies] == null) return {};
    return (jsonDecode(values[_cookies]!) as Map<String, dynamic>).cast<String, String>();
  }

  Future<void> saveCookies(Map<String, String> cookies) => _s.write(key: _cookies, value: jsonEncode(cookies));

  Future<void> clear() => _s.deleteAll();
}

final credentialStoreProvider = Provider<CredentialStore>((ref) => CredentialStore());
