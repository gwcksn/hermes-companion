# Hermes Companion: Tamagotchi Behaviour Plan (v2, no growth)

Status: plan only, no code yet. Written for Claude Code to implement after owner approval.
Scope: the current avatar stays exactly as it is. We add Tamagotchi-style needs, care actions and reactions. No growth stages, no evolving look, no unlockables, no shell, scarf or badge overlays. All 21 existing scenes and props are available from day one.

## 1. Goals and guardrails

1. The pet layer is cosmetic and emotional. It must never block, slow or gate Hermes chat, voice or any page.
2. No death, sickness or punishment. Neglect only makes the avatar sleepy, bored or sulky. Every stat has a floor.
3. Care comes from real use (chatting, finishing tasks, saying thanks), not from chores.
4. All pet state is local to the device. No server change needed.
5. A "Quiet mode" setting hides all pet UI, so the screen can stay a clean clock.
6. Everything is testable without a real clock: inject a `Clock` and keep the rules as pure functions.

## 2. Pet model

Three stats, each 0 to 100, clamped to a floor so nothing reaches zero.

| Stat | Meaning | Floor | Drains | Refills |
|---|---|---|---|---|
| energy | Awake vs sleepy | 15 | about 4 per hour awake | about 10 per hour while sleeping (dim window or sleeping state) |
| mood | Happiness | 25 | 1 per 20 min with no interaction | chat turn +4, thanks +10, tap +6, task done +8, play +10 |
| curiosity | Wants new things | 20 | 1 per 15 min | question asked +5, Feed +25, news or brief opened +10 |

Rules:
1. Decay is computed from timestamps, not a running timer, so it survives app restarts. On resume, apply elapsed decay, capped at 12 hours.
2. A one-minute tick keeps the UI live while the app is open.
3. Derived labels: `joyful` (mood 80+), `content` (50 to 79), `bored` (30 to 49), `gloomy` (below 30, never worse).
4. Derived needs: `sleepy` (energy below 30), `curious` (curiosity below 35).
5. No long-term counters, no levels, no streak penalties. Nothing is ever "lost".

## 3. Events that change the pet

Other features publish typed events to the pet. The pet never calls them.

| Event | Source | Effect |
|---|---|---|
| UserMessageSent | chat | mood +4, curiosity +5 |
| ReplyFinished | chat | mood +2 |
| ThanksDetected | existing happy trigger | mood +10 |
| AvatarTapped | avatar | mood +6, happy for 3 s (as today) |
| TaskCompleted | a finished task | mood +8, avatar shows `proud` |
| AlertRaised | an alert raised elsewhere | alert scene as today, no stat penalty |
| DailyFirstTouch | first interaction after 06:00 | morning greeting (hook for the Morning Brief feature) |
| FeedTapped | care sheet | asks Hermes for a fun fact or news item, curiosity +25 |
| PlayTapped | care sheet | mood +10, plays a short play scene |
| TuckedIn | care sheet, or night dim start | energy refill starts, sleeping scene |
| NightStarted / NightEnded | clock | switches sleeping and activity rules |

## 4. Behaviour: how the pet acts

1. **Idle activity choice becomes weighted.** The existing idle ladder timing stays (activities after about 3 min idle, sleeping at 10 min). The pick uses weights:
   - bored: favors doodling, gaming, daydreaming.
   - curious: favors reading, stargazing, and the new `curious` scene now and then.
   - sleepy: favors stretching, meditating, and goes to sleeping earlier.
   - joyful: favors singing, coffee.
   - Never the same activity twice in a row. The night allow-list still applies.
2. **Reactions stay as today** (thinking, working, searching, speaking, done, oops, alert). Pet state only adds flavor, for example `done` plays `proud` when the finished work was a completed task.
3. **Need hints:** when a need is low, the avatar occasionally plays its need scene for about 4 s (sleepy yawn, curious look) instead of a normal activity.
4. **Morning and night routines** hook into the future Morning Brief and Night Resume features: stretch and greeting at the first touch, tuck-in at night.

## 5. New art (SVG, done in Claude Design after plan approval)

