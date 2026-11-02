# Sixth Sense (formerly Rear Heat HUD; HellForge / offline HD2 build 25480438)

*Sixth Sense v1.4.6 is a 360-degree enemy radar. The section below describes the original v0.x bars; see the version notes at the end for what it is now.*

Three bars at the bottom centre of the screen: **left-rear, rear, right-rear**. Each one fades from clear to yellow
to red as the threat behind you rises. Threat in a sector = the sum, over living enemies within `range` metres
(default 40) that are more than 100° off your view, of tier weight (light 1, medium 2.5, heavy 5) × closeness.
"Rear" is more than 150° off your view, and the two side bars cover 100–150° on each side.
Dead enemies are skipped. It is read-only and draws only rectangles, no text.

Route: a **Lua addon for Bingus Shared Loader**, which HellForge loads as a Lua mod (docs/lua-bridge.md).
HellForge's C SDK has no camera, unit-position or drawing API, and its docs say "HellForge has not mapped enemies yet".

## Files
- `src/rear_heat_hud.lua`: the source. Its first line is the `-- HD2-Addon: mods/darryl/rear_heat_hud` declaration.
- `Rear-Heat-HUD.zip`: built with Bingus Shared Loader's own `scripts/build_addon.py`. It holds the patch, its empty
  sidecars and `manifest.json`. GUID is in `GUID.txt`; reuse it for updates.

## Install (on ix, Windows)
1. Get **Bingus Shared Loader v20** (`Bingus-Shared-Loader-v20.zip`, Nexus Mods / github.com/CowboyBingus/BingusSharedLoader).
   v20 supports build 25480438, the build HellForge runs. HellForge does not ship it.
2. Copy `Rear-Heat-HUD.zip` to ix.
3. Open the HellForge launcher > **Mods** page > **Add mods...** and pick both zips.
4. Switch both on. New mods start switched off. They show in the cosmetic group with a **LUA** tag.
   The Mods page warns if Bingus Shared Loader is missing.
5. Launch the game from HellForge.

## Test
1. Start any mission, solo is fine. On the ship the bars should show only as faint white outlines.
2. Let enemies get behind you. Turn away from a patrol and the matching bar should go yellow, then red, as they close.
   Spin around: the heat should move between bars and fade smoothly.
3. Read the logs. Open them by pasting the path into File Explorer's address bar:
   - `%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\rear_heat_hud.log`: `loaded`, `camera unit found`,
     `screen gui created`, and a `scan` line about every 10 s (live enemy count, those in range, L/C/R threat).
   - The Bingus Shared Loader log in the same folder says whether `mods/darryl/rear_heat_hud` was discovered and started.
4. If left and right are mirrored, set `swap_sides=true` (see below).

## Settings
`rear_heat_hud.ini` in the Logs folder is written on the first run (v0.2). Edit it in Notepad, then restart the game.
`range` (10–100 m), `opacity` (0.1–1), `position` (`bottom`/`top`), `offset_y` (share of screen height),
`size` (0.5–2), `scan_interval` (s), `swap_sides`, `debug` (logs every scan).
There is no in-game menu.

## Not verified in game (everything below is from source reading and an offline stub test)
- That these engine calls behave the same on build 25480438 as in the 2026 mods they were taken from:
  `Unit.num_cameras`/`Unit.camera`/`Camera.world_position`/`Camera.world_rotation`/`Quaternion.forward`,
  `World.units_by_resource` + `IdString64.from_hex`, `Unit.has_animation_state_machine` (as the dead check),
  `World.create_screen_gui(w, "immediate")` + `Gui.rect(gui, Vector3, Vector2, Color(a,r,g,b))`.
- That the main world is the one with the most units, and that the first unit with a camera is the player's view camera.
- The enemy ids come from Treasure Radar's list for the 2026 build. Enemies added after 25480438 just won't match.
  An old-build enemy missing from the list is not counted.
- The left/right sign (z-up assumed), screen origin bottom-left, and how it looks at resolutions other than 1080p.
- A dying enemy keeps its animation state machine for a few seconds, so it still counts briefly.
Safety: only enemy resource ids are ever asked for a position. It never calls position on runtime-built units from
`World.units`, which ends the game. All state is dropped when the world changes, it draws no text so it holds no
font ids, every engine call is pcall'd, and the HUD switches itself off after 50 errors.

