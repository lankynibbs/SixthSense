# HANDOFF: Sixth Sense (formerly Rear Heat HUD)

> Current state only, in five parts. Update in place at each checkpoint. Rationale, decisions, and history go to [docs/history/](docs/history/), and release notes go to [CHANGELOG.md](CHANGELOG.md).

## Current goal
Get **v1.4.7** confirmed in game: a 360° north-up enemy radar HUD for Helldivers 2, a Lua addon under HellForge's Bingus Shared Loader (LuaJIT, offline build 25480438). Work goes on `develop`; batch several fixes per build.

## What is done
- v1.4.6 per-resolution layouts (`radar_layouts=WxH:cx,cy,d;...`, unsaved = centred, Reset clears current only): **approved in game by Darryl** (3840x1080 <-> 1920x1080).
- v1.4.7: settings file search APPDATA -> LOCALAPPDATA -> `<HellForge>\userdata\profiles\*\user_settings.config` (window-matching screen_resolution, else newest); drawable area = top-left render_resolution (Darryl: 2960x832 in 3840x1080), cut at the gui clip; logged as `viewport:`.
- F7 page: Display / Settings tabs, grab and corner handles, two-click Reset, F7 held 3 s, resolution + SAVED / NO SAVED LAYOUT line. Mouse only: no `[ ]`, no F8.
- Settings: Size, Sensitivity, Repeat rate, Dot size sliders; Shown / Hidden buttons. Dots 12/24/44/58 px at 1080.

## What is blocked
- Darryl's in-game check of v1.4.7: does the `viewport:` line now name `profiles\default\user_settings.config` and render 2960x832, and does the radar stay inside the visible area?
- Whether io.popen/lfs exist under Bingus (profile listing); `default` is always tried regardless.
- Gui.resolution returns "596 1": meaning unknown, logged only. GUI transform still only measured at 3840x1080.
- Illuminate turret ids unknown (`static?:` lines).

## Key file paths / locations
- Repo: box `/workspace/hd2-research/rear_heat_hud`, remote `lankynibbs/SixthSense`, branch `develop`.
- Source: `src/sixth_sense.lua` (+ `src/enemy_tiers.lua.inc`); older versions `src/rear_heat_hud_v*.lua`, `src/sixth_sense_v1.4.*.lua`.
- Build: `python3 tools/build.py` → `SixthSense.zip` (`--no-texture` → `SixthSense-no-texture.zip`). GUID in `GUID.txt` (reuse). Textures: `assets/`, `tools/radar_texture.py`, `tools/label_textures.py`.
- On `ix`: HellForge `D:\HellForge`; Darryl's versioned zips in `C:\Users\kluster\Downloads`; log and ini `D:\HellForge\userdata\environment\Local\CowboyBingus\Helldivers2\Logs\sixth_sense.{log,ini}`.
- User docs and per-version notes: [README.md](README.md).

## Next concrete action
Get Darryl's v1.4.7 `sixth_sense.log` at 3840x1080 with Render Scale 77% (2960x832) and at native; confirm the drawable rect matches what he sees.
