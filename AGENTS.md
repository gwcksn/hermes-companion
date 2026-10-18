# AGENTS.md

Short, repo-specific notes for an OpenCode session working in `hermes-companion`.
Read `HANDOFF.md` and `docs/hermes-protocol.md` before touching code; CLAUDE.md carries the same facts.

## What this repo is

A Flutter (Android) landscape companion screen for a self-hosted Hermes Agent (`hermes serve`, port 9119), reached over Tailscale. Target device is a Samsung Galaxy S8 docked as a bedside display. One project, one app (`hermes_companion`). No monorepo, no packages, no codegen, no native iOS work — `android/` and `build/` are intentionally excluded from the analyzer and not edited by hand.

## Quick verification commands

```bash
flutter pub get
flutter analyze                       # flutter_lints; build/ and android/ are excluded
flutter test                          # all tests
flutter test test/chat_controller_test.dart                  # one file
flutter test test/chat_controller_test.dart --plain-name "<name>"   # one test
flutter run                           # needs a device/emulator; app locks to landscape
flutter build apk
```

There is no `build_runner` step, no `flutter pub run` codegen, no `melos`, no pre-commit hook. CI scripts are not in the repo.

If `flutter analyze` reports only messages inside `build/` or `android/`, that is by design — those trees are excluded in `analysis_options.yaml`.

## Project layout (what each top-level path actually does)

```
lib/
  main.dart                 boots SharedPreferences, locks landscape + immersive, runs HermesApp
  app.dart                  wraps every route in ScaledStage + design-size MediaQuery
  layout/scaled_stage.dart  740x360 canvas scaled with FittedBox (HSizes.designSize)
  theme/                    tokens.dart mirrors tokens.json 1:1; app_theme.dart wires Material 3 dark
  avatar/                   12 state scene port of assets/avatar/*.svg (see below)
  data/                     hermes_client, settings_store, connection, weather, auth/, gateway/
  screens/                  HomeShell + chat/clock/weather/listening/settings + setup/ + avatar_gallery
  widgets/                  frame, common (hDisplay/hText), bubbles, markdown_text, icons, weather_icons, waveform
assets/avatar/              12 source SVGs (CSS @keyframes) + gallery.html to preview them all
design/*.dc.html            Claude Design source for every screen — read for exact sizes/colors
docs/hermes-protocol.md     verified server protocol (auth, REST, /api/ws JSON-RPC)
tokens.json                 single source for colors, fonts, radii, sizes, avatar state order
test/fakes/                 FakeHermes (REST) and FakeGateway (scripted /api/ws); wire via overrides
test/fixtures/open_meteo.dart  trimmed real Open-Meteo response for the Weather page tests
```

`HANDOFF.md` is the original design brief (screens, avatar state triggers, open decisions). `CLAUDE.md` and this file describe the same code from different angles.

## Conventions that differ from "normal Flutter"

- **Dimensions live in a 740x360 design canvas.** `app.dart` wraps every route in `ScaledStage` (`FittedBox`) and overrides `MediaQuery.size` to `HSizes.designSize`. Do **not** read real screen sizes in widgets — copy measurements verbatim from `design/*.dc.html`. `HSizes.stage` is 268 dp (the avatar column). Touch targets ≥ 44 dp (`HSizes.minTouch`).
- **Colors, fonts, radii come from `lib/theme/tokens.dart`, which mirrors `tokens.json` 1:1.** A `widget_test.dart` test asserts the alignment — change one, change both. Token additions (`bubble`, `cloud`, `mintGlow`) are noted as "not in tokens.json" inside `tokens.dart`.
- **State is Riverpod 3 `Notifier`/`NotifierProvider`.** `main.dart` injects `SharedPreferences` once via `sharedPrefsProvider.overrideWithValue`, so `SettingsNotifier` reads settings synchronously. Never `await SharedPreferences.getInstance()` inside a provider — read `ref.read(sharedPrefsProvider)` instead.
- **Secrets vs settings:** username, password, session cookies live in `CredentialStore` (flutter_secure_storage, Android Keystore-backed), keyed to the server URL. Non-secret settings (server URL, profile, screen switches, setupComplete) live in `SharedPreferences`. Do not put secrets in SharedPreferences, do not put non-secrets in the keystore.
- **Setup is decided once at launch.** `app.dart` reads `setupComplete` once; later changes navigate explicitly to `Setup1Server`.
- **Landscape lock + immersive + wakelock are mandatory.** `main.dart` sets the orientations and `SystemUiMode.immersiveSticky`; `app.dart` toggles `WakelockPlus` from the keep-screen-on setting.
- **Markdown in chat bubbles is hand-rolled.** `widgets/markdown_text.dart` is the renderer for Hermes replies (headings, lists, code, quotes, inline emphasis). Don't pull in a package for it.