## v0.2.0 changes
- Enemies are found by walking `World.units` (300 units a frame) and reading each unit's resource id
  (`Unit.resource_name`, then `IdString64.to_hex`, or the hex inside its `#ID[...]` text). v0.1 used
  `World.units_by_resource` instead, and saw 0 enemies. Runtime-built units (`46cab355bd8d4d37`) are only counted.
  Nothing else is asked of them, since asking their position ends the game.
- Discovery mode (`discovery=true`, the default) logs every unit kind near you every 5 s: count, how many are within
  `discovery_range`, how many have an animation state machine, how many moved, and the nearest distance.
  It also writes `rear_heat_hud_discovery.txt` every 30 s: the top resource ids from combat moments.
  It logs once whether `World.units_by_resource` answers on this build.
- `detect=list|candidates|both`. `candidates` counts any animated unit that moved in the last 20 s, other than you,
  as an enemy, so the HUD works without a list. Squadmates, SEAF and civilians can count too.
- The ini, the log and the summary are all in the Logs folder, and the log prints their resolved paths and the
  LOCALAPPDATA/APPDATA values. Under HellForge the folder is
  `D:\HellForge\userdata\environment\Local\CowboyBingus\Helldivers2\Logs\`.

## v0.3.0 changes
- Drawing: the screen GUI is now made the way Treasure Radar's loader makes it, with the `core/performance_hud/debug`
  font and the `core/performance_hud/gui` material. Two simpler fallbacks follow it, and each attempt is logged.
  Vector3, Vector2 and Color now come from the `stingray` table first. The screen size comes from
  `Application.back_buffer_size`. For 20 s after each world load there is a big magenta test box plus a test text line
  (`test_draw=true`). The first 3 drawn frames log what each draw step returned.
- Known enemies: `World.units_by_resource` with a fresh `IdString64` every 0.25 s. v0.1 kept them across frames, the
  likely cause of its 0 enemies. The main world is `Application.main_world`.
- Candidates no longer include units within 4 m of your Helldiver. Kinds that looked ambient or attached to you in
  run2 are ignored.
- A `scan:` line every 5 s shows known enemies, candidates, the threat and heat per bar, and the draw ok/failed counts.
  Discovery logs its top 15 every 30 s and still writes the summary file. Units without animation are only counted;
  set `discovery_static=true` to also measure them.
- Delete the old `rear_heat_hud.ini` so the new keys are written.

## v0.4.0 changes
- No Gui.text at all. The test is rect-only: a magenta box with a white bar that shrinks over 20 s.
- World teardown: the old GUI is never touched or destroyed. v0.3 called `World.destroy_gui` on the old world.
  When the number of worlds changes, or the main world is no longer among `Application.worlds()`, or the world's clock
  goes back, the mod drops all its state and does nothing (no unit calls, no drawing) for 2 s.
- Bars are centred on the back-buffer width (3840x1080 works the same as 1920x1080), sized by screen height.

## v0.5.0 changes
- The bars use the same `rect()` as the test box and its layer (950; ini `layer`). They are bigger (160x22 at 1080p
  height), have a dark backing and a 4-sided white outline that is always shown, and sit at 12% of the screen height
  from the bottom (`offset_y=0.12`), centred on the full width (3840 wide works).
- Heat is clamped to 0..3 before it becomes a colour, and alpha is clamped to 0..255.
- `bar_debug=true` (the default in this build) keeps every bar at least half heat and draws its fill half width.
  Set it false for real use.
- The first 3 frames after each world load log each bar's rect (x, y, w, h, layer, heat) next to the test box's.
- Delete the old `rear_heat_hud.ini` so `bar_debug`, `layer` and the new `offset_y` are written.

## v0.6.0 changes
- Everything (test box, bars, diagnostics) is drawn by one helper, `box()`. It makes the test box's exact call:
  whole-number x, y, w, h, `Color(a, r, g, b)` from whole numbers, and layer 950.
- `heartbeat=true`: a 40x40 magenta square at (20, 20), always drawn.
- `probes=true`: red, green and blue 30x30 squares at screen centre, at 15%, 35% and 65% of the height.
  Note which of them you see.
- Delete `rear_heat_hud.ini` so the new keys are written.

## v0.7.0 changes
- Bars default to `offset_y=0.42` from the bottom (`origin_top=false`). That is inside the 35%-65% band where the
  probes were seen, and just below the middle. Set `origin_top=true` if the bars show above the middle instead.
- `calibrate=true`: a column of squares at 55% of the width and a row at 55% of the height, one every 5% (21 each).
  Every 25% (0, 25, 50, 75, 100%) is white. The rest cycle red, orange, yellow, green, cyan, blue, magenta, and
  squares grow from 10 px (0%) to 50 px (100%). Report the first and last visible square in each, counted from the
  smallest. Probes are off by default; the heartbeat stays on.
- Logs `Application.back_buffer_size`, `Application.resolution`, `Gui.resolution`, `Window.*`, `user_setting` and
  `RESOLUTION_LOOKUP` once per world (`res ...` lines).
- Delete `rear_heat_hud.ini` so the new keys are written.

## v0.8.0 changes
- Drawing goes through a view transform. The visible screen is taken to be the part of the drawing space from
  (`view_x0`, `view_y0`) of size (`view_w`, `view_h`), as fractions, with y running from the top down. Defaults
  0.25 / 0.25 / 0.75 / 0.75 come from the v0.7 calibration.
- The bars sit at the bottom centre of that view, `offset_y=0.15` of its height up from its bottom edge.
- `corners=true`: L marks in the view's corners (top-left red, top-right green, bottom-left blue, bottom-right
  yellow) and a white cross in its middle. They should touch the screen's corners. If the right/bottom ones stop
  short, raise `view_w`/`view_h`.
- The test box is at the view centre. Heartbeat, probes and calibration grid are removed.
- `user_setting` values (screen_resolution, render_settings, fullscreen, window mode, render_scale, hud_scale, ...)
  are dumped into the log as `res` lines.
- Delete `rear_heat_hud.ini` so the new keys are written.

## v0.9.0 changes
- One screen transform, measured in game at 3840x1080: the drawing space's y runs from the **bottom up**, and
  `screen_x = 1.2*gx`, `screen_y = (1080 - gy)*0.9333` (from the top). The visible gui runs gx 0..3200 and
  gy 1080 (top) down to about -77 (bottom). A point at fraction (fx, fy) of the visible screen, fy from the top, is
  drawn at `gx = fx*SW/sx_scale`, `gy = gy_top - fy*SH/sy_scale - h_gui`. The rect's gui height is subtracted
  because rects extend upward, which puts the rect's top edge at fy. SW and SH come from `Application.back_buffer_size`.
  Sizes are in screen px (gui w = w/sx_scale, h = h/sy_scale).
- ini keys `sx_scale=1.2`, `sy_scale=0.9333`, `gy_top=1080`. The `view_*` keys are gone.
- Every rect goes through the transform: corner Ls (red top-left, green top-right, blue bottom-left, yellow
  bottom-right), the white centre cross and the bars. `corners=true` and `bar_debug=true` by default.
- Bars sit at the bottom centre of the screen, their bottom edge `offset_y=0.15` of the screen height up from the bottom.
- The magenta test box, its timer bar and `test_draw` are removed.
- A `transform:` log line (once) gives the values and the visible gui range. Bar log lines give screen and gui rects.
- Delete `rear_heat_hud.ini` so the new keys are written.

## v1.0.0 changes
- Interactive calibration (`calibrate=true` by default in this build). It replaces the corner and cross debug marks,
  which are now drawn only while calibrating. With `calibrate=false` only the bars are drawn.
- The placement area is saved in the ini as `area_x0`, `area_y0`, `area_x1`, `area_y1` (gui units: x0 left, x1 right,
  y0 bottom, y1 top, gui y runs up) plus the derived `area_scale`, and loaded on start. All 0 means not calibrated:
  the area starts as the full screen from `sx_scale`, `sy_scale` and `gy_top`.
- The bars are centred at `bars_fx=0.5`, `bars_fy=0.85` of the area (fy from its top) and scale with it. Change these
  to move the bars later without calibrating again. `offset_y` and `corners` are gone.
- At most every 0.5 s while it changes, and when calibration is switched off (F7 since v1.0.1), the log gets two lines:
  `area ...: gui left/right/top/bottom/centre/width/height/scale` and the same in screen px.
- On load, the log lists which Mouse, Keyboard and Window functions exist, the axis, button and key indexes, the first
  cursor, delta and wheel reads, and the mouse dead zone. It then logs the raw values of the first 12 mouse moves (cursor
  axis, window size, whether the game shows its cursor, whether the mouse is held) with the screen px they map to.

## How to calibrate
1. Install the new zip and start the game. On the ship you see a see-through blue rectangle with a white outline, a
   coloured square in each corner (red top-left, green top-right, blue bottom-left, yellow bottom-right), a white
   cross in the middle, the three bars, a slider near its top and a small white square, which is your cursor.
2. **Move:** hold the left mouse button inside the rectangle and drag. Without the mouse, use the **arrow keys**
   (2 px a press; hold **Shift** for 20 px; holding a key repeats).
3. **Scale:** drag the cyan slider's white knob left or right (scale 0.25 on the left, 2.5 on the right; the yellow
   tick is 1.0), or turn the **mouse wheel**. (No +/- keys since v1.2.1.)
4. Get the four corner squares exactly into your screen's four corners.
   Under the cyan scale slider are two settings sliders. Drag their knobs with the mouse (no keys):
   **orange = sensitivity**, **magenta = repeat_rate** (both 0.25-3, yellow tick at 1.0).
5. Press **F7**. That saves the area (`calibrate=false`) and hides everything except the bars. Press **F7** again at
   any time to bring the calibration back. (HellForge uses F8. The key is `toggle_key=f7` in the ini, and any engine
   key name works, e.g. `f6`.)
6. If the white cursor square moves opposite to your mouse vertically, set `cursor_flip_y=true` in the ini.
   If the mouse does nothing at all, use the keys. Either way, send `rear_heat_hud.log`: its `input:` lines show what
   the game answered.
While you calibrate, the mouse is held so the camera doesn't turn: its dead zone is raised the way Chef Shared Loader
does it, then put back on F7 or when the game exits. The game still sees the clicks and keys, so calibrate on the ship.

## v1.0.1 changes
- The calibration toggle is **F7** (HellForge uses F8). It is set by the new ini key `toggle_key=f7`, which an older ini
  gains on the next save.
- The game clips gui drawing below gy 0, even though the screen goes lower. The area is now kept with its bottom at
  gy 0 or higher and its right edge at the visible gx (screen width / sx_scale, 3200 at 3840 wide) or lower, both
  when dragging and when scaling. It is shifted back inside, never resized. The log says `drawable gui bounds` once,
  and `area clamped (move|scale)` when a clamp happens (at most every 0.5 s). A saved area is loaded as it is.

## v1.1.0 changes (steady indicator)
Why it flickered in v1.0.1:
- Candidates (animated units that moved lately) were only swapped in at the end of a full `World.units` walk. At
  300 units a frame that takes seconds, so the candidate list jumped between 0 and 11 at random moments.
- Known enemies were rebuilt from scratch on every lookup.
- The heat followed the instant threat both ways with the same 0.17 s time constant, so turning the camera a few
  degrees, or one missed frame, dropped a bar to nothing at once.
- The rear zone started at 100° off the view, so an enemy beside-behind you (90-100°) never counted.

What changed:
- One tracking table that lasts across frames:
  - Known enemies are re-acquired every 0.5 s.
  - Candidates are added the moment the walk qualifies them.
  - Every tracked unit's position is read every frame, and the threat is worked out every frame.
  - A unit is kept until it is dead, loses its animation state machine, is beyond `range` + 15 m, or was not seen
    again (known: 3 s, candidate: 30 s).
- Rear = the back 180° in thirds: **L** bearing -150..-90, **C** beyond ±150, **R** +90..+150. Bearing is measured
  from the camera's forward and right vectors (z up, right = (fy, -fx)), + right, - left. Distance is measured from your
  Helldiver when it's found.
- Smoothing: the heat rises to the threat in about 0.15 s. When the threat drops, it holds 1 s and then fades over 1.5 s.
- Every scan line gives the nearest tracked enemy: id, kind (name), distance, bearing (left/right) and which bar
  (or "front, no bar").
- `bar_debug=false` is the default, and an older ini is switched to false once on load (`v110_migrated=true` marks
  it done; nothing else in the ini is touched). Idle bars are faint outlines.

## v1.2.0 changes
- **sensitivity** (ini `sensitivity=1.0`, 0.25-3): the detection range is `range` × sensitivity, clamped to 10-120 m
  (40 m becomes 80 m at 2.0), and each enemy's threat is multiplied by it too. Higher means farther and hotter.
- **repeat_rate** (ini `repeat_rate=1.0`, 0.25-3): higher means faster response. Known enemies are looked up every
  0.5 s / rate, the bars hold for 1 s / rate and fade over 1.5 s / rate.
- In calibration (F7) each one is a slider under the scale slider: sensitivity is orange and repeat_rate is magenta. Each
  has a yellow tick at 1.0 and is drawn with rects only. Keys: `[` and `]` for sensitivity, `;` and `'` for
  repeat_rate. Each press is 0.05 (Shift: 0.25). The key indexes are looked up under several names
  (`[`/`left bracket`/`oem_4`, `]`/`right bracket`/`oem_6`, `;`/`semicolon`/`oem_1`, `'`/`apostrophe`/`quote`/`oem_7`),
  and the `input: key sens_*` and `rate_*` lines log which ones the game answered.
