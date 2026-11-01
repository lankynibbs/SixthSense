# Sixth Sense dev history (Rear Heat HUD v0.1 → Sixth Sense v1.4.5)

Archive of rationale, attempts and decisions, reconstructed from git log, README version sections and `src/` old versions. Not a current-state doc; see [HANDOFF.md](../../HANDOFF.md).

## Origin: Rear Heat HUD (v0.1)
- Goal: warn about enemies behind you. Three bars (left-rear, rear, right-rear) fading clear→yellow→red; threat = tier weight × closeness for enemies >100° off view within `range`.
- Route: a Lua addon for Bingus Shared Loader, because HellForge's C SDK has no camera, unit-position or drawing API ("HellForge has not mapped enemies yet").
- Safety rules from the start: never ask position of runtime-built units (`46cab355bd8d4d37`, crashes the game), pcall everything, no text, self-disable after 50 errors.

## Finding enemies (v0.1–v0.3)
- v0.1 `World.units_by_resource` with cached `IdString64`s saw 0 enemies.
- v0.2 walked `World.units` (300/frame) reading resource ids; added discovery mode and `detect=candidates` (animated units that moved).
- v0.3 went back to `units_by_resource` with a fresh `IdString64` every 0.25 s (stale ids were the likely v0.1 bug). Used Treasure Radar's GUI setup with the performance-HUD font: this crashed, later explained by Chef Shared Loader's notes (a font whose material the game doesn't make ends the game). Text was dropped for good.

## The calibration saga (v0.4–v1.0.1)
Nothing showed on screen where expected, so drawing was debugged step by step:
- v0.4 rect-only test box; never touch the old world's GUI on teardown (v0.3 destroyed it).
- v0.5 bigger bars on the test box's layer; v0.6 one `box()` helper, heartbeat square and RGB probes. Only probes in the 35–65% height band were seen.
- v0.7 calibration grid of growing squares + resolution logging; Darryl reported visible squares.
- v0.8 view transform guess (0.25/0.25/0.75/0.75) with corner L marks.
- v0.9 measured transform at 3840x1080: gui y runs bottom-up, `screen_x = 1.2·gx`, `screen_y = (1080 − gy)·0.9333`.
- v1.0 stopped guessing: interactive calibration (drag/arrow keys/scale slider) saving an area in the ini. This set Darryl's standing preference: **for uncertain layout, build interactive adjusters rather than guessing.**
- v1.0.1 toggle moved to F7 (HellForge uses F8); area clamped because gui clips below gy 0.

## Flicker smoothing (v1.1)
- Causes: candidates only swapped in at the end of a multi-second walk; known enemies rebuilt every lookup; symmetric 0.17 s smoothing; rear zone started at 100°.
- Fix: persistent tracking table, per-frame positions/threat, rise ~0.15 s, hold 1 s then fade 1.5 s, rear = back 180° in thirds.

## Sliders and keys (v1.2–v1.2.1)
- v1.2 added sensitivity and repeat_rate sliders with `[ ]`/`; '` keys. v1.2.1 removed all slider keys so the game keeps them: mouse only. (No `[ ]`, no F8 remains a rule.)

## The radar and the oval disc (v1.3–v1.3.2)
- v1.3 replaced the bars with a 360° north-up radar; texture disc via `Gui.bitmap` with rect fallback; `tools/build.py` adds texture rows.
- The disc came out tall and skinny (~1.29× too narrow): `Gui.bitmap` takes size in screen px while rects take gui units. v1.3.1 sized textures in screen px and added `radar_aspect`; v1.3.2 defaulted aspect to 1.25 after Darryl still saw an oval. v1.3.1 also added label word textures (no Gui.text).
- v1.3.2 cleaned the picture: pods excluded (seen 3–5 where you land), falling-object filter, 0.5 s candidate delay, fast death detection (death states, learned states, still-hide), size classes.
- v1.3.2 is the first git commit (`cd28f7c`).

## Sixth Sense (v1.4.0–v1.4.1)
- Rename with same GUID so HellForge updates in place; ini carried over.
- Enemy structures as diamonds (Automaton turret ids from hashlist paths); our stratagem turrets excluded, plus a "spawned near you after the first walk = ours" heuristic. Illuminate turrets have no hashlist paths, hence `static_log`.
- Fixed panel, then tabs (Display/Settings). v1.4.1 drew the panel on top, auto-placed it, and added a **Move toggle** so clicks on the radar didn't move it by accident.

## Grab handle and resolution-change fix (v1.4.2)
- The Move toggle was clunky; replaced by a grab handle on the radar's top edge and corner resize handles.
- Placement in gui units broke when the resolution changed. Now stored as screen fractions (`radar_cx/cy/d`), migrated once, transform assumed 1080-tall-normalised (sx, sy scaled by H/1080), back buffer checked each second, radar clamped/reset on change.
- Recovery: two-click Reset, hold F7 3 s. Still only 3840x1080 measured.

## Dot sizes (v1.4.3–v1.4.4)
- Darryl wanted bigger dots: 7/15/28/38 px (v1.4.3), then about double, 12/24/44/58 px (v1.4.4), small→medium once.

## HUD mode removal (v1.4.4–v1.4.5)
- v1.4.4 tried `visibility=hud` (show only when the game HUD is shown) by probing globals and `user_setting` keys; nothing answered on this build.
- v1.4.5 dropped HUD mode and its probes; Shown/Hidden buttons replace the slider.

## Working preferences (Darryl)
- Work on `develop`; batch several fixes per build; versioned zips in `C:\Users\kluster\Downloads` on ix.
- Interactive adjusters over guessing for any uncertain layout.
