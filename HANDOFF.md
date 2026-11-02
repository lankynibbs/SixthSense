# HANDOFF: Sixth Sense (formerly Rear Heat HUD)

> Current state only, in five parts. Update in place at each checkpoint. Rationale, decisions, and history go to [docs/history/](docs/history/), and release notes go to [CHANGELOG.md](CHANGELOG.md).

## Current goal
Get **v1.4.8** confirmed in game (and v1.4.7's settings-file fix): a 360° north-up enemy radar HUD for Helldivers 2, a Lua addon under HellForge's Bingus Shared Loader (LuaJIT, offline build 25480438). Work goes on `develop`; batch several fixes per build.

## What is done
- v1.4.6 per-resolution layouts (`radar_layouts`, unsaved = centred, Reset clears current only): approved in game by Darryl.
- v1.4.7: settings file search APPDATA -> LOCALAPPDATA -> `<HellForge>\userdata\profiles\*\user_settings.config`; drawable area = top-left render_resolution, logged as `viewport:` (not yet tested in game).
- v1.4.8: **Pick** button (F7, mouse only): logs `PICK id <hex> name ... class ... dist ...` for the unit nearest the crosshair, shows `PICKED: <id>` large on the F7 page, rings it on the radar for 2 s, counts `picked_ids` in the ini. Darryl declined an automatic discovery mode.
- F7 page: Display / Settings tabs, grab and corner handles, Reset, Pick, F7 held 3 s, resolution line. No `[ ]`, no F8. Settings: 4 sliders + Shown / Hidden.

## What is blocked
- Darryl's in-game tests of v1.4.7 (`viewport:` should name `profiles\default\user_settings.config`, render 2960x832) and v1.4.8 (does Pick get the unit under the crosshair?).
- Illuminate turret ids: to be collected with Pick (`picked_ids`), then added to `static_ids`.
- Gui.resolution "596 1" unexplained; GUI transform only measured at 3840x1080.

## Key file paths / locations
- Repo: box `/workspace/hd2-research/rear_heat_hud`, remote `lankynibbs/SixthSense`, branch `develop`.
- Source: `src/sixth_sense.lua` (+ `src/enemy_tiers.lua.inc`); older versions `src/rear_heat_hud_v*.lua`, `src/sixth_sense_v1.4.*.lua`.
- Build: `python3 tools/build.py` → `SixthSense.zip` (`--no-texture` → `SixthSense-no-texture.zip`). GUID in `GUID.txt` (reuse). Textures: `assets/`, `tools/radar_texture.py`, `tools/label_textures.py`.
- On `ix`: HellForge `D:\HellForge`; Darryl's versioned zips in `C:\Users\kluster\Downloads`; log and ini `D:\HellForge\userdata\environment\Local\CowboyBingus\Helldivers2\Logs\sixth_sense.{log,ini}`.
- User docs and per-version notes: [README.md](README.md).

## Next concrete action
Get Darryl's v1.4.8 log: `viewport:` lines, and `PICK id` lines for an Illuminate sentry; add confirmed ids to the built-in static list.