- Changes are saved with the area, at most every 0.5 s and on F7. A `settings ...` log line gives the resulting range,
  gain, re-acquire, hold and fade. The other ini keys and the saved area are left as they are.

## v1.2.1 changes
- No keyboard bindings for the sliders. `[ ]` (sensitivity), `; '` (repeat_rate) and `+ / -` (scale) are gone, and so
  are their key lookups. The game keeps those keys. The sliders are mouse only, and the mouse wheel still scales.
  The arrow-key nudges and F7 (`toggle_key`) are unchanged. The ini is unchanged.

## v1.3.0: the radar
The three bars are replaced by a classic radar inside the saved F7 area. The view is always north-up, meaning up is
where the camera looks.
- **Where:** centred at `radar_fx=0.5`, `radar_fy=0.78` of the area (fy from its top). `radar_size=0.35` is the
  diameter as a share of the area height. It scales with the area. `bars_fx` and `bars_fy` are no longer used.
- **What's on it:**
  - an outer circle, and rings at 1/3 and 2/3 of the effective range (`range` × `sensitivity`, 10-120 m)
  - cross hairs, and a white player marker in the middle with a small nose pointing up
- **Enemies:**
  - Every tracked enemy (known and candidates, updated every frame) is a red dot at its true bearing and distance,
    a full 360°: front is up, behind is down, left is left. The world is turned into camera space with the same
    forward and right vectors as the L/C/R math (`swap_sides` still mirrors).
  - Heavies are 1.3x larger.
  - Beyond range (up to range + 15 m, while still tracked), a dot sits on the rim, faded.
  - A lost enemy's dot stays at its last spot for 1 s / `repeat_rate`, then fades over 1.5 s / `repeat_rate`.
