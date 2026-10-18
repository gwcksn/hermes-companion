import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_companion/data/auth/credential_store.dart';
import 'package:hermes_companion/data/hermes_client.dart';

import 'fakes/fake_hermes.dart';

const _url = 'https://bash.example.ts.net';

Matcher _kind(HermesErrorKind k) => throwsA(isA<HermesError>().having((e) => e.kind, 'kind', k));

void main() {
  test('normalizes the address the owner types', () {
    expect(normalizeServerUrl('bash.example.ts.net/'), _url);
    expect(normalizeServerUrl('  https://bash.example.ts.net///  '), _url);
    expect(normalizeServerUrl('http://100.64.0.1:9119'), 'http://100.64.0.1:9119');
    expect(normalizeServerUrl(''), isNull);
    expect(normalizeServerUrl('ftp://x'), isNull);
  });

  test('profile query is omitted for default', () {
    expect(profileQuery('default'), isEmpty);
    expect(profileQuery('work'), {'profile': 'work'});
  });

  test('parses Set-Cookie and drops deletions', () {
    expect(parseSetCookies(['a=1; Path=/', 'b=2; HttpOnly', 'a=3']), {'a': '3', 'b': '2'});
    expect(parseSetCookies(['a=1', 'a=; Max-Age=0']), isEmpty);
  });

  test('status reads version, password support and profiles', () async {
    final s = await fakeClient(_url, MemoryCredentialStore(), FakeHermes()).status();
    expect(s.summary, 'Reachable. Hermes 0.21.6, gateway running');
    expect(s.passwordLogin, isTrue);
    expect(s.profiles, ['default', 'work', 'personal']);
  });

  test('login stores the session cookie; authed calls send it', () async {
    final store = MemoryCredentialStore();
    final server = FakeHermes();
    final c = fakeClient(_url, store, server);
    await store.save(const Credentials(server: _url, username: 'admin', password: 'secret'));
    await c.login('admin', 'secret');
    expect(store.cookies, {'hermes_session': 's1'});
    expect(await c.modelName('default'), 'hermes-pro');
    expect(await c.modelName('work'), 'work-model');
    expect(server.requests.last.uri.queryParameters['profile'], 'work');
  });

  test('wrong password is reported as bad credentials', () async {
    final c = fakeClient(_url, MemoryCredentialStore(), FakeHermes());
    await expectLater(c.login('admin', 'nope'), _kind(HermesErrorKind.badCredentials));
  });

  test('expired session: signs in again silently with stored credentials, once', () async {
    final store = MemoryCredentialStore();
    final server = FakeHermes();
    await store.save(const Credentials(server: _url, username: 'admin', password: 'secret'));
    await fakeClient(_url, store, server).login('admin', 'secret');

    server.sessionValue = 's2'; // server restarted / session expired
    final fresh = fakeClient(_url, store, server); // e.g. after an app restart
    expect(await fresh.modelName('default'), 'hermes-pro');
    expect(server.logins, 2);
    expect(store.cookies, {'hermes_session': 's2'});
  });

  test('changed password on the server reads as signed out', () async {
    final store = MemoryCredentialStore();
    await store.save(const Credentials(server: _url, username: 'admin', password: 'old'));
    final c = fakeClient(_url, store, FakeHermes(password: 'new'));
    await expectLater(c.modelName('default'), _kind(HermesErrorKind.signedOut));
  });

  test('unreachable server', () async {
    final c = fakeClient(_url, MemoryCredentialStore(), FakeHermes(reachable: false));
    await expectLater(c.status(), _kind(HermesErrorKind.unreachable));
  });
}
