# HANDOFF: Sixth Sense (formerly Rear Heat HUD)

> Current state only, in five parts. Update in place at each checkpoint. Rationale, decisions, and history go to [docs/history/](docs/history/), and release notes go to [CHANGELOG.md](CHANGELOG.md).

## Current goal
Get **v1.4.5** confirmed in game: a 360° north-up enemy radar HUD for Helldivers 2, a Lua addon under HellForge's Bingus Shared Loader (LuaJIT, offline build 25480438). Work goes on `develop`; batch several fixes per build.

## What is done
- v1.4.5 (`beb089e`): F7 calibration page with **Display** and **Settings** tabs, grab handle (move) and corner handles (resize), two-click **Reset**, hold F7 3 s to reset the layout. Mouse only: no `[ ]` keys, no F8.
- Settings tab: Size, Sensitivity, Repeat rate and Dot size sliders, plus **Shown / Hidden** visibility buttons (`visibility=shown|hidden`).
- Dots 12/24/44/58 px at 1080 tall (× dot_size). Enemy turrets are orange diamonds. Pods and dead enemies are excluded.
- Placement is stored as screen fractions and survives resolution changes; transform scaled by screen height.

## What is blocked
- Darryl's in-game test of v1.4.5 (not yet reported).
- Transform only measured at 3840x1080; other resolutions unverified (check the `transform (...)` log lines).
- Illuminate turret ids unknown: `static_log=true` collects `static?:` candidates in the log.
- Possible custom radar PNG from Darryl (would replace `assets/radar_disc.png`).

## Key file paths / locations
- Repo: box `/workspace/hd2-research/rear_heat_hud`, remote `lankynibbs/SixthSense`, branch `develop`.
- Source: `src/sixth_sense.lua` (+ `src/enemy_tiers.lua.inc`); older versions `src/rear_heat_hud_v*.lua`, `src/sixth_sense_v1.4.*.lua`.
- Build: `python3 tools/build.py` → `SixthSense.zip` (`--no-texture` → `SixthSense-no-texture.zip`). GUID in `GUID.txt` (reuse). Textures: `assets/`, `tools/radar_texture.py`, `tools/label_textures.py`.
- On `ix`: HellForge `D:\HellForge`; Darryl's versioned zips in `C:\Users\kluster\Downloads`; log and ini `D:\HellForge\userdata\environment\Local\CowboyBingus\Helldivers2\Logs\sixth_sense.{log,ini}`.
- User docs and per-version notes: [README.md](README.md).

## Next concrete action
Wait for Darryl's v1.4.5 in-game report and `sixth_sense.log`; then batch the fixes (plus any Illuminate turret ids from `static?:` lines and other-resolution `transform` lines) into v1.4.6. For uncertain layout, add interactive adjusters rather than guessing.