- **Dot size:** `dot_size=small|medium|large` (6 / 10 / 16 px at 1080 tall, scaled with the area). In F7 it's the 4th
  slider (red, under the magenta one), with 3 snap positions and the tick at medium. Mouse only, no keys.
- **Disc style:** `radar_style=auto|texture|dots`.
  - The texture (`assets/radar_disc.png`, 512x512 RGBA: a see-through dark green disc, a bright green rim, 2 rings
    and cross hairs, made by `tools/radar_texture.py`) ships in the same patch as the Lua, the way Treasure Radar
    ships its textures. It's drawn on its own screen GUI with the game's UI material `content/ui/shared/misc/yellow_logo`
    (`Gui.material` + `Material.set_texture`, then `Gui.bitmap`).
  - The first try is checked with `Application.can_get` and logged as `radar: texture bitmap draw succeeded` or
    `... failed: <why> -> rect dots`.
  - auto and texture fall back to rect dots when it fails: an 80-dot rim, rings of 48 and 32, and 2 cross hair rects.
  - dots never tries the texture.
- **Draw cost:** at most 150 enemy dots. Dots style is about 170 rects a frame; texture style is 1 bitmap + 2 rects +
  the enemy dots. The first 3 frames log a `radar:` line (style, centre, radius, range, dot size, rects, dots), and
  every scan line adds `radar <style> rects/frame N dots N`.
