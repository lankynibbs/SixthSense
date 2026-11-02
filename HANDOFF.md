# HANDOFF: Sixth Sense (formerly Rear Heat HUD)

> Current state only, in five parts. Update in place at each checkpoint. Rationale, decisions, and history go to [docs/history/](docs/history/), and release notes go to [CHANGELOG.md](CHANGELOG.md).

## Current goal
Get **v1.4.6** confirmed in game: a 360° north-up enemy radar HUD for Helldivers 2, a Lua addon under HellForge's Bingus Shared Loader (LuaJIT, offline build 25480438). Work goes on `develop`; batch several fixes per build.

## What is done
- v1.4.6: drawable area detected from `render_resolution` in `user_settings.config` (top-left of the window, cut at the gui's bottom), logged as `viewport:`. Placement is fractions of that area, saved per resolution in `radar_layouts=WxH:cx,cy,d;...`; unsaved resolutions start centred at the default size; Reset clears only the current resolution. Display tab shows the resolution and SAVED / NO SAVED LAYOUT.
- F7 page: **Display** and **Settings** tabs, grab and corner handles, two-click Reset, F7 held 3 s. Mouse only: no `[ ]`, no F8.
- Settings tab: Size, Sensitivity, Repeat rate, Dot size sliders; **Shown / Hidden** buttons (`visibility=shown|hidden`).
- Dots 12/24/44/58 px at 1080 tall (× dot_size). Turrets are orange diamonds; pods and dead enemies excluded.

## What is blocked
- Darryl's in-game test of v1.4.6: check the `viewport:` lines (is `user_settings.config` found? does the drawable rect match what he sees?).
- The gui transform (1.2/0.9333 at 1080 tall) is still only measured at 3840x1080.
- Illuminate turret ids unknown (`static?:` lines). Possible custom radar PNG from Darryl.

## Key file paths / locations
- Repo: box `/workspace/hd2-research/rear_heat_hud`, remote `lankynibbs/SixthSense`, branch `develop`.
- Source: `src/sixth_sense.lua` (+ `src/enemy_tiers.lua.inc`); older versions `src/rear_heat_hud_v*.lua`, `src/sixth_sense_v1.4.*.lua`.
- Build: `python3 tools/build.py` → `SixthSense.zip` (`--no-texture` → `SixthSense-no-texture.zip`). GUID in `GUID.txt` (reuse). Textures: `assets/`, `tools/radar_texture.py`, `tools/label_textures.py`.
- On `ix`: HellForge `D:\HellForge`; Darryl's versioned zips in `C:\Users\kluster\Downloads`; log and ini `D:\HellForge\userdata\environment\Local\CowboyBingus\Helldivers2\Logs\sixth_sense.{log,ini}`.
- User docs and per-version notes: [README.md](README.md).

## Next concrete action
Get Darryl's v1.4.6 `sixth_sense.log` from two or more resolutions (and a Render Scale below native) and compare the `viewport:` lines with where the radar really appears; if the settings file is not found under HellForge, add its real path.
