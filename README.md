# Hermes Companion

> A landscape-only bedside companion screen for a self-hosted [Hermes Agent](https://hermes-agent.nousresearch.com), built with Flutter for Android and tuned for a docked Samsung Galaxy S8.

It renders a 740×360 design canvas with an animated chat-owl avatar on the left and a chat / clock / weather panel on the right. It signs into the Hermes dashboard with a stored session cookie, holds a JSON-RPC WebSocket open for realtime chat, and stays on screen as a peaceful always-on display.

<p align="left">
  <img alt="Flutter"      src="https://img.shields.io/badge/Flutter-Android-02569B?logo=flutter&logoColor=white" />
  <img alt="Dart 3.13"    src="https://img.shields.io/badge/Dart-3.13%2B-0175C2?logo=dart&logoColor=white" />
  <img alt="Riverpod 3"   src="https://img.shields.io/badge/State-Riverpod%203-3178C6" />
  <img alt="Landscape"    src="https://img.shields.io/badge/Orientation-Landscape%20only-orange" />
  <img alt="Hermes 0.21"  src="https://img.shields.io/badge/Hermes%20server-0.21.6-9F70FD" />
</p>

## What it is

A single-purpose Flutter app whose only job is to live on a bedside shelf:

| Surface | What it shows |
|---|---|
| Avatar stage (268 dp) | 12 hand-ported animations of `assets/avatar/*.svg`, each driven by a tiny CSS-keyframes engine |
| Chat page | One ongoing conversation per Hermes profile, with streamed replies, an approval card and a clarify card |
| Clock page | 24 h digital clock, date, Yogyakarta · WIB chip |
| Weather page | Open-Meteo current + 4 hours, in °C |
| Connection settings | Server URL, account, profile, keep-screen-on, dim-at-night |
| First-run wizard | Address → sign in (or sign out) → profile pick |

The owner reaches their `hermes serve` (dashboard port 9119) over a Tailscale tunnel; on the S8, immersive sticky landscape + wakelock are mandatory and that's how the app boots.

## Architecture

State is Riverpod 3 (`Notifier` / `NotifierProvider`). All non-secret settings live in `SharedPreferences` (loaded once in `main()` and injected via `sharedPrefsProvider`); usernames, passwords, and session cookies live in `flutter_secure_storage` (Android Keystore-backed, keyed to the server URL).

```
                          ┌──────────────────────────────────────────────────┐
                          │                 HermesApp (app.dart)            │
                          │  locks landscape, immersive, wraps every route  │
                          │  in ScaledStage → 740×360 canvas via FittedBox  │
                          └────────────────────────┬─────────────────────────┘
                                                   │
                ┌──────────────────────────────────┼──────────────────────────────────┐
                │                                  │                                  │
        ┌───────▼────────┐                ┌────────▼────────┐                ┌───────▼───────┐
        │   Setup flow   │                │    HomeShell    │                │ SettingsScreen│
        │ 1/2/3 wizard   │                │ PageView: Chat/ │                │ server URL,   │
        │ (decides once) │                │  Clock/Weather  │                │ profile,      │
        └────────────────┘                │ + avatar stage  │                │ keep-screen-on│
                │                          └────────┬────────┘                └───────────────┘
                │                                   │
   ┌────────────┼───────────────────────────────────┼────────────────────────────┐
   │                          Riverpod providers                                  │
   │  sharedPrefsProvider     credentialStoreProvider     hermesClientProvider    │
   │          │                       │                           │                │
   │  SettingsNotifier          CredentialStore           HermesClient (Dio)     │
   │  (server, profile,         (cookies, username,        ↳ password login →    │
   │   keep/dim, setupComplete)  password per server)        session cookie       │
   │                                                            ↳ status(),        │
   │  chatProvider (ChatController) ─→ GatewaySocket ──→ wss /api/ws?ticket=…     │
   │  connectionProvider         polls /api/status + /api/model/info every 1 min  │
   │  avatarProvider             12 states (engine + scenes), driven by chat events │
   │  weatherProvider            Open-Meteo cache + 30 min refresh                │
   └────────────────────────────────────────────────────────────────────────────────┘
```

The realtime chat frame flow (verified against Hermes 0.21.6 in `docs/hermes-protocol.md`):

```
client                                  server  (hermes serve :9119)
  │  POST /api/auth/ws-ticket  (cookie)        │
  │ ────────────────────────────────────────► │  → {ticket}
  │
  │  wss://…/api/ws?ticket=…                 │
  │ ────────────────────────────────────────► │  gateway.ready
  │ ◄──────────────────────────────────────── │
  │  client.capabilities {server_requests}   │
  │ ────────────────────────────────────────► │  → {server_requests:…}
  │  session.create | session.resume          │
  │ ────────────────────────────────────────► │  → {session_id, stored_session_id}
  │  prompt.submit {session_id, text}         │
  │ ────────────────────────────────────────► │  → {status: streaming}
  │ ◄──── event message.start / tool.* / delta / complete / approval / clarify
  │  gateway.ping  every ~15 s                │
```

## Repository layout

```
lib/
  main.dart, app.dart, layout/           boot, theme, design-canvas scaling
  theme/{tokens.dart, app_theme.dart}    mirrors tokens.json 1:1; Material 3 dark
  avatar/                                12 hand-ported scenes + keyframes engine
  data/                                  settings, auth, REST, WS gateway, weather
    hermes_client.dart                   Dio + cookie auth + one-shot re-login
    connection.dart                      1-min /api/status + /api/model/info
    gateway/{gateway_socket, chat_controller}.dart
                                         JSON-RPC 2.0 + avatar/event mapping
    weather.dart, weather_provider.dart  Open-Meteo, Yogyakarta, °C, WIB
  screens/                               home_shell + chat/clock/weather/listening/settings
  screens/setup/                         3 first-run wizard screens
  widgets/                               frame, common, bubbles, markdown_text, icons

assets/avatar/*.svg  +  gallery.html     source of truth for the 12 states
design/*.dc.html                         Claude Design source (use the live canvas link)
docs/hermes-protocol.md                  verified server protocol (REST + /api/ws)
tokens.json                              colors, fonts, radii, sizes, state order
test/fakes/                              FakeHermes (REST), FakeGateway (WS), MemoryCredentialStore
test/fixtures/open_meteo.dart            trimmed real /v1/forecast payload
```

## Getting started

You need the Flutter SDK on `^3.13.4`, an Android device or emulator, and (for a real run) a `hermes serve` reachable over Tailscale.

```bash
flutter pub get
flutter analyze            # flutter_lints; build/ and android/ are excluded
flutter test               # all tests (no network required)
flutter run                # locks to landscape; uses settings from a previous setup
flutter build apk          # release APK
flutter test test/chat_controller_test.dart --plain-name "connects with a fresh ticket"
```

First launch runs the wizard (address → sign in → profile). On later launches `app.dart` decides Setup vs HomeShell once from `settings.setupComplete` and never re-asks.

There is **no** codegen step (`build_runner`, `freezed`, `json_serializable`, etc.), no monorepo tool, no pre-commit hook.

## Conventions that matter

| Area | Rule of thumb |
|---|---|
| Dimensions | Live in the **740×360 design canvas**. `MediaQuery.size` is already `HSizes.designSize` — don't reach for the physical screen. Copy measurements from `design/*.dc.html` verbatim. |
| Tokens | `tokens.json` ↔ `lib/theme/tokens.dart` are checked by a test. Change both or neither. |
| State | Riverpod 3 `Notifier` / `NotifierProvider`. Inject `SharedPreferences`; never `await SharedPreferences.getInstance()` in a provider. |
| Secrets vs settings | Keystore for `username` / `password` / session cookies (keyed to server URL). `SharedPreferences` for `serverUrl`, `profile`, `keepScreenOn`, `dimAtNight`, `setupComplete`, plus `chat.session.<server>\|<profile>`. |
| Avatar | The SVGs animate with CSS `@keyframes`; `flutter_svg` cannot replay them. The 12 scenes in `lib/avatar/scenes.dart` are 1:1 ports. Compare against the matching SVG (or `assets/avatar/gallery.html`) before editing one. |
| Realtime chat | Mint a 30 s ticket immediately before every (re)connect, then `client.capabilities {server_requests: true}`, then `session.create` / `session.resume`. Without `server_requests: true`, every approval/clarify request for this client **fails fast**. |
| Profile URLs | Use `?profile=<name>` but omit the parameter for `default` (matches hermes-conduit). |
| Tests | Never hit the network. Inject `fakeClient(url, store, FakeHermes())` and `gatewayConnectorProvider = fakeGateway.connect`. Load `assets/fonts/*` and freeze avatar animation via `accessibilityFeatures(disableAnimations: true)` for widget tests. |

See `AGENTS.md` for the full list of "looks like a bug but is intentional" and the gotchas that future OpenCode sessions are most likely to get wrong.

## Testing

Tests are organized around four provider overrides:

```dart
overrides: [
  sharedPrefsProvider.overrideWithValue(prefs),                  // SharedPreferences.setMockInitialValues({...})
  credentialStoreProvider.overrideWithValue(store),             // MemoryCredentialStore
  hermesClientFactoryProvider.overrideWithValue(                // fakeClient(url, store, FakeHermes())
      (url) => fakeClient(url, store, server)),
  gatewayConnectorProvider.overrideWithValue(gateway.connect),  // FakeGateway().connect
  weatherClientProvider.overrideWithValue(_FixtureWeather()),   // open_meteo.dart
]
```

Fixtures live in `test/fakes/{fake_hermes.dart,fake_gateway.dart}` and `test/fixtures/open_meteo.dart`.

## Pointers

- [`HANDOFF.md`](HANDOFF.md) — original design brief: screens, avatar state triggers, open decisions.
- [`docs/hermes-protocol.md`](docs/hermes-protocol.md) — verified REST + `/api/ws` JSON-RPC protocol; **read before touching the gateway, REST, or avatar** code.
- [`tokens.json`](tokens.json) and [`lib/theme/tokens.dart`](lib/theme/tokens.dart) — single sources of truth for the visual language.
- [`design/*.dc.html`](design/) — exact measurements and colors per screen (need the Claude Design runtime to render).
- [`AGENTS.md`](AGENTS.md) — short, repo-specific agent notes; intended for OpenCode and similar sessions.
- [`CLAUDE.md`](CLAUDE.md) — overlapping agent guidance from the previous Claude Code setup.
- [Hermes Agent docs](https://hermes-agent.nousresearch.com/docs/user-guide/desktop) — what the companion talks to.
- [hermes-conduit](https://github.com/kaishi00/hermes-conduit) — iOS client for the same dashboard; the WS protocol was first reverse-engineered from here.

## License & status

Released under the [MIT License](LICENSE). Designed around a single owner's bedside display, so it is not a general-purpose Hermes client.