- **L/C/R:** the math is kept only for the scan log (threat and heat per sector, nearest threat).
- **Build:** `python3 tools/build.py` makes `Rear-Heat-HUD.zip`. It uses `build_addon.py`'s entry declaration,
  manifest and zip layout, adds the texture type row, and puts the pixels in `.gpu_resources`.
  `python3 tools/build.py --no-texture --output Rear-Heat-HUD-no-texture.zip` makes the Lua-only patch.
  It is byte-identical to `build_addon.py`'s output, so the radar draws in dots.

## v1.3.1 changes
- **Round disc.** In v1.3 the disc was tall and skinny, about 1.2 / 0.9333 = 1.29 too narrow. That means `Gui.bitmap`
  takes its size in screen px while its position follows the gui transform (rects take their size in gui units).
  Textures are now sized in screen px (`tex_size_px=true`; false gives v1.3's way). The disc is centred on the same
  point as the overlay. Its rim sits on the overlay's circle (rim radius = 250/256 of the texture's half size), so the
  1/3 and 2/3 rings line up with the dots' range.
- `radar_aspect=1.0` (0.5-2) trims the width of the disc and the dot overlay together if it still isn't round on your screen.
- **Slider labels in F7:** Size, Sensitivity, Repeat rate and Dot size sit left of each slider. Each label is a word
  texture (`assets/label_*.png`, Poppins Bold under the SIL OFL, made by `tools/label_textures.py`), drawn with the
  same bitmap method as the disc. Each slider's current value (`1.00x`, or S/M/L for the dot size) sits to its right,
  in a 5x7 pixel font made of rects, in the slider's colour.
  - A label texture that fails is logged (`bitmap label <name>: draw failed: ...`) and drawn in the pixel font from then on.
  - `label_style=auto|texture|pixel|off`.
  - Labels are drawn only in calibration, never while a world settles.
