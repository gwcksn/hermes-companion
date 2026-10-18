# Hermes dashboard protocol (verified 2026-10-16)

The companion talks to the Hermes **dashboard** started with `hermes serve` on port 9119. The owner runs it on their own machine and reaches it at `https://your-hermes.ts.net/` through a Tailscale tunnel. The OpenAI-compatible API on 8642 is not used.

Sources:
- Hermes docs, *Desktop → Connecting to a remote backend*: https://hermes-agent.nousresearch.com/docs/user-guide/desktop
- hermes-conduit, a working iOS client for the same dashboard (commit `674f26f`): https://github.com/kaishi00/hermes-conduit. Mainly `Conduit/Services/NativeOAuth.swift`, `NativeAuthClient.swift` and `HermesClient.swift`.
- Live probes against the owner's server, using only public and unauthenticated calls.

## Discovery (public, no auth)

`GET /api/status` returns:
- `version` (0.21.6) and `gateway_running` / `gateway_state`.
- `auth_required: true`, `auth_providers: ["basic"]`, `auth_flows: ["cookie", "native_pkce"]`.
- `profiles: ["default", "work", "personal"]`. The profile list is public, so Setup 3 can show it before an authed call.

`GET /api/auth/providers` returns `{"providers":[{"name":"basic","display_name":"Username & Password","supports_password":true}]}`.

## Sign-in: password login + session cookie (chosen by the owner)

- `POST /auth/password-login` with the JSON body `{"provider":"basic","username","password"}`. A 2xx (or 3xx) response sets the session cookie(s); 401/403 means wrong credentials; 429 means rate limited.
- The app keeps every `Set-Cookie` name=value pair (as Conduit does) and replays them as a `Cookie` header on authed REST calls.
- The username, password and cookies are stored with flutter_secure_storage, encrypted with an Android Keystore key and bound to the server URL.
- A 401, or a 3xx redirect to `/login`, triggers one silent re-login with the stored credentials, then the request is retried once. If the stored password is now rejected, the state becomes "Signed out".
- Implemented in `lib/data/hermes_client.dart`.

Not used: native PKCE. `/auth/native/authorize?provider=basic&code_challenge=…&redirect_uri=http://127.0.0.1:<port>/callback` answers `302 → /login` live. `POST /auth/native/token {code, code_verifier}` returns bearer tokens, and `POST /auth/native/refresh {refresh_token, provider}` renews them. Kept here in case the owner switches later.

## Profiles

REST calls are profile-scoped with `?profile=<name>`, for example:
- `GET /api/model/info?profile=default`
- `GET /api/sessions?limit=&offset=&order=recent&profile=`

## Realtime chat: /api/ws (verified against Hermes v0.21.6 source)

Sources:
- Server: `hermes-agent` tag `v0.21.6`. The typed contracts in `tui_gateway/contracts/{events,sessions,prompt_voice,liveness,server_requests}.py`, the transport in `tui_gateway/ws.py`, and ticket admission in `hermes_cli/web_server_chat.py`.
- Client: Conduit `HermesClient.swift` and `StreamEventParser.swift`.

### Connect

1. `POST /api/auth/ws-ticket`, authed with the session cookie, returns `{"ticket": "…"}`. A ticket is single use with a **30 s TTL**, so mint one immediately before every (re)connect.
2. Open `wss://<host>/api/ws?ticket=<ticket>`. The server also accepts the ticket as a subprotocol (`hermes-gateway-v1` plus `hermes-gateway-ticket.<ticket>`); the query form is simpler and is what Conduit uses.
3. The first frame is the event `gateway.ready`, with `{skin, change_events, replay_epoch, heartbeat: true}`.
4. Reply with `client.capabilities {server_requests: bool}`. Without `true`, every approval or clarify request for this client **fails fast**: the command is blocked or the question is dropped.
5. Heartbeat: send `gateway.ping` every ~15 s. The server answers `{ok: true}` on its reader thread, even mid-turn. The official clients treat 45 s without traffic as dead and reconnect.

### Frames (JSON-RPC 2.0)

