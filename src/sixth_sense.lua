-- HD2-Addon: mods/darryl/sixth_sense
-- Sixth Sense v1.5.6 (formerly Rear Heat HUD) for Bingus Shared Loader (HellForge, game build 25480438, LuaJIT).
-- Three bars at the bottom (left-rear, rear, right-rear) glow clear -> yellow -> red with the threat behind you.
-- v0.2: enemies are found by walking World.units and reading each unit's resource id (no World.units_by_resource),
-- a discovery mode logs every unit kind near you, and an optional "candidate enemy" heuristic works without a list.
-- Read-only: it changes nothing in the game.

local MOD, VERSION = "sixth_sense", "1.5.6"
local RUNTIME_HEX = "46cab355bd8d4d37"   -- runtime-built units: asking their position/rotation/meshes/box ends the game

-- ---------------------------------------------------------------- engine access (every call pcall'd)
local function ns(name)
  local t = rawget(_G, name)
  if type(t) ~= "table" then local sr = rawget(_G, "stingray"); t = type(sr) == "table" and rawget(sr, name) or nil end
  return type(t) == "table" and t or nil
end
local FN = {}
local function fn(nsname, f)
  local key = nsname .. "." .. f
  local v = FN[key]
  if v ~= nil then return v or nil end
  local t = ns(nsname); v = t and rawget(t, f)
  if type(v) ~= "function" and t then local ok, w = pcall(function() return t[f] end); if ok then v = w end end
  FN[key] = type(v) == "function" and v or false
  return FN[key] or nil
end
local function call(nsname, f, ...)
  local g = fn(nsname, f); if not g then return nil end
  local ok, a, b, c, d = pcall(g, ...)
  if ok then return a, b, c, d end
  return nil
end
-- Constructors (Vector3, Vector2, Color) from the stingray table first, as Treasure Radar's loader takes them
-- (v0.1/v0.2 took the global first; a global that is a plain table could not be called, so nothing was drawn).
local CTOR = {}
local function ctor_fn(name)
  local g = CTOR[name]
  if g ~= nil then return g or nil end
  local sr = rawget(_G, "stingray")
  local cands = { type(sr) == "table" and sr[name] or nil, rawget(_G, name) }
  g = false
  for i = 1, 2 do
    local c = cands[i]
    if type(c) == "function" then g = c break end
    if type(c) == "table" or type(c) == "userdata" then
      local mt = getmetatable(c)
      if type(mt) == "table" and mt.__call then g = c break end
    end
  end
  CTOR[name] = g
  return g or nil
end
local CTOR_ERR = {}
local function ctor(name, ...)
  local g = ctor_fn(name)
  if not g then CTOR_ERR[name] = "no callable " .. name; return nil end
  local ok, v = pcall(g, ...)
  if ok then return v end
  CTOR_ERR[name] = tostring(v)
  return nil
end

-- ---------------------------------------------------------------- paths and log
-- HellForge redirects LOCALAPPDATA/APPDATA into <HellForge>\userdata\environment\...; everything goes next to the log,
-- in the folder Bingus Shared Loader already made (LOCALAPPDATA\CowboyBingus\Helldivers2\Logs).
local LOCAL = os.getenv("LOCALAPPDATA") or "."
local DIR = LOCAL .. "\\CowboyBingus\\Helldivers2\\Logs\\"
local LOG_PATH = DIR .. MOD .. ".log"
local CFG_PATH = DIR .. MOD .. ".ini"
local SUMMARY_PATH = DIR .. MOD .. "_discovery.txt"
local OLD_CFG_PATH = DIR .. "rear_heat_hud.ini"      -- v1.4.0: the mod was Rear Heat HUD; its settings carry over once
local logf
do
  local L = rawget(_G, "CowboyBingusModLoader")
  if type(L) == "table" and type(L.open_log) == "function" then local ok, f = pcall(L.open_log, MOD .. ".log"); if ok and f then logf = f end end
  if not logf then logf = io.open(LOG_PATH, "w") end
end
local log_lines = 0
local function say(s)
  if not logf or log_lines > 20000 then return end
  log_lines = log_lines + 1
  pcall(function() logf:write(os.date("%H:%M:%S "), s, "\n"); logf:flush() end)
end

-- ---------------------------------------------------------------- config
local CFG = { range = 40, opacity = 0.85, position = "bottom", sx_scale = 1.2, sy_scale = 0.9333, gy_top = 1080, calibrate = true, toggle_key = "f7", cursor_flip_y = false, area_x0 = 0, area_y0 = 0, area_x1 = 0, area_y1 = 0, area_scale = 1, bars_fx = 0.5, bars_fy = 0.85, bar_debug = false, v110_migrated = false, sensitivity = 1.0, repeat_rate = 1.0, radar_size = 0.35, radar_fx = 0.5, radar_fy = 0.78, radar_style = "auto", dot_size = "medium", radar_color = "green", control = "keyboard_mouse", radar_aspect = 1.25, v132_migrated = false, ignore_ids = "", still_hide = 1.0, static_ids = "", static_log = true, panel_fx = 0.03, panel_fy = 0.08, radar_cx = -1, radar_cy = -1, radar_d = -1, v142_migrated = false, v144_migrated = false, v145_migrated = false, v146_migrated = false, radar_layouts = "", visibility = "shown", transform_scale = "height", transform_ref_h = 1080, tex_size_px = true, label_style = "auto", layer = 950,  size = 1.0, swap_sides = false,
              detect = "both", discovery = true, discovery_static = false, discovery_range = 80, candidate_weight = 1.5,
              debug = false }
local CFG_TEXT = [[
; Sixth Sense (formerly Rear Heat HUD) settings. Edit, save, restart the game.
; range: metres (10-100). opacity: 0.1-1. position: bottom or top.
; size: 0.5-2. swap_sides: true if left/right look mirrored.
; detect: list (known enemy ids only), candidates (moving animated units that are not you), or both.
; discovery: true logs every unit kind near you every 5 s and writes sixth_sense_discovery.txt.
; discovery_static: true also measures units without animation (structures; slower). discovery_range: metres.
; candidate_weight: threat of one candidate enemy (a light enemy is 1).
; Note v0.2 ini files are kept as they are; delete sixth_sense.ini to get the new keys written.
range=40
opacity=0.85
position=bottom
; Screen transform (v0.9, measured in game at 3840x1080). The drawing space ("gui") has y running from the
; bottom up. A point at fraction (fx, fy) of the visible screen, fy from the top, is drawn at
;   gx = fx * screen_w / sx_scale      gy = gy_top - fy * screen_h / sy_scale - (rect height in gui units)
; Measured: screen_x = 1.2 * gx and screen_y = (1080 - gy) * 0.9333 (from the top), so the visible gui runs
; gx 0..3200 and gy 1080 (top) down to about -77 (bottom). Sizes are in screen px (gui w = w/sx_scale, h = h/sy_scale).
sx_scale=1.2
sy_scale=0.9333
gy_top=1080
; calibrate: true shows the placement area (drag it, scale it with the cyan slider or the mouse wheel; the orange and magenta
; sliders under it set sensitivity and repeat_rate; the toggle key saves and hides it).
; toggle_key (default f7; HellForge uses F8) saves and hides it, and turns it back on in game.
; cursor_flip_y: true if the drawn cursor moves opposite to the mouse vertically.
calibrate=true
toggle_key=f7
cursor_flip_y=false
; The placement area in gui units (x0 left, x1 right, y0 bottom, y1 top; gui y runs up), written by calibration.
; All 0 = not calibrated yet (starts as the full screen from the transform). area_scale is derived (width / screen width).
area_x0=0
area_y0=0
area_x1=0
area_y1=0
area_scale=1
; bars_fx, bars_fy: unused since v1.3 (the radar replaced the bars; see radar_fx, radar_fy).
bars_fx=0.5
bars_fy=0.85
; bar_debug: true draws every bar at least half full so you can see where they are. Off by default: idle bars are faint outlines.
bar_debug=false
v110_migrated=true
; sensitivity (0.25-3, default 1): detection range = range x sensitivity (10-120 m), and the threat-to-heat gain is
; multiplied by it. Higher = farther and hotter. Orange slider in calibration (mouse only).
sensitivity=1.0
; repeat_rate (0.25-3, default 1): faster response. Known enemies are looked up every 0.5 s / rate, and the bars hold
; 1 s / rate and fade over 1.5 s / rate. Magenta slider in calibration (mouse only).
repeat_rate=1.0
; The radar (v1.3). radar_fx, radar_fy: its centre in the area, as fractions (fy from the area's top).
; radar_size: its diameter as a share of the area's height (0.1-1). It scales with the area.
radar_fx=0.5
radar_fy=0.78
radar_size=0.35
; radar_style: auto (the texture if the game draws it, else rect dots), texture, or dots.
radar_style=auto
; dot_size: small (x0.75), medium (x1) or large (x1.35). Base sizes at 1080 tall (v1.4.4): tiny 12, medium 24,
; large 44, extra large 58 px, scaled with the radar. Red slider in calibration. (v144_migrated: a saved small was
; reset to medium once, so everyone sees the bigger v1.4.4 dots.)
dot_size=medium
v144_migrated=true
; radar_color (v1.5.1): the radar display's colour (disc, rings, cross hairs; v1.5.2: not the enemy markers): green (default), white, yellow,
; red or light_blue. "Radar color" snap slider on the F7 page's Settings tab (mouse only); Reset puts it back to green.
; Enemy dots and enemy structures (diamonds) stay red in every colour.
radar_color=green
; control (v1.5.4): keyboard_mouse (default: F7 and the mouse) or controller (a game pad: hold View / Back /
; touchpad 2 s to open or close the F7 page; D-pad, face buttons and bumpers on it; see CONTROLS.md). In controller
; mode the F7 key and the mouse do nothing while a pad is connected (with no pad found they still work, so you are
; never locked out). "Controls" buttons on the F7 page's Settings tab.
control=keyboard_mouse
; visibility (v1.4.5): shown (the radar is on screen) or hidden (it is not; the F7 calibration page still shows it so
; you can set it up). Shown / Hidden buttons on the F7 page's Settings tab (mouse only). (v145_migrated: v1.4.4's
; hud and always became shown once.)
visibility=shown
v145_migrated=true
; radar_aspect (0.5-2, default 1.25 since v1.3.2: v1.3.1 measured about 25% too narrow): the radar's width trim,
; disc and dots together.
radar_aspect=1.25
v132_migrated=true
; ignore_ids: extra resource ids (16 hex, comma separated) never shown, on top of the built-in pod list.
ignore_ids=
; still_hide: seconds an enemy may stand fully still (same spot, same animation state) before its dot is hidden
; (bodies; it shows again when it moves). 0 = off.
still_hide=1.0
; static_ids: extra enemy structure ids (16 hex, comma separated) shown as red diamonds, on top of the built-in
; list (bot cannon, AA and mortar turrets, the bunker turret). static_log: true logs unknown non-animated kinds near you
; once each, with their distance ("static?: ..."), so turrets can be mapped.
static_ids=
static_log=true
; panel_fx, panel_fy: where the calibration slider panel sits (top-left corner, fractions of the visible screen, fy from
; the top). It stays there: dragging moves only the radar.
panel_fx=0.03
panel_fy=0.08
; radar_layouts (v1.4.6): the radar's place saved per window resolution, WxH:cx,cy,d entries separated by ";", e.g.
;   radar_layouts=3840x1080:0.5000,0.7500,0.3500;2560x1440:0.3000,0.6000,0.3000
; cx, cy = the radar's centre as fractions of the DRAWABLE area (cy from its top), d = its diameter as a fraction of
; the drawable height. The drawable area is the part of the window the mod can draw on: the render size from the game's
; user_settings.config (APPDATA, LOCALAPPDATA, then HellForge's userdata\profiles\*; render_resolution) anchored
; top-left, cut at the bottom where the game clips the gui (see the "viewport:" lines in sixth_sense.log). Going back
; to a resolution restores its layout; one with none saved starts centred in the drawable area at the default size. Reset (two clicks, or F7 held 3 s) clears only the current resolution's entry. Written by calibration.
radar_layouts=
v146_migrated=true
; (until v1.4.5) radar placement: radar_cx, radar_cy = the radar's centre as fractions of the visible
; screen (cy from the top), radar_d = its diameter as a fraction of the screen height. Written by calibration; the
; area_* / radar_fx / radar_fy / radar_size keys were converted into these once (v142_migrated) and are no longer used.
; transform_scale: height (sx_scale/sy_scale were measured at transform_ref_h tall and scale with the screen height,
; i.e. a 1080-tall-normalised gui) or fixed (the old way: the same numbers at every resolution).
transform_scale=height
transform_ref_h=1080
; tex_size_px: true (v1.3.1) sizes textures in screen px, which fixes v1.3's tall, skinny disc. false = v1.3's way.
tex_size_px=true
; label_style: slider labels in calibration. auto (word textures, then a rect pixel font), texture, pixel, or off.
label_style=auto
; layer: draw order (950).
layer=950
size=1.0
swap_sides=false
detect=both
discovery=true
discovery_static=false
discovery_range=80
candidate_weight=1.5
debug=false
]]
local LAYOUTS_COMMENT = [[; radar_layouts (v1.4.6): the radar's place saved per window resolution, WxH:cx,cy,d entries separated by ";", e.g.
;   radar_layouts=3840x1080:0.5000,0.7500,0.3500;2560x1440:0.3000,0.6000,0.3000
; cx, cy = the radar's centre as fractions of the DRAWABLE area (cy from its top), d = its diameter as a fraction of
; the drawable height. The drawable area is the part of the window the mod can draw on: the render size from the game's
; user_settings.config (APPDATA, LOCALAPPDATA, then HellForge's userdata\profiles\*; render_resolution) anchored
; top-left, cut at the bottom where the game clips the gui (see the "viewport:" lines in sixth_sense.log). Going back
; to a resolution restores its layout; one with none saved starts centred in the drawable area at the default size. Reset (two clicks, or F7 held 3 s) clears only the current resolution's entry. Written by calibration.]]
local CONTROL_COMMENT = [[; control (v1.5.4): keyboard_mouse (default: F7 and the mouse) or controller (a game pad: hold View / Back /
; touchpad 2 s to open or close the F7 page; D-pad, face buttons and bumpers on it; see CONTROLS.md). In controller
; mode the F7 key and the mouse do nothing while a pad is connected (with no pad found they still work, so you are
; never locked out). "Controls" buttons on the F7 page's Settings tab.]]
local COLOR_COMMENT = [[; radar_color (v1.5.1): the radar display's colour (disc, rings, cross hairs; v1.5.2: not the enemy markers): green (default), white, yellow,
; red or light_blue. "Radar color" snap slider on the F7 page's Settings tab (mouse only); Reset puts it back to green.
; Enemy dots and enemy structures (diamonds) stay red in every colour.]]
-- v1.5.1 radar colours: ring = disc tint, rings and cross hairs. v1.5.2: the radar display only; enemy dots stay red
-- and enemy structures (diamonds) red too (v1.5.3: no orange) in every colour
local COLOR_NAMES = { "green", "white", "yellow", "red", "light_blue" }
local COLOR_IDX = { green = 1, white = 2, yellow = 3, red = 4, light_blue = 5 }
local PALETTE = {
  green = { ring = { 90, 255, 140 } },
  white = { ring = { 235, 235, 235 } },
  yellow = { ring = { 255, 225, 60 } },
  red = { ring = { 255, 70, 60 } },
  light_blue = { ring = { 110, 200, 255 } },
}
_G.SIXTH_SENSE_PALETTE = PALETTE
-- pretty-ui: the F7 menu's named colours, { a, r, g, b }
local UI = {
  bg       = { 215, 12, 14, 18 },     -- panel backing, near-black blue-grey
  panel    = { 235, 18, 22, 28 },     -- help frame, a step lighter
  btn      = { 200, 28, 34, 44 },     -- button, off
  hover    = { 220, 40, 50, 64 },     -- button under the cursor
  selected = { 240, 0, 120, 215 },    -- button, on
  accent   = { 255, 0, 150, 255 },    -- electric blue: stripes, slider fill
  border   = { 200, 50, 60, 75 },     -- 1 px outlines
  track    = { 200, 35, 42, 52 },     -- slider track
  tick     = { 200, 120, 130, 145 },  -- slider 1.0 tick
  knob     = { 255, 220, 230, 240 },  -- slider knob
  knob_drag = { 255, 255, 255, 255 }, -- slider knob while dragged: pure white
  text     = { 255, 230, 235, 240 },  -- cool white
  muted    = { 255, 140, 150, 165 },
  focus    = { 255, 0, 180, 255 },   -- controller focus frame
}
local VIS_COMMENT = [[; visibility (v1.4.5): shown (the radar is on screen) or hidden (it is not; the F7 calibration page still shows it so
; you can set it up). Shown / Hidden buttons on the F7 page's Settings tab (mouse only). (v145_migrated: v1.4.4's
; hud and always became shown once.)]]
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
local cfg_state
local cfg_copied = nil
do
  -- v1.4.0 rename: first load with no sixth_sense.ini but a rear_heat_hud.ini: copy it as it is (area, sliders, radar
  -- keys, migration flags), so nothing is lost. The old file is left in place.
  local f = io.open(CFG_PATH, "r")
  if f then f:close() else
    local o = io.open(OLD_CFG_PATH, "r")
    if o then
      local txt = o:read("*a"); o:close()
      local w = io.open(CFG_PATH, "w")
      if w and txt then w:write(txt); w:close(); cfg_copied = #txt end
    end
  end
  f = io.open(CFG_PATH, "r")
  if not f then
    local w = io.open(CFG_PATH, "w")
    if w then w:write(CFG_TEXT); w:close(); cfg_state = "written with defaults" else cfg_state = "could not be written" end
  else
    for line in f:lines() do
      local k, v = line:match("^%s*([%w_]+)%s*=%s*([^;%s]+)")
      local lk, lv = line:match("^%s*(radar_layouts)%s*=%s*(.-)%s*$")   -- (v1.4.6: its entries are separated by ";")
      if lk then k, v = lk, lv end
      if k and CFG[k] ~= nil then
        if type(CFG[k]) == "number" then CFG[k] = tonumber(v) or CFG[k]
        elseif type(CFG[k]) == "boolean" then CFG[k] = (v == "true" or v == "1")
        else CFG[k] = v end
      end
    end
    f:close(); cfg_state = "read"
  end
  CFG.range = clamp(CFG.range, 10, 100); CFG.opacity = clamp(CFG.opacity, 0.1, 1)
  CFG.sensitivity = clamp(CFG.sensitivity, 0.25, 3); CFG.repeat_rate = clamp(CFG.repeat_rate, 0.25, 3); CFG.bars_fx = clamp(CFG.bars_fx, 0, 1); CFG.bars_fy = clamp(CFG.bars_fy, 0, 1); CFG.size = clamp(CFG.size, 0.5, 2)
  CFG.radar_size = clamp(CFG.radar_size, 0.1, 1); CFG.radar_aspect = clamp(CFG.radar_aspect, 0.5, 2); CFG.still_hide = clamp(CFG.still_hide, 0, 30);
  CFG.label_style = tostring(CFG.label_style):lower(); if CFG.label_style ~= "texture" and CFG.label_style ~= "pixel" and CFG.label_style ~= "off" then CFG.label_style = "auto" end
  CFG.radar_fx = clamp(CFG.radar_fx, 0, 1); CFG.radar_fy = clamp(CFG.radar_fy, 0, 1)
  CFG.radar_style = tostring(CFG.radar_style):lower(); if CFG.radar_style ~= "texture" and CFG.radar_style ~= "dots" then CFG.radar_style = "auto" end
  CFG.visibility = tostring(CFG.visibility):lower(); if CFG.visibility ~= "hidden" and CFG.visibility ~= "hud" then CFG.visibility = "shown" end   -- (hud: migrated below)
  CFG.control = tostring(CFG.control):lower(); if CFG.control ~= "controller" then CFG.control = "keyboard_mouse" end
  CFG.radar_color = tostring(CFG.radar_color):lower():gsub("[%s-]+", "_"); if not COLOR_IDX[CFG.radar_color] then CFG.radar_color = "green" end
  CFG.dot_size = tostring(CFG.dot_size):lower(); if CFG.dot_size ~= "small" and CFG.dot_size ~= "large" then CFG.dot_size = "medium" end
  if CFG.sx_scale <= 0 then CFG.sx_scale = 1.2 end; if CFG.sy_scale <= 0 then CFG.sy_scale = 0.9333 end
  CFG.discovery_range = clamp(CFG.discovery_range, 10, 300); CFG.candidate_weight = clamp(CFG.candidate_weight, 0, 10)
  if CFG.detect ~= "list" and CFG.detect ~= "candidates" then CFG.detect = "both" end
  CFG.panel_fx = clamp(CFG.panel_fx, 0, 0.9); CFG.panel_fy = clamp(CFG.panel_fy, 0, 0.9)
  if CFG.transform_ref_h <= 0 then CFG.transform_ref_h = 1080 end
  CFG.transform_scale = tostring(CFG.transform_scale):lower() == "fixed" and "fixed" or "height"
end
local XF_REF = { sx = CFG.sx_scale, sy = CFG.sy_scale }   -- (as measured, at transform_ref_h tall)

-- ---------------------------------------------------------------- known enemies: resource id -> tier (1 light, 2 medium, 3 heavy)
-- From Treasure Radar 0.7.x (2026 build). Resource ids are hashes of the unit's file path, so a unit whose path did not
-- change keeps its id across builds (checked: 64090088502435dd = content/fac_bugs/cha_shrieker/cha_shrieker).
-- Overseer da40bb347c7447f2 and Elevated Overseer 604a794ec45bb820 are in it; no Illuminate emplacement is.
local TIER = {
  ['1a7fcdff98c664b0']=3, ['3aff5fd7d5450b99']=3, ['6b202392f4ab605e']=3, ['0ab7b92b131c228c']=3,
  ['dcf8e74212fbee3b']=3, ['9e2e17f2ccccafdd']=3, ['ef04cb84d097a497']=3, ['960b48a421a3faaa']=3,
  ['d465d9c7f77a07cb']=3, ['36aa99cce5e60146']=2, ['ccae5264acd591b7']=2, ['cc7022fdd172089b']=2,
  ['a381a11c07d3eb94']=2, ['d522fd4748d443a5']=2, ['f79cd8bb654397df']=2, ['a1f37bf2a40fbde4']=2,
  ['f540ca9d9d4a422e']=2, ['a35207c6f2150806']=2, ['09872e66d1276e1f']=1, ['be39e313a1e46bb9']=1,
  ['10081acef6163ef6']=1, ['1baeef36a88ae579']=1, ['a478d36a62a861f4']=1, ['d7e2c78b1ef4a8e1']=1,
  ['c28b3482e73d1ea9']=1, ['aab438596f5e8fd9']=1, ['c14e0e887e7d2106']=1, ['5b968cd78f8bc7a0']=1,
  ['db964631be1cf501']=1, ['72a83e49ced6db3d']=1, ['64090088502435dd']=1, ['846bc06c6b213a06']=3,
  ['b16493b009eec762']=3, ['00bcf8247a544cdc']=3, ['d37e8d120d2836e3']=3, ['ef570293245a17c2']=3,
  ['bc242702fb46b7e7']=3, ['ae63e525853d7044']=2, ['c626d2bb495a202d']=2, ['db7139323c40ae6f']=2,
  ['3d9c95bd03c0c7cf']=2, ['a6a68d8af177f3a1']=2, ['54e107dacf6929cb']=2, ['f8131632aa867107']=2,
  ['282eb766c1ffa6a1']=2, ['db90077e76faa025']=2, ['b2b3056bdf28e57b']=1, ['64ba5f030b114ec1']=1,
  ['9821303bd499cd62']=1, ['9f57782f00e6ed20']=1, ['a71aafd82c6ebc92']=1, ['746a7f3beda32699']=1,
  ['1338b552afe68f0a']=1, ['9f44121c554dae89']=1, ['67381f685e9b69a8']=1, ['965eae5a51acdd4a']=3,
  ['453fe22c634eb30f']=3, ['f22d027b37bef107']=3, ['da40bb347c7447f2']=2, ['604a794ec45bb820']=2,
  ['e8f19a0aa958e46d']=2, ['905809a4c28d8a45']=2, ['cc188f0c80505c6c']=2, ['20b9c7734daead65']=2,
  ['ac60e78435098c9d']=2, ['67dc32dca4f02d33']=3, ['19e18b46ec55d94a']=2, ['74e2285c01da4f71']=2,
  ['78e1497571012c47']=1, ['0adc9f9173ad8e1d']=1, ['44458a2c52b002fb']=1, ['34dfd23365472e9e']=1,
  ['f735a51a991e4bda']=2, ['9926876b2375a1bb']=2,
}

local NAME = { ['da40bb347c7447f2'] = 'Overseer', ['604a794ec45bb820'] = 'Elevated Overseer', ['e8f19a0aa958e46d'] = 'Crescent Overseer',
  ['1a7fcdff98c664b0'] = 'Charger', ['846bc06c6b213a06'] = 'Hulk', ['ae63e525853d7044'] = 'Devastator', ['09872e66d1276e1f'] = 'Warrior',
  ['78e1497571012c47'] = 'Voteless', ['74e2285c01da4f71'] = 'Warp Ship', ['f735a51a991e4bda'] = 'Warp Ship', ['9926876b2375a1bb'] = 'Bunker Turret',
  ['64090088502435dd'] = 'Shrieker', ['4d1c334d294dfa97'] = 'Helldiver (2026 id)', [RUNTIME_HEX] = 'runtime-built (skipped)' }
-- Seen in the v0.2 run on build 25480438 (Illuminate mission). Helldiver 4d1c334d294dfa97 matches this build too.
NAME['0adc9f9173ad8e1d'] = 'Voteless (confirmed in run2: x7, animated, 19-30 m)'
NAME['ac60e78435098c9d'] = 'Watcher (in list; seen in run2)'
NAME['9c7ef47a463d5327'] = 'GUESS: part of the Overseer (always with it, count 2)'
NAME['c6a5bb8b319217ac'] = 'GUESS: part of the Watcher (always with it)'
-- Never candidates: the local Helldiver, and kinds that in run2 behaved like ambient or attached-to-you units.
local FRIENDLY = { ['4d1c334d294dfa97'] = true,
  ['0c6567f9e37920e1'] = true,   -- GUESS ambient/foliage: up to 154 animated, everywhere, never close
  ['05e4e5c2db6e44a2'] = true, ['968211c0033dce64'] = true, ['a9936cbe561e8180'] = true }  -- GUESS: on your Helldiver (always 0 m)
for h in pairs(FRIENDLY) do if not NAME[h] then NAME[h] = 'ignored (ambient or on you, guess)' end end
local TIER_WEIGHT = { 1.0, 2.5, 5.0 }
local KNOWN_HEX, KNOWN_TIER = {}, {}
for hex, t in pairs(TIER) do KNOWN_HEX[#KNOWN_HEX + 1] = hex; KNOWN_TIER[#KNOWN_TIER + 1] = t end

-- ---------------------------------------------------------------- safe resource id of a unit
local function hex_of(u)
  local id = call("Unit", "resource_name", u)
  if id == nil then return nil end
  if type(id) == "string" then
    local h = id:match("%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x"); return h and h:lower() or nil
  end
  local h = call("IdString64", "to_hex", id)
  if type(h) == "string" then h = h:match("%x+"); if h and #h <= 16 then return (string.rep("0", 16 - #h) .. h):lower() end end
  local s = tostring(id); h = s and s:match("%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x")
  return h and h:lower() or nil
end

-- ---------------------------------------------------------------- state
local S = { world = nil, cam_unit = nil, gui = nil, cam_retry = 0, t = 0,
            target = { 0, 0, 0 }, heat = { 0, 0, 0 }, hold = { 0, 0, 0 }, peak = { 0, 0, 0 }, T = {}, nT = 0, nearest = nil, ghost = {}, fails = 0,
            px = nil, py = nil, pz = nil, fx = 0, fy = 1,
            list = nil, li = 0, pass_started = 0,           -- the World.units walk, spread over frames
            info = {},                                      -- unit -> { hex, asm, x, y, t } (this world only)
            tracked = {}, ntracked = 0,                     -- array of { u, w (weight) } from the last full pass
            build = {}, nbuild = 0, pass = {},              -- the pass being built; per-hex stats of this pass
            totals = {}, combat_scans = 0, known = {}, nknown = 0, next_known = 0, body = nil,
            draw_ok = 0, draw_fail = 0, rect_logs = 0, draw_err = nil, gui_how = nil, gui_tries = 0, text_ok = 0, text_err = nil, next_summary = 0, next_disc = 0, passes = 0, ubr_tested = false }
local RAD_RESET = function() end
local function reset(w)
  -- The old GUI is dropped without being touched: a GUI used (or destroyed) after its world went away crashes the
  -- game (Treasure Radar's loader drops it the same way). The world's units are forgotten too.
  S.world, S.cam_unit, S.gui, S.cam_retry = w, nil, nil, 0
  S.list, S.li, S.info, S.tracked, S.ntracked, S.build, S.nbuild, S.pass = nil, 0, {}, {}, 0, {}, 0, {}
  S.known, S.nknown, S.body, S.gui_tries = {}, 0, nil, 0
  S.T, S.nT, S.nearest, S.ghost = {}, 0, nil, {}
  RAD_RESET()
  S.rect_logs = 0
  S.settle_until = S.t + 2      -- nothing is asked of a new world for 2 s
  S.target[1], S.target[2], S.target[3] = 0, 0, 0
end

local last_nworlds = -1
local function pick_world()
  local ws = call("Application", "worlds")
  if type(ws) ~= "table" then return nil end
  -- a change in the number of worlds = a transition: settle before touching anything
  if #ws ~= last_nworlds then
    if last_nworlds >= 0 then S.settle_until = S.t + 2; say("worlds count " .. last_nworlds .. " -> " .. #ws .. ": settling") end
    last_nworlds = #ws
  end
  local m = call("Application", "main_world")       -- as Treasure Radar's loader picks it
  if m ~= nil then
    for i = 1, #ws do if ws[i] == m then return m end end
    return nil                                       -- main world not (or no longer) among the live worlds
  end
  if type(ws) ~= "table" then return nil end
  local best, most = nil, -1
  for i = 1, #ws do
    local n = call("World", "num_units", ws[i]) or 0
    if n > most then best, most = ws[i], n end
  end
  return best
end

local function find_camera(w)
  if S.cam_unit and call("Unit", "alive", S.cam_unit) == true then return S.cam_unit end
  S.cam_unit = nil
  if S.t < S.cam_retry then return nil end
  local units = call("World", "units", w)
  if type(units) == "table" then
    for i = 1, #units do
      local u = units[i]
      if call("Unit", "alive", u) == true then
        local nc = call("Unit", "num_cameras", u)
        if type(nc) == "number" and nc > 0 then S.cam_unit = u; say("camera unit found: " .. tostring(hex_of(u))); return u end
      end
    end
  end
  S.cam_retry = S.t + 2
  return nil
end
local function read_camera(w)
  local u = find_camera(w); if not u then S.px = nil; return end
  local c = call("Unit", "camera", u, 1); if not c then S.px = nil; return end
  local px, py, pz = call("Vector3", "to_elements", call("Camera", "world_position", c))
  local rot = call("Camera", "world_rotation", c)
  local fx, fy = call("Vector3", "to_elements", rot and call("Quaternion", "forward", rot))
  if type(px) ~= "number" or type(fx) ~= "number" then S.px = nil; return end
  local l = math.sqrt(fx * fx + fy * fy); if l < 1e-4 then return end
  S.px, S.py, S.pz, S.fx, S.fy = px, py, pz, fx / l, fy / l
end

-- position of a vetted unit (never a runtime-built one)
local function pos(u)
  local x, y, z = call("Vector3", "to_elements", call("Unit", "world_position", u, 1))
  if type(x) == "number" then return x, y, z end
end

-- ---------------------------------------------------------------- the walk: one unit
local PER_FRAME = 300
local IGNORE, STATIC, static_seen, static_logs = {}, {}, {}, 0   -- (filled below: pods, ours; enemy structures)
local track_add
local function visit(u)
  if call("Unit", "alive", u) ~= true then return end
  local inf = S.info[u]
  if not inf then
    local h = hex_of(u)
    if not h then return end
    inf = { hex = h, asm = nil, late = S.passes >= 1 }
    S.info[u] = inf
  end
  local h = inf.hex
  local st = S.pass[h]
  if not st then st = { n = 0, asm = 0, near = 0, moving = 0, dmin = 1e9 }; S.pass[h] = st end
  st.n = st.n + 1
  if h == RUNTIME_HEX then return end                       -- the crash case: nothing more is asked of it
  local asm = call("Unit", "has_animation_state_machine", u) == true
  if asm then st.asm = st.asm + 1 end
  local known = TIER[h]
  local static = STATIC[h] and not IGNORE[h]
  -- unknown non-animated kinds near me: a position once a kind every 10th pass (static_log), to map turrets
  local probe = CFG.static_log and not asm and not known and not static and not IGNORE[h] and not static_seen[h]
    and (S.passes % 10 == 0) and st.n <= 6 and static_logs < 80
  -- Positions only for: known enemies, animated units (candidates), listed structures, and in discovery any other unit file.
  if not (known or asm or static or probe or (CFG.discovery and CFG.discovery_static)) then return end
  if not S.px then return end
  local x, y, z = pos(u)
  if not x then return end
  local dx, dy = x - S.px, y - S.py
  local d = math.sqrt(dx * dx + dy * dy)
  if d < st.dmin then st.dmin = d end
  if d <= CFG.discovery_range then st.near = st.near + 1 end
  if probe and d <= CFG.range then
    static_seen[h] = true; static_logs = static_logs + 1
    say(string.format("static?: %s at %.0f m (no animation state machine, not listed%s) - an enemy structure? add it to static_ids", h, d, NAME[h] and (" " .. NAME[h]) or ""))
  end
  if static then
    if inf.ally == nil then inf.ally = inf.late and d < 50 end
    if inf.ally then
      if not static_seen[h .. "a"] then static_seen[h .. "a"] = true; say(string.format("static: %s %s appeared at %.0f m after landing: taken as ours, not shown", h, STATIC[h], d)) end
      return
    end
    if d > CFG.range + 10 then return end
    for _, e in pairs(S.T) do
      if e.kind == "known" and e.x and (e.x - x) ^ 2 + (e.y - y) ^ 2 < 36 then return end   -- a tank's own turret
    end
    if not static_seen[h] then static_seen[h] = true; say(string.format("static: %s %s at %.0f m: shown", h, STATIC[h], d)) end
    track_add(u, 2.0, h, "static")
    return
  end
  if probe then return end
  local moved = false
  if inf.x then
    local mx, my = x - inf.x, y - inf.y
    if mx * mx + my * my > 1.0 then moved = true end   -- moved over 1 m since the last pass
  end
  if moved then inf.moved_at = S.t end
  inf.x, inf.y = x, y
  if inf.moved_at and S.t - inf.moved_at < 20 then st.moving = st.moving + 1 end
  -- tracking for the HUD
  if d > CFG.range + 10 then return end
  if h == "4d1c334d294dfa97" and d < 8 then S.body = u end     -- my Helldiver (nearest to the camera)
  local weight = nil
  local bd = 99
  if S.body and S.bx then local bx, by = x - S.bx, y - S.by; bd = math.sqrt(bx * bx + by * by) end
  if known then
    -- counted by the known-id pass (World.units_by_resource), not here
  elseif CFG.detect ~= "list" and asm and not FRIENDLY[h] and d > 3 and bd > 4 and inf.moved_at and S.t - inf.moved_at < 20 then
    weight = CFG.candidate_weight                           -- candidate enemy: animated, moved lately, not within 3 m of you
  end
  if weight then track_add(u, weight, h, "candidate") end
end

-- ---------------------------------------------------------------- discovery output
local function sorted_pass(tbl, key)
  local arr = {}
  for h, st in pairs(tbl) do arr[#arr + 1] = { h = h, st = st } end
  table.sort(arr, function(a, b) return a.st[key] > b.st[key] end)
  return arr
end
local function tag(h) return (TIER[h] and ("KNOWN t" .. TIER[h]) or "") .. (NAME[h] and (" " .. NAME[h]) or "") end
local function end_pass()
  S.passes = S.passes + 1
  -- swap in the new tracked list
  local pass = S.pass; S.pass = {}
  -- in combat = some animated non-runtime kind moving within discovery range
  local combat = false
  for h, st in pairs(pass) do if h ~= RUNTIME_HEX and st.moving > 0 and st.near > 0 and not FRIENDLY[h] then combat = true end end
  if combat then
    S.combat_scans = S.combat_scans + 1
    for h, st in pairs(pass) do
      local t = S.totals[h]
      if not t then t = { seen = 0, maxn = 0, near = 0, moving = 0, asm = 0, dmin = 1e9 }; S.totals[h] = t end
      t.seen = t.seen + 1; t.near = t.near + st.near; t.moving = t.moving + st.moving; t.asm = t.asm + st.asm
      if st.n > t.maxn then t.maxn = st.n end
      if st.dmin < t.dmin then t.dmin = st.dmin end
    end
  end
  if CFG.discovery and S.t >= S.next_disc then
    S.next_disc = S.t + 30
    local arr = sorted_pass(pass, "near")
    local total, rt = 0, (pass[RUNTIME_HEX] and pass[RUNTIME_HEX].n or 0)
    for i = 1, #arr do total = total + arr[i].st.n end
    say(string.format("discovery pass %d: %d live units, %d kinds, %d runtime-built skipped, tracked %d, combat %s",
      S.passes, total, #arr, rt, S.ntracked, tostring(combat)))
    local shown = 0
    for i = 1, #arr do
      local a = arr[i]
      if a.h ~= RUNTIME_HEX and a.st.near > 0 and shown < 15 then
        shown = shown + 1
        say(string.format("  %s x%d near %d asm %d moving %d dmin %.0f %s", a.h, a.st.n, a.st.near, a.st.asm, a.st.moving, a.st.dmin, tag(a.h)))
      end
    end
    -- once: does World.units_by_resource answer on this build? (v0.1 used it and saw 0 enemies)
    if not S.ubr_tested and arr[1] and arr[1].h ~= RUNTIME_HEX then
      S.ubr_tested = true
      local id = call("IdString64", "from_hex", arr[1].h)
      local r = id and call("World", "units_by_resource", S.world, id)
      say(string.format("check: World.units_by_resource(%s) -> %s (%s); IdString64.from_hex %s",
        arr[1].h, type(r), type(r) == "table" and tostring(#r) or "-", id and "ok" or "nil"))
    end
  end
  if CFG.discovery and S.t >= S.next_summary then
    S.next_summary = S.t + 30
    local f = io.open(SUMMARY_PATH, "w")
    if f then
      f:write(string.format("Sixth Sense %s discovery summary, %s\n", VERSION, os.date("%Y-%m-%d %H:%M:%S")))
      f:write(string.format("combat passes: %d (passes where something animated moved within %d m)\n", S.combat_scans, CFG.discovery_range))
      f:write("resource_id       combat_passes max_count near_total moving_total asm_total min_dist  note\n")
      local arr = sorted_pass(S.totals, "moving")
      for i = 1, math.min(#arr, 150) do
        local a, t = arr[i], arr[i].st
        f:write(string.format("%s  %6d %9d %10d %12d %9d %8.0f  %s\n", a.h, t.seen, t.maxn, t.near, t.moving, t.asm, t.dmin, tag(a.h)))
      end
      f:close()
    end
  end
end

local function walk(w)
  if not (CFG.discovery or CFG.detect ~= "list") then return end
  if not S.list then
    local us = call("World", "units", w)
    if type(us) ~= "table" then return end
    S.list, S.li, S.pass_started = us, 0, S.t
  end
  local list, last = S.list, math.min(#S.list, S.li + PER_FRAME)
  for i = S.li + 1, last do visit(list[i]) end
  S.li = last
  if last >= #list then S.list = nil; end_pass() end
end

-- ---------------------------------------------------------------- tracking (v1.1)
-- One table of tracked units, keyed by unit, kept from frame to frame:
--   known enemies are (re)acquired with World.units_by_resource every 0.5 s,
--   candidates are added the moment the World.units walk qualifies them (not at the end of the multi-second pass),
--   every tracked unit's position is read every frame, and a unit is kept until it is dead, loses its animation
--   state machine, is out of range + 15 m, or (known) was not re-acquired for 3 s / (candidate) did not re-qualify for 30 s.
-- A fresh IdString64 every time: v0.1 made them once and kept them across frames, and saw 0 enemies all mission.
-- ---------------------------------------------------------------- v1.3.2: pods, death, size classes
-- Pods and deployment craft: never tracked. From the ix log/discovery of 2026-11-01 (v1.3.1):
--   583ecde0d7718126  3-5 at a time, animated, at you (0-5 m) right after landing: the Hellpod + stratagem pods
--   16f397ca5f51f271  2 at a time, seen briefly after drops (36 of 595 passes): a pod (GUESS)
--   74e2285c01da4f71, f735a51a991e4bda  Warp Ship (Illuminate deployment), db90077e76faa025  Dropship (Automaton)
-- Plus ini ignore_ids (comma separated hex) on top of these.
local POD_IDS = { ["583ecde0d7718126"] = "Hellpod / stratagem pod", ["16f397ca5f51f271"] = "pod (GUESS)",
                  ["74e2285c01da4f71"] = "Warp Ship", ["f735a51a991e4bda"] = "Warp Ship", ["db90077e76faa025"] = "Dropship" }
for h in pairs(POD_IDS) do IGNORE[h] = true end
for h in tostring(CFG.ignore_ids or ""):gmatch("%x+") do if #h == 16 then IGNORE[h:lower()] = true end end
-- flyers: fast vertical moves are normal for them (the Stingray "Strikers" must keep working)
local FLYER = { ["19e18b46ec55d94a"] = true, ["282eb766c1ffa6a1"] = true }
-- size classes (x dot_size): tiny 0.6, medium 1.0, large 1.6, xlarge 2.2. Known ids not listed go by tier
-- (light tiny, medium medium, heavy large); candidates of unknown kind are medium. Names from Treasure Radar's list.
-- v1.4.1: base dot sizes in screen px at 1080 tall (dot_size medium), x dot_size (small 0.75, medium 1, large 1.35)
-- x the area scale. SIZE_MULT (relative to medium) is kept for the log.
local CLASS_PX = { tiny = 12, medium = 24, large = 44, xlarge = 58 }  -- v1.4.4: dots start out about twice as big
local SIZE_MULT = { tiny = 7 / 15, medium = 1.0, large = 28 / 15, xlarge = 38 / 15 }
local SIZE_OF = {
  ["78e1497571012c47"] = "tiny", ["0adc9f9173ad8e1d"] = "tiny", ["44458a2c52b002fb"] = "tiny",   -- Voteless
  ["da40bb347c7447f2"] = "medium", ["604a794ec45bb820"] = "medium", ["e8f19a0aa958e46d"] = "medium",  -- Overseers
  ["ac60e78435098c9d"] = "medium",                                  -- Watcher
  ["19e18b46ec55d94a"] = "medium",                                  -- Stingray
  ["67dc32dca4f02d33"] = "large",                                   -- Fleshmob
  ["965eae5a51acdd4a"] = "xlarge", ["f22d027b37bef107"] = "large",  -- Harvester (walker); Leviathan large (v1.4.1)
  ["d37e8d120d2836e3"] = "xlarge", ["ef570293245a17c2"] = "xlarge", ["bc242702fb46b7e7"] = "xlarge",  -- Factory/War Strider, Vox Engine
}
local TIER_SIZE = { "tiny", "medium", "large" }
local size_logged = {}
local function size_class(h, kind)
  local c = SIZE_OF[h] or (TIER[h] and TIER_SIZE[TIER[h]]) or "medium"
  if not size_logged[h] then
    size_logged[h] = true
    if not SIZE_OF[h] then
      say(string.format("size: %s %s%s -> %s x%.1f (not in the size map)", h, TIER[h] and ("known t" .. TIER[h]) or kind,
        NAME[h] and (" " .. NAME[h]) or "", c, SIZE_MULT[c]))
    end
  end
  return c
end
-- Death: Unit.has_animation_state_machine stays true while a body plays its death (several seconds), so v1.3.1's dots
-- lingered. Now (1) the animation state: Unit.animation_get_state answers one state per layer (up to 4); a state known
-- as a kind's death state (Treasure Radar's table, keyed layer * 100000 + state, layer 1 bare) hides it at once;
-- the last states a kind's units were in when their state machine went are learned as death states (after 2);
-- (2) still: one that moved and then has not moved 5 cm and kept the same states for still_hide s (1.0) is hidden
-- (dead or standing still; it shows again when it moves). The dead fade in 0.3 s, with no hold.
local DEATH = { ["846bc06c6b213a06"] = { [12] = 2 }, ["b2b3056bdf28e57b"] = { [60] = 2 }, ["a71aafd82c6ebc92"] = { [60] = 2 },
  ["09872e66d1276e1f"] = { [26] = 2 }, ["a1f37bf2a40fbde4"] = { [26] = 2 }, ["d522fd4748d443a5"] = { [24] = 2 },
  ["c14e0e887e7d2106"] = { [18] = 2 }, ["78e1497571012c47"] = { [31] = 2 }, ["0adc9f9173ad8e1d"] = { [31] = 2 },
  ["44458a2c52b002fb"] = { [31] = 2 }, ["da40bb347c7447f2"] = { [300000] = 2 }, ["e8f19a0aa958e46d"] = { [200009] = 2 },
  ["604a794ec45bb820"] = { [200005] = 2, [300002] = 2 } }
local DEATH_SEEN, LAYER = 2, 100000
local function states(u)
  if not fn("Unit", "animation_get_state") then return nil end
  local a, b, c, d = call("Unit", "animation_get_state", u)
  if type(a) ~= "number" then return nil end
  return a, b, c, d
end
local function in_death(h, a, b, c, d)
  local t = DEATH[h]
  if not t or a == nil then return false end
  if a ~= 0 and (t[a] or 0) >= DEATH_SEEN then return true end
  local L = { b, c, d }
  for i = 1, 3 do local s = L[i]; if type(s) == "number" and (t[(i + 1) * LAYER + s] or 0) >= DEATH_SEEN then return true end end
  return false
end
local function learn_death(e)
  if e.hidden_dead or not e.st then return end         -- (already caught: nothing to learn)
  local t = DEATH[e.hex]; if not t then t = {}; DEATH[e.hex] = t end
  if e.st[1] and e.st[1] ~= 0 and e.st[1] ~= e.st0 then t[e.st[1]] = (t[e.st[1]] or 0) + 1
    if t[e.st[1]] == DEATH_SEEN then say(string.format("death: learned %s state %d as a death state", e.hex, e.st[1])) end end
end
-- ---------------------------------------------------------------- v1.4.0: enemy structures (turrets, emplacements)
-- They have no animation state machine (or one that never moves) and stand still, so the candidate and still-hide
-- rules drop them. A listed static kind is tracked from the World.units walk (its position is read even with no state
-- machine) and drawn as a red diamond, medium size, never hidden for standing still; it goes when it is no
-- longer alive, its death state shows (asked only with a state machine), its first mesh is hidden (Treasure Radar's
-- destroyed-structure test), or the walk stops finding it (10 s).
-- Ids are hashes of the unit paths (hashlist + BingusSharedLoader archive.resource_hash); none was in the v1.3.2 ix
-- logs, which only measured animated units (discovery_static=false), and that was an Illuminate mission:
--   2cf3488c4845f8bd  content/fac_cyborgs/turrets/cyborg_tank_turret_cannon/cyborg_turret_heavycannon   (Cannon Turret)
--   aeaef7a1851e6c9d  content/fac_cyborgs/turrets/cyborg_tank_turret_autocannons/cyborg_turret_autocannons (AA turret)
--   ff5cc825b9571052  content/fac_cyborgs/turrets/cyborg_tank_turret_mortar/cyborg_turret_mortar          (Mortar)
--   9926876b2375a1bb  Bunker Turret (Treasure Radar's enemy list)
-- The tank-turret paths are also the turrets on Tanks/Shredder Tanks: a turret within 6 m of a tracked known enemy is
-- skipped (the tank is already its own dot). Gun emplacements (cyborg_emplacement_mg/hmg) are left out (harmless until a
-- bot mans one, and the bot shows). Bug nests do not shoot; none listed. Illuminate turrets: no path in the hashlist;
-- static_log finds them (see the log), then they go in static_ids.
for h, n in pairs({ ["2cf3488c4845f8bd"] = "Cannon Turret", ["aeaef7a1851e6c9d"] = "AA/autocannon turret",
                 ["ff5cc825b9571052"] = "Mortar turret", ["9926876b2375a1bb"] = "Bunker Turret" }) do STATIC[h] = n end
for h in tostring(CFG.static_ids or ""):gmatch("%x+") do if #h == 16 then STATIC[h:lower()] = STATIC[h:lower()] or "static_ids" end end
-- Ours: the Helldivers' stratagem turrets are never shown (ids from their paths), and a static unit that first appears
-- after the first full walk within 50 m of me (dropped in by a stratagem, as enemy structures are there from the start)
-- is taken as ours.
local ALLY = { ["ef85d6cf58e31d70"] = "gatling_turret", ["0e977c49db7604f9"] = "manned_turret",
               ["a970cba66fbeaa11"] = "manned_turret_discoverable", ["37cde43876ba26bb"] = "turret_machinegun_gpmg",
               ["57f27cbd5b71b0cb"] = "tutorial_turret", ["87f46b6d12bb016a"] = "target_turret" }
for h in pairs(ALLY) do IGNORE[h] = true end
local TRACK_MAX = 200
function track_add(u, w, h, kind)
  local e = S.T[u]
  if e then e.seen = S.t; if w > e.w then e.w = w end; if kind == "known" then e.kind = "known" end; return end
  if S.nT >= TRACK_MAX or IGNORE[h] then return end
  local sz = kind == "static" and "medium" or size_class(h, kind)
  S.T[u] = { w = w, hex = h, kind = kind, seen = S.t, added = S.t, x = nil, y = nil, size = sz, moved_t = S.t }
  S.nT = S.nT + 1
end
local function known_pass(w)
  if CFG.detect == "candidates" then return end
  for i = 1, #KNOWN_HEX do
    local id = call("IdString64", "from_hex", KNOWN_HEX[i])
    local us = id and call("World", "units_by_resource", w, id)
    if type(us) == "table" then
      for j = 1, #us do
        local u = us[j]
        if call("Unit", "alive", u) == true and call("Unit", "has_animation_state_machine", u) == true then
          track_add(u, TIER_WEIGHT[KNOWN_TIER[i]], KNOWN_HEX[i], "known")
        end
      end
    end
  end
end
-- bearing: 0 straight ahead, +right / -left, degrees -180..180, from the camera's forward and right vectors (z up:
-- right = (fy, -fx)). Rear = |bearing| > 90 (the back 180 degrees) in thirds: L -150..-90, C beyond +-150, R 90..150.
local function bearing(dx, dy)
  local fwd = dx * S.fx + dy * S.fy
  local right = dx * S.fy - dy * S.fx
  local b = math.deg(math.atan2(right, fwd))
  if CFG.swap_sides then b = -b end
  return b
end
local function sector(b)
  local ab = math.abs(b)
  if ab <= 90 then return nil end
  if ab >= 150 then return 2 end
  return (b < 0) and 1 or 3
end
local BAR_NAME = { "L", "C", "R" }
-- every frame: positions of the tracked units, the drop rules, the threat per bar and the nearest threat
local function threat()
  local t1, t2, t3 = 0, 0, 0
  local nk, nc, near = 0, 0, nil
  local ox, oy = S.px, S.py
  if S.bx then ox, oy = S.bx, S.by end                -- distance from my Helldiver when found, else the camera
  local R = clamp(CFG.range * CFG.sensitivity, 10, 120)
  S.eff_range = R
  local dt = S.dt or 0.016
  for u, e in pairs(S.T) do
    local drop, dead = false, false
    local stat = e.kind == "static"
    if stat then
      -- a structure: gone when not alive, when its first mesh is hidden (destroyed), or when the walk lost it (10 s)
      if call("Unit", "alive", u) ~= true then drop, dead = true, true
      else
        local m = fn("Unit", "mesh") and call("Unit", "mesh", u, 1)
        if m ~= nil and call("Mesh", "visibility", m) == false then drop, dead = true, true
        elseif S.t - e.seen > 10 then drop = true end
      end
    elseif call("Unit", "alive", u) ~= true or call("Unit", "has_animation_state_machine", u) ~= true then
      drop, dead = true, true; learn_death(e)
    elseif e.kind == "known" and S.t - e.seen > 3 then drop = true
    elseif e.kind ~= "known" and S.t - e.seen > 30 then drop = true end
    local x, y, z
    if not drop then x, y, z = pos(u); if not x then drop = true end end
    if not drop and stat then        -- a turret on a tracked tank: the tank is the dot (checked every frame)
      for _, o in pairs(S.T) do
        if o.kind == "known" and o.x and (o.x - x) ^ 2 + (o.y - y) ^ 2 < 36 then drop, e.x = true, nil; break end
      end
    end
    if not drop and ox then
      -- death by animation state, and stillness
      local a, b, c, d
      if not stat or call("Unit", "has_animation_state_machine", u) == true then a, b, c, d = states(u) end   -- (asking one without crashes)
      if a ~= nil then
        if not e.st then e.st, e.st0 = { a, b, c, d }, a end
        if a ~= e.st[1] or b ~= e.st[2] or c ~= e.st[3] or d ~= e.st[4] then e.st[1], e.st[2], e.st[3], e.st[4], e.state_t = a, b, c, d, S.t end
        e.hidden_dead = in_death(e.hex, a, b, c, d)
      end
      if e.lx then
        local mx, my = x - e.lx, y - e.ly
        if mx * mx + my * my > 0.0025 then e.moved_t, e.moved_ever, e.lx, e.ly = S.t, true, x, y end
      else e.lx, e.ly = x, y end
      local still_for = S.t - math.max(e.moved_t or S.t, e.state_t or 0)
      e.still = not stat and CFG.still_hide > 0 and e.moved_ever and still_for > CFG.still_hide
      -- pods: fast vertical, little horizontal, not a flyer (hidden for 2 s after it was seen falling)
      if e.z and not stat and not FLYER[e.hex] and dt > 0 then
        local vz = (z - e.z) / dt
        local hx, hy = (x - (e.px or x)) / dt, (y - (e.py or y)) / dt
        if math.abs(vz) > 12 and hx * hx + hy * hy < 9 then e.pod_t = S.t end
      end
      e.z, e.px, e.py = z, x, y
      e.show = not e.hidden_dead and not e.still and (S.t - e.added >= 0.5 or e.kind == "known") and not (e.pod_t and S.t - e.pod_t < 2)
      if e.kind ~= "known" and S.t - e.added < 0.5 then e.show = false end
      local dx, dy = x - ox, y - oy
      local dd = math.sqrt(dx * dx + dy * dy)
      if dd > R + 15 then drop = true
      else
        e.x, e.y, e.d = x, y, dd
        if e.show then S.ghost[u] = nil end              -- (shown again in range: no ghost beside it)
        if e.kind == "known" then nk = nk + 1 else nc = nc + 1 end
        if dd < R and dd > 0.5 and e.show then
          local bb = bearing(x - S.px, y - S.py)      -- the angle from the camera, as the view is turned
          local sc = sector(bb)
          e.b, e.s = bb, sc
          if not near or dd < near.d then near = e end
          if sc then
            local k = 1 - dd / R
            local v = e.w * (0.25 + 0.75 * k * k) * CFG.sensitivity
            if sc == 1 then t1 = t1 + v elseif sc == 2 then t2 = t2 + v else t3 = t3 + v end
          end
        end
        if e.was_shown and not e.show and (e.hidden_dead or e.still) then  -- (a body: a short fade where it fell)
          S.ghost[u] = { x = x, y = y, size = e.size, lost = S.t, dead = true }
        end
        e.was_shown = e.show
      end
    end
    if drop then
      if e.x and e.was_shown ~= false then
        S.ghost[u] = { x = e.x, y = e.y, size = e.size, lost = S.t, dead = dead or e.hidden_dead or e.still, static = stat }
      end
      S.T[u] = nil; S.nT = S.nT - 1
    end
  end
  S.nknown, S.ntracked, S.nearest = nk, nc, near
  S.target[1], S.target[2], S.target[3] = t1, t2, t3
end
-- heat: rises to the target in about 0.15 s; when the target falls it holds 1 s, then fades over 1.5 s
local RISE_TAU, HOLD_S, FADE_S = 0.05, 1.0, 1.5
local function smooth(dt)
  for i = 1, 3 do
    local h, tg = S.heat[i], S.target[i]
    if tg >= h then
      S.heat[i] = h + (tg - h) * (1 - math.exp(-dt / RISE_TAU))
      S.hold[i], S.peak[i] = S.t + HOLD_S / CFG.repeat_rate, math.max(S.heat[i], 0)
    elseif tg >= 0.97 * h then
      S.hold[i] = S.t + HOLD_S / CFG.repeat_rate   -- v1.3.2: a walking enemy's small dips keep the hold fresh
    elseif S.t >= S.hold[i] then
      S.heat[i] = math.max(tg, h - math.max(S.peak[i], 0.3) / (FADE_S / CFG.repeat_rate) * dt)
    end
  end
end

-- ---------------------------------------------------------------- draw
-- Made as Treasure Radar's loader makes its GUI: World.create_screen_gui(main world, "immediate", "material",
-- "core/performance_hud/debug", "material", "core/performance_hud/gui"), then Gui.rect(gui, Vector3, Vector2, Color).
-- v0.1/v0.2 made it with "immediate" only (no material), which may draw nothing. Each way tried is logged.
local GUI_FONT, GUI_MAT = "core/performance_hud/debug", "core/performance_hud/gui"
local GUI_WAYS = {
  { "immediate + font + gui material", { "immediate", "material", GUI_FONT, "material", GUI_MAT } },
  { "immediate + gui material", { "immediate", "material", GUI_MAT } },
  { "immediate only", { "immediate" } },
}
local function make_gui()
  local g = fn("World", "create_screen_gui")
  if not g then say("draw: World.create_screen_gui does not exist"); return nil end
  for k = 1, #GUI_WAYS do
    local way = GUI_WAYS[k]
    local a = way[2]
    local ok, gui = pcall(g, S.world, a[1], a[2], a[3], a[4], a[5])
    say(string.format("draw: create_screen_gui (%s) -> %s %s", way[1], ok and "ok" or "error", tostring(gui)))
    if ok and gui then S.gui_how = way[1]; return gui end
  end
  return nil
end
local function heat_color(h, alpha)
  h = clamp(h, 0, 3)
  if h < 0.02 then return nil end
  local r, g
  if h <= 1 then r, g = 255, 220 else r, g = 255, 220 * (1 - (h - 1) / 2) end
  local a = clamp(255 * alpha * clamp(0.35 + 0.65 * h, 0, 1), 0, 255)
  return ctor("Color", math.floor(a), math.floor(clamp(r, 0, 255)), math.floor(clamp(g, 0, 255)), 30)
end
local LAYER_NOW = 950   -- v1.4.1: the calibration panel draws at 990 (rects) / its labels at 995, above the radar
local function rect(x, y, w, h, c, layer)
  local p, sz = ctor("Vector3", x, y, layer), ctor("Vector2", w, h)
  local f = fn("Gui", "rect")
  if not (p and sz and c and f) then
    S.draw_fail = S.draw_fail + 1
    S.draw_err = string.format("missing: Vector3 %s, Vector2 %s, Color %s, Gui.rect %s (%s)", tostring(p ~= nil),
      tostring(sz ~= nil), tostring(c ~= nil), tostring(f ~= nil), tostring(CTOR_ERR.Vector3 or CTOR_ERR.Vector2 or CTOR_ERR.Color))
    return
  end
  local ok, err = pcall(f, S.gui, p, sz, c)
  if ok then S.draw_ok = S.draw_ok + 1 else S.draw_fail = S.draw_fail + 1; S.draw_err = "Gui.rect: " .. tostring(err) end
end
-- v0.4: no Gui.text. With the performance HUD font it drew white blocks in v0.3, and the game crashed in the
-- transition to the ship while that text was being drawn.
local function screen()
  local w, h = call("Application", "back_buffer_size")
  if type(w) ~= "number" or w <= 0 then w, h = call("Application", "resolution") end
  if type(w) ~= "number" or w <= 0 then w, h = 1920, 1080 end
  return w, h
end
-- ---------------------------------------------------------------- input and calibration (v1.0)
-- Input comes from the engine's own Lua devices, the same calls Chef Shared Loader's options menu uses on this game:
-- Mouse.axis_index('cursor'/'mouse'/'wheel'), Mouse.button_index('left'), Mouse.axis(i) -> Vector3, Mouse.button(i),
-- Keyboard.button_index(name), Keyboard.pressed(i), Keyboard.button(i), Window.get_main_window/show_cursor,
-- Mouse.dead_zone/set_dead_zone (to stop the camera turning while you drag). Every call is pcall'd; anything missing
-- is logged once and the keyboard does the rest.
local HOLD = 917351                                -- the dead zone size Chef's loader uses to hold the mouse
local IN = { probed = false, keys = {}, key_at = {}, rep = {}, axes = nil, hold = nil, hold_off = false,
             raw_logs = 0, mx = nil, my = nil, px = nil, py = nil, lmb = false, src = "none", rw = nil, rh = nil, res_at = -1,
             lastraw = nil }
local KEYNAMES = { toggle = { "f7" }, left = { "left", "numpad 4" }, right = { "right", "numpad 6" },
                   up = { "up", "numpad 8" }, down = { "down", "numpad 2" }, shift = { "left shift", "right shift" } }
local function key_ids(n)
  local t = IN.keys[n]
  if t and (#t > 0 or S.t < (IN.key_at[n] or 0)) then return t end
  t = {}
  for _, name in ipairs(KEYNAMES[n]) do
    local i = call("Keyboard", "button_index", name)
    if type(i) == "number" then t[#t + 1] = i end
  end
  IN.keys[n], IN.key_at[n] = t, S.t + 2      -- (no index yet: asked again in 2 s)
  return t
end
local function truthy(v) return v == true or (type(v) == "number" and v > 0.5) end
local function kpressed(n) for _, i in ipairs(key_ids(n)) do if truthy(call("Keyboard", "pressed", i)) then return true end end return false end
local function kdown(n) for _, i in ipairs(key_ids(n)) do if truthy(call("Keyboard", "button", i)) then return true end end return false end
-- pressed, or held: repeats after 0.35 s, every 0.05 s
local function krep(n)
  if kpressed(n) then IN.rep[n] = S.t + 0.35; return true end
  if IN.rep[n] and kdown(n) then
    if S.t >= IN.rep[n] then IN.rep[n] = S.t + 0.05; return true end
  else IN.rep[n] = nil end
  return false
end
-- ---------------------------------------------------------------- v1.5.4: controller (control=controller)
-- The engine's own pads (Pad1..Pad8; the first active / connected one), its buttons found by the names the pad
-- lists itself (num_buttons, button_name), as Chef Shared Loader's options menu does on this game. Only read in
-- controller mode. The game still sees every button (Lua cannot take input from it), so the page opens on a long
-- hold of View / Back / touchpad (the button the game leaves free off a mission) and the rest is read only while
-- the page is open.
local PAD = { n = nil, ix = {}, look_at = 0, down = {}, pr = {}, since = {}, rep = {}, name = nil }
_G.SIXTH_SENSE_PAD = PAD                           -- (read by the stub test)
local PAD_NAMES = { up = { "d_up", "up", "dpad_up" }, down = { "d_down", "down", "dpad_down" },
  left = { "d_left", "left", "dpad_left" }, right = { "d_right", "right", "dpad_right" },
  a = { "a", "cross" }, b = { "b", "circle" }, x = { "x", "square" }, y = { "y", "triangle" },
  lb = { "left_shoulder", "l1", "lb" }, rb = { "right_shoulder", "r1", "rb" }, r3 = { "right_thumb", "r3", "right_stick", "rs" },
  view = { "touch", "touchpad", "back", "view", "select", "share" } }
local function pad_find()
  if S.t < PAD.look_at then return end
  PAD.look_at = S.t + 2
  for n = 1, 8 do
    local p = "Pad" .. n
    if truthy(call(p, "active")) or truthy(call(p, "connected")) then
      local cnt, by = call(p, "num_buttons"), {}
      if type(cnt) == "number" and cnt > 0 and cnt <= 64 then
        for i = 0, cnt - 1 do local nm = call(p, "button_name", i); if type(nm) == "string" and nm ~= "" then by[nm:lower()] = i end end
      end
      local ix, miss = {}, {}
      for k, names in pairs(PAD_NAMES) do
        for _, c in ipairs(names) do if by[c] then ix[k] = by[c]; break end end
        if not ix[k] then miss[#miss + 1] = k end
      end
      if ix.view and ix.a and ix.up then
        PAD.n, PAD.ix, PAD.down, PAD.since, PAD.p = n, ix, {}, {}, p
        PAD.name = tostring(call(p, "name"))
        table.sort(miss)
        say(string.format("controller: %s (%s)%s", p, PAD.name, #miss > 0 and ("; no button for " .. table.concat(miss, ", ")) or ""))
        return
      end
    end
  end
end
-- this frame's buttons: PAD.pr[k] pressed this frame, PAD.since[k] held since
local function pad_frame()
  PAD.pr = {}
  if not PAD.n then pad_find(); if not PAD.n then return end end
  if not (truthy(call(PAD.p, "active")) or truthy(call(PAD.p, "connected"))) then
    say("controller: " .. PAD.p .. " gone"); PAD.n, PAD.look_at = nil, 0; return
  end
  for k, i in pairs(PAD.ix) do
    local d = truthy(call(PAD.p, "button", i))
    if d and not PAD.down[k] then PAD.pr[k] = true; PAD.since[k] = S.t end
    if not d then PAD.since[k] = nil end
    PAD.down[k] = d
  end
end
-- controller mode with a pad found: the pad drives the page and the F7 key / mouse do nothing
local function use_pad() return CFG.control == "controller" and PAD.n ~= nil end
local function prep(k)
  if PAD.pr[k] then PAD.rep[k] = S.t + 0.35; return true end
  if PAD.rep[k] and PAD.down[k] then
    if S.t >= PAD.rep[k] then PAD.rep[k] = S.t + 0.05; return true end
  else PAD.rep[k] = nil end
  return false
end
local function xy(v)
  if v == nil then return nil end
  local x, y = call("Vector3", "to_elements", v)
  if type(x) ~= "number" then
    local ok, a, b = pcall(function() return v.x, v.y end)
    if ok and type(a) == "number" then x, y = a, b
    elseif type(v) == "table" then x, y = v[1], v[2] end
  end
  if type(x) ~= "number" or type(y) ~= "number" then return nil end
  return x, y
end
local function find_axes()
  if IN.axes and (IN.axes.cursor or IN.axes.move or S.t < IN.axes.at) then return IN.axes end
  local A = { cursor = call("Mouse", "axis_index", "cursor"), move = call("Mouse", "axis_index", "mouse"),
              wheel = call("Mouse", "axis_index", "wheel"), l = call("Mouse", "button_index", "left"), at = S.t + 2 }
  for k, v in pairs(A) do if k ~= "at" and type(v) ~= "number" then A[k] = nil end end
  if not IN.axes or A.cursor or A.move then
    say(string.format("input: axes cursor %s mouse %s wheel %s, left button %s", tostring(A.cursor), tostring(A.move),
      tostring(A.wheel), tostring(A.l)))
  end
  IN.axes = A
  return A
end
local function probe()
  IN.probed = true
  for _, nsn in ipairs({ "Mouse", "Keyboard", "Window" }) do
    local t, names = ns(nsn), {}
    if t then pcall(function() for k, v in pairs(t) do if type(v) == "function" then names[#names + 1] = tostring(k) end end end) end
    table.sort(names)
    say(string.format("input: %s %s: %s", nsn, t and "present" or "ABSENT", table.concat(names, " ")))
  end
  for _, f in ipairs({ "Mouse.axis_index", "Mouse.button_index", "Mouse.axis", "Mouse.button", "Mouse.pressed",
                       "Mouse.dead_zone", "Mouse.set_dead_zone", "Mouse.num_axes", "Mouse.num_buttons",
                       "Keyboard.button_index", "Keyboard.pressed", "Keyboard.button", "Window.get_main_window",
                       "Window.show_cursor", "Vector3.to_elements" }) do
    local a, b = f:match("(%w+)%.([%w_]+)")
    say("input: " .. f .. (fn(a, b) and " yes" or " NO"))
  end
  say(string.format("input: Mouse.num_axes %s num_buttons %s", tostring(call("Mouse", "num_axes")), tostring(call("Mouse", "num_buttons"))))
  for n, names in pairs(KEYNAMES) do
    local parts = {}
    for _, name in ipairs(names) do parts[#parts + 1] = name .. "=" .. tostring(call("Keyboard", "button_index", name)) end
    say("input: key " .. n .. ": " .. table.concat(parts, ", "))
  end
  local A = find_axes()
  local win = call("Window", "get_main_window")
  say(string.format("input: main window %s, show_cursor %s, Application.resolution %s", tostring(win),
    tostring(win ~= nil and call("Window", "show_cursor", win)), table.concat({ tostring((call("Application", "resolution"))) }, "")))
  for _, k in ipairs({ "cursor", "move", "wheel" }) do
    if A[k] then local x, y = xy(call("Mouse", "axis", A[k])); say(string.format("input: first read %s axis -> %s, %s", k, tostring(x), tostring(y))) end
  end
  if A.move then local m, s = call("Mouse", "dead_zone", A.move); say(string.format("input: mouse dead zone %s %s", tostring(m), tostring(s))) end
end
local function hold_take()
  local A = IN.axes
  if IN.hold or IN.hold_off or not (A and A.move) then return end
  local mode, size = call("Mouse", "dead_zone", A.move)
  if type(mode) ~= "number" or type(size) ~= "number" then
    IN.hold_off = true; say("input: no Mouse.dead_zone answer: the camera turns while you move the mouse"); return
  end
  if size >= 1e5 then return end                    -- (another mod holds it; the cursor axis still moves mine)
  call("Mouse", "set_dead_zone", A.move, 1, HOLD)
  local _, now = call("Mouse", "dead_zone", A.move)
  if now == HOLD then IN.hold = { mode, size }; say(string.format("input: mouse held for calibration (dead zone was %s %s)", tostring(mode), tostring(size)))
  else IN.hold_off = true; say("input: could not hold the mouse (dead zone reads " .. tostring(now) .. ")") end
end
local function hold_give()
  if not IN.hold then return end
  local A = IN.axes
  local _, size = call("Mouse", "dead_zone", A.move)
  if size == HOLD then call("Mouse", "set_dead_zone", A.move, IN.hold[1], IN.hold[2]) end
  say(string.format("input: mouse given back (dead zone %s %s)", tostring(IN.hold[1]), tostring(IN.hold[2])))
  IN.hold = nil
end
-- the cursor in screen px, y from the top; the left button; the wheel this frame
local function read_mouse(sw, sh)
  local A = find_axes()
  if IN.mx == nil then IN.mx, IN.my = sw / 2, sh / 2 end
  if not (A.cursor or A.move) then IN.src = "none"; return end
  if S.t >= IN.res_at then
    local a, b = call("Application", "resolution")
    IN.rw, IN.rh, IN.res_at = tonumber(a), tonumber(b), S.t + 1
  end
  local win = call("Window", "get_main_window")
  local shown = win ~= nil and call("Window", "show_cursor", win) == true
  local moved, rx, ry = false, nil, nil
  if A.cursor and IN.rw and IN.rw > 0 and IN.rh > 0 then
    rx, ry = xy(call("Mouse", "axis", A.cursor))
    if rx then
      -- the cursor axis counts the window's pixels from the bottom left, y up (cursor_flip_y=true if it is y down)
      local cx = rx * sw / IN.rw
      local cy = CFG.cursor_flip_y and (ry * sh / IN.rh) or (sh - ry * sh / IN.rh)
      if shown then
        moved = cx ~= IN.mx or cy ~= IN.my
        IN.mx, IN.my, IN.src, IN.px = cx, cy, "cursor", nil
      else
        hold_take()
        local px, py = IN.px, IN.py
        IN.px, IN.py = cx, cy
        if px then
          local dx, dy = cx - px, cy - py
          local mid = math.abs(cx - sw / 2) <= 3 and math.abs(cy - sh / 2) <= 3   -- (the game re-centring its hidden cursor)
          local jump = math.abs(dx) > sw / 3 or math.abs(dy) > sh / 3
          if (dx ~= 0 or dy ~= 0) and not mid and not jump then
            moved = true; IN.mx, IN.my, IN.src = IN.mx + dx, IN.my + dy, "cursor moves"
          end
        end
      end
    end
  end
  local dx, dy
  if not moved and not IN.hold and A.move and not shown then
    dx, dy = xy(call("Mouse", "axis", A.move))
    if dx and (dx ~= 0 or dy ~= 0) then
      local k = sh / 1080                            -- (the delta counts y down)
      IN.mx, IN.my, IN.src, moved = IN.mx + dx * k, IN.my + dy * k, "mouse delta", true
    end
  end
  IN.mx, IN.my = clamp(IN.mx, 0, sw - 1), clamp(IN.my, 0, sh - 1)
  IN.wheel = 0
  if A.wheel then local _, wy = xy(call("Mouse", "axis", A.wheel)); IN.wheel = wy or 0 end
  IN.lmb = A.l ~= nil and truthy(call("Mouse", "button", A.l))
  local raw = string.format("%s,%s", tostring(rx), tostring(ry))
  if moved and IN.raw_logs < 12 and raw ~= IN.lastraw then
    IN.raw_logs = IN.raw_logs + 1
    say(string.format("input: mouse move %d: cursor axis raw %s of window %sx%s, delta %s,%s, game cursor shown %s, held %s -> screen px %.0f, %.0f from top (%s)",
      IN.raw_logs, raw, tostring(IN.rw), tostring(IN.rh), tostring(dx), tostring(dy), tostring(shown), tostring(IN.hold ~= nil), IN.mx, IN.my, IN.src))
  end
  IN.lastraw = raw
end
-- ini: replace or append key=value lines, keeping everything else
local function ini_save(kv)
  local lines, seen = {}, {}
  local f = io.open(CFG_PATH, "r")
  if f then for line in f:lines() do lines[#lines + 1] = line end; f:close() else for line in CFG_TEXT:gmatch("([^\n]*)\n") do lines[#lines + 1] = line end end
  for i, line in ipairs(lines) do
    local k = line:match("^%s*([%w_]+)%s*=")
    if k and kv[k] ~= nil then lines[i] = k .. "=" .. kv[k]; seen[k] = true end
  end
  for _, k in ipairs(kv.__order) do
    if not seen[k] then
      if kv.__comment and kv.__comment[k] then for c in (kv.__comment[k] .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = c end end
      lines[#lines + 1] = k .. "=" .. kv[k]
    end
  end
  local w = io.open(CFG_PATH, "w")
  if not w then say("ini: could not be written"); return false end
  w:write(table.concat(lines, "\n"), "\n"); w:close()
  return true
end
-- the placement area, in gui units (gui y runs up: y1 is the top edge, y0 the bottom)
-- v1.5.5 Help: README.md and CONTROLS.md, rendered into page textures and embedded as text by tools/build.py
-- (tools/help_pages.py) at build time; the block between the markers is generated.
-- BEGIN HELP DOCS (generated by tools/help_pages.py from README.md and CONTROLS.md at build time; do not edit)
local HELP_PAGES = {
  { '54514a6e65fab9d6', 1024, 768, "README" },
  { '7a34a487cd463077', 1024, 768, "README" },
  { '12852d207553801a', 1024, 768, "README" },
  { 'a370d5eed5f4d95b', 1024, 768, "CONTROLS" },
  { 'f5328f610e4af399', 1024, 768, "CONTROLS" },
  { 'cbef31d6a26c5b78', 1024, 768, "CONTROLS" },
  { '4b85ef9770a28f13', 1024, 768, "CONTROLS" },
  { '96a5e48f673a5f89', 1024, 768, "CONTROLS" },
}
local HELP_TEXT = [==[
==== README (README.md) ====
# Sixth Sense

**A 360° enemy radar HUD for Helldivers 2, running under HellForge with Bingus Shared Loader.**

Version **1.5.6** · GUID `bb72454c-ccd3-4e9b-927c-fcd80a09baf1`

![Sixth Sense radar preview](docs/images/radar_preview_green.png)

Sixth Sense draws a round radar on your screen showing enemies all around you, including the ones behind you. It
turns with your view: up on the radar is where you are looking. Red squares are enemies, red diamonds are enemy
structures (turrets and the like), and the white marker in the middle is you. It only reads the game and draws on
the screen; it changes nothing in the game.

> **Homepage / source:** https://github.com/lankynibbs/SixthSense (branch `develop`)  
> Controls guide: https://github.com/lankynibbs/SixthSense/blob/develop/CONTROLS.md  
> Bug reports and ideas: https://github.com/lankynibbs/SixthSense/issues

## Requirements
- **HellForge** (the offline Helldivers 2 launcher, game build 25480438).
- **Bingus Shared Loader v20** or newer (Nexus Mods / github.com/CowboyBingus/BingusSharedLoader). HellForge does
  not ship it.

## Install
1. Download **Bingus Shared Loader** (`Bingus-Shared-Loader-v20.zip`) and **`SixthSense.zip`** (from the mod page, or
   build it from the source above).
2. Open the HellForge launcher > **Mods** > **Add mods...** and pick both zips.
3. Switch **both** on (new mods start switched off; they show in the cosmetic group with a **LUA** tag).
4. Launch the game from HellForge. The radar appears in game; press **F7** to set it up.

Updating: add the new `SixthSense.zip` the same way. The GUID stays the same, so it replaces the old version and
keeps your settings.

## Features
- **360° radar** with enemies and enemy structures, range rings and cross hairs; enemies you lose sight of fade out.
- **F7 setup page** with two tabs:
  - **Display**: drag the **grab handle** to move the radar, drag a **corner** (or use the mouse wheel) to resize it.
  - **Settings**: sliders for **Size**, **Sensitivity** (range, 10 to 120 m), **Repeat rate** (how quickly dots
    update and fade), **Dot size** (S / M / L) and **Radar color**, plus **Shown / Hidden** and **Controls**.
- **Radar color**: green (default), white, yellow, red or light blue. It colours the radar display only (disc,
  rings, cross hairs); enemy markers always stay red.
- **Reset** (click twice) restores the defaults of the current tab; **hold F7 for 3 s** for a panic layout reset.
- **Shown / Hidden**: hide the radar during play without uninstalling it.
- **Keyboard + mouse or controller**: pick the scheme on the Settings tab. On a controller, hold **View / Back /
  touchpad for 2 s** to open the page.
- **Per-resolution layouts**: the radar's place and size are remembered for each screen resolution, and kept
  inside the part of the window the game lets mods draw on (Render Scale aware).

- **Help** button on the F7 page: this README and the full controls guide, built into the mod (works offline).

Full controls (mouse and controller): **[CONTROLS.md](CONTROLS.md)**, also shown in game by **Help**.

## Settings and logs
Under HellForge they live in `<HellForge>\userdata\environment\Local\CowboyBingus\Helldivers2\Logs\`
(for example `D:\HellForge\userdata\...`):
- `sixth_sense.ini`: your settings, written by the F7 page (commented; close the game before editing by hand).
- `sixth_sense.log`: what the mod did; include it when reporting a problem.

Settings from the older **Rear Heat HUD** (`rear_heat_hud.ini`) are copied over once.

## Known limits
- Built and tested for the offline build HellForge runs (25480438) only.
- A Lua mod cannot take input away from the game: controller buttons used on the F7 page also reach the game, so set
  the radar up on the ship.
- Enemy recognition uses a built-in list of enemy ids; an enemy type not on it may not show.

## For developers
- Browse or clone: https://github.com/lankynibbs/SixthSense (`git clone https://github.com/lankynibbs/SixthSense.git`, branch `develop`).
- Source: `src/sixth_sense.lua` (plus `src/enemy_tiers.lua.inc`). Build: `python3 tools/build.py` writes
  `SixthSense.zip` (needs the sibling `BingusSharedLoader` and `Treasure-Radar` checkouts). Offline test:
  `python3 tests/stub_test.py` (needs `lupa`).
- Release zip contents (`SixthSense.zip`): `manifest.json` (name "Sixth Sense v1.5.6", the GUID above) and
  `Addon/9ba626afa44a3aa3.patch_0` with its `.gpu_resources` and `.stream`: the Lua addon plus the textures from
  `assets/` (the radar disc, the F7 page's word labels and the Help pages). The Help pages (`assets/help_*.png`)
  and the text embedded in the Lua are made from README.md and CONTROLS.md by `tools/help_pages.py`, which
  `tools/build.py` runs before every build. Zips are git-ignored; attach `SixthSense.zip` to a
  release instead of committing it.
- Changes: [CHANGELOG.md](CHANGELOG.md). Development notes: [docs/history/](docs/history/).

## Credits
Bingus Shared Loader (CowboyBingus), HellForge; texture drawing after Treasure Radar; controller discovery after Chef
Shared Loader; labels set in Poppins Bold (SIL Open Font License); Help pages set in DejaVu Sans (`tools/fonts/`, its licence alongside).

==== CONTROLS (CONTROLS.md) ====
# Sixth Sense: controls (v1.5.6)

> On-request document: written when asked, not updated every commit. It describes v1.5.6
> (`src/sixth_sense.lua`); regenerated for v1.5.6 (public repo links). Online: https://github.com/lankynibbs/SixthSense/blob/develop/CONTROLS.md (source: https://github.com/lankynibbs/SixthSense). The same text is built into the mod: press Help on the F7 page. For an overview see [README.md](README.md), per-version notes [docs/history/version-notes.md](docs/history/version-notes.md), and [CHANGELOG.md](CHANGELOG.md).

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
- The page has four buttons at the top of its panel: **Display**, **Settings**, **Reset**, **Help**. The panel places itself
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

### Help
- **Help** (the fourth button, both tabs) shows this guide and the README (what the mod is, install, features)
  inside the game, as pages. **Mouse wheel**, or a click on the **left / right half** of the page, turns pages.
- Close it with **Help** again, a **click outside** the page, or a click on **Reset** or a tab (Reset is not armed;
  your radar settings are untouched). Closing the F7 page also closes Help.

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
| Close the page (saved) | **B / Circle** (with Help open, B closes Help first) |
| Display / Settings tab | **LB / RB** (L1 / R1), either one flips the tab |
| Reset (arm, then confirm within 3 s) | **X / Square**, twice |
| Help (open / close) | **R3** (click the right stick) |
| Help: turn pages | **LB / RB** or **D-pad left / right** |
| Help: close (the page stays open) | **B / Circle** or **R3** |
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
]==]
-- END HELP DOCS
_G.SIXTH_SENSE_HELP_TEXT = HELP_TEXT              -- (read by the stub test)
local CAL = { x0 = nil, y0 = nil, x1 = nil, y1 = nil, bw = nil, bh = nil, drag = nil, dirty = false, last_save = -1, on = false }
_G.SIXTH_SENSE_CAL = CAL                          -- (read by the stub test)
local SMIN, SMAX
-- v1.4.2 placement: the radar's centre (CAL.cx, CAL.cy) and diameter (CAL.d) as fractions of the visible screen
-- (cy from the top, d of the screen height). The gui-unit box CAL.x0..y1 (the radar's bounding box) is derived from
-- them each time through the current transform, so a resolution change keeps the radar where it was on screen.
local D_DEF = 0.35
SMIN, SMAX = 0.08, 1.0
-- the transform for this back buffer: sx/sy measured at transform_ref_h tall, scaled with the height (gui space
-- normalised to the height) unless transform_scale=fixed
local function apply_xf(sw, sh, why)
  local k = CFG.transform_scale == "height" and sh / CFG.transform_ref_h or 1
  CFG.sx_scale, CFG.sy_scale = XF_REF.sx * k, XF_REF.sy * k
  CAL.sw, CAL.sh = sw, sh
  CAL.bw, CAL.bh = sw / CFG.sx_scale, sh / CFG.sy_scale
  say(string.format("transform (%s): screen %dx%d, model %s (ref %.4f/%.4f at %d tall) -> sx %.4f sy %.4f gy_top %.1f; visible gui x 0..%.1f, y %.1f..%.1f; drawable bottom at %.3f of the screen",
    why, sw, sh, CFG.transform_scale, XF_REF.sx, XF_REF.sy, CFG.transform_ref_h, CFG.sx_scale, CFG.sy_scale, CFG.gy_top, CAL.bw, CFG.gy_top, CFG.gy_top - CAL.bh,
    math.min(1, CFG.gy_top * CFG.sy_scale / sh)))
end
local function ybot() return math.min(1, CFG.gy_top * CFG.sy_scale / CAL.sh) end   -- the game clips gui below gy 0
-- v1.4.6 viewport: the drawable rect in screen px (x, y from the window's top-left; w, h). A screen GUI in the game's
-- world is placed in window px but only the render size's worth of it (top-left) reaches the picture (Chef Shared
-- Loader 1.3.1 found this on this game: Render Scale below native, or a Resolution below the window in Borderless).
-- The render size comes from the game's user_settings.config (render_resolution = [ W H ]), read on load, on a
-- resolution change and every 10 s; the bottom is cut where the gui clips (gy 0). Gui.resolution is logged as well.
local VP = { x = 0, y = 0, w = 1920, h = 1080, src = "default", key = nil }
_G.SIXTH_SENSE_VP = VP                            -- (read by the stub test)
-- v1.4.7 settings file search: %APPDATA%\Arrowhead\Helldivers2, %LOCALAPPDATA%\Arrowhead\Helldivers2, then HellForge's
-- <...>\userdata\profiles\*\user_settings.config (userdata found by going up from LOCALAPPDATA, which HellForge points at
-- <HellForge>\userdata\environment\Local). Darryl's game reads profiles\default; the redirected AppData has none.
-- Profiles are listed with lfs when present, else "dir /b /ad /o-d" through io.popen (newest folder first), and
-- "default" is always tried. Among the files found, one whose screen_resolution is the window's wins; else the most
-- recently modified (lfs), else the first listed (newest folder).
local function read_cfg(path)
  local f = io.open(path, "r"); if not f then return nil end
  local txt = f:read("*a") or ""; f:close()
  local rw, rh = txt:match("[%s{]render_resolution%s*=%s*%[%s*(%d+)%s+(%d+)%s*%]")
  local qw, qh = txt:match("[%s{]screen_resolution%s*=%s*%[%s*(%d+)%s+(%d+)%s*%]")
  if not rw then rw, rh = txt:match("^render_resolution%s*=%s*%[%s*(%d+)%s+(%d+)%s*%]") end
  if not qw then qw, qh = txt:match("^screen_resolution%s*=%s*%[%s*(%d+)%s+(%d+)%s*%]") end
  return { path = path, rw = tonumber(rw), rh = tonumber(rh), qw = tonumber(qw), qh = tonumber(qh) }
end
local function list_profiles(dir)
  local names, how = {}, "default only"
  local lfs = rawget(_G, "lfs")
  if type(lfs) == "table" and type(lfs.dir) == "function" then
    local ok = pcall(function() for n in lfs.dir(dir) do if n ~= "." and n ~= ".." then names[#names + 1] = n end end end)
    if ok then how = "lfs" end
  end
  if #names == 0 and type(io.popen) == "function" then
    local ok, p = pcall(io.popen, 'dir /b /ad /o-d "' .. dir .. '" 2>nul')
    if ok and p then
      local okr, out = pcall(p.read, p, "*a"); pcall(p.close, p)
      if okr and type(out) == "string" then for n in out:gmatch("[^\r\n]+") do names[#names + 1] = n end end
      if #names > 0 then how = "dir listing (newest first)" end
    end
  end
  local seen = {}
  for _, n in ipairs(names) do seen[n:lower()] = true end
  if not seen.default then names[#names + 1] = "default" end
  return names, how
end
local function settings_render_res(sw, sh)
  local tried = {}
  for _, env in ipairs({ "APPDATA", "LOCALAPPDATA" }) do
    local base = os.getenv(env)
    if type(base) == "string" and base ~= "" then
      local path = base .. "\\Arrowhead\\Helldivers2\\user_settings.config"
      tried[#tried + 1] = path
      local c = read_cfg(path)
      if c and c.rw then return c.rw, c.rh, path end
      if c then tried[#tried] = path .. " (no render_resolution)" end
    end
  end
  local root = tostring(os.getenv("LOCALAPPDATA") or ""):match("^(.-[\\/][Uu][Ss][Ee][Rr][Dd][Aa][Tt][Aa])[\\/]")
  if root then
    local pdir = root .. "\\profiles"
    local names, how = list_profiles(pdir)
    local found, best = {}, nil
    for _, n in ipairs(names) do
      local path = pdir .. "\\" .. n .. "\\user_settings.config"
      local c = read_cfg(path)
      if c and c.rw then
        local lfs = rawget(_G, "lfs")
        if type(lfs) == "table" and type(lfs.attributes) == "function" then local ok, m = pcall(lfs.attributes, path, "modification"); c.mtime = ok and tonumber(m) or nil end
        found[#found + 1] = c
      else tried[#tried + 1] = path .. (c and " (no render_resolution)" or "") end
    end
    for _, c in ipairs(found) do if c.qw == sw and c.qh == sh then best = c; best.why = "screen_resolution matches the window"; break end end
    if not best then
      for _, c in ipairs(found) do if c.mtime and (not best or c.mtime > best.mtime) then best = c end end
      if best then best.why = "most recently modified" elseif found[1] then best = found[1]; best.why = "first listed (" .. how .. "), no modification times" end
    end
    if best then
      return best.rw, best.rh, string.format("%s (HellForge profile, %d found, %s; screen_resolution %s; not found before it: %s)", best.path, #found, best.why,
        best.qw and (best.qw .. "x" .. best.qh) or "?", #tried > 0 and table.concat(tried, ", ") or "-")
    end
  else tried[#tried + 1] = "(no HellForge userdata folder in LOCALAPPDATA)" end
  return nil, nil, #tried > 0 and ("not found: " .. table.concat(tried, ", ")) or "no APPDATA"
end
local function viewport(sw, sh, why)
  local w, h, src = sw, sh, "window (back buffer)"
  local rw, rh, rsrc = settings_render_res(sw, sh)
  if rw and rh and rw > 0 and rh > 0 and (rw < sw - 1 or rh < sh - 1) then
    w, h, src = math.min(sw, rw), math.min(sh, rh), string.format("render_resolution %dx%d (top-left of the window)", rw, rh)
  end
  local hb = math.min(h, CFG.gy_top * CFG.sy_scale)          -- (the gui is clipped below gy 0)
  local key = string.format("%d,%d,%d,%d", sw, sh, w, hb)
  local changed = key ~= VP.key
  VP.x, VP.y, VP.w, VP.h, VP.src, VP.key, VP.rw, VP.rh = 0, 0, w, hb, src, key, rw, rh
  if changed then
    local gr, gres = fn("Gui", "resolution"), "absent"
    if gr and S.gui then local ok, a, b = pcall(gr, S.gui); gres = ok and (tostring(a) .. " " .. tostring(b)) or ("error " .. tostring(a)) end
    say(string.format("viewport (%s): screen %dx%d, render %s (%s), drawable rect x %d..%d y %d..%d px from the top-left (offset 0,0, %dx%d, centre %.0f,%.0f), gui %.1f x %.1f units (sx %.4f sy %.4f gy_top %.1f, gui y %.1f..%.1f), source %s; Gui.resolution -> %s",
      why, sw, sh, rw and (rw .. "x" .. rh) or "?", rsrc, 0, w, 0, hb, w, hb, w / 2, hb / 2, w / CFG.sx_scale, hb / CFG.sy_scale,
      CFG.sx_scale, CFG.sy_scale, CFG.gy_top, CFG.gy_top, CFG.gy_top - hb / CFG.sy_scale, src, gres))
  end
  return changed
end
local function derive()
  local SX, SY, GT = CFG.sx_scale, CFG.sy_scale, CFG.gy_top
  local rpx = CAL.d * VP.h / 2
  local wpx = rpx * CFG.radar_aspect
  local cxp, cyp = VP.x + CAL.cx * VP.w, VP.y + CAL.cy * VP.h
  CAL.x0, CAL.x1 = (cxp - wpx) / SX, (cxp + wpx) / SX
  CAL.y1, CAL.y0 = GT - (cyp - rpx) / SY, GT - (cyp + rpx) / SY
end
local function clamp_area(why)
  local yb = 1                                     -- (v1.4.6: fractions of the drawable rect, its bottom already cut)
  local dmax = 0.98 * math.min(yb, VP.w / (VP.h * CFG.radar_aspect))
  local d = clamp(CAL.d, 0.05, dmax)
  local hw, hh = d * VP.h / 2 * CFG.radar_aspect / VP.w, d / 2
  local cx, cy = clamp(CAL.cx, hw, 1 - hw), clamp(CAL.cy, hh, yb - hh)
  if math.abs(cx - CAL.cx) > 1e-6 or math.abs(cy - CAL.cy) > 1e-6 or math.abs(d - CAL.d) > 1e-6 then
    CAL.clamp_log = CAL.clamp_log or {}
    if S.t >= (CAL.clamp_log[why] or 0) then
      CAL.clamp_log[why] = S.t + 0.5
      say(string.format("area clamped (%s): centre %.3f,%.3f -> %.3f,%.3f, diameter %.3f -> %.3f (kept inside the drawable area, bottom %.3f)", why, CAL.cx, CAL.cy, cx, cy, CAL.d, d, yb))
    end
    CAL.cx, CAL.cy, CAL.d = cx, cy, d
  end
  derive()
end
local function valid_pos() return type(CAL.cx) == "number" and CAL.cx == CAL.cx and CAL.cy == CAL.cy and CAL.d == CAL.d
  and CAL.cx > -0.5 and CAL.cx < 1.5 and CAL.cy > -0.5 and CAL.cy < 1.5 and CAL.d > 0.02 and CAL.d < 1.5 end
-- v1.4.6 per-resolution layouts: LAYOUTS["WxH"] = { cx, cy, d } (fractions of the drawable rect)
local LAYOUTS = {}
_G.SIXTH_SENSE_LAYOUTS = LAYOUTS                  -- (read by the stub test)
local function layouts_parse(str)
  for k in pairs(LAYOUTS) do LAYOUTS[k] = nil end
  for w, h, a, b, c in tostring(str or ""):gmatch("(%d+)x(%d+)%s*:%s*([%d%.%-]+)%s*,%s*([%d%.%-]+)%s*,%s*([%d%.%-]+)") do
    a, b, c = tonumber(a), tonumber(b), tonumber(c)
    if a and b and c and c > 0.02 and c < 1.5 and a > -0.5 and a < 1.5 and b > -0.5 and b < 1.5 then LAYOUTS[w .. "x" .. h] = { a, b, c } end
  end
end
local function layouts_str()
  local keys = {}
  for k in pairs(LAYOUTS) do keys[#keys + 1] = k end
  table.sort(keys)
  local out = {}
  for _, k in ipairs(keys) do local L = LAYOUTS[k]; out[#out + 1] = string.format("%s:%.4f,%.4f,%.4f", k, L[1], L[2], L[3]) end
  return table.concat(out, ";")
end
local function res_key(sw, sh) return string.format("%dx%d", sw, sh) end
local function reset_pos(why)
  CAL.cx, CAL.cy, CAL.d = 0.5, 0.5, D_DEF           -- (v1.4.6: the centre of the drawable area)
  clamp_area("reset"); CAL.dirty = true
  if CAL.key and LAYOUTS[CAL.key] then LAYOUTS[CAL.key] = nil end   -- (only this resolution's layout goes)
  CAL.pos_set, CAL.has_saved = false, false
  say(string.format("reset (%s): radar centred at %.3f, %.3f of the drawable area, diameter %.2f; saved layout for %s cleared", why, CAL.cx, CAL.cy, CAL.d, tostring(CAL.key)))
end
-- this resolution's layout: its own if saved, else the centred default (the centre of the drawable area, default size)
local function layout_load(sw, sh, why)
  local key = res_key(sw, sh)
  CAL.key = key
  local L, how = LAYOUTS[key], "saved"
  if not L then
    how = "centred default"
    say(string.format("viewport: no saved layout for %s, using centered default", key))
  end
  CAL.has_saved = LAYOUTS[key] ~= nil
  CAL.pos_set = false
  if L then CAL.cx, CAL.cy, CAL.d = L[1], L[2], L[3] else CAL.cx, CAL.cy, CAL.d = 0.5, 0.5, D_DEF end
  CAL.layout_how = how
  say(string.format("layout (%s): %s uses %s: centre %.3f, %.3f of the drawable area, diameter %.3f of its height", why, key, how, CAL.cx, CAL.cy, CAL.d))
end
-- on load and on a resolution change: clamp back in; reset if still invalid
local function sanity(why)
  if not valid_pos() then reset_pos(why .. ": invalid position") return end
  clamp_area(why)
  if not valid_pos() then reset_pos(why .. ": invalid after clamping") end
end
local function cal_scale() return CAL.d end
local function set_scale(s)
  CAL.d = clamp(s, SMIN, SMAX)
  clamp_area("scale")
  CAL.dirty, CAL.pos_set = true, true
end
local function move_by(dx, dy)
  CAL.cx = CAL.cx + dx * CFG.sx_scale / VP.w
  CAL.cy = CAL.cy - dy * CFG.sy_scale / VP.h
  clamp_area("move")
  CAL.dirty, CAL.pos_set = true, true
end
local function cal_init(sw, sh)
  apply_xf(sw, sh, "load")
  viewport(sw, sh, "load")
  layouts_parse(CFG.radar_layouts)
  local mig146 = nil
  if CFG.radar_cx >= 0 and CFG.radar_cy >= 0 and CFG.radar_d > 0 then
    if not CFG.v146_migrated then
      -- v1.4.6 migration, once: radar_cx/cy/d (screen fractions, made at Darryl's 3840x1080, where the drawable area
      -- was the full window cut at the gui's bottom, 0.9333 of the height) -> the 3840x1080 layout
      local yb = math.min(1, CFG.gy_top * XF_REF.sy * (1080 / CFG.transform_ref_h) / 1080)
      if CFG.transform_scale ~= "height" then yb = math.min(1, CFG.gy_top * XF_REF.sy / 1080) end
      mig146 = { "3840x1080", { CFG.radar_cx, CFG.radar_cy / yb, CFG.radar_d / yb } }
    end
  else
    -- v1.4.2 migration, once: the old gui-unit area + radar_fx/fy/size -> screen fractions, keeping the radar where it
    -- is on screen now (through this resolution's transform)
    local SX, SY, GT = CFG.sx_scale, CFG.sy_scale, CFG.gy_top
    local x0, y0, x1, y1 = CFG.area_x0, CFG.area_y0, CFG.area_x1, CFG.area_y1
    local had = x1 > x0 and y1 > y0
    if not had then x0, x1, y1 = 0, CAL.bw, GT; y0 = GT - CAL.bh end
    local aw, ah = x1 - x0, y1 - y0
    local cgx, cgy = x0 + CFG.radar_fx * aw, y1 - CFG.radar_fy * ah
    local rpx = CFG.radar_size * ah * SY / 2
    CAL.cx, CAL.cy, CAL.d = cgx * SX / sw, (GT - cgy) * SY / sh, 2 * rpx / sh
    if not CFG.v146_migrated then mig146 = { res_key(sw, sh), { CAL.cx * sw / VP.w, CAL.cy * sh / VP.h, CAL.d * sh / VP.h } } end
    say(string.format("ini: v1.4.2 migration once: %s area + radar_fx %.2f radar_fy %.2f radar_size %.2f -> radar_cx %.4f radar_cy %.4f radar_d %.4f (at %dx%d)",
      had and "saved" or "default", CFG.radar_fx, CFG.radar_fy, CFG.radar_size, CAL.cx, CAL.cy, CAL.d, sw, sh))
    CFG.v142_migrated = true
    ini_save({ radar_cx = string.format("%.4f", CAL.cx), radar_cy = string.format("%.4f", CAL.cy), radar_d = string.format("%.4f", CAL.d),
      v142_migrated = "true", __order = { "radar_cx", "radar_cy", "radar_d", "v142_migrated" } })
  end
  if not CFG.v146_migrated then
    if mig146 and not LAYOUTS[mig146[1]] then LAYOUTS[mig146[1]] = mig146[2] end
    CFG.v146_migrated, CFG.radar_layouts = true, layouts_str()
    if ini_save({ radar_layouts = CFG.radar_layouts, v146_migrated = "true", __order = { "radar_layouts", "v146_migrated" }, __comment = { radar_layouts = LAYOUTS_COMMENT } }) then
      say(string.format("ini: v1.4.6 migration once: %s -> radar_layouts=%s", mig146 and string.format("radar_cx %.4f radar_cy %.4f radar_d %.4f as %s", CFG.radar_cx, CFG.radar_cy, CFG.radar_d, mig146[1]) or "no saved position", CFG.radar_layouts))
    end
  end
  layout_load(sw, sh, "load")
  sanity("load")
  CAL.on = CFG.calibrate; CAL.tab = "display"
  if not CFG.v132_migrated then                     -- v1.3.2: radar_aspect 1.0 (the old default) -> 1.25, once
    local old = CFG.radar_aspect
    local f = io.open(CFG_PATH, "r"); local txt = f and f:read("*a") or ""; if f then f:close() end
    local had = txt:match("\n%s*radar_aspect%s*=%s*([%d%.]+)") or txt:match("^%s*radar_aspect%s*=%s*([%d%.]+)")
    local kv = { v132_migrated = "true", __order = { "v132_migrated" } }
    if had and math.abs((tonumber(had) or 0) - 1.0) < 1e-6 then CFG.radar_aspect = 1.25; kv.radar_aspect = "1.25"; table.insert(kv.__order, 1, "radar_aspect") end
    CFG.v132_migrated = true
    if ini_save(kv) then say(string.format("ini: v1.3.2 migration once (radar_aspect %s -> %.2f)", tostring(had or "not set"), CFG.radar_aspect)) end
  end
  if not CFG.v144_migrated then                     -- v1.4.4: dots doubled; a saved small (which kept them small) -> medium, once
    local old = CFG.dot_size
    if old == "small" then CFG.dot_size = "medium" end
    CFG.v144_migrated = true
    if ini_save({ dot_size = CFG.dot_size, v144_migrated = "true", __order = { "dot_size", "v144_migrated" },
                  }) then
      say(string.format("ini: v1.4.4 migration once (dot_size %s -> %s, base dots 12/24/44/58 px)", old, CFG.dot_size))
    end
  end
  if not CFG.v145_migrated or CFG.visibility == "hud" then   -- v1.4.5: HUD mode dropped; hud / always -> shown, once
    local old = CFG.visibility
    if old ~= "hidden" then CFG.visibility = "shown" end
    CFG.v145_migrated = true
    if ini_save({ visibility = CFG.visibility, v145_migrated = "true", __order = { "visibility", "v145_migrated" }, __comment = { visibility = VIS_COMMENT } }) then
      say(string.format("ini: v1.4.5 migration once (visibility %s -> %s)", old, CFG.visibility))
    end
  end
  if not CFG.v110_migrated then                     -- v1.1: bar_debug off once in an older ini (nothing else touched)
    CFG.bar_debug, CFG.v110_migrated = false, true
    if ini_save({ bar_debug = "false", v110_migrated = "true", __order = { "bar_debug", "v110_migrated" } }) then
      say("ini: bar_debug set to false (v1.1 migration, once)")
    end
  end
  KEYNAMES.toggle = { tostring(CFG.toggle_key):lower() }
  say(string.format("drawable gui bounds: x 0..%.1f, y 0 (bottom, the game clips below) .. %.1f (top); toggle key %s",
    CAL.bw, CFG.gy_top, KEYNAMES.toggle[1]))
end
local function cal_log(why, sw, sh)
  local SX, SY, GT = CFG.sx_scale, CFG.sy_scale, CFG.gy_top
  local w, h = CAL.x1 - CAL.x0, CAL.y1 - CAL.y0
  say(string.format("radar %s: centre %.4f, %.4f of the drawable area, diameter %.4f of its height (%dx%d, drawable %dx%d, layout %s)", why, CAL.cx, CAL.cy, CAL.d, sw, sh, VP.w, VP.h, CAL.has_saved and "saved" or "not saved"))
  say(string.format("area %s: gui left %.1f right %.1f top %.1f bottom %.1f centre %.1f,%.1f width %.1f height %.1f scale %.3f",
    why, CAL.x0, CAL.x1, CAL.y1, CAL.y0, (CAL.x0 + CAL.x1) / 2, (CAL.y0 + CAL.y1) / 2, w, h, cal_scale()))
  say(string.format("area %s: screen px (transform %.4f/%.4f/%.1f, screen %dx%d, y from top) left %.0f right %.0f top %.0f bottom %.0f centre %.0f,%.0f width %.0f height %.0f",
    why, SX, SY, GT, sw, sh, CAL.x0 * SX, CAL.x1 * SX, (GT - CAL.y1) * SY, (GT - CAL.y0) * SY,
    (CAL.x0 + CAL.x1) / 2 * SX, (GT - (CAL.y0 + CAL.y1) / 2) * SY, w * SX, h * SY))
end
local function cal_save(why, sw, sh)
  cal_log(why, sw, sh)
  if CAL.pos_set and CAL.key then LAYOUTS[CAL.key] = { CAL.cx, CAL.cy, CAL.d }; CAL.has_saved = true end   -- (moved or resized here)
  CFG.radar_layouts = layouts_str()
  local kv = { calibrate = tostring(CAL.on), toggle_key = KEYNAMES.toggle[1], radar_layouts = CFG.radar_layouts, panel_fx = string.format("%.2f", CFG.panel_fx), panel_fy = string.format("%.2f", CFG.panel_fy),
               sensitivity = string.format("%.2f", CFG.sensitivity), repeat_rate = string.format("%.2f", CFG.repeat_rate), dot_size = CFG.dot_size, radar_color = CFG.radar_color, control = CFG.control, visibility = CFG.visibility,
               __order = { "calibrate", "toggle_key", "radar_layouts", "panel_fx", "panel_fy", "sensitivity", "repeat_rate", "dot_size", "radar_color", "control", "visibility" },
               __comment = { control = CONTROL_COMMENT, radar_color = COLOR_COMMENT, visibility = VIS_COMMENT, radar_layouts = LAYOUTS_COMMENT } }
  say("settings " .. why .. ": dot_size " .. CFG.dot_size .. ", radar_color " .. CFG.radar_color .. ", control " .. CFG.control .. ", visibility " .. CFG.visibility)
  say(string.format("settings %s: sensitivity %.2f (range %.0f m, gain x%.2f), repeat_rate %.2f (re-acquire %.2f s, hold %.2f s, fade %.2f s)",
    why, CFG.sensitivity, clamp(CFG.range * CFG.sensitivity, 10, 120), CFG.sensitivity, CFG.repeat_rate,
    0.5 / CFG.repeat_rate, 1.0 / CFG.repeat_rate, 1.5 / CFG.repeat_rate))
  if ini_save(kv) then say("ini: saved " .. why .. " (calibrate=" .. kv.calibrate .. ")") end
  CAL.dirty, CAL.last_save = false, S.t
end
-- the sliders, in gui units: stacked under the area's top edge, a fixed size so they stay usable at any scale.
-- 1 scale (cyan), 2 sensitivity (orange), 3 repeat_rate (magenta): yellow tick at 1.0; 4 dot_size (red): 3 snap positions, tick at medium.
local DOT_IDX_, DOT_NAMES_ = { small = 1, medium = 2, large = 3 }, { "small", "medium", "large" }
local SL = {
  { name = "scale", min = SMIN, max = SMAX, tick = D_DEF, rgb = { 0, 200, 255 }, get = function() return cal_scale() end, set = function(v) set_scale(v) end },
  { name = "sensitivity", min = 0.25, max = 3, rgb = { 255, 140, 0 }, get = function() return CFG.sensitivity end,
    set = function(v) CFG.sensitivity = clamp(v, 0.25, 3); CAL.dirty = true end },
  { name = "repeat_rate", min = 0.25, max = 3, rgb = { 220, 0, 255 }, get = function() return CFG.repeat_rate end,
    set = function(v) CFG.repeat_rate = clamp(v, 0.25, 3); CAL.dirty = true end },
  { name = "dot_size", min = 1, max = 3, tick = 2, rgb = { 255, 50, 50 }, get = function() return DOT_IDX_[CFG.dot_size] or 2 end,
    set = function(v) local n = DOT_NAMES_[clamp(math.floor(v + 0.5), 1, 3)]; if n ~= CFG.dot_size then CFG.dot_size = n; CAL.dirty = true end end },
  -- v1.5.1: 5 radar_color (white track): 5 snap positions, green white yellow red light_blue; the value is a colour swatch
  { name = "radar_color", min = 1, max = 5, tick = 1, rgb = { 230, 230, 230 }, get = function() return COLOR_IDX[CFG.radar_color] or 1 end,
    set = function(v) local n = COLOR_NAMES[clamp(math.floor(v + 0.5), 1, 5)]; if n ~= CFG.radar_color then CFG.radar_color = n; CAL.dirty = true; say("radar_color: " .. n) end end },
}
local function slider_rect(i)
  i = i or 1
  local w, h, sp = 600 / CFG.sx_scale, 16 / CFG.sy_scale, 50 / CFG.sy_scale
  -- v1.4.0: a fixed panel (panel_fx, panel_fy of the visible screen: its top-left corner), not tied to the radar's
  -- area, so dragging moves only the radar. The labels sit left of the tracks (room for the widest, 140 px).
  local vw, vtop, vbot = CAL.bw, CFG.gy_top, CFG.gy_top - CAL.bh
  local tx = (CAL.pfx or CFG.panel_fx) * vw + 150 / CFG.sx_scale
  local top = vtop - (CAL.pfy or CFG.panel_fy) * CAL.bh - 80 / CFG.sy_scale     -- (below the tab buttons)
  -- (the whole stack and its values kept on the visible screen)
  tx = clamp(tx, 150 / CFG.sx_scale, vw - w - 140 / CFG.sx_scale)
  top = clamp(top, math.max(vbot, 0) + h + #SL * sp + 102 / CFG.sy_scale, vtop - 20 / CFG.sy_scale)
  return tx, top - h - (i - 1) * sp, w, h
end
-- v1.4.5: the Shown / Hidden buttons (radio style, the chosen one lit), one row under the last slider, 200 x 48 px
local VIS_BTN = { { id = "shown", label = "vis_shown" }, { id = "hidden", label = "vis_hidden" } }
local function vis_rect(i)
  local tx, ty = slider_rect(#SL)
  local w, h = 200 / CFG.sx_scale, 48 / CFG.sy_scale
  return tx + (i - 1) * (w + 12 / CFG.sx_scale), ty - 50 / CFG.sy_scale - h / 2 + 8 / CFG.sy_scale, w, h
end
-- v1.5.4: the Controls buttons (keyboard / mouse, controller), one row under Shown / Hidden
local CTL_BTN = { { id = "keyboard_mouse", label = "ctl_kbm" }, { id = "controller", label = "ctl_pad" } }
local function ctl_rect(i)
  local x, y, w, h = vis_rect(i)
  return x, y - 62 / CFG.sy_scale, w, h
end
_G.SIXTH_SENSE_CTL = ctl_rect
_G.SIXTH_SENSE_VIS = vis_rect                     -- (read by the stub test)
_G.SIXTH_SENSE_SLIDER = slider_rect               -- (read by the stub test)
local function knob_x(tx, tw, i)
  local d = SL[i or 1]
  return tx + tw * (d.get() - d.min) / (d.max - d.min)
end
-- v1.4.0 tabs, fixed at the panel position: 1 Display (the radar: drag, wheel, arrows), 2 Settings (the sliders; the
-- radar shows as a preview and does not move). Buttons 200 x 48 screen px, 12 px apart.
local TABS = { { id = "display", label = "tab_display" }, { id = "settings", label = "tab_settings" } }
-- v1.4.2: button 3 is Reset (both tabs): one click arms it (lit 3 s), a second click within 3 s confirms. On Display it
-- puts the radar back (centred, 75% down, default size); on Settings it restores the slider defaults. Saved at once.
-- Moving (Display tab): drag the grab handle on the radar's top edge; drag a corner handle to resize; the wheel over
-- the radar resizes. Clicks elsewhere do nothing.
local function tab_rect(i)
  local vw, vtop = CAL.bw, CFG.gy_top
  local w, h = 200 / CFG.sx_scale, 48 / CFG.sy_scale
  local x = clamp((CAL.pfx or CFG.panel_fx) * vw, 0, vw - 4 * w - 48 / CFG.sx_scale)
  local top = clamp(vtop - (CAL.pfy or CFG.panel_fy) * CAL.bh, h, vtop)
  return x + (i - 1) * (w + 12 / CFG.sx_scale), top - h, w, h
end
-- the panel's bounding box (tabs, Move and the slider stack with labels and values), gui units
local function panel_box()
  local x0, y0, w, h = tab_rect(1)
  local x1, y1 = x0 + 4 * w + 60 / CFG.sx_scale, y0 + h
  for i = 1, #SL do
    local tx, ty, tw, th = slider_rect(i)
    x0 = math.min(x0, tx - 150 / CFG.sx_scale); x1 = math.max(x1, tx + tw + 140 / CFG.sx_scale)
    y0 = math.min(y0, ty - 12 / CFG.sy_scale); y1 = math.max(y1, ty + th + 12 / CFG.sy_scale)
  end
  for i = 1, #VIS_BTN do
    local x, y, w, h = vis_rect(i)
    x0 = math.min(x0, x - 150 / CFG.sx_scale); x1 = math.max(x1, x + w); y0 = math.min(y0, y - 12 / CFG.sy_scale)
    x, y, w, h = ctl_rect(i)
    x0 = math.min(x0, x - 150 / CFG.sx_scale); x1 = math.max(x1, x + w); y0 = math.min(y0, y - 12 / CFG.sy_scale)
  end
  return x0, y0, x1, y1
end
-- Auto-place (v1.4.1): the panel_fx/panel_fy spot unless the radar's area covers it; then the opposite vertical half,
-- then the other side, then both; else the spot with the least overlap. Run when the radar is dropped (not mid-drag),
-- when Move goes off, and when calibration opens.
local function panel_place(why)
  if not CAL.bw then return end
  local fx, fy = CFG.panel_fx, CFG.panel_fy
  local pw, ph
  do CAL.pfx, CAL.pfy = fx, fy; local a, b, c, d = panel_box(); pw, ph = (c - a) / CAL.bw, (d - b) / CAL.bh end
  local spots = { { fx, fy }, { fx, 1 - fy - ph }, { 1 - fx - pw, fy }, { 1 - fx - pw, 1 - fy - ph } }
  local best, bestov = 1, 1e18
  for i = 1, #spots do
    CAL.pfx, CAL.pfy = clamp(spots[i][1], 0, math.max(0, math.min(0.9, 1 - pw))), clamp(spots[i][2], 0, math.max(0, math.min(0.9, ybot() - ph)))   -- (v1.4.9: the whole panel fits)
    local a, b, c, d = panel_box()
    local ow = math.max(0, math.min(c, CAL.x1) - math.max(a, CAL.x0))
    local oh = math.max(0, math.min(d, CAL.y1) - math.max(b, CAL.y0))
    if ow * oh < bestov then best, bestov = i, ow * oh end
    if ow * oh <= 0 then break end
  end
  local nfx, nfy = clamp(spots[best][1], 0, math.max(0, math.min(0.9, 1 - pw))), clamp(spots[best][2], 0, math.max(0, math.min(0.9, ybot() - ph)))
  if nfx ~= CAL.lpfx or nfy ~= CAL.lpfy or (bestov > 0 and why ~= CAL.lpwhy) then
    CAL.lpwhy = bestov > 0 and why or nil
    say(string.format("panel: at %.2f, %.2f of the screen (%s; spot %d, overlap with the radar %s)", nfx, nfy, why or "-", best, bestov > 0 and "yes, least" or "none"))
  end
  CAL.pfx, CAL.pfy, CAL.lpfx, CAL.lpfy = nfx, nfy, nfx, nfy
end
_G.SIXTH_SENSE_TAB = function(i) if i then return tab_rect(i) end return CAL.tab end   -- (read by the stub test)
-- the grab handle: 44 x 44 screen px, centred on the radar's top edge, just inside it
local function grab_rect()
  local w, h = 44 / CFG.sx_scale, 44 / CFG.sy_scale
  return (CAL.x0 + CAL.x1) / 2 - w / 2, CAL.y1 - h, w, h
end
_G.SIXTH_SENSE_GRAB = grab_rect
_G.SIXTH_SENSE_PANEL = function() return CAL.pfx, CAL.pfy, panel_box() end
_G.SIXTH_SENSE_RESET = function() return CAL.armed ~= nil and S.t < CAL.armed end
local function reset_click(sw, sh)
  if CAL.armed and S.t < CAL.armed then
    CAL.armed = nil
    if CAL.tab == "settings" then
      CFG.sensitivity, CFG.repeat_rate, CFG.dot_size, CFG.radar_color, CFG.visibility = 1.0, 1.0, "medium", "green", "shown"; set_scale(D_DEF)   -- (control is kept)
      say("reset (Settings, confirmed): size, sensitivity, repeat_rate, dot_size, radar_color and visibility back to their defaults")
    else reset_pos("Display, confirmed") end
    cal_save("reset", sw, sh); panel_place("reset")
  else
    CAL.armed = S.t + 3
    say("reset: armed for 3 s (" .. CAL.tab .. "), click Reset again to confirm")
  end
end
-- one frame of calibration input (mx, my: the cursor in gui units)
-- v1.5.5 Help: button 4 on the F7 page (both tabs). The page texture fits the larger free part of the drawable area
-- above or below the panel's buttons, 4:3. Mouse: wheel or a click on the left / right half turns the page; a click
-- outside it, or on Help / Reset / a tab, closes it (Reset is not armed, nothing else changes).
local function help_rect()
  local vw, vtop, bh = CAL.bw, CFG.gy_top, CAL.bh
  local SX, SY = CFG.sx_scale, CFG.sy_scale
  local tx, ty, tw, th = tab_rect(1)
  local below = (ty - 60 / SY) - (vtop - bh)        -- (gui units: from the bottom of the drawable area to under the status line)
  local above = vtop - (ty + th + 16 / SY)
  local y0, room = vtop - bh + 10 / SY, below - 20 / SY
  if above > below then y0, room = ty + th + 16 / SY, above - 10 / SY end
  local hpx = math.max(room, 40 / SY) * SY
  local wpx = math.min(hpx * 4 / 3, vw * SX * 0.94)
  hpx = wpx * 3 / 4
  local w, h = wpx / SX, hpx / SY
  return vw / 2 - w / 2, y0 + (room - h) / 2, w, h, wpx, hpx
end
_G.SIXTH_SENSE_HELP = function() return CAL.help == true, CAL.hpage or 1, #HELP_PAGES end
_G.SIXTH_SENSE_HELP_RECT = help_rect
local function help_open(how)
  CAL.help, CAL.hpage, CAL.armed = true, CAL.hpage or 1, nil
  say(string.format("help: open (%s), page %d of %d", how, CAL.hpage, #HELP_PAGES))
end
local function help_close(how)
  if CAL.help then CAL.help = false; say("help: closed (" .. how .. ")") end
end
local function help_turn(d)
  local n = math.max(#HELP_PAGES, 1)
  CAL.hpage = clamp((CAL.hpage or 1) + d, 1, n)
end
local function help_mouse(gx, gy)
  if IN.wheel and IN.wheel ~= 0 then help_turn(IN.wheel > 0 and -1 or 1) end
  if not (gx and IN.lmb and not CAL.was_lmb) then return end
  for i = 1, 4 do
    local x, y, w, h = tab_rect(i)
    if gx >= x and gx <= x + w and gy >= y and gy <= y + h then
      help_close(i == 4 and "Help" or (i == 3 and "Reset area" or "tab"))
      if i <= #TABS and CAL.tab ~= TABS[i].id then CAL.tab = TABS[i].id; say("calibration tab: " .. CAL.tab) end
      CAL.drag = "tab"; return
    end
  end
  local x, y, w, h = help_rect()
  if gx >= x and gx <= x + w and gy >= y and gy <= y + h then help_turn(gx < x + w / 2 and -1 or 1)
  else help_close("click outside") end
  CAL.drag = "tab"
end
-- v1.5.4: one frame of the F7 page on the controller (the page open; see CONTROLS.md)
-- LB / RB: Display / Settings tab. X: Reset (twice within 3 s). B: close the page (saved).
-- Display: D-pad moves the radar (hold: repeats, faster after 1 s); Y bigger, A smaller (hold repeats).
-- Settings: D-pad up / down picks a row (the sliders, Visibility, Controls), left / right changes it.
local function pad_input(sw, sh)
  if CAL.armed and S.t >= CAL.armed then CAL.armed = nil end
  if PAD.pr.b and not CAL.help then
    CAL.on, CAL.armed, CAL.drag, CAL.help = false, nil, nil, false
    cal_save("calibration off (controller B)", sw, sh); return
  end
  if CAL.help then                                  -- v1.5.5: Help open: B / R3 close it, LB / RB or D-pad left / right turn pages
    if PAD.pr.b or PAD.pr.r3 then help_close(PAD.pr.b and "controller B" or "controller R3") return end
    if PAD.pr.lb or prep("left") then help_turn(-1) end
    if PAD.pr.rb or prep("right") then help_turn(1) end
    return
  end
  if PAD.pr.r3 then help_open("controller R3"); return end
  if PAD.pr.lb or PAD.pr.rb then
    CAL.armed = nil; CAL.tab = (CAL.tab == "settings") and "display" or "settings"; CAL.sel = CAL.sel or 1
    say("calibration tab: " .. CAL.tab .. " (controller)")
  end
  if PAD.pr.x then reset_click(sw, sh); return end
  if CAL.tab ~= "settings" then
    local moved = false
    for _, k in ipairs({ "left", "right", "up", "down" }) do
      if prep(k) then
        local st = (PAD.since[k] and S.t - PAD.since[k] > 1) and 20 or 4
        local dx = (k == "left" and -st) or (k == "right" and st) or 0
        local dy = (k == "up" and st) or (k == "down" and -st) or 0
        move_by(dx / CFG.sx_scale, dy / CFG.sy_scale); moved = true
      end
    end
    if prep("y") then set_scale(cal_scale() * 1.03); moved = true end
    if prep("a") then set_scale(cal_scale() / 1.03); moved = true end
    if moved then CAL.pad_moved = S.t end
    if CAL.pad_moved and S.t - CAL.pad_moved > 0.5 then       -- (let go: dropped, as with the mouse)
      CAL.pad_moved = nil; panel_place("radar dropped (controller)"); cal_save("dropped (controller)", sw, sh)
    end
    return
  end
  local rows = #SL + 2
  CAL.sel = clamp(CAL.sel or 1, 1, rows)
  if prep("up") then CAL.sel = (CAL.sel - 2) % rows + 1 end
  if prep("down") then CAL.sel = CAL.sel % rows + 1 end
  local dir = (prep("left") and -1 or 0) + (prep("right") and 1 or 0)
  if dir ~= 0 then
    local i = CAL.sel
    if i <= #SL then
      local d = SL[i]
      local snap = d.name == "dot_size" or d.name == "radar_color"
      local stp = snap and 1 or (d.max - d.min) / 40
      d.set(clamp(d.get() + dir * stp, d.min, d.max)); CAL.dirty = true
      if i == 1 then panel_place("size changed (controller)") end
    elseif i == #SL + 1 then
      local v = dir < 0 and "shown" or "hidden"
      if CFG.visibility ~= v then CFG.visibility = v; CAL.dirty = true; say("visibility: " .. v .. " (controller)") end
    else
      local v = dir < 0 and "keyboard_mouse" or "controller"
      if CFG.control ~= v then CFG.control = v; CAL.dirty = true; say("control: " .. v .. " (controller)") end
    end
  end
end
-- pretty-ui: the F7 panel's hit regions. Drawing registers each control (id + rect, optional padding);
-- input resolves the cursor against the last drawn list once and dispatches to action(id).
local RG = { list = {} }                             -- one local: the main chunk is near Lua's 200-local limit
function RG.add(id, x, y, w, h, px, py)
  px, py = px or 0, py or 0
  local L = RG.list
  L[#L + 1] = { id = id, x0 = x - px, y0 = y - py, x1 = x + w + px, y1 = y + h + py }
end
function RG.at(gx, gy)                     -- the last registered (topmost) region under the cursor
  if not gx then return nil end
  local L = RG.list
  for i = #L, 1, -1 do
    local r = L[i]
    if gx >= r.x0 and gx <= r.x1 and gy >= r.y0 and gy <= r.y1 then return r.id end
  end
end
function RG.action(id, sw, sh)                    -- one handler for every panel control; sets CAL.drag
  local kind, arg = id:match("^(%w+):?(.*)$")
  CAL.drag = "tab"
  if kind == "tab" then
    if CAL.tab ~= arg then CAL.armed = nil; CAL.tab = arg; say("calibration tab: " .. CAL.tab) end
  elseif kind == "reset" then reset_click(sw, sh)
  elseif kind == "help" then help_open("Help button")
  elseif kind == "vis" then
    if CFG.visibility ~= arg then CFG.visibility = arg; CAL.dirty = true; say("visibility: " .. CFG.visibility) end
  elseif kind == "ctl" then
    if CFG.control ~= arg then CFG.control = arg; CAL.dirty = true; say("control: " .. CFG.control .. " (mouse)") end
  elseif kind == "slider" then CAL.drag = tonumber(arg)
  else CAL.drag = nil end
end
local function cal_input(sw, sh, gx, gy)
  CAL.mgx, CAL.mgy = gx, gy                          -- pretty-ui: for hover
  CAL.hot = (CAL.on and not CAL.help) and RG.at(gx, gy) or nil
  if CAL.help then                                   -- v1.5.5: Help open: only the help's own clicks and the wheel
    if CAL.armed and S.t >= CAL.armed then CAL.armed = nil end
    help_mouse(gx, gy)
    if not IN.lmb and CAL.drag then CAL.drag = nil end
    CAL.was_lmb = IN.lmb; return
  end
  local sh_ = kdown("shift")
  local step = (sh_ and 20 or 2)
  local disp = CAL.tab ~= "settings"
  if CAL.armed and S.t >= CAL.armed then CAL.armed = nil end
  if disp then
  if krep("left") then move_by(-step / CFG.sx_scale, 0) end
  if krep("right") then move_by(step / CFG.sx_scale, 0) end
  if krep("up") then move_by(0, step / CFG.sy_scale) end
  if krep("down") then move_by(0, -step / CFG.sy_scale) end
  if IN.wheel and IN.wheel ~= 0 and gx and gx >= CAL.x0 and gx <= CAL.x1 and gy >= CAL.y0 and gy <= CAL.y1 then
    set_scale(cal_scale() * (1 + 0.02 * clamp(IN.wheel, -10, 10)))                          -- the wheel over the radar
  end
  end
  if not gx then return end
  if IN.lmb and not CAL.was_lmb then           -- the button went down: what is under the cursor?
    CAL.drag = nil
    if CAL.hot then RG.action(CAL.hot, sw, sh) end
    if not CAL.drag and disp then
      local x, y, w, h = grab_rect()
      local hw, hh = 40 / CFG.sx_scale, 40 / CFG.sy_scale
      local nearx = gx <= CAL.x0 + hw or gx >= CAL.x1 - hw
      local neary = gy <= CAL.y0 + hh or gy >= CAL.y1 - hh
      if gx >= x and gx <= x + w and gy >= y and gy <= y + h then CAL.drag = "move"; CAL.gx, CAL.gy = gx, gy
      elseif gx >= CAL.x0 and gx <= CAL.x1 and gy >= CAL.y0 and gy <= CAL.y1 and nearx and neary then CAL.drag = "resize" end
    end
  elseif not IN.lmb then
    if CAL.drag == "move" or CAL.drag == "resize" then panel_place("radar dropped"); cal_save("dropped", sw, sh)
    elseif CAL.drag == 1 then panel_place("size slider released") end
    CAL.drag = nil
  end
  CAL.was_lmb = IN.lmb
  if type(CAL.drag) == "number" then
    local d = SL[CAL.drag]
    local tx, _, tw = slider_rect(CAL.drag)
    local v = d.min + (d.max - d.min) * clamp((gx - tx) / tw, 0, 1)
    if math.abs(v - d.get()) > 1e-4 then d.set(v) end
  elseif CAL.drag == "move" then
    if gx ~= CAL.gx or gy ~= CAL.gy then move_by(gx - CAL.gx, gy - CAL.gy); CAL.gx, CAL.gy = gx, gy end
  elseif CAL.drag == "resize" then                      -- the corner follows the cursor (about the centre)
    local cxg, cyg = (CAL.x0 + CAL.x1) / 2, (CAL.y0 + CAL.y1) / 2
    local rpx = math.max(math.abs(gx - cxg) * CFG.sx_scale / CFG.radar_aspect, math.abs(gy - cyg) * CFG.sy_scale)
    local d = 2 * rpx / VP.h
    if math.abs(d - CAL.d) > 1e-6 then set_scale(d) end
  end
end
-- ---------------------------------------------------------------- the radar (v1.3)
-- Texture route (as Treasure Radar ships its textures): the disc is a texture in this mod's own patch
-- (mods/darryl/rear_heat_hud/radar_disc), drawn on its own screen GUI through a copy of the game's UI material
-- content/ui/shared/misc/yellow_logo (one texture slot): Gui.material + Material.set_texture, then Gui.bitmap.
-- Fallback: rect dots for the rim and rings, rect cross hairs. radar_style=auto|texture|dots.
local TEX_HEX, UI_MATERIAL, UI_SLOT = "03c798e2775e07a4", "e2d6ed90906c1e8b", "3aa8b87e00000000"
local TEX_RIM = 250 / 256                          -- the rim's radius in the texture, as a share of half its size
local DOT_MUL = { small = 0.75, medium = 1.0, large = 1.35 }
local DOT_NAMES = { "small", "medium", "large" }
local DOT_IDX = { small = 1, medium = 2, large = 3 }
local RAD = { tex = {}, info = {} }
_G.SIXTH_SENSE_RADAR = RAD.info                   -- (read by the stub test)
local function id64(h) return call("IdString64", "from_hex", h) end
-- One screen GUI per texture (as Chef Shared Loader does), its copy of the UI material bound to that texture once a
-- frame. The first draw of each texture is checked (Application.can_get) and logged; a texture that fails once is off
-- for the session and its caller draws its own fallback. GUIs are dropped untouched on a world change (RAD_RESET).
-- Size: Gui.bitmap's size comes out in screen px while its position follows the gui transform (v1.3 in game: the
-- disc drawn with gui-unit sizes was tall and skinny, 1.2/0.9333 = 1.29 too narrow). tex_size_px=false: v1.3's way.
local function tex_draw(hex, x, y, w, h, what, rgb)
  local st = RAD.tex[hex]
  if st == nil then st = { state = nil }; RAD.tex[hex] = st end
  if st.state == false then return false end
  local ok, err = pcall(function()
    if st.state == nil then
      local cg = fn("Application", "can_get")
      if not cg then error("no Application.can_get") end
      if cg("material", id64(UI_MATERIAL)) ~= true then error("the UI material yellow_logo is not loaded") end
      if cg("texture", id64(hex)) ~= true then error("texture " .. hex .. " is not loaded") end
    end
    if not st.gui then
      st.gui = fn("World", "create_screen_gui")(S.world, "immediate")
      if not st.gui then error("no screen GUI for the texture") end
    end
    if st.frame ~= S.frame then
      st.frame = S.frame
      local mh = fn("Gui", "material")(st.gui, id64(UI_MATERIAL))
      if not mh then error("Gui.material gave nothing") end
      fn("Material", "set_texture")(mh, id64(UI_SLOT), id64(hex))
    end
    fn("Gui", "bitmap")(st.gui, id64(UI_MATERIAL), ctor("Vector3", x, y, LAYER_NOW > 950 and 995 or 900), ctor("Vector2", w, h), ctor("Color", 255, rgb and rgb[1] or 255, rgb and rgb[2] or 255, rgb and rgb[3] or 255))
  end)
  if st.state == nil then
    say("bitmap " .. (what or hex) .. ": draw " .. (ok and "succeeded" or ("failed: " .. tostring(err) .. " -> fallback")))
    if what == "radar disc" then say("radar: texture bitmap draw " .. (ok and "succeeded (style texture)" or ("failed: " .. tostring(err) .. " -> rect dots"))) end
  end
  st.state = ok
  if not ok then st.err = tostring(err) end
  return ok
end
-- a texture centred at gui (cx, cy), wpx x hpx screen px
local function tex_centred(hex, cx, cy, wpx, hpx, what, rgb)
  local SX, SY = CFG.sx_scale, CFG.sy_scale
  local w, h = wpx, hpx
  if not CFG.tex_size_px then w, h = wpx / SX, hpx / SY end
  return tex_draw(hex, cx - wpx / 2 / SX, cy - hpx / 2 / SY, w, h, what, rgb)
end
local function ring(gbox, cx, cy, rx, ry, n, px, SX, SY, a, c)
  local w, h = px / SX, px / SY
  for k = 0, n - 1 do
    local t = k / n * 2 * math.pi
    gbox(cx + math.sin(t) * rx - w / 2, cy + math.cos(t) * ry - h / 2, w, h, a, c[1], c[2], c[3])
  end
end
-- (x, y) in the world -> radar gui point; f = share of the range (clamped to the rim), faded = beyond range
local function project(x, y, ox, oy, R)
  local dx, dy = x - ox, y - oy
  local fwd = dx * S.fx + dy * S.fy
  local right = dx * S.fy - dy * S.fx               -- the same right vector as bearing()
  if CFG.swap_sides then right = -right end
  local d = math.sqrt(dx * dx + dy * dy)
  local beyond = d > R
  if beyond and d > 0 then fwd, right = fwd * R / d, right * R / d end
  return right / R, fwd / R, beyond
end
local function draw_radar(gbox, ax0, ay0, aw, ah, SX, SY, sh, sc)
  local I = RAD.info
  local rpx = ah * SY / 2                           -- v1.4.2: the box is the radar's own (diameter = box height)
  local rx, ry = rpx / SX * CFG.radar_aspect, rpx / SY        -- (round on screen; radar_aspect trims the width)
  local cx, cy = ax0 + aw / 2, ay0 + ah / 2
  local R = clamp(CFG.range * CFG.sensitivity, 10, 120)
  local before = S.draw_ok + S.draw_fail
  local style = "dots"
  local PC = PALETTE[CFG.radar_color] or PALETTE.green
  local RC = PC.ring
  I.color = CFG.radar_color
  if CFG.radar_style ~= "dots" then
    local d = 2 * rpx / TEX_RIM                   -- the texture's size in screen px (its rim on the overlay's circle)
    if tex_centred(TEX_HEX, cx, cy, d * CFG.radar_aspect, d, "radar disc", RC) then style = "texture" end
  end
  if style == "dots" then
    local k = sh / 1080 * sc
    ring(gbox, cx, cy, rx, ry, 80, 4 * k, SX, SY, 220, RC)                        -- the rim
    ring(gbox, cx, cy, rx * 2 / 3, ry * 2 / 3, 48, 3 * k, SX, SY, 130, RC)        -- 2/3 of the range
    ring(gbox, cx, cy, rx / 3, ry / 3, 32, 3 * k, SX, SY, 130, RC)                -- 1/3
    gbox(cx - rx, cy - 1 * k / SY, 2 * rx, 2 * k / SY, 90, RC[1], RC[2], RC[3])      -- cross hairs
    gbox(cx - 1 * k / SX, cy - ry, 2 * k / SX, 2 * ry, 90, RC[1], RC[2], RC[3])
  end
  local k = sh / 1080 * sc
  gbox(cx - 5 * k / SX, cy - 5 * k / SY, 10 * k / SX, 10 * k / SY, 255, 255, 255, 255)   -- me, facing up
  gbox(cx - 2 * k / SX, cy + 5 * k / SY, 4 * k / SX, 6 * k / SY, 255, 255, 255, 255)     -- (a nose: up is where I look)
  local ndots = 0
  local ox, oy = S.px, S.py
  if S.bx then ox, oy = S.bx, S.by end
  if ox and S.fx then
    local base = (DOT_MUL[CFG.dot_size] or 1) * k
    local function dot(x, y, alpha, size, static)
      if ndots >= 150 then return end
      local fx, fy, beyond = project(x, y, ox, oy, R)
      local s = base * (CLASS_PX[size] or 24)
      local a = beyond and alpha * 0.4 or alpha
      local px, py = cx + fx * rx, cy + fy * ry
      if static then
        -- v1.4.0 enemy structure: a diamond (v1.5.3: the enemy dots' red, was orange) (three stacked bars: narrow, wide, narrow)
        local w, h = s / SX, s / SY
        gbox(px - w * 0.2, py + h * 0.2, w * 0.4, h * 0.3, a, 255, 40, 40)
        gbox(px - w * 0.5, py - h * 0.2, w, h * 0.4, a, 255, 40, 40)
        gbox(px - w * 0.2, py - h * 0.5, w * 0.4, h * 0.3, a, 255, 40, 40)
      else
        local w, h = s / SX, s / SY
        gbox(px - w / 2, py - h / 2, w, h, a, 255, 40, 40)   -- (v1.5.2: always red)
      end
      ndots = ndots + 1
    end
    for u, e in pairs(S.T) do if e.x and e.show then S.ghost[u] = nil; dot(e.x, e.y, 240, e.size, e.kind == "static") end end
    for u, g in pairs(S.ghost) do
      -- lost from tracking: hold 1 s / repeat_rate, fade 1.5 s / repeat_rate; dead: no hold, 0.3 s fade
      local hold, fade = 1.0 / CFG.repeat_rate, 1.5 / CFG.repeat_rate
      if g.dead then hold, fade = 0, 0.3 end
      local age = S.t - g.lost
      if age > hold + fade then S.ghost[u] = nil
      else dot(g.x, g.y, 200 * (age <= hold and 1 or (1 - (age - hold) / fade)), g.size, g.static) end
    end
  end
  I.cx, I.cy, I.rx, I.ry, I.R, I.style, I.dots = cx, cy, rx, ry, R, style, ndots
  I.rects = S.draw_ok + S.draw_fail - before
end
-- ---------------------------------------------------------------- slider labels (v1.3.1)
-- Labels: one texture per word (assets/label_*.png, Poppins Bold), drawn with the bitmap path the radar disc proved.
-- Values, and labels whose texture fails: a 5x7 pixel font made of rects (the call that always worked). No Gui.text:
-- in v0.3 the performance HUD font drew white blocks and the game crashed in the ship transition; working mods on this
-- game use a retained text GUI with the game's runtime font and its own material, which is a lot to get right blind.
local LABEL_TEX = {
  tab_reset = { 'a44a41940a973e9e', 104, 48 },
  tab_display = { '9b2fd888f42b0c0e', 132, 48 },
  tab_settings = { 'ad6b66f6687bfb85', 144, 48 },
  size = { '7c2ccf6a4c4cb0d5', 76, 48 },
  sensitivity = { '7a7091af0d8c0316', 180, 48 },
  repeat_rate = { 'ae02fd6005683294', 196, 48 },
  dot_size = { '8024c7d02d7bd868', 136, 48 },
  radar_color = { '05ff3e115296cc83', 196, 48 },
  controls = { '8e35a2efcf759a3e', 148, 48 },
  tab_help = { 'd57c2ed8109dc446', 88, 48 },
  ctl_kbm = { 'e034b5447cc4edd1', 192, 48 },
  ctl_pad = { 'c13ff984012bfdeb', 172, 48 },
  visibility = { '9f6f6ca838a05cdf', 152, 48 },
  vis_shown = { 'ebe63964e4089a54', 120, 48 },
  vis_hidden = { '5d673ce754dcc40d', 128, 48 },
}
local LABEL_WORD = { tab_reset = "RESET", tab_display = "DISPLAY", tab_settings = "SETTINGS", size = "SIZE", sensitivity = "SENSITIVITY", repeat_rate = "REPEAT RATE", dot_size = "DOT SIZE", radar_color = "RADAR COLOR", controls = "CONTROLS", tab_help = "HELP", ctl_kbm = "MOUSE", ctl_pad = "PAD", visibility = "VISIBILITY", vis_shown = "SHOWN", vis_hidden = "HIDDEN" }
local GLYPH = {
  ["0"] = "01110100011001110101110011000101110", ["1"] = "00100011000010000100001000010001110",
  ["2"] = "01110100010000100010001000100011111", ["3"] = "11110000010000101110000010000111110",
  ["4"] = "00010001100101010010111110001000010", ["5"] = "11111100001111000001000011000101110",
  ["6"] = "00110010001000011110100011000101110", ["7"] = "11111000010001000100010000100001000",
  ["8"] = "01110100011000101110100011000101110", ["9"] = "01110100011000101111000010001001100",
  ["."] = "00000000000000000000000000110001100", ["x"] = "00000000001000101010001000101010001",
  A = "01110100011000111111100011000110001", D = "11110100011000110001100011000111110",
  E = "11111100001000011110100001000011111", G = "01110100011000010111100011000101111",
  I = "01110001000010000100001000010001110", L = "10000100001000010000100001000011111",
  M = "10001110111010110101100011000110001", N = "10001110011010110011100011000110001",
  O = "01110100011000110001100011000101110", P = "11110100011000111110100001000010000",
  R = "11110100011000111110101001001010001", S = "01111100001000001110000010000111110",
  T = "11111001000010000100001000010000100", V = "10001100011000110001100010101000100",
  Y = "10001100010101000100001000010000100", Z = "11111000010001000100010001000011111",
  H = "10001100011000111111100011000110001", U = "10001100011000110001100011000101110",
  W = "10001100011000110101101011101110001", B = "11110100011000111110100011000111110",
  C = "01110100011000010000100001000101110", F = "11111100001000011110100001000010000",
  J = "00111000100001000010000101001001100", K = "10001100101010011000101001001010001",
  Q = "01110100011000110001101011001001101", X = "10001100010101000100010101000110001",
  [":"] = "00000011000110000000011000110000000", ["-"] = "00000000000000011111000000000000000",
  ["/"] = "00001000010001000100010001000010000", ["("] = "00010001000100001000010000010000010",
  [")"] = "01000001000001000010000100010001000",
  [" "] = "00000000000000000000000000000000000",
}
-- text in the pixel font, cell = px screen px; anchor: "left" (x is its left end) or "right"; (x, cy) in gui units.
-- One rect per run of lit cells in a row. Returns the rects drawn.
local function pixel_text(gbox, str, x, cy, px, anchor, a, r, g, b)
  local SX, SY = CFG.sx_scale, CFG.sy_scale
  local cw, ch = px / SX, px / SY
  local n = #str
  local width = (n * 6 - 1) * cw
  if anchor == "right" then x = x - width end
  local top = cy + 3.5 * ch
  local count = 0
  for i = 1, n do
    local ch_ = str:sub(i, i); local gl = GLYPH[ch_] or GLYPH[ch_:upper()] or GLYPH[" "]
    local gx = x + (i - 1) * 6 * cw
    for row = 0, 6 do
      local col = 0
      while col < 5 do
        if gl:sub(row * 5 + col + 1, row * 5 + col + 1) == "1" then
          local c2 = col
          while c2 + 1 < 5 and gl:sub(row * 5 + c2 + 2, row * 5 + c2 + 2) == "1" do c2 = c2 + 1 end
          gbox(gx + col * cw, top - (row + 1) * ch, (c2 - col + 1) * cw, ch, a, r, g, b)
          count = count + 1
          col = c2 + 1
        else col = col + 1 end
      end
    end
  end
  return count
end
local LABELS = { how = {} }
_G.SIXTH_SENSE_LABELS = LABELS.how                 -- (read by the stub test)
-- a slider's label, right-aligned to gui x, centred on gui cy, about 22 px tall at 1080
local function draw_label(gbox, key, x, cy, k)
  if CFG.label_style == "off" then return end
  local t = LABEL_TEX[key]
  if t and (CFG.label_style == "auto" or CFG.label_style == "texture") then
    local hpx = 30 * k
    local wpx = hpx * t[2] / t[3]
    if tex_centred(t[1], x - wpx / 2 / CFG.sx_scale, cy, wpx, hpx, "label " .. key) then LABELS.how[key] = "texture"; return end
  end
  pixel_text(gbox, LABEL_WORD[key] or key, x, cy, 2 * k, "right", 240, 255, 255, 255)
  LABELS.how[key] = "pixel"
end
local function slider_value(i)
  if i == 4 then return ({ "S", "M", "L" })[DOT_IDX[CFG.dot_size] or 2] end
  local d = SL[i]
  return string.format("%.2fx", d.get())
end
-- v1.4.5 visibility: shown or hidden (HUD mode was dropped: the game's HUD toggle could not be read)
local function radar_visible() return CFG.visibility ~= "hidden" end
RAD_RESET = function() for _, st in pairs(RAD.tex) do st.gui = nil end end   -- (the old world's GUI is dropped untouched)
local function draw()
  if not S.gui then
    if S.gui_tries >= 3 then return end
    S.gui_tries = S.gui_tries + 1
    S.gui = make_gui()
    if not S.gui then return end
  end
  local sw, sh = screen()
  -- ONE helper for everything: one call, rect(x, y, w, h, Color(a, r, g, b), 950), with whole numbers
  local function box(x, y, w, h, a, r, g, b)
    rect(math.floor(x), math.floor(y), math.floor(w), math.floor(h), ctor("Color", math.floor(clamp(a, 0, 255)),
      math.floor(clamp(r, 0, 255)), math.floor(clamp(g, 0, 255)), math.floor(clamp(b, 0, 255))), LAYER_NOW)
  end
  -- the screen transform (v0.9): (fx, fy) of the visible screen, fy from the top, w and h in screen px -> gui units.
  if not CAL.bw then cal_init(sw, sh) end
  local SX, SY, GT = CFG.sx_scale, CFG.sy_scale, CFG.gy_top
  if not S.xf_logged then
    S.xf_logged = true
    say(string.format("transform: screen %dx%d sx_scale %.4f sy_scale %.4f gy_top %.1f -> visible gui x 0..%.1f, y %.1f (top)..%.1f (bottom)",
      sw, sh, SX, SY, GT, sw / SX, GT, GT - sh / SY))
  end
  if not CAL.bw then cal_init(sw, sh) end
  if not IN.probed then probe() end
  -- v1.4.2: a resolution change (checked once a second): new transform, the radar kept at its screen fractions,
  -- clamped back in (reset if invalid), the panel re-placed
  if S.t >= (CAL.res_next or 0) then
    CAL.res_next = S.t + 1
    if sw ~= CAL.sw or sh ~= CAL.sh then
      local ow, oh = CAL.sw, CAL.sh
      if CAL.dirty then cal_save("before the resolution change", ow, oh) end   -- (the old resolution's layout kept)
      CAL.drag = nil
      apply_xf(sw, sh, string.format("resolution change from %dx%d", ow, oh))
      SX, SY = CFG.sx_scale, CFG.sy_scale
      viewport(sw, sh, string.format("resolution change from %dx%d", ow, oh))
      layout_load(sw, sh, "resolution change")
      sanity("resolution change"); panel_place("resolution change"); cal_save("resolution change", sw, sh)
      CAL.vp_next = S.t + 10
    elseif S.t >= (CAL.vp_next or 0) then             -- the render size can change without the window (Render Scale)
      CAL.vp_next = S.t + 10
      if viewport(sw, sh, "render size check") then sanity("render size change"); panel_place("render size change") end
    end
  end
  -- toggle_key (f7): calibration on/off (saved both ways)
  if CFG.control == "controller" then pad_frame() end
  local kbm = not use_pad()                          -- (v1.5.4: the F7 key and the mouse, unless a pad drives the page)
  if use_pad() then                                  -- View / Back / touchpad held 2 s: the page on / off; 5 s: layout reset
    local hv = PAD.since.view and S.t - PAD.since.view
    if not hv then CAL.pv_done, CAL.pv_reset = nil, nil end
    if hv and hv >= 2 and not CAL.pv_done then
      CAL.pv_done = true; CAL.on = not CAL.on; CAL.armed, CAL.drag, CAL.help = nil, nil, false
      if CAL.on then CAL.tab = "display"; panel_place("opened (controller)") end
      cal_save(CAL.on and "calibration on (controller View held 2 s)" or "calibration off (controller View held 2 s)", sw, sh)
    end
    if hv and hv >= 5 and not CAL.pv_reset then
      CAL.pv_reset = true
      CFG.panel_fx, CFG.panel_fy = 0.03, 0.08
      reset_pos("controller View held 5 s"); CAL.on, CAL.tab, CAL.drag = true, "display", nil
      panel_place("controller View held 5 s"); cal_save("layout reset (controller View held 5 s)", sw, sh)
    end
  end
  if kbm and kpressed("toggle") then
    CAL.on = not CAL.on
    CAL.armed, CAL.help = nil, false
    if not CAL.on then hold_give(); CAL.drag = nil else CAL.tab = "display"; panel_place("opened") end   -- (F7 opens on Display)
    cal_save((CAL.on and "calibration on (" or "calibration off (") .. KEYNAMES.toggle[1] .. ")", sw, sh)
  end
  -- panic recovery: F7 held 3 s resets the layout (radar and panel), calibration left on
  if kbm and kdown("toggle") then
    CAL.f7_t = CAL.f7_t or S.t
    if not CAL.f7_done and S.t - CAL.f7_t >= 3 then
      CAL.f7_done = true
      CFG.panel_fx, CFG.panel_fy = 0.03, 0.08
      reset_pos("F7 held 3 s"); CAL.on, CAL.tab, CAL.drag = true, "display", nil
      panel_place("F7 held 3 s"); cal_save("layout reset (F7 held 3 s)", sw, sh)
    end
  else CAL.f7_t, CAL.f7_done = nil, nil end
  local function gbox(x, y, w, h, a, r, g, b) box(x, y, w, h, a, r, g, b) end
  local gx, gy
  if CAL.on and not kbm then
    if IN.hold then hold_give() end
    pad_input(sw, sh)
    if CAL.dirty and S.t - CAL.last_save >= 0.5 then cal_save("changed", sw, sh) end
  elseif CAL.on then
    read_mouse(sw, sh)
    if IN.mx then gx, gy = IN.mx / SX, GT - IN.my / SY end
    cal_input(sw, sh, gx, gy)
    if CAL.dirty and S.t - CAL.last_save >= 0.5 then cal_save("changed", sw, sh) end
  elseif IN.hold then hold_give() end
  local ax0, ay0, ax1, ay1 = CAL.x0, CAL.y0, CAL.x1, CAL.y1
  local aw, ah = ax1 - ax0, ay1 - ay0
  local sc = CAL.d / D_DEF                          -- (dot and marker sizes follow the radar's size; 1 at the default)
  if CAL.on and not CAL.placed then CAL.placed = true; panel_place("start") end
  if CAL.on and CAL.tab ~= "settings" then
    local t1, t2 = 3 / SX, 3 / SY
    gbox(ax0, ay0, aw, ah, 45, 40, 120, 255)                                 -- the area, see-through blue
    gbox(ax0, ay1 - t2, aw, t2, 230, 255, 255, 255); gbox(ax0, ay0, aw, t2, 230, 255, 255, 255)
    gbox(ax0, ay0, t1, ah, 230, 255, 255, 255); gbox(ax1 - t1, ay0, t1, ah, 230, 255, 255, 255)
    local hw, hh = 40 / SX, 40 / SY                                          -- corner handles, 40 px
    gbox(ax0, ay1 - hh, hw, hh, 240, 255, 0, 0)                              -- top-left: red
    gbox(ax1 - hw, ay1 - hh, hw, hh, 240, 0, 255, 0)                         -- top-right: green
    gbox(ax0, ay0, hw, hh, 240, 0, 80, 255)                                  -- bottom-left: blue
    gbox(ax1 - hw, ay0, hw, hh, 240, 255, 255, 0)                            -- bottom-right: yellow
    local hx, hy, hw2, hh2 = grab_rect()                                    -- the grab handle: a 4-way arrow
    local mx, my = hx + hw2 / 2, hy + hh2 / 2
    gbox(hx, hy, hw2, hh2, 245, 20, 20, 30)
    gbox(mx - 16 / SX, my - 2 / SY, 32 / SX, 4 / SY, 255, 255, 255, 255); gbox(mx - 2 / SX, my - 16 / SY, 4 / SX, 32 / SY, 255, 255, 255, 255)
    for s = -1, 1, 2 do                                                      -- arrow heads
      gbox(mx + s * 14 / SX - 3 / SX, my - 6 / SY, 6 / SX, 12 / SY, 255, 255, 255, 255)
      gbox(mx - 6 / SX, my + s * 14 / SY - 3 / SY, 12 / SX, 6 / SY, 255, 255, 255, 255)
    end
  end
  -- the radar: replaces the bars (v1.3). v1.4.5: visibility (shown / hidden); the F7 page always shows it.
  if CAL.on or radar_visible() then draw_radar(gbox, ax0, ay0, aw, ah, SX, SY, sh, sc) end
  -- v1.4.1: the panel last and on a higher layer (rects 990, labels 995), so the radar never covers it
  if CAL.on then
    LAYER_NOW = 990
    local kk = sh / 1080
    local function ui(c, x, y, w, h) gbox(x, y, w, h, c[1], c[2], c[3], c[4]) end
    local function outline(c, x, y, w, h)
      local t1, t2 = 1 / SX, 1 / SY
      ui(c, x, y, w, t2); ui(c, x, y + h - t2, w, t2); ui(c, x, y, t1, h); ui(c, x + w - t1, y, t1, h)
    end
    RG.list = {}
    local function ui_button(id, x, y, w, h, label, on)  -- off / hover / on, with a border and an accent stripe when on
      RG.add(id, x, y, w, h)
      ui(on and UI.selected or (CAL.hot == id and UI.hover or UI.btn), x, y, w, h)
      outline(on and UI.accent or UI.border, x, y, w, h)
      if on then ui(UI.accent, x, y, w, 4 / SY) end
      draw_label(gbox, label, x + w / 2 + (LABEL_TEX[label][2] * 30 / 48 * kk) / 2 / SX, y + h / 2, kk)
    end
    local px0, py0, px1, py1 = panel_box()
    if CAL.tab == "settings" then ui(UI.bg, px0, py0, px1 - px0, py1 - py0); outline(UI.border, px0, py0, px1 - px0, py1 - py0)   -- a dark backing
    else
      local x, y, w, h = tab_rect(1); ui(UI.bg, x - 6 / SX, y - 48 / SY, 4 * w + 72 / SX, h + 54 / SY)
      -- v1.4.6: this resolution and whether it has a saved layout (green) or not yet (amber)
      local txt = string.format("%dx%d %s", CAL.sw or 0, CAL.sh or 0, CAL.has_saved and "SAVED LAYOUT" or "NO SAVED LAYOUT")
      CAL.status = txt
      if CAL.has_saved then pixel_text(gbox, txt, x, y - 22 / SY, 2 * kk, "left", 240, 80, 255, 120)
      else pixel_text(gbox, txt, x, y - 22 / SY, 2 * kk, "left", 240, 255, 190, 60) end
    end
    local function button(i, id, label, on)
      local x, y, w, h = tab_rect(i)
      ui_button(id, x, y, w, h, label, on)
    end
    if CAL.help then                                                         -- v1.5.5: the help page (under the buttons)
      local hx, hy, hw, hh, wpx, hpx = help_rect()
      local pg = HELP_PAGES[CAL.hpage or 1]
      ui(UI.panel, hx - 6 / SX, hy - 6 / SY, hw + 12 / SX, hh + 12 / SY)
      if pg and tex_centred(pg[1], hx + hw / 2, hy + hh / 2, wpx, hpx, "help page") then CAL.help_drawn = (CAL.help_drawn or 0) + 1
      else pixel_text(gbox, "HELP: SEE README.MD AND CONTROLS.MD", hx + 20 / SX, hy + hh / 2, 3 * kk, "left", 255, 255, 255, 255) end
    end
    for i = 1, #TABS do button(i, "tab:" .. TABS[i].id, TABS[i].label, CAL.tab == TABS[i].id and not CAL.help) end   -- the tab buttons; the active one lit
    button(3, "reset", "tab_reset", CAL.armed ~= nil and S.t < CAL.armed)              -- Reset (both tabs), lit while armed
    button(4, "help", "tab_help", CAL.help == true)                                   -- v1.5.5: Help, lit while open
    if CAL.tab == "settings" and not CAL.help then
    for i = 1, #SL do                                                        -- the sliders: track, fill, knob, tick at 1.0
      local d = SL[i]
      local tx, ty, tw, th = slider_rect(i)
      RG.add("slider:" .. i, tx, ty, tw, th, 15, 12)                -- padded hit area
      ui(UI.track, tx, ty, tw, th); outline(UI.border, tx, ty, tw, th)
      local kx = knob_x(tx, tw, i)
      ui(UI.accent, tx, ty, kx - tx, th)
      local kc = CAL.drag == i and UI.knob_drag or UI.knob
      ui(UI.border, kx - 11 / SX, ty - 11 / SY, 22 / SX, th + 22 / SY); ui(kc, kx - 10 / SX, ty - 10 / SY, 20 / SX, th + 20 / SY)
      local one = tx + tw * ((d.tick or 1) - d.min) / (d.max - d.min)
      local k = sh / 1080
      draw_label(gbox, d.name == "scale" and "size" or d.name, tx - 16 / SX, ty + th / 2, k)
      if d.name == "radar_color" then                                     -- v1.5.1: a swatch of the colour
        local c = (PALETTE[CFG.radar_color] or PALETTE.green)
        gbox(tx + tw + 18 / SX, ty + th / 2 - 14 / SY, 56 / SX, 28 / SY, 255, c.ring[1], c.ring[2], c.ring[3])
      else
      pixel_text(gbox, slider_value(i), tx + tw + 18 / SX, ty + th / 2, 2 * k, "left", UI.text[1], UI.text[2], UI.text[3], UI.text[4])
      end
      ui(UI.tick, one - 1 / SX, ty - 6 / SY, 2 / SX, th + 12 / SY)
    end
    do                                                                       -- v1.4.5: Shown / Hidden buttons
      local x1_, y1_, w1_, h1_ = vis_rect(1)
      draw_label(gbox, "visibility", x1_ - 16 / SX, y1_ + h1_ / 2, kk)
      for i = 1, #VIS_BTN do
        local x, y, w, h = vis_rect(i)
        local on = CFG.visibility == VIS_BTN[i].id
        ui_button("vis:" .. VIS_BTN[i].id, x, y, w, h, VIS_BTN[i].label, on)
      end
    end
    do                                                                       -- v1.5.4: Controls buttons
      local x1_, y1_, w1_, h1_ = ctl_rect(1)
      draw_label(gbox, "controls", x1_ - 16 / SX, y1_ + h1_ / 2, kk)
      for i = 1, #CTL_BTN do
        local x, y, w, h = ctl_rect(i)
        local on = CFG.control == CTL_BTN[i].id
        ui_button("ctl:" .. CTL_BTN[i].id, x, y, w, h, CTL_BTN[i].label, on)
      end
    end
    if not kbm then                                                          -- v1.5.4: the controller's row, framed yellow
      local i, x, y, w, h = CAL.sel or 1
      if i <= #SL then x, y, w, h = slider_rect(i); x, y, w, h = x - 20 / SX, y - 16 / SY, w + 40 / SX, h + 32 / SY
      else
        local f = (i == #SL + 1) and vis_rect or ctl_rect
        local xa, ya, wa, ha = f(1); local xb, _, wb = f(2)
        x, y, w, h = xa - 6 / SX, ya - 6 / SY, xb + wb - xa + 12 / SX, ha + 12 / SY
      end
      local t1, t2 = 3 / SX, 3 / SY
      ui(UI.focus, x, y, w, t2); ui(UI.focus, x, y + h - t2, w, t2)
      ui(UI.focus, x, y, t1, h); ui(UI.focus, x + w - t1, y, t1, h)
      CAL.sel_drawn = (CAL.sel_drawn or 0) + 1
    end
    end
    LAYER_NOW = 950
  end
  if S.rect_logs < 3 and RAD.info.rx then           -- (v1.4.4: not until the radar has been drawn once)
    local I = RAD.info
    say(string.format("radar: style %s, centre gui %.0f,%.0f radius gui %.0f x %.0f (screen %.0f px), range %.0f m, dot_size %s, rects %d, dots %d",
      I.style, I.cx, I.cy, I.rx, I.ry, I.rx * SX, I.R, CFG.dot_size, I.rects, I.dots))
  end
  if CAL.on and gx then                                                      -- my cursor: 12 px white square, black edge
    LAYER_NOW = 999
    gbox(gx - 8 / SX, gy - 8 / SY, 16 / SX, 16 / SY, 255, 0, 0, 0)
    gbox(gx - 6 / SX, gy - 6 / SY, 12 / SX, 12 / SY, 255, 255, 255, 255)
    LAYER_NOW = 950
  end
  if S.rect_logs == 0 then
    local function q(label, ...) local ok, a, b, c = pcall(...); say(string.format("res query %s -> %s %s %s %s", label, tostring(ok), tostring(a), tostring(b), tostring(c))) end
    local function f(nsn, n) return fn(nsn, n) or function() return "absent" end end
    q("Application.back_buffer_size", f("Application", "back_buffer_size"))
    q("Application.resolution", f("Application", "resolution"))
    q("Gui.resolution(gui)", f("Gui", "resolution"), S.gui)
    q("Window.get_resolution", f("Window", "get_resolution"))
    q("Window.size", f("Window", "size"))
    local function dump(label, t, depth)
      if type(t) ~= "table" then say("res " .. label .. " = " .. tostring(t)); return end
      local n = 0
      for k, v in pairs(t) do
        n = n + 1; if n > 60 then say("res " .. label .. " ... (more)"); break end
        if type(v) == "table" and depth < 2 then dump(label .. "." .. tostring(k), v, depth + 1)
        else say("res " .. label .. "." .. tostring(k) .. " = " .. tostring(v)) end
      end
      if n == 0 then say("res " .. label .. " = {} (empty)") end
    end
    for _, key in ipairs({ "screen_resolution", "render_settings", "fullscreen", "fullscreen_output", "window_mode",
                           "borderless_fullscreen", "aspect_ratio", "render_scale", "hud_scale" }) do
      local ok, v = pcall(f("Application", "user_setting"), key)
      if ok then dump("user_setting " .. key, v, 0) else say("res user_setting " .. key .. " error " .. tostring(v)) end
    end
    local gr = fn("Gui", "resolution")
    if gr then local ok, a, b = pcall(gr, S.gui); say("res Gui.resolution types: " .. type(a) .. " " .. type(b)) end
    local RL = rawget(_G, "RESOLUTION_LOOKUP")
    if type(RL) == "table" then
      for k, v in pairs(RL) do say("res RESOLUTION_LOOKUP." .. tostring(k) .. " = " .. tostring(v)) end
    else say("res RESOLUTION_LOOKUP: " .. type(RL)) end
  end
  if S.rect_logs < 3 then S.rect_logs = S.rect_logs + 1 end
end

-- ---------------------------------------------------------------- per frame
local next_threat, next_scan_log, first_draw_logs = 0, 0, 0
local function step(dt)
  dt = (type(dt) == "number" and dt > 0 and dt < 1) and dt or 0.016
  S.t = S.t + dt
  S.dt = dt
  S.frame = (S.frame or 0) + 1
  local w = pick_world()
  if w == nil then return end
  if w ~= S.world then reset(w); say("world changed") end
  -- a world whose clock went backwards was replaced in place: start over
  local wt = call("World", "time", w)
  if type(wt) == "number" then
    if S.wtime and wt + 0.5 < S.wtime then reset(w); say("world clock went back: treated as a new world") end
    S.wtime = wt
  end
  if S.t < (S.settle_until or 0) then return end   -- no unit calls and no drawing while a world settles
  read_camera(w)
  if S.body then
    if call("Unit", "alive", S.body) == true then S.bx, S.by = pos(S.body) else S.body, S.bx = nil, nil end
  end
  walk(w)
  if S.t >= S.next_known then S.next_known = S.t + 0.5 / CFG.repeat_rate; known_pass(w) end
  threat()
  smooth(dt)
  local before_ok, before_fail = S.draw_ok, S.draw_fail
  draw()
  if first_draw_logs < 3 and S.gui then
    first_draw_logs = first_draw_logs + 1
    local sw, sh = screen()
    say(string.format("draw frame %d: gui %s via %s, screen %dx%d, rects ok %d failed %d, last error %s,",
      first_draw_logs, tostring(S.gui), tostring(S.gui_how), sw, sh, S.draw_ok - before_ok, S.draw_fail - before_fail,
      tostring(S.draw_err)))
  end
  if S.t >= next_scan_log then
    next_scan_log = S.t + 5
    local nd = 0
    for _, e in pairs(S.T) do if e.d and e.d < CFG.range then nd = nd + 1 end end
    local n = S.nearest
    local nearest = n and string.format("nearest %s %s%s %.1fm bearing %+.0f (%s) -> %s", n.hex, n.kind, NAME[n.hex] and (" " .. NAME[n.hex]) or "",
      n.d, n.b or 0, (n.b or 0) >= 0 and "right" or "left", n.s and ("bar " .. BAR_NAME[n.s]) or "front, no bar") or "nearest none in range"
    say(string.format("scan: cam %s | tracked known %d candidates %d (within %dm %d) | %s | threat L %.2f C %.2f R %.2f | heat L %.2f C %.2f R %.2f | radar %s rects/frame %s dots %s | draws ok %d failed %d%s",
      S.px and string.format("%.0f,%.0f fwd %.2f,%.2f", S.px, S.py, S.fx, S.fy) or "none", S.nknown, S.ntracked, CFG.range, nd, nearest,
      S.target[1], S.target[2], S.target[3], S.heat[1], S.heat[2], S.heat[3], tostring(RAD.info.style), tostring(RAD.info.rects), tostring(RAD.info.dots), S.draw_ok, S.draw_fail,
      S.draw_err and (" last error: " .. S.draw_err) or ""))
  end
end

local inner_update = rawget(_G, "update")
_G.update = function(...)
  local r1, r2
  if inner_update then r1, r2 = inner_update(...) end
  if S.fails < 50 then
    local ok, err = pcall(step, (...))
    if not ok then
      S.fails = S.fails + 1
      if S.fails <= 5 then say("error: " .. tostring(err)) end
      if S.fails == 50 then say("50 errors: HUD stopped for this launch") end
    end
  end
  return r1, r2
end
local inner_shutdown = rawget(_G, "shutdown")
_G.shutdown = function(...)
  pcall(hold_give)
  pcall(function() if logf then logf:close(); logf = nil end end)
  if inner_shutdown then return inner_shutdown(...) end
end
local nk = 0; for _ in pairs(TIER) do nk = nk + 1 end
say(string.format("Sixth Sense %s loaded: detect=%s discovery=%s range %d, %d known enemy kinds", VERSION, CFG.detect, tostring(CFG.discovery), CFG.range, nk))
say("LOCALAPPDATA = " .. tostring(os.getenv("LOCALAPPDATA")) .. " | APPDATA = " .. tostring(os.getenv("APPDATA")))
say("ini: " .. CFG_PATH .. " (" .. tostring(cfg_state) .. ")")
if cfg_copied then say(string.format("ini: settings copied from %s (%d bytes, first load as Sixth Sense)", OLD_CFG_PATH, cfg_copied)) end
say("discovery summary: " .. SUMMARY_PATH)
return true
