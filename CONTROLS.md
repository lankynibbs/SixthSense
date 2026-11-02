# Sixth Sense: controls (v1.5.4)

> On-request document: written when asked, not updated every commit. It describes v1.5.4
> (`src/sixth_sense.lua`); regenerated for the v1.5.4 controller option. For an overview see [README.md](README.md), per-version notes [docs/history/version-notes.md](docs/history/version-notes.md), and [CHANGELOG.md](CHANGELOG.md).

Sixth Sense is a 360° enemy radar that turns with your view (up is where you look). Red
squares are enemies, red diamonds are enemy structures (turrets), the white square in the middle is you.

## Install
1. Get **Bingus Shared Loader v20** (it supports the build HellForge runs; HellForge does not ship it).
2. Build or take `SixthSense.zip` (`python3 tools/build.py` in this repo).
3. HellForge launcher > **Mods** > **Add mods...**, pick both zips, switch both on (new mods start off; they show with
   a **LUA** tag), launch the game from HellForge. Updating: add the new `SixthSense.zip`; the GUID is the same, so
   it replaces the old one.

## Control scheme: keyboard / mouse or controller
`control=keyboard_mouse` (default) or `control=controller` in the ini, or the **Controls** buttons
(**KB + Mouse** / **Controller**) at the bottom of the Settings tab.
- **Keyboard / mouse**: F7 and the mouse, as below. The controller is not read at all.
- **Controller**: a connected game pad drives the page (see [Controller](#controller)); F7, the arrow keys and the
  mouse do nothing on the page. If no pad is connected, F7 and the mouse still work, so you can always switch back.

## The F7 page (setup, keyboard / mouse)
- **F7** opens and closes the setup page (mouse cursor shown, the camera holds still while it is open). Opening and
  closing both save. It always opens on the Display tab. The key is `toggle_key=f7` in the ini.
- Everything on the page is done with the **mouse**. There are no `[ ]` or F8 bindings (HellForge itself uses F8).
- The page has three buttons at the top of its panel: **Display**, **Settings**, **Reset**. The panel places itself
  where the radar is not, and moves out of the way when you drop the radar.

### Display tab: place the radar
- **Move**: drag the **grab handle** (the 4-way arrow on the radar's top edge).
- **Resize**: drag any of the four **corner handles**; the radar grows or shrinks about its centre. The **mouse wheel**
  over the radar resizes it too.
- (The arrow keys also nudge the radar 2 px, 20 px with Shift, on this tab only.)
- A line above the buttons shows the current resolution and **SAVED LAYOUT** (green) or **NO SAVED LAYOUT** (amber).

### Settings tab: sliders and buttons
Drag a slider's knob or click/drag along its track. The yellow tick marks the default.

| Slider | Range | What it does |
|---|---|---|
| **Size** (cyan) | 0.08 - 1.00, default 0.35 | radar diameter as a share of the drawable height (same as resizing on Display) |
| **Sensitivity** (orange) | 0.25x - 3.00x, default 1.00x | radar range = 40 m x sensitivity (10 - 120 m) |
| **Repeat rate** (magenta) | 0.25x - 3.00x, default 1.00x | how fast dots update: re-scan every 0.5 s / rate; a lost enemy is held 1 s / rate and fades over 1.5 s / rate |
| **Dot size** (red) | S / M / L (3 snaps), default M | enemy dot size x0.75 / x1 / x1.35 |
| **Radar color** (white) | 5 snaps, default green | green, white, yellow, red, light blue; the swatch right of the track shows it |

- **Radar color** tints only the radar display: the disc, its rings and cross hairs. **Enemy dots and structure
  diamonds stay red** in every colour.
- **Controls: KB + Mouse / Controller** (the bottom row): the control scheme, see above.
- **Visibility: Shown / Hidden** (two buttons under the sliders). Hidden takes the radar off screen during play; the
  F7 page still shows it so you can set it up.

### Reset
- **Reset button**: click once to arm it (lit for 3 s), click again within 3 s to confirm.
  - On **Display**: the radar goes back to the centre of the drawable area at the default size, and the saved layout
    for **this resolution only** is cleared.
  - On **Settings**: Size, Sensitivity, Repeat rate, Dot size, Radar color (green) and Visibility (Shown) go back to
    their defaults (the control scheme is kept).
- **Hold F7 for 3 s** (keyboard / mouse; controller: hold View / touchpad 5 s) (panic reset, works even with the page closed): resets this resolution's radar layout and the
  panel position and opens the page on Display.

## Controller
Pads are found as Chef Shared Loader does on this game: the first active Pad1..Pad8, its buttons by the names the pad
reports (Xbox and PlayStation names both). The log says `controller: Pad1 (<name>)` when one is found.

| Action | Button |
|---|---|
| Open / close the page | hold **View / Back** (Xbox) or **touchpad** (PlayStation) **2 s** |
| Panic reset (like F7 held 3 s) | keep holding View / touchpad to **5 s**: layout reset, page open on Display |
| Close the page (saved) | **B / Circle** |
| Display / Settings tab | **LB / RB** (L1 / R1), either one flips the tab |
| Reset (arm, then confirm within 3 s) | **X / Square**, twice |
| Display: move the radar | **D-pad** (hold repeats; faster after 1 s) |
| Display: bigger / smaller | **Y / Triangle** / **A / Cross** (hold repeats) |
| Settings: pick a row | **D-pad up / down** (Size, Sensitivity, Repeat rate, Dot size, Radar color, Visibility, Controls); the row is framed yellow |
| Settings: change it | **D-pad left / right** (Visibility: left Shown, right Hidden; Controls: left KB + Mouse, right Controller) |

- The game still sees every button (a Lua mod cannot take input from it). Set the radar up **on the ship**: in a
  mission View / touchpad also opens the map and the D-pad / face buttons do their game actions. Nothing is read
  from the pad except that hold while the page is closed.
- No `[ ]` or F8 bindings in either scheme (F8 is HellForge's editor).
- Confirmed working in game (v1.5.4).

## Per-resolution layouts and the drawable area
- The radar's place and size are saved **per window resolution** (`radar_layouts=WxH:cx,cy,d;...`). Switching back to
  a resolution restores its layout; one never set up starts centred at the default size.
- **Viewport**: at some settings (Render Scale below native, or Resolution below the window) the game only draws mod
  graphics in part of the window, anchored top-left. Sixth Sense reads `render_resolution` from the game's
  `user_settings.config` (`%APPDATA%\Arrowhead\Helldivers2`, then `%LOCALAPPDATA%\Arrowhead\Helldivers2`, then
  `<HellForge>\userdata\profiles\*\user_settings.config`, preferring the profile whose screen size matches the
  window) and keeps the radar inside that area. The file used and the area are logged as `viewport:` lines.

## Files on HellForge (ix)
- Folder: `D:\HellForge\userdata\environment\Local\CowboyBingus\Helldivers2\Logs\`
  - `sixth_sense.ini`: settings, written by the F7 page (commented). Keys set from the page include `radar_layouts`,
    `sensitivity`, `repeat_rate`, `dot_size`, `radar_color`, `control`, `visibility`, `panel_fx` / `panel_fy`, `calibrate`.
    Editing by hand: close the game first.
  - `sixth_sense.log`: what the mod did (load, `viewport:`, `settings changed`, resets, radar draw style).