- **No Gui.text.** Working mods on this game (Chef Shared Loader's `chef.text`) draw text through a retained text GUI,
  with the game's runtime font (`content/fonts/fs_sinclair_medium_runtime`) and its `content/fonts/runtime_font`
  material, plus `Gui.update_text` and `Gui.destroy_text` bookkeeping. Chef's own notes say a GUI given a font whose
  material the game doesn't make "ends the game", and that is how v0.3 crashed with the performance HUD font.
  Those font names are from the 2026 game, not checked on 25480438, so word textures are the safer default.
- The build ships 5 textures: the disc and 4 labels. `python3 tools/build.py`, and add `--no-texture` for the Lua-only zip.

## v1.3.2 changes
- **Rounder disc:** `radar_aspect` now defaults to 1.25 (25% wider), for both the disc texture and the dot overlay. An ini that still has `radar_aspect=1.0` is moved to 1.25 once (`v132_migrated=true` is written after that). Your placement keys, sensitivity and repeat_rate are not touched.
- **Pods excluded:** these are never tracked: `583ecde0d7718126` (Hellpod and stratagem pods; in the log there were 3-5 of them right where you landed), `16f397ca5f51f271` (a pod, a guess: 2 at a time, seen only after drops), the Warp Ship `74e2285c01da4f71` and `f735a51a991e4bda`, and the Dropship `db90077e76faa025`. You can add more ids with `ignore_ids=` in the ini (16-digit hex, separated by commas).
- **Candidate filter:** an unknown kind has to be tracked for 0.5 s before it shows. Anything falling faster than 12 m/s while moving less than 3 m/s sideways is hidden for 2 s. Flyers are exempt: the Stingray (Strikers) and the Gunship.
- **Dead enemies clear in about 0.3 s:**
  - A unit is dead when its animation state is a known death state (Treasure Radar's table, e.g. Voteless state 31). The mod also learns a kind's death state after it has seen it twice.
  - It is also dead when it stops being alive or loses its animation state machine.
  - A unit that has moved and then stays still, with no movement over 5 cm and no state change, for `still_hide` s (default 1.0; 0 turns this off) is hidden too. It shows again as soon as it moves.
  - The dead fade out in 0.3 s with no hold. The repeat_rate hold (1 s ÷ rate, then a 1.5 s ÷ rate fade) now applies only to units that were lost from tracking.
- **Size classes** (× dot_size):
  - tiny 0.6: Voteless
  - medium 1.0: Overseers, Watcher, Stingray, and unknown candidates
  - large 1.6: Fleshmob and other heavies
  - xlarge 2.2: Harvester, Leviathan, Factory and War Strider, Vox Engine

  Other known kinds go by tier (light tiny, medium medium, heavy large). A kind that is not in the size map is logged once as `size: <hex> ... (not in the size map)`.

## v1.4.0: Sixth Sense
- **Renamed** to Sixth Sense. The display name is "Sixth Sense v1.4.0" and the files are `sixth_sense.log`, `sixth_sense.ini` and `sixth_sense_discovery.txt`. The Lua module is `mods/darryl/sixth_sense`, the source is `src/sixth_sense.lua`, and the zips are `SixthSense.zip` and `SixthSense-no-texture.zip`. The GUID is unchanged, so HellForge updates the mod in place. The textures keep their v1.3 resource paths because the Lua names their ids.
- **Settings carried over:** on the first load with no `sixth_sense.ini`, `rear_heat_hud.ini` is copied as it is (area, sliders, radar keys and migration flags), and the log says so. The old file stays where it is.
- **Enemy structures** are drawn as orange-red diamonds at medium size. They are exempt from still-hide and from the fall filter. They wait 0.5 s like candidates before they show.
  - Built-in list:
    - Cannon Turret `2cf3488c4845f8bd` (`cyborg_turret_heavycannon`)
    - AA/autocannon turret `aeaef7a1851e6c9d` (`cyborg_turret_autocannons`)
    - Mortar turret `ff5cc825b9571052` (`cyborg_turret_mortar`)
    - Bunker Turret `9926876b2375a1bb`
  - Ids are hashes of the unit paths in the hashlist. Add more with `static_ids=` (16-digit hex, comma separated).
  - A structure is removed when it is no longer alive, when its first mesh is hidden (Treasure Radar's destroyed test), when its death animation state shows (asked only of units that have a state machine), or when the walk has not found it for 10 s.
  - The tank-turret paths are also the turrets on Tanks, so a turret within 6 m of a tracked known enemy is not drawn.
  - `static_log=true` logs each unknown non-animated kind within range once, with its distance, as `static?: <hex> at N m`. Illuminate turrets have no path in the hashlist, so map them from that log.
- **Our turrets are never shown.** The Helldiver stratagem turret ids are excluded (`gatling_turret`, `manned_turret`, `manned_turret_discoverable`, `turret_machinegun_gpmg`, `tutorial_turret`). A listed structure that first appears after the first full walk within 50 m of you is also taken as ours, since enemy structures are there from the start.
- **Fixed slider panel:** in F7 calibration the sliders, labels and values sit at `panel_fx`/`panel_fy` (default 0.03, 0.08: top left), kept on screen. Dragging, the wheel and the arrows move only the radar. The clamp applies to the radar alone.
- **Tabs in F7 calibration:** there are two buttons, Display and Settings. They are word textures with a pixel-font fallback, fixed at the panel position, and the active one is lit. F7 always opens on **Display**, which shows only the radar with its outline and handles: drag moves it (clamped to the drawable area), and the wheel and arrows resize or nudge it. **Settings** shows the four sliders with their labels and values below the tabs. The radar stays visible as a preview but cannot be dragged, resized or nudged there. Mouse only, with no new keys.

## v1.4.1 changes
- **The panel is always visible.** The tabs, the Move button, the sliders, labels and values are drawn after the radar, on a higher layer: rects at 990 over the radar's 950, and label textures at 995 over the disc's 900. The cursor is drawn on top at 999. Each tab has a dark backing.
- **Auto-placed panel:** if the radar's area covers the `panel_fx`/`panel_fy` spot, the panel moves to the opposite vertical half, then to the other side, then to the opposite corner. If none of those is clear, it takes the spot with the least overlap. It is placed when F7 opens, when the radar is dropped and when Move goes off, never mid-drag, and the log notes it ("panel: at ...").
- **Move button** on the Display tab (a word texture, lit while on). Only with Move on does a left-drag move the radar and the wheel or arrows resize or nudge it. With Move off, clicks on the radar do nothing. Clicking Move again, switching tabs or closing with F7 turns it off and saves. F7 always opens with Move off.
- **Wider dot sizes:** the base sizes in screen px at 1080 tall are tiny 5, medium 11, large 22 and xlarge 30. They are multiplied by dot_size (small 0.75, medium 1, large 1.35) and by the area scale.
  - The Fleshmob `67dc32dca4f02d33` and the Leviathan `f22d027b37bef107` are large; the Leviathan was xlarge before.
  - xlarge is the Harvester and the Factory/War Striders and Vox Engine.
  - The hashlist has no Fleshmob (or other Illuminate unit) paths, so no other ids were found.
  - Enemy structures stay medium diamonds (11 px).

## v1.4.2 changes
- **Placement that survives a resolution change:** the radar is now stored as `radar_cx` and `radar_cy` (its centre as fractions of the visible screen, cy from the top) and `radar_d` (its diameter as a fraction of the screen height). These are converted through the current transform every frame.
  - Your old `area_*`, `radar_fx`, `radar_fy` and `radar_size` were converted once (`v142_migrated`) at the resolution in use when it first loads, so the radar stays where it was on screen. The old keys are left in the ini but no longer used.
  - The Size slider now sets the diameter (0.08–1.0, tick at the default 0.35).
- **Transform:** `sx_scale` and `sy_scale` (1.2 and 0.9333, measured at 3840×1080) are taken as measured at `transform_ref_h` (1080) and scaled with the screen height. In other words the gui is assumed to be 1080-tall-normalised: sx = 1.2·H/1080, sy = 0.9333·H/1080, with gy_top fixed at 1080, so the visible gui width follows the aspect ratio. `transform_scale=fixed` brings back the old fixed numbers.
  - This model is an assumption; only 3840×1080 has been measured. Every load and resolution change logs a `transform (...)` line (screen, model, sx/sy, visible gui and drawable bottom) so other resolutions can be checked.
  - Back_buffer_size is checked once a second. On a change the transform is redone, the radar keeps its fractions, is clamped back in (reset if still invalid), the panel is re-placed and everything is saved.
- **Recovery:**
  - On load and on any resolution change, a radar outside the drawable screen is clamped back in, and an invalid one is reset.
  - The **Reset** button sits on both tabs. One click arms it (lit for 3 s); a second click within 3 s confirms. On Display it puts the radar back centred, 75% down the drawable area, at the default size. On Settings it restores the slider defaults (size, sensitivity, repeat rate, dot size). It saves at once and logs.
  - **Holding F7 for 3 s** resets the whole layout (radar and panel position) and leaves calibration on.
- **Moving without the Move toggle** (which is gone): on the Display tab, drag the 4-way grab handle on the radar's top edge to move it, drag a corner handle to resize it about its centre, or use the wheel over the radar to resize. Clicks anywhere else on the radar do nothing, and the arrow keys still nudge. The panel stays on top and is re-placed when the radar is dropped or the Size slider is released.

## v1.4.4 changes

- Dots start out about twice as big: base sizes at 1080 tall are tiny 12, medium 24, large 44, extra large 58 px
  (x0.75 / x1 / x1.35 for dot_size small / medium / large). A saved dot_size=small is reset to medium once
  (v144_migrated).
- New `visibility` setting: hidden, always, or hud (only while the game's HUD is shown). Set it with the green
  3-way slider on the F7 page's Settings tab (mouse only). The F7 page always shows the radar, even when hidden.
  hud mode probes for the game's HUD state (game globals, then Application.user_setting keys such as hud_visible)
  and logs what it finds as `visibility:` lines in sixth_sense.log; if nothing answers, hud acts as always.
  The default is always, because HUD detection is not confirmed on this build yet.

## v1.4.5 changes

- HUD mode is gone (the game's HUD toggle could not be read), with its probing code and log lines.
- Visibility is now a choice: Shown / Hidden buttons (the chosen one lit) under the sliders on the F7 page's
  Settings tab, mouse only. Saved as `visibility=shown|hidden` (default shown). The F7 page always shows the radar.
- A saved `visibility=hud` or `always` becomes `shown` once (v145_migrated).

## v1.4.6 changes

- The drawable area is detected, not assumed: the render size from the game's `user_settings.config`
  (`render_resolution`, Render Scale or a Resolution below the window), anchored top-left, cut where the gui clips at the
  bottom. Logged as a `viewport:` line on load, on a resolution change and when the render size changes.
- Radar placement is stored as fractions of that drawable area, so a centred radar is centred in what you can see.
- Positions are saved per window resolution in `radar_layouts=WxH:cx,cy,d;...`. Going back to a resolution restores
  its layout. A resolution with no saved layout starts centred in the drawable area at the default size
  (`viewport: no saved layout for WxH, using centered default`).
- The old `radar_cx/cy/d` become the 3840x1080 layout once (`v146_migrated`).
- Reset (two clicks, or F7 held 3 s) clears only the current resolution's layout and centres the radar.
- The F7 Display tab shows the resolution and SAVED LAYOUT / NO SAVED LAYOUT.
