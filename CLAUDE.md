# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Hermes Companion: a landscape-only Flutter (Android) companion screen for a self-hosted Hermes Agent (dashboard `hermes serve`, port 9119, reached over Tailscale). Target device is a Samsung Galaxy S8 docked as a bedside display. `HANDOFF.md` is the original design brief (screens, avatar states, open decisions); `docs/hermes-protocol.md` is the verified server protocol. `README.md` is the project overview. `design/*.dc.html` are design sources (need the Claude Design runtime to render; read them for exact measurements). `tokens.json` mirrors `lib/theme/tokens.dart`.

## Commands

```bash
flutter pub get
flutter analyze                       # flutter_lints; build/ and android/ are excluded
flutter test                          # all tests
flutter test test/chat_controller_test.dart                 # one file
flutter test test/chat_controller_test.dart --plain-name "<test name>"   # one test
flutter run                           # needs a device/emulator; app locks to landscape
flutter build apk
```

Google sign-in needs its web client ID at build time. Pass `--dart-define-from-file=google.env.json` (template: `google.env.example.json`, real file is untracked/secret) to `flutter run`, `flutter build apk` and any debug build for a device; without it the Connect Google screen fails with `serverClientId must be provided on Android`. Use `adb install -r` rather than `flutter install` on a device, since the latter uninstalls first and wipes saved server/credentials. The `/usr/bin/flutter` wrapper prints nothing here; use `/opt/flutter/bin/flutter`.

There is no code generation step.

## Architecture

**State**: Riverpod 3 (`Notifier`/`NotifierProvider`). `main.dart` loads `SharedPreferences` once and injects it via `sharedPrefsProvider.overrideWithValue`, so settings are synchronous. Secrets (username, password, session cookies) go through `CredentialStore` (flutter_secure_storage), never SharedPreferences.

**Fixed design canvas**: `app.dart` wraps every route in `ScaledStage`, which lays out a 740x360 canvas (`HSizes.designSize`) and scales it to the real screen with `FittedBox`. It also overrides `MediaQuery` to the design size. So all dimensions in widgets are design-canvas dp copied verbatim from `design/*.dc.html`; don't use raw screen sizes. Colors/fonts/radii live in `lib/theme/tokens.dart` (fonts: Fredoka display, Nunito body, bundled in `assets/fonts`).

**Connection layers** (`lib/data/`):
- `hermes_client.dart`: Dio REST client. Auth is `POST /auth/password-login` → session cookie, stored and replayed as a `Cookie` header; a 401 or redirect to `/login` triggers one silent re-login with stored credentials and one retry. Failures are mapped to `HermesError(kind)` with user-facing messages. Native PKCE is deliberately not used.
- `connection.dart`: `ConnectionNotifier` polls `/api/status` + model info every minute and exposes `LinkState` (checking/connected/offline/signedOut). Drives the status pill and forces the avatar to `oops` when offline.
- `gateway/gateway_socket.dart` + `gateway/chat_controller.dart`: realtime chat over the `/api/ws` JSON-RPC WebSocket. Flow: mint a single-use 30 s ticket (`POST /api/auth/ws-ticket`) right before every (re)connect, wait for `gateway.ready`, send `client.capabilities`, ping every ~15 s, then `session.create`/`session.resume` and `prompt.submit`; turn progress arrives as `event` frames. `ChatController` maps events (message/tool/thinking/error) to chat bubbles **and to the avatar state** via `avatarProvider`, and handles approval/clarify server requests. Check `docs/hermes-protocol.md` before touching any of this; the doc says not to invent endpoints or message formats.
- `settings_store.dart`, `weather.dart`/`weather_provider.dart` (Open-Meteo, Yogyakarta, Celsius; clock is 24h WIB).

**Avatar** (`lib/avatar/`): `assets/avatar/*.svg` use CSS keyframe animation, which flutter_svg can't run. Instead `engine.dart` is a small keyframe/transform engine mimicking CSS semantics (per-property tracks, per-segment easing, `alternate`, delays as phase offsets, fill-box transform origins), and `scenes.dart` ports each of the 12 SVG states 1:1 with the keyframes copied from the SVG `<style>`. Drive it with `avatarProvider` (`AvatarState` enum). When changing a scene, compare against the matching SVG (`assets/avatar/gallery.html` plays all 12; `screens/avatar_gallery.dart` is the in-app version).

**UI** (`lib/screens/`, `lib/widgets/`): `HomeShell` is the avatar stage plus a panel with swipeable Chat / Clock / Weather pages. First run goes through `screens/setup/` (server → sign-in → profile); `app.dart` picks Setup vs HomeShell once at launch from `setupComplete`. `widgets/markdown_text.dart` is a hand-rolled markdown renderer for Hermes replies. `main.dart` sets immersive mode; `app.dart` applies wakelock from the keep-screen-on setting.

## Testing

Tests never touch the network. `test/fakes/fake_hermes.dart` provides a fake REST server behind `fakeClient(...)`, and `test/fakes/fake_gateway.dart` is a scripted WebSocket gateway. Wire them in with provider overrides (`hermesClientFactoryProvider`, `gatewayConnectorProvider`, `credentialStoreProvider` → `MemoryCredentialStore`, `sharedPrefsProvider` with `SharedPreferences.setMockInitialValues`). See `test/chat_controller_test.dart` (`_Rig`) for the pattern; `test/fixtures/open_meteo.dart` holds weather payloads.
