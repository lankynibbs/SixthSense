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

## Per-resolution layouts (v1.4.6, 2026-11-02)
- Darryl: the drawable area does not cover the whole window at some resolutions. Chef Shared Loader 1.3.1 had found why on this game: a screen GUI in the game's world shows only the render size's worth of the window (top-left) when Render Scale is below native or the Resolution is below the window. v1.4.6 reads `render_resolution` from `user_settings.config` (as Chef does) and normalises placement to that rect.
- Layouts saved per window resolution; Darryl asked that unsaved resolutions default to the centre (no nearest-layout fallback).

## Settings file under HellForge (v1.4.7, 2026-11-02)
- Darryl approved v1.4.6 layouts. His log showed the settings file not found in the redirected AppData; HellForge's real one is `<HellForge>\userdata\profiles\default\user_settings.config` (screen 3840x1080, render 2960x832, Render Scale index 3). The C:\ AppData file (5120x1440 borderless) is not the one HellForge uses. v1.4.7 searches the profiles folder and picks the profile matching the window.
- Layouts stay keyed by window size, not render scale: fractions of the drawable area already absorb a render-scale change, and Darryl approved per-resolution keys.
- Gui.resolution returned "596 1": not understood (not a size); logged only.

## Pick debug control (v1.4.8, 2026-11-02)
- Darryl declined an automatic discovery mode and asked for a control to mark a unit he sees and print its id. Pick scores every live unit (World.units, runtime-built skipped) by angle off the camera's 3D forward ray within 12 degrees and 250 m, with a small bonus for known/listed/animated units over props; fallbacks: 2D view direction (20 degrees), then nearest unit.
- Per Darryl: the id is the first field (`PICK id <hex>`) for Ctrl+F and copy, and it stays on screen (`PICKED: <id>`) until the next pick.

## Mark then Pick (v1.4.9, 2026-11-02)
- Darryl rejected v1.4.8's aim-at-click Pick: he wants to mark a unit first and then pick (log) it with the aim free. Mark uses the v1.4.8 targeting and stores the unit; Pick logs the stored unit's id (re-reading its position) and never re-aims.

## Mark and Pick removed (v1.5.0, 2026-11-02)
- At Darryl's request, Mark and Pick were removed completely: buttons 4 and 5, the targeting code, `MARK` / `PICK` log lines, `MARKED:` F7 text, the radar blink ring, `picked_ids` persistence and the Mark / Pick label textures. The F7 panel shrank to three buttons (Display, Settings, Reset). Their stub tests were replaced by a check that none of it remains.

## Radar colours (v1.5.1, 2026-11-02)
- Darryl asked for colour options besides green: white, yellow, red, light blue. Added as a fifth snap slider (mouse only, like Dot size) with a swatch instead of a text value (the pixel font lacks some letters). To recolour the disc without five textures, `radar_disc.png` is now white lines on a neutral dark fill and tinted through the `Color` argument of `Gui.bitmap` (not yet proven in game: if the engine ignores the tint the disc shows white). Green keeps red enemy dots so the default is unchanged; other colours use a brighter dot of the same hue. Enemy structures stay orange.