- **Client request:** `{"jsonrpc":"2.0","id":<int>,"method":"…","params":{…}}`. The reply carries the same int `id` and either `result` or `error`.
- **Event:** `{"jsonrpc":"2.0","method":"event","params":{"type":"…","session_id":"…","payload":{…}}}`.
- **Server-to-client request:** `{"jsonrpc":"2.0","id":"<string>","method":"approval"|"clarify"|…,"params":{…}}`. Answer with that string `id`. Unhandled methods get error `-32601`.

### Methods the companion needs

**`session.create`** opens a live session.

| Params | Notes |
|---|---|
| `profile` | Omit for `default` (Conduit does) |
| `source` | `"desktop"` in Conduit |
| `cols` | `96` in Conduit |
| `title` | Optional |
| `idempotency_key` | A retried create returns the same session |
| `close_on_disconnect` | Defaults to false |

Result: `{session_id, stored_session_id, message_count, messages, info}`. `session_id` is the live runtime id. `stored_session_id` is the durable database key used to resume later.

**`session.resume`** reattaches to a stored session after a reconnect or app restart.
- Params: `{session_id: <stored id>, profile, cols, source, omit_messages}`.
- Result: `{session_id, stored_session_id, messages, …}`.

**`prompt.submit`** sends a user turn. The reply arrives as events.
- Params: `{session_id, text, profile?, surface?, voice_turn?}`.
- Result: `{status: streaming | queued | steered | redirected}`.
- Conduit allows 180 s for this call.

**`session.interrupt`** stops a running turn.
- Params: `{session_id}`.
- Result: `{status: interrupted | not_interrupted}`.

**`approval.respond` / `clarify.respond`**: answer approval and clarify requests, if the companion advertises `server_requests`.

### Events during a turn

| Event | Payload | Use in the companion |
|---|---|---|
| `message.start` | (none) | Avatar → **thinking**; add an empty Hermes bubble |
| `thinking.delta`, `reasoning.delta`, `reasoning.available` | `{text}` | Keep **thinking**; text not shown |
| `tool.start` | `{tool_id, name, context?, args?, preview?}` | Avatar → **searching** if `name` looks like search/web/browse, else **working** |
| `tool.generating` | `{name}` | Same rule as `tool.start` |
| `tool.complete` | `{tool_id, name, duration_s, summary?, result}` | Back to **thinking** until text arrives |
| `message.delta` | `{text, rendered?}` | Append to the bubble; avatar → **speaking** while text streams |
| `message.interim` | `{text, already_streamed}` | Interim text between tool rounds |
| `message.complete` | `{text, status: complete | error | interrupted, usage?, reasoning?, warning?}` | Finalize the bubble. `complete` → **done**, then **idle**. `error` → **oops**. `interrupted` → **idle** |
| `error` | `{message}` | **oops** plus an error line |
| `status.update` | `{kind, text}` | Optional status text |
| `session.title` | `{session_id, title}` | Ignored |
| `approval.request` | (approval details) | See server requests above |
| `session.reclaimed` | `{session_id, stored_session_id, reason}` | The live session was reaped (idle, LRU, orphan). Resume by `stored_session_id` before the next prompt |

Ignored by the companion: skin, pet, preview, browser, terminal, cron, moa, voice.*, subagent.*.

### History

- `session.resume` returns `messages`.
- REST: `GET /api/sessions?limit=&order=recent&profile=` and `GET /api/sessions/{id}/messages`.

## Voice (server side)

- `POST /api/audio/transcribe` with `{data_url, mime_type}` (speech to text). Verified live: wav, mp4/m4a, webm and ogg all work; answers `{ok, transcript, provider: "local"}`. The first call took ~40 s (model load), later ones ~8 s, so use a long receive timeout (the app uses 90 s).
- `POST /api/audio/speak` with `{text}` returns a base64 audio data URL (text to speech).

## New session (`/new`)

The dashboard gateway has no reset or slash-command RPC (`tui_gateway/contracts/sessions.py`, v0.21.6). The companion handles `/new` and `/reset [title]` client-side: it drops the stored session id, calls `session.close` on the live session (best effort), then `session.create`. The old session stays in Hermes history. The refresh button in the chat page does the same.
