# HANDOFF: Sixth Sense (formerly Rear Heat HUD)

> Current state only, in five parts. Update in place at each checkpoint. Rationale, decisions, and history go to [docs/history/](docs/history/), and release notes go to [CHANGELOG.md](CHANGELOG.md).

## Current goal
Get **v1.5.2** confirmed in game (with v1.4.7's settings-file fix): a 360° north-up enemy radar HUD for Helldivers 2, a Lua addon under HellForge's Bingus Shared Loader (LuaJIT, offline build 25480438). Work goes on `develop`; batch several fixes per build.

## What is done
- v1.4.6 per-resolution layouts (`radar_layouts`, unsaved = centred, Reset clears current only): approved in game by Darryl.
- v1.4.7: settings file search APPDATA -> LOCALAPPDATA -> `<HellForge>\userdata\profiles\*\user_settings.config`; drawable area = top-left render_resolution, logged as `viewport:` (not yet tested in game).
- v1.5.0: Mark and Pick removed completely at Darryl's request (buttons, logging, F7 text, radar blink, `picked_ids`, label textures).
- v1.5.1: radar colours (green default, white, yellow, red, light_blue) via a mouse-only "Radar color" snap slider on Settings; `radar_color` in the ini; Reset -> green. Disc texture is white, tinted with the Gui.bitmap colour (confirmed working in game by Darryl).
- v1.5.2: the colour applies to the radar display only (disc, rings, cross hairs); enemy dots always red, structures always orange.
- F7 page: Display / Settings tabs, grab and corner handles, Reset, F7 held 3 s, resolution line. No `[ ]`, no F8. Settings: 5 sliders (Size, Sensitivity, Repeat rate, Dot size, Radar color) + Shown / Hidden.

## What is blocked
- Darryl's in-game tests of v1.4.7 (`viewport:` should name `profiles\default\user_settings.config`, render 2960x832), v1.5.0 (F7 page with Display / Settings / Reset only) and v1.5.2 (enemy markers keep red / orange in every radar colour).
- Illuminate turret ids: still unknown (Mark / Pick, the planned way to collect them, was removed); add any found to `static_ids`.
- Gui.resolution "596 1" unexplained; GUI transform only measured at 3840x1080.

## Key file paths / locations
- Repo: box `/workspace/hd2-research/rear_heat_hud`, remote `lankynibbs/SixthSense`, branch `develop`.
- Source: `src/sixth_sense.lua` (+ `src/enemy_tiers.lua.inc`); older versions `src/rear_heat_hud_v*.lua`, `src/sixth_sense_v1.4.*.lua`.
- Build: `python3 tools/build.py` → `SixthSense.zip` (`--no-texture` → `SixthSense-no-texture.zip`). GUID in `GUID.txt` (reuse). Textures: `assets/`, `tools/radar_texture.py`, `tools/label_textures.py`.
- On `ix`: HellForge `D:\HellForge`; Darryl's versioned zips in `C:\Users\kluster\Downloads`; log and ini `D:\HellForge\userdata\environment\Local\CowboyBingus\Helldivers2\Logs\sixth_sense.{log,ini}`.
- User docs and per-version notes: [README.md](README.md).

## Next concrete action
Get Darryl's v1.5.2 log (`viewport:` lines); confirm in game that each radar colour tints only the disc / rings while enemy dots stay red and structures orange.