## Avatar (lib/avatar)

The 12 SVG states (`assets/avatar/*.svg`) animate with CSS `@keyframes`, which `flutter_svg` cannot run.

- `engine.dart` is a tiny CSS-keyframes engine: per-property tracks, per-segment easing, `alternate`, delays as phase offsets, fill-box transform-origin. Mirror what each SVG's `<style>` says.
- `scenes.dart` ports each of the 12 SVG states 1:1, copying the keyframes from the SVG `<style>` block.
- `avatar_state.dart` is the enum (order matches `tokens.json.order`), with per-state FPS (10/20/30) tuned for the S8 GPU and per-state caption color/glow.
- Drive the avatar with `avatarProvider`; the chat controller sets it on events (`message.start` → thinking, `tool.start` w/ name matching `/search|web|browse|fetch|crawl|lookup|extract/i` → searching else working, `message.delta` → speaking, `message.complete` complete → done then idle, error → oops, `approval` → alarm, `clarify` → thinking).
- `assets/avatar/gallery.html` plays all 12 SVGs in a browser; `screens/avatar_gallery.dart` is the in-app version. Compare against the matching SVG when touching a scene.

## Hermes connection (read `docs/hermes-protocol.md` first)

The doc says not to invent endpoints or message formats. The short version, with the file each fact lives in:

- **REST:** `lib/data/hermes_client.dart`. Auth is `POST /auth/password-login` → session cookies; cookies are stored in `CredentialStore` and replayed as a `Cookie` header. A 401 or `/login` redirect triggers exactly one silent re-login + retry; if the stored password is now rejected, the state becomes "Signed out" (`HermesErrorKind.signedOut`). Redirects and statuses are handled by hand (`followRedirects=false`, `validateStatus=(_)=>true`) because login sets its cookie on a 302.
- **Profiles:** use `?profile=<name>` via `profileQuery(profile)`, and **omit** the parameter for `default` (matches hermes-conduit). Model info comes from `GET /api/model/info?profile=`.
- **Discovery:** `GET /api/status` is public and returns `version`, `gateway_running`, `auth_providers`, `auth_required`, and `profiles`.
- **Native PKCE is deliberately not used.** `flutter_secure_storage` holds a password the owner types; cookie auth follows. (Loopback PKCE is documented in `docs/hermes-protocol.md` §"Not used".)
- **Realtime chat:** `lib/data/gateway/`. Flow per (re)connect: mint a single-use 30 s ticket via `POST /api/auth/ws-ticket` immediately before opening the socket, wait for `gateway.ready`, send `client.capabilities {server_requests: true}` (otherwise approval/clarify fail fast server-side), then `session.create` or `session.resume`. Tickets expire in 30 s — never cache one across a failed reconnect.
- **Heartbeat:** `gateway.ping` every ~15 s; treat 45 s without traffic as dead.
- **Events to avatar:** `message.start` → thinking; `thinking.delta|reasoning.delta|reasoning.available` → thinking (text not shown); `tool.start|tool.generating` → searching if `name` matches the search regex else working; `tool.complete` → thinking; `message.delta` → speaking; `message.complete` complete → done then idle, error → oops, interrupted → idle; `error` → oops; `approval` → alarm; `clarify` → thinking; `session.reclaimed` → reattach by stored_session_id before the next prompt. Skin, pet, preview, browser, terminal, cron, moa, voice.*, subagent.* are ignored.
- **Per-server+profile session id** is persisted in `SharedPreferences` under `chat.session.<server>|<profile>` so a resume sticks across restarts.

## Weather (lib/data)

Open-Meteo `/v1/forecast` (free, no key) for Yogyakarta, °C, WIB (`WeatherPlace`). `WeatherNotifier` shows the cached forecast immediately, refreshes every 30 min, and keeps the last good forecast if a refresh fails. **Retries are manual** (`retry: (_, _) => null` on the provider) — the user taps to retry, not Riverpod's auto-backoff.

## Testing (test/)

