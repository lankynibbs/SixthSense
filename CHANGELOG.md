# Changelog

Release notes for **Sixth Sense** (formerly **Rear Heat HUD**), newest first. Format loosely follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Full per-version detail is in the README's version sections; the story behind them is in [docs/history/](docs/history/).

Versions before v1.3.2 were built before the repo was put under git and are undated.

## [Unreleased]

## [1.4.9] - 2026-11-02
### Changed
- Pick split into **Mark** (locks the unit at the crosshair: `MARK id <hex> ...`, `MARKED: <id>` on the F7 page, dot blinks) and **Pick** (logs the marked unit, `PICK id <hex> ...`, no re-aim; `PICK: no mark set` without one). Darryl rejected aim-at-click Pick.
### Fixed
- Panel auto-placement keeps the whole (wider) panel above the gui's clipped bottom.

## [1.4.8] - 2026-11-02
### Added
- Pick debug button on the F7 page (mouse only): the unit nearest the crosshair is logged as `PICK id <hex> name ... class ... dist ...`, shown large on the F7 page until the next pick, and ringed on the radar for 2 s; `picked_ids=id:count` in the ini. (Automatic discovery mode declined by Darryl.)

## [1.4.7] - 2026-11-02
### Confirmed
- v1.4.6 per-resolution layouts approved in game by Darryl (3840x1080 <-> 1920x1080): saved resolutions restore, unsaved start centred.
### Fixed
- Settings file not found under HellForge: now also searched in `<HellForge>\userdata\profiles\*\user_settings.config` (profile matching the window's screen_resolution, else most recently modified); the file used is logged.

## [1.4.6] - 2026-11-02
### Added
- Drawable-area (viewport) detection from `render_resolution` in the game's settings file; `viewport:` log lines.
- Per-resolution layouts: `radar_layouts=WxH:cx,cy,d;...`; unsaved resolutions start centred in the drawable area at the default size.
- Display tab shows the resolution and whether it has a saved layout.
### Changed
- Placement is fractions of the drawable area. `radar_cx/cy/d` migrated once as the 3840x1080 layout (`v146_migrated`).
- Reset and F7-hold reset clear only the current resolution's layout and centre the radar.

## [1.4.5] - 2026-11-01
### Removed
- HUD visibility mode and its HUD-state probing (the game's HUD toggle can't be read).
### Changed
- Visibility is Shown / Hidden buttons on the Settings tab (`visibility=shown|hidden`); saved `hud`/`always` become `shown` once (`v145_migrated`).

## [1.4.4] - 2026-11-01
### Changed
- Dots about twice as big: 12/24/44/58 px at 1080 tall; saved `dot_size=small` reset to medium once (`v144_migrated`).
### Added
- `visibility` hidden/always/hud with a 3-way slider and HUD-state probe (hud fell back to always).

## [1.4.3] - 2026-11-01
### Changed
- All radar dots larger (7/15/28/38 px at 1080).

## [1.4.2] - 2026-11-01
### Changed
- Placement stored as screen fractions (`radar_cx`, `radar_cy`, `radar_d`), migrated once (`v142_migrated`); transform scaled with screen height; resolution changes re-place and clamp the radar.
- Move toggle replaced by a grab handle (move) and corner handles (resize).
### Added
- Two-click Reset on both tabs; hold F7 for 3 s to reset the layout.

## [1.4.1] - 2026-11-01
### Changed
- Panel always drawn on top and auto-placed away from the radar; wider dot sizes (5/11/22/30 px).
### Added
- Move toggle on the Display tab.

## [1.4.0] - 2026-11-01
### Changed
- Renamed to Sixth Sense (`sixth_sense.*` files, same GUID); `rear_heat_hud.ini` carried over.
- Fixed slider panel; tabbed F7 page (Display / Settings).
### Added
- Enemy structures (turrets) as orange-red diamonds; our own turrets excluded; `static_log`, `static_ids`.

## [1.3.2] - 2026-11-01
### Changed
- `radar_aspect` default 1.25 (rounder disc), migrated once.
### Added
- Pods excluded; candidate delay and fall filter; dead enemies clear in ~0.3 s; still-hide; size classes.

## [1.3.1]
### Fixed
- Disc was tall and skinny: textures now sized in screen px (`tex_size_px`), `radar_aspect`.
### Added
- Slider labels as word textures, values in a rect pixel font.

## [1.3.0]
### Changed
- Three rear bars replaced by a 360° north-up radar (texture disc with rect fallback), `dot_size`, `tools/build.py`.

## [1.2.1]
### Removed
- Keyboard slider bindings (`[ ]`, `; '`, `+ -`); sliders are mouse only.

## [1.2.0]
### Added
- `sensitivity` and `repeat_rate` sliders.

## [1.1.0]
### Fixed
- Flicker: persistent tracking table, per-frame threat, rise/hold/fade smoothing, rear zone from 90°.

## [1.0.1]
### Changed
- Calibration toggle on F7 (`toggle_key`); area clamped to the drawable gui.

## [1.0.0]
### Added
- Interactive mouse/arrow-key calibration of the placement area.

## [0.9.0]
- Single measured screen transform at 3840x1080 (`sx_scale=1.2`, `sy_scale=0.9333`, `gy_top=1080`).

## [0.8.0]
- View transform with corner marks.

## [0.7.0]
- Calibration grid and resolution logging.

## [0.6.0]
- One `box()` draw helper, heartbeat and probe squares.

## [0.5.0]
- Bigger bars on the test box's layer, `bar_debug`.

## [0.4.0]
- Rect-only test, safe world-teardown handling.

## [0.3.0]
- Treasure Radar-style screen GUI, `units_by_resource` re-queried each 0.25 s.

## [0.2.0]
- Enemies found by walking `World.units`; discovery mode; ini and logs in the Logs folder.

## [0.1.0]
- First Rear Heat HUD: three rear threat bars (left-rear, rear, right-rear).