The engine draws SVG scenes, so the art is SVG, same format as the existing 21, drawn on the same avatar. Six new scenes, already drawn and exported (`assets/avatar/curious.svg`, `bored.svg`, `proud.svg`, `sulky.svg`, `play.svg`, `eat_info.svg`):
1. `curious`: head tilt, a small question mark and sparkles.
2. `bored`: slumps a little, sighs, a floating "..." bubble.
3. `proud`: chest out, small star.
4. `sulky`: puffed cheek and a turned-away look. Cute, never sad or sick.
5. `play`: short play scene for the Play action (chasing a ball).
6. `eat_info`: a little "gulp" of a glowing note for the Feed action.
UI icons: three stat icons (energy, mood, curiosity).

## 6. UI changes

1. **Stats strip:** three small icon bars on the avatar stage, under the name. Hidden by default. Shown for 4 s after a tap, or automatically when a need is low. Fits inside the existing 268 dp stage without moving the avatar.
2. **Care sheet:** long-press the avatar. Three large buttons (Feed, Play, Tuck in), each at least 44 dp.
3. **Settings:** a `Pet` section with Quiet mode and Reset pet (with confirmation).
4. No growth screen, no shelf, no stage UI. Existing pages and page dots are unchanged.

## 7. Architecture (Flutter, Riverpod, matches the current stack)

```
lib/pet/
  pet_state.dart        immutable: energy, mood, curiosity, lastTick, lastActivity
  pet_events.dart       sealed event classes (section 3)
  pet_rules.dart        pure functions: applyDecay, applyEvent, labelsFor, pickActivity
  pet_store.dart        SharedPreferences JSON, versioned schema, debounced save
  pet_controller.dart   Notifier: loads state, ticks every minute, accepts events, exposes state
  pet_clock.dart        Clock interface, system implementation, fake for tests
lib/pet/ui/
  stats_strip.dart, care_sheet.dart
```

Integration points:
1. Chat, Tasks, monitoring and ambient features call `petController.onEvent(...)`. No stat logic inside them.
2. The ambient behaviour (idle ladder) asks `pickActivity(state, now)` for the next activity instead of its own random pick.
3. The avatar engine gets the six new scenes (port the SVG scenes like the existing 21).
4. Settings reads and writes Quiet mode and Reset.
5. Storage: SharedPreferences only, no credentials, schema version field.

## 8. Tests (no network, fake clock)

1. Decay: elapsed time maps to expected changes, respects floors, caps at 12 hours.
2. Events: each gives the expected delta, stats clamp at 100.
3. pickActivity: honors the night allow-list, never repeats, weights by mood and needs.
4. Persistence: save, restart and load round trip, plus a schema migration test.
5. Widget tests: stats strip shows and hides, care sheet actions fire events, Quiet mode hides all pet UI.
6. Regression: existing chat, avatar engine and ambient tests still pass.

## 9. Phases and acceptance

1. **P0 Baseline.** Run `flutter analyze` and `flutter test` on a new branch and fix or record failures. Acceptance: clean baseline.
2. **P1 Engine.** Pet state, rules, store and controller with tests, no UI. Acceptance: all section 8 unit tests pass.
3. **P2 Wiring.** Publish events from chat, tap, tasks, thanks and the clock. Weighted idle picks. Acceptance: stats change correctly during normal use, verified with a temporary debug overlay.
4. **P3 UI and actions.** Stats strip, care sheet, Feed (a Hermes request for a fun fact, shown in chat), Play, Tuck in. Acceptance: all three actions work and chat is never blocked, even offline.
5. **P4 Art.** Port the six new scenes into the engine (the SVGs already exist). Acceptance: each plays in the in-app avatar gallery and is used by the behaviour rules.
6. **P5 Polish.** Quiet mode, reset flow, battery check (the extra ticking must not add noticeable drain on the S8).

Suggested split for Claude Code sessions: P0 and P1 together, then P2 and P3, with P4 porting after P2 (the art is already done).

## 10. Decisions (resolved)

1. Feed asks Hermes for a real fun fact or news item. One per tap, 30-minute cooldown, shown as a normal chat reply. If the server is offline, Feed plays the `eat_info` scene and gives a small curiosity boost without a fact.
2. The pet keeps the name "Hermes".
3. `eat_info` is included. All 6 new scenes are drawn and delivered as SVGs in `assets/avatar/` (see section 5).
