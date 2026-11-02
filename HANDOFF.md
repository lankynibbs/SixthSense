# HANDOFF: Sixth Sense (formerly Rear Heat HUD)

> Current state only, in five parts. Update in place at each checkpoint. Rationale, decisions, and history go to [docs/history/](docs/history/), and release notes go to [CHANGELOG.md](CHANGELOG.md).

## Current goal
Get **v1.4.9** confirmed in game (with v1.4.7's settings-file fix): a 360° north-up enemy radar HUD for Helldivers 2, a Lua addon under HellForge's Bingus Shared Loader (LuaJIT, offline build 25480438). Work goes on `develop`; batch several fixes per build.

## What is done
- v1.4.6 per-resolution layouts (`radar_layouts`, unsaved = centred, Reset clears current only): approved in game by Darryl.
- v1.4.7: settings file search APPDATA -> LOCALAPPDATA -> `<HellForge>\userdata\profiles\*\user_settings.config`; drawable area = top-left render_resolution, logged as `viewport:` (not yet tested in game).
- v1.4.9: **Mark** (button 4) locks the unit at the crosshair (`MARK id <hex>`, `MARKED: <id>` on F7, dot blinks); **Pick** (button 5) logs the marked unit (`PICK id <hex>`, no re-aim; `PICK: no mark set`), counts `picked_ids`. Replaces v1.4.8's aim-at-click Pick (rejected by Darryl).
- F7 page: Display / Settings tabs, grab and corner handles, Reset, Mark, Pick, F7 held 3 s, resolution line. No `[ ]`, no F8. Settings: 4 sliders + Shown / Hidden.

## What is blocked
- Darryl's in-game tests of v1.4.7 (`viewport:` should name `profiles\default\user_settings.config`, render 2960x832) and v1.4.9 (does Mark lock the unit under the crosshair, and Pick log it after aiming away?).
- Illuminate turret ids: to be collected with Mark + Pick (`picked_ids`), then added to `static_ids`.
- Gui.resolution "596 1" unexplained; GUI transform only measured at 3840x1080.

## Key file paths / locations
- Repo: box `/workspace/hd2-research/rear_heat_hud`, remote `lankynibbs/SixthSense`, branch `develop`.
- Source: `src/sixth_sense.lua` (+ `src/enemy_tiers.lua.inc`); older versions `src/rear_heat_hud_v*.lua`, `src/sixth_sense_v1.4.*.lua`.
- Build: `python3 tools/build.py` → `SixthSense.zip` (`--no-texture` → `SixthSense-no-texture.zip`). GUID in `GUID.txt` (reuse). Textures: `assets/`, `tools/radar_texture.py`, `tools/label_textures.py`.
- On `ix`: HellForge `D:\HellForge`; Darryl's versioned zips in `C:\Users\kluster\Downloads`; log and ini `D:\HellForge\userdata\environment\Local\CowboyBingus\Helldivers2\Logs\sixth_sense.{log,ini}`.
- User docs and per-version notes: [README.md](README.md).

## Next concrete action
Get Darryl's v1.4.9 log: `viewport:` lines, and `MARK id` / `PICK id` lines for an Illuminate sentry; add confirmed ids to the built-in static list.
