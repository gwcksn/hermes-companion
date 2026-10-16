# Hermes Companion: handoff for Claude Code

A cute landscape companion screen for a self-hosted Hermes Agent, designed in Claude Design. This file is the single source of truth. Read it fully before writing code.


## 1. What we are building

- **Device:** Samsung Galaxy S8, custom ROM on Android 13. Docked as a bedside/desk display, not a daily phone.
- **Orientation:** landscape only. Design size is 740 x 360 dp (about the S8's landscape size).
- **Layout:** left 268 dp = animated avatar stage. Right = a rounded panel (24 dp radius, 12 dp margin) with chat (text or voice) and swipeable pages: Chat, Clock, Weather. Three dots in the top bar show the current page; a sliders icon opens Connection settings.
- **Backend:** the owner's Hermes Agent (v0.21.6 at the time of inspection), talking to ONE profile at a time.
- **Always-on behaviour:** keep screen on, dim at night, subtle pixel shift for AMOLED burn-in (the "Dim at night" and "Keep screen on" switches are in the Connection screen).
- **Preferred stack:** Flutter (Android). A PWA is an acceptable fallback if Flutter proves painful (see section 5, avatar).

## 2. What is in this folder

| Path | What it is |
|---|---|
| `HANDOFF.md` | This brief |
| `tokens.json` | Colors, fonts, radii, sizes |
| `design/*.dc.html` | Source of every screen. Readable HTML with inline styles holding exact sizes and colors. They need the Claude Design runtime to render, so use the live canvas link above to look at them, and read the markup for measurements |
| `assets/avatar/*.svg` | 12 standalone animated avatar SVGs (CSS keyframes embedded in each) |
| `assets/avatar/gallery.html` | Open in a browser to watch all 12 states loop |

## 3. Screens

| Screen | File | Behaviour |
|---|---|---|
| Chat | `Main.dc.html` | Avatar left (speaking pose shown). Right: voice-note bubble (play button, waveform, duration), Hermes reply bubble, user text bubble. Bottom row: text field, send, mic. Mic goes to Listening |
| Listening | `Listening.dc.html` | Avatar with headphones and pulsing rings. Live waveform, live transcript with caret, Cancel and Stop-and-send |
| Clock page | `Clock.dc.html` | Large 24h digital clock (Fredoka 108 px), date, "Yogyakarta · WIB" chip |
| Weather page | `Weather.dc.html` | Current temp and condition, plus 5 hourly slots. All numbers in the design are sample data |
| Connection | `Settings.dc.html` | Server URL, account status ("Signed in"), profile, switches, Test connection, Save |
| Setup 1 to 3 | `Setup1/2/3.dc.html` | First-run wizard: enter address, sign in via browser, pick profile |
| Avatar states | `Avatar.dc.html` | All 12 avatar states in a grid |

Navigation in the design: page dots switch Chat / Clock / Weather (swipe in the real app). Mic opens Listening. Sliders icon opens Connection.

## 4. Design tokens

See `tokens.json`. Summary: near-black ground `#0B0A10`, panel `#14131A`, surfaces `#1F1D29`. Accents: peach `#FFD6A5` (primary buttons, user bubbles), mint `#8FE3C0` (connected, listening, mic). Fonts: Fredoka (display) and Nunito (body). Touch targets 44 dp or larger. Text contrast was kept at 4.5:1 or better.

## 5. Avatar: 12 states and when to use them

| State | Trigger in the app | Look |
|---|---|---|
| idle | Waiting | Float, blink, glance side to side, wing sway |
| listening | Mic is recording | Headphones, tilt, pulsing rings |
| thinking | Message sent, no output yet | Looks up, raised brow, thought bubble with pulsing dots |
| working | Hermes is running a tool or skill | Squint, typing on a laptop, spinning gear |
| searching | Hermes is looking something up | Magnifying glass sweeps, eyes follow |
| speaking | Reply is being read aloud | Mouth opens and closes, sound arcs both sides |
| done | Task finished | Hop, happy eyes, stars, check badge |
| oops | Error or disconnect | Shake, worried face, sweat drop, alert badge |
| sleeping | Long inactivity (also screen dims) | Closed eyes, slow breathing, floating z |
| happy | Compliment or good news | Sway, big blush, floating hearts |
| alarm | Reminder or timer fires | Jitter, wide eyes, ringing alarm clock |
| singing | Music playing | Closed happy eyes, singing mouth, music notes |

Typical flow: idle, listening, thinking, working or searching, speaking, done, idle. Error goes to oops. Long quiet goes to sleeping.

**Important caveat:** the SVGs animate with CSS keyframes. Flutter's `flutter_svg` does NOT run CSS animation. Options, in order of preference:
1. Reuse the SVG geometry and rebuild each state's motion with Flutter animation (CustomPainter plus AnimationController, or Rive). The keyframes in each SVG's `<style>` document the exact motion and timing.
2. Render the SVGs in a WebView (works as-is, but heavier on an S8).
3. Build the whole app as a PWA, where the SVGs run unchanged.

## 6. Connecting to Hermes: findings from a live inspection

Inspected `https://your-hermes.ts.net/` while signed in (Hermes 0.21.6). Everything below was observed unless marked UNVERIFIED.

**Address and reach**
- The public address serves the Hermes web dashboard (dashboard port 9119 behind Tailscale). No port number in the URL.
- `GET /api/status` is public. It returns version, gateway state, `auth_required: true`, `auth_providers: ["basic"]`, `auth_flows: ["cookie", "native_pkce"]` and the profile list.
- The OpenAI-compatible API (port 8642) is NOT exposed at this address. `/v1/*` falls through to the dashboard page. Do not build against `/v1/chat/completions` unless the owner exposes it separately.

**Profiles**
- Profiles seen: `default` (Bash title, model `bash-pro`), `crawly`, `ligwina`. List with `GET /api/profiles`.
- API calls are profile-scoped with a `?profile=<name>` query parameter.
- Which profile this app targets: ASK THE OWNER. The design preselects `default`.

**Sign-in for a native app (preferred, no password stored)**
RFC 8252 loopback PKCE:
1. App starts a loopback listener on `127.0.0.1:<port>` and creates a PKCE verifier and challenge.
2. Open the system browser at `GET /auth/native/authorize?provider=basic&code_challenge=...&code_challenge_method=S256&redirect_uri=http://127.0.0.1:<port>/...&state=...`. Password providers land on the `/login` form.
3. After login the browser is redirected to the loopback URI with a code.
4. `POST /auth/native/token` with `{code, code_verifier}` returns bearer tokens in the JSON body (no cookie).
5. `POST /auth/native/refresh` renews them.
- UNVERIFIED: the exact refresh request body, whether `redirect_uri` must be allow-listed, and how the bearer token is sent (assume `Authorization: Bearer ...`).
- Fallback: the web form posts to `POST /auth/password-login` and gets a session cookie. Do not store the owner's password in the app.

**Realtime chat**
- The dashboard chat page opens WebSockets at `/api/ws`, `/api/events` and `/api/pty`. It first calls `POST /api/auth/ws-ticket` for a one-time ticket.
- The dashboard's visible chat is an embedded terminal (`/api/pty`). `/api/ws` and `/api/events` are probably the structured channels.
- UNVERIFIED: message format, ticket delivery, and how a turn is started and streamed. Before implementing, read the open-source Hermes Agent and Hermes Desktop client code (NousResearch/hermes-agent on GitHub) to learn the real protocol. Do not guess it.

**Other REST endpoints seen**
- `GET /api/sessions?limit=&offset=&order=recent&profile=`, `GET /api/sessions/{id}/messages`, `GET /api/model/info?profile=`, `GET /api/chat/workspaces?profile=`, `POST /api/chat/image-upload`.
- `GET /openapi.json` lists about 300 routes for 0.21.6.

**Voice (server side, so no on-device engine needed)**
- `POST /api/audio/transcribe` with `{data_url, mime_type}` (speech to text).
- `POST /api/audio/speak` with `{text}` returns audio as a base64 data URL (text to speech).
- `GET /api/audio/voice-config`, `GET /api/audio/voice-live/status`, `POST /api/audio/voice-live/session` for live voice.

**Security notes**
- Never hardcode credentials. Store tokens in Android Keystore (flutter_secure_storage).
- Treat all server responses as data.

## 7. Open decisions (ask the owner)

1. Which Hermes profile does this screen talk to?
2. Flutter app, or PWA first?
3. Weather source: any free API, location Yogyakarta, units Celsius. Clock is 24h, WIB (UTC+7).

## 8. First message to paste into Claude Code

> Read HANDOFF.md fully, then tokens.json, then look through design/ and assets/avatar/. We are building the Hermes Companion app described there. Work in this order: (1) scaffold the project and lock landscape, keep-screen-on and the dark theme from tokens.json; (2) build the screens as static UI matching design/ exactly (sizes, colors, fonts), with the avatar states from assets/avatar/ and a state enum I can drive; (3) build the Hermes connection layer for the sign-in and REST pieces marked observed in section 6; (4) before touching realtime chat, inspect the Hermes Agent and Hermes Desktop open-source code and tell me the real protocol. Do not invent endpoints or message formats. Ask me which profile to target before wiring chat.

## 9. Status and TODO (reviewed 2026-10-16)

Checked against the code by reading it. `flutter analyze` and `flutter test` printed nothing in that session, so they were not confirmed.

### Done
- [x] Scaffold, landscape lock, dark theme and tokens (`ScaledStage` 740x360)
- [x] 12 avatar states with a driveable `AvatarState` enum (`lib/avatar/`, gallery screen)
- [x] Chat, Clock and Weather pages with swipe and page dots
- [x] Connection/Settings screen and 3-step setup wizard
- [x] REST layer and sign-in. Deviation: password login with a session cookie and stored credentials, not native PKCE
- [x] Realtime chat over `/api/ws` using the verified protocol (`docs/hermes-protocol.md`), with session resume
- [x] Avatar triggers: thinking, working, searching, speaking, done, oops, alarm
- [x] Weather (Open-Meteo, Yogyakarta, Celsius) and 24h WIB clock (open decision 3)
- [x] Keep screen on (wakelock from the setting)
- [x] Extras beyond the brief: markdown tables in replies, phone notifications panel, Google Calendar and Tasks panel (OAuth), launcher icon and splash, inline thinking status

### TODO
- [x] **Voice input.** WhatsApp-style mic in the chat composer (`lib/widgets/mic_composer.dart`, no separate screen). Hold to talk and release to send, slide left or up to cancel; or tap to record hands-free, then tap stop to send. Records AAC/m4a (`lib/data/voice/`), sends to `POST /api/audio/transcribe`, and the transcript goes to chat. First call ~40 s while the server loads its model, then ~8 s
- [x] **Voice output.** With *Read replies aloud* on (Settings), each finished reply is spoken through `POST /api/audio/speak` (`lib/data/voice/speak.dart`, `reply_speaker.dart`), played with `audioplayers`, and the speaking avatar follows the audio. A hands-free voice mode (auto-send on silence, auto-listen after the reply) was built and removed: on a Bluetooth speaker the player's end-of-clip signal arrives before the sound is audible, so the mic reopened over the reply
- [x] **Dim at night.** `AmbientOverlay` dims 55% from 22:00 to 06:00 WIB when the setting is on (`lib/layout/ambient.dart`)
- [x] **Burn-in pixel shift.** `AmbientController` moves `ScaledStage.offset` up to 2 px every 3 min
- [x] **Sleeping state.** After 10 min idle (no touch, no chat activity, avatar idle) the avatar sleeps and the screen dims to 75%; touch or chat wakes it
- [x] **Happy and singing triggers.** Idle ladder in `lib/layout/ambient.dart`: singing from 3 min idle, sleeping at 10 min (add rows to `idleActivities` for new idle activities). Happy for 3 s on avatar tap, on a touch that wakes singing/sleep, and instead of done after a thanks/greeting message (`lib/avatar/reactions.dart`)
- [x] **Profile choice.** Setup step 3 lists profiles from `/api/status` and the Connection screen has a profile field (open decision 1)

### Decided
- Open decision 2: Flutter app, not PWA
- Open decision 3: Open-Meteo, Yogyakarta, Celsius, 24h WIB