Tests **never touch the network**. The harness pattern is documented in `widget_test.dart` (`_Harness`) and `chat_controller_test.dart` (`_Rig`).

- Fake REST: `test/fakes/fake_hermes.dart` is a `FakeHermes implements HttpClientAdapter`; `fakeClient(url, store, server)` wires it into a real `Dio`. Defaults: user `admin`, pass `secret`, version `0.21.6`, profiles `default/work/personal`.
- Fake gateway: `test/fakes/fake_gateway.dart` implements `GatewayTransport`; auto-emits `gateway.ready` after connect; supports `event(type, sessionId, [payload])` and `serverRequest(id, method, params)`.
- In-memory keystore: `MemoryCredentialStore` (in `fake_hermes.dart`) drops creds/cookies on `clear()`. It also drops stored creds on wrong password (the test asserts `expect(h.store.creds, isNull)` after a failed sign-in).
- Real SharedPreferences: `SharedPreferences.setMockInitialValues({...})` then `SharedPreferences.getInstance()`.
- Provider overrides: `sharedPrefsProvider`, `credentialStoreProvider`, `hermesClientFactoryProvider`, `gatewayConnectorProvider`, `weatherClientProvider`. The chat controller's WebSocket connector is **specifically** a provider override (`gatewayConnectorProvider`) — tests inject `gateway.connect`, prod gets `connectIoGateway`.
- Widget tests need to **load the bundled fonts** (`assets/fonts/Fredoka-{500,600}.ttf`, `assets/fonts/Nunito-{600,700}.ttf`) so overflow checks use real glyph widths; see `_loadFonts` in `widget_test.dart`. Also set the view to `2960x1440 @ 3.5` for the S8 landscape and use `accessibilityFeatures(disableAnimations: true)` so the avatar stops ticking and `pumpAndSettle` actually settles.
- A pending clarify question swallows typed text as its answer — the chat test confirms `prompt.submit` is not called.

## Things that look like bugs but are intentional

- `app.dart` decides Setup vs HomeShell **once** at launch (`late final _configured = ref.read(settingsProvider).setupComplete`). To re-enter setup later, navigate explicitly.
- `HermesClient._authed` retries once on 401 *only*; a second 401 surfaces as `signedOut`.
- `widgets/markdown_text.dart` renders links as text, not as tappable widgets — by design for the bedside display.
- `setup1_server.dart` treats an unreachable-but-not-Hermes response as a setup-time error, not a runtime `LinkState.offline`.
- `weather_provider.dart` always caches the raw JSON as best-effort (`try { ... } catch (_) { }`); no fallback storm if SharedPreferences throws.

## Things future sessions are likely to get wrong

- Reading real screen sizes in a widget (`MediaQuery.size(context)` is the design size, not the physical screen). Use `HSizes.designSize` or design-canvas dp.
- Putting the device in portrait. Landscape is locked by `main.dart`; if you remove that line, every measurement breaks.
- Calling `SharedPreferences.getInstance()` inside a provider. Inject via `sharedPrefsProvider`.
- Caching the WS ticket. Tickets are 30 s and single-use; mint per connect.
- Using `flutter_svg` for the avatar and expecting CSS animation. Use the scenes in `lib/avatar/scenes.dart`; compare changes against the matching SVG in `assets/avatar/`.
- Sending `client.capabilities` after the first `prompt.submit`. Without `server_requests: true`, approvals/clarifies fail fast server-side.
- Forgetting to override `gatewayConnectorProvider` in widget tests — real `WebSocket.connect` will throw immediately.
- Picking `flutter pub run build_runner` thinking there's codegen. There isn't.
- Editing colors in `tokens.json` without updating `lib/theme/tokens.dart`, or vice versa. A test asserts they match.
- Adding a brand new avatar state. Update `AvatarState` (in this order), `tokens.json.order`, a scene in `scenes.dart`, an SVG in `assets/avatar/`, and the entry in `gallery.html`; wire it through `avatarProvider`.

## Pointers to other files worth reading

- `HANDOFF.md` — original brief: screens, avatar triggers, open decisions.
- `docs/hermes-protocol.md` — verified REST + /api/ws JSON-RPC protocol.
- `tokens.json` ↔ `lib/theme/tokens.dart` — colors/fonts/radii/sizes.
- `design/*.dc.html` — exact measurements/colors per screen (Claude Design runtime to render).
- `CLAUDE.md` — overlapping agent guidance, kept in sync with this file.
