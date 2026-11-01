-- HD2-Addon: mods/darryl/rear_heat_hud
-- Rear Heat HUD v1.0 for Bingus Shared Loader (HellForge, game build 25480438, LuaJIT).
-- Three bars at the bottom (left-rear, rear, right-rear) glow clear -> yellow -> red with the threat behind you.
-- v0.2: enemies are found by walking World.units and reading each unit's resource id (no World.units_by_resource),
-- a discovery mode logs every unit kind near you, and an optional "candidate enemy" heuristic works without a list.
-- Read-only: it changes nothing in the game.

local MOD, VERSION = "rear_heat_hud", "1.0.0"
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
local CFG = { range = 40, opacity = 0.85, position = "bottom", sx_scale = 1.2, sy_scale = 0.9333, gy_top = 1080, calibrate = true, cursor_flip_y = false, area_x0 = 0, area_y0 = 0, area_x1 = 0, area_y1 = 0, area_scale = 1, bars_fx = 0.5, bars_fy = 0.85, bar_debug = true, layer = 950,  size = 1.0, swap_sides = false,
              detect = "both", discovery = true, discovery_static = false, discovery_range = 80, candidate_weight = 1.5,
              debug = false }
local CFG_TEXT = [[
; Rear Heat HUD v1.0 settings. Edit, save, restart the game.
; range: metres (10-100). opacity: 0.1-1. position: bottom or top.
; size: 0.5-2. swap_sides: true if left/right look mirrored.
; detect: list (known enemy ids only), candidates (moving animated units that are not you), or both.
; discovery: true logs every unit kind near you every 5 s and writes rear_heat_hud_discovery.txt.
; discovery_static: true also measures units without animation (structures; slower). discovery_range: metres.
; candidate_weight: threat of one candidate enemy (a light enemy is 1).
; Note v0.2 ini files are kept as they are; delete rear_heat_hud.ini to get the new keys written.
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
; calibrate: true shows the placement area (drag it, scale it with the slider/wheel/+/-; F8 saves and hides it).
; F8 also turns it back on in game. cursor_flip_y: true if the drawn cursor moves opposite to the mouse vertically.
calibrate=true
cursor_flip_y=false
; The placement area in gui units (x0 left, x1 right, y0 bottom, y1 top; gui y runs up), written by calibration.
; All 0 = not calibrated yet (starts as the full screen from the transform). area_scale is derived (width / screen width).
area_x0=0
area_y0=0
area_x1=0
area_y1=0
area_scale=1
; bars_fx, bars_fy: where the bars' centre sits in the area, as fractions (fy from the area's top). No recalibration needed.
bars_fx=0.5
bars_fy=0.85
; bar_debug: true draws every bar half full in grey-yellow so you can see where they are (set false for real use).
bar_debug=true
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
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
local cfg_state
do
  local f = io.open(CFG_PATH, "r")
  if not f then
    local w = io.open(CFG_PATH, "w")
    if w then w:write(CFG_TEXT); w:close(); cfg_state = "written with defaults" else cfg_state = "could not be written" end
  else
    for line in f:lines() do
      local k, v = line:match("^%s*([%w_]+)%s*=%s*([^;%s]+)")
      if k and CFG[k] ~= nil then
        if type(CFG[k]) == "number" then CFG[k] = tonumber(v) or CFG[k]
        elseif type(CFG[k]) == "boolean" then CFG[k] = (v == "true" or v == "1")
        else CFG[k] = v end
      end
    end
    f:close(); cfg_state = "read"
  end
  CFG.range = clamp(CFG.range, 10, 100); CFG.opacity = clamp(CFG.opacity, 0.1, 1)
  CFG.bars_fx = clamp(CFG.bars_fx, 0, 1); CFG.bars_fy = clamp(CFG.bars_fy, 0, 1); CFG.size = clamp(CFG.size, 0.5, 2)
  if CFG.sx_scale <= 0 then CFG.sx_scale = 1.2 end; if CFG.sy_scale <= 0 then CFG.sy_scale = 0.9333 end
  CFG.discovery_range = clamp(CFG.discovery_range, 10, 300); CFG.candidate_weight = clamp(CFG.candidate_weight, 0, 10)
  if CFG.detect ~= "list" and CFG.detect ~= "candidates" then CFG.detect = "both" end
end

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
            target = { 0, 0, 0 }, heat = { 0, 0, 0 }, fails = 0,
            px = nil, py = nil, pz = nil, fx = 0, fy = 1,
            list = nil, li = 0, pass_started = 0,           -- the World.units walk, spread over frames
            info = {},                                      -- unit -> { hex, asm, x, y, t } (this world only)
            tracked = {}, ntracked = 0,                     -- array of { u, w (weight) } from the last full pass
            build = {}, nbuild = 0, pass = {},              -- the pass being built; per-hex stats of this pass
            totals = {}, combat_scans = 0, known = {}, nknown = 0, next_known = 0, body = nil,
            draw_ok = 0, draw_fail = 0, rect_logs = 0, draw_err = nil, gui_how = nil, gui_tries = 0, text_ok = 0, text_err = nil, next_summary = 0, next_disc = 0, passes = 0, ubr_tested = false }
local function reset(w)
  -- The old GUI is dropped without being touched: a GUI used (or destroyed) after its world went away crashes the
  -- game (Treasure Radar's loader drops it the same way). The world's units are forgotten too.
  S.world, S.cam_unit, S.gui, S.cam_retry = w, nil, nil, 0
  S.list, S.li, S.info, S.tracked, S.ntracked, S.build, S.nbuild, S.pass = nil, 0, {}, {}, 0, {}, 0, {}
  S.known, S.nknown, S.body, S.gui_tries = {}, 0, nil, 0
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
local function visit(u)
  if call("Unit", "alive", u) ~= true then return end
  local inf = S.info[u]
  if not inf then
    local h = hex_of(u)
    if not h then return end
    inf = { hex = h, asm = nil }
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
  -- Positions only for: known enemies, animated units (candidates), and in discovery any other unit file.
  if not (known or asm or (CFG.discovery and CFG.discovery_static)) then return end
  if not S.px then return end
  local x, y, z = pos(u)
  if not x then return end
  local dx, dy = x - S.px, y - S.py
  local d = math.sqrt(dx * dx + dy * dy)
  if d < st.dmin then st.dmin = d end
  if d <= CFG.discovery_range then st.near = st.near + 1 end
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
  if weight then S.nbuild = S.nbuild + 1; S.build[S.nbuild] = { u = u, w = weight, hex = h } end
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
  S.tracked, S.ntracked, S.build, S.nbuild = S.build, S.nbuild, {}, 0
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
      f:write(string.format("Rear Heat HUD %s discovery summary, %s\n", VERSION, os.date("%Y-%m-%d %H:%M:%S")))
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

-- ---------------------------------------------------------------- known enemies, 4 times a second
-- A fresh IdString64 every time: v0.1 made them once and kept them across frames, and saw 0 enemies all mission,
-- while v0.2's check with a fresh one found units. (Engine values don't outlive their frame: Chef Shared Loader's docs.)
local function known_pass(w)
  if CFG.detect == "candidates" then S.nknown = 0; return end
  local list, n = S.known, 0
  for i = 1, #KNOWN_HEX do
    local id = call("IdString64", "from_hex", KNOWN_HEX[i])
    local us = id and call("World", "units_by_resource", w, id)
    if type(us) == "table" then
      for j = 1, #us do
        local u = us[j]
        if n < 200 and call("Unit", "alive", u) == true and call("Unit", "has_animation_state_machine", u) == true then
          n = n + 1; list[n] = { u = u, w = TIER_WEIGHT[KNOWN_TIER[i]], hex = KNOWN_HEX[i] }
        end
      end
    end
  end
  for i = n + 1, S.nknown do list[i] = nil end
  S.nknown = n
end

-- ---------------------------------------------------------------- threat from the tracked list (about 10 times a second)
local REAR, MID = math.rad(100), math.rad(150)
local function threat()
  local t1, t2, t3 = 0, 0, 0
  if S.px then
    local R = CFG.range
    local nk = S.nknown
    for i = 1, nk + S.ntracked do
      local e = (i <= nk) and S.known[i] or S.tracked[i - nk]
      if call("Unit", "alive", e.u) == true and call("Unit", "has_animation_state_machine", e.u) == true then
        local x, y = pos(e.u)
        if x then
          local dx, dy = x - S.px, y - S.py
          local d = math.sqrt(dx * dx + dy * dy)
          if d < R and d > 0.5 then
            local a = math.atan2(S.fx * dy - S.fy * dx, dx * S.fx + dy * S.fy)
            if CFG.swap_sides then a = -a end
            local aa = math.abs(a)
            if aa > REAR then
              local k = 1 - d / R
              local v = e.w * (0.25 + 0.75 * k * k)
              if aa >= MID then t2 = t2 + v elseif a > 0 then t1 = t1 + v else t3 = t3 + v end
            end
          end
        end
      end
    end
  end
  S.target[1], S.target[2], S.target[3] = t1, t2, t3
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
local KEYNAMES = { toggle = { "f8" }, left = { "left", "numpad 4" }, right = { "right", "numpad 6" },
                   up = { "up", "numpad 8" }, down = { "down", "numpad 2" }, shift = { "left shift", "right shift" },
                   plus = { "numpad +", "=", "+" }, minus = { "numpad -", "-" } }
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
  for _, k in ipairs(kv.__order) do if not seen[k] then lines[#lines + 1] = k .. "=" .. kv[k] end end
  local w = io.open(CFG_PATH, "w")
  if not w then say("ini: could not be written"); return false end
  w:write(table.concat(lines, "\n"), "\n"); w:close()
  return true
end
-- the placement area, in gui units (gui y runs up: y1 is the top edge, y0 the bottom)
local CAL = { x0 = nil, y0 = nil, x1 = nil, y1 = nil, bw = nil, bh = nil, drag = nil, dirty = false, last_save = -1, on = false }
_G.REAR_HEAT_HUD_CAL = CAL                          -- (read by the stub test)
local SMIN, SMAX = 0.25, 2.5
local function cal_scale() return (CAL.x1 - CAL.x0) / CAL.bw end
local function set_scale(s)
  s = clamp(s, SMIN, SMAX)
  local cx, cy = (CAL.x0 + CAL.x1) / 2, (CAL.y0 + CAL.y1) / 2
  local w, h = CAL.bw * s, CAL.bh * s
  CAL.x0, CAL.x1, CAL.y0, CAL.y1 = cx - w / 2, cx + w / 2, cy - h / 2, cy + h / 2
  CAL.dirty = true
end
local function move_by(dx, dy)
  CAL.x0, CAL.x1, CAL.y0, CAL.y1 = CAL.x0 + dx, CAL.x1 + dx, CAL.y0 + dy, CAL.y1 + dy
  CAL.dirty = true
end
local function cal_init(sw, sh)
  CAL.bw, CAL.bh = sw / CFG.sx_scale, sh / CFG.sy_scale
  if CFG.area_x1 > CFG.area_x0 and CFG.area_y1 > CFG.area_y0 then
    CAL.x0, CAL.y0, CAL.x1, CAL.y1 = CFG.area_x0, CFG.area_y0, CFG.area_x1, CFG.area_y1
    say(string.format("area: loaded from the ini (scale %.3f)", cal_scale()))
  else
    CAL.x0, CAL.x1, CAL.y1 = 0, CAL.bw, CFG.gy_top
    CAL.y0 = CFG.gy_top - CAL.bh
    say("area: none saved, starting from the sx_scale/sy_scale/gy_top transform (full screen)")
  end
  CAL.on = CFG.calibrate
end
local function cal_log(why, sw, sh)
  local SX, SY, GT = CFG.sx_scale, CFG.sy_scale, CFG.gy_top
  local w, h = CAL.x1 - CAL.x0, CAL.y1 - CAL.y0
  say(string.format("area %s: gui left %.1f right %.1f top %.1f bottom %.1f centre %.1f,%.1f width %.1f height %.1f scale %.3f",
    why, CAL.x0, CAL.x1, CAL.y1, CAL.y0, (CAL.x0 + CAL.x1) / 2, (CAL.y0 + CAL.y1) / 2, w, h, cal_scale()))
  say(string.format("area %s: screen px (transform %.4f/%.4f/%.1f, screen %dx%d, y from top) left %.0f right %.0f top %.0f bottom %.0f centre %.0f,%.0f width %.0f height %.0f",
    why, SX, SY, GT, sw, sh, CAL.x0 * SX, CAL.x1 * SX, (GT - CAL.y1) * SY, (GT - CAL.y0) * SY,
    (CAL.x0 + CAL.x1) / 2 * SX, (GT - (CAL.y0 + CAL.y1) / 2) * SY, w * SX, h * SY))
end
local function cal_save(why, sw, sh)
  cal_log(why, sw, sh)
  local kv = { calibrate = tostring(CAL.on), area_x0 = string.format("%.2f", CAL.x0), area_y0 = string.format("%.2f", CAL.y0),
               area_x1 = string.format("%.2f", CAL.x1), area_y1 = string.format("%.2f", CAL.y1),
               area_scale = string.format("%.4f", cal_scale()),
               __order = { "calibrate", "area_x0", "area_y0", "area_x1", "area_y1", "area_scale" } }
  if ini_save(kv) then say("ini: saved " .. why .. " (calibrate=" .. kv.calibrate .. ")") end
  CAL.dirty, CAL.last_save = false, S.t
end
-- the slider, in gui units: centred under the area's top edge, a fixed size so it stays usable at any scale
local function slider_rect()
  local w, h = 600 / CFG.sx_scale, 16 / CFG.sy_scale
  local cx = (CAL.x0 + CAL.x1) / 2
  local top = CAL.y1 - (CAL.y1 - CAL.y0) * 0.08
  -- (kept on the screen as the transform sees it, so it can't be dragged out of reach)
  local vw, vtop, vbot = CAL.bw, CFG.gy_top, CFG.gy_top - CAL.bh
  cx = clamp(cx, w / 2 + 20, vw - w / 2 - 20)
  top = clamp(top, vbot + h + 40 / CFG.sy_scale, vtop - 40 / CFG.sy_scale)
  return cx - w / 2, top - h, w, h
end
local function knob_x(tx, tw) return tx + tw * (cal_scale() - SMIN) / (SMAX - SMIN) end
-- one frame of calibration input (mx, my: the cursor in gui units)
local function cal_input(sw, sh, gx, gy)
  local sh_ = kdown("shift")
  local step = (sh_ and 20 or 2)
  if krep("left") then move_by(-step / CFG.sx_scale, 0) end
  if krep("right") then move_by(step / CFG.sx_scale, 0) end
  if krep("up") then move_by(0, step / CFG.sy_scale) end
  if krep("down") then move_by(0, -step / CFG.sy_scale) end
  if krep("plus") then set_scale(cal_scale() * (sh_ and 1.05 or 1.01)) end
  if krep("minus") then set_scale(cal_scale() / (sh_ and 1.05 or 1.01)) end
  if IN.wheel and IN.wheel ~= 0 then set_scale(cal_scale() * (1 + 0.02 * clamp(IN.wheel, -10, 10))) end
  if not gx then return end
  local tx, ty, tw, th = slider_rect()
  if IN.lmb and not CAL.was_lmb then           -- the button went down: what is under the cursor?
    if gx >= tx - 15 and gx <= tx + tw + 15 and gy >= ty - 15 and gy <= ty + th + 15 then CAL.drag = "slider"
    elseif gx >= CAL.x0 and gx <= CAL.x1 and gy >= CAL.y0 and gy <= CAL.y1 then CAL.drag = "move"; CAL.gx, CAL.gy = gx, gy
    else CAL.drag = nil end
  elseif not IN.lmb then CAL.drag = nil end
  CAL.was_lmb = IN.lmb
  if CAL.drag == "slider" then
    local s = SMIN + (SMAX - SMIN) * clamp((gx - tx) / tw, 0, 1)
    if math.abs(s - cal_scale()) > 1e-4 then set_scale(s) end
  elseif CAL.drag == "move" then
    if gx ~= CAL.gx or gy ~= CAL.gy then move_by(gx - CAL.gx, gy - CAL.gy); CAL.gx, CAL.gy = gx, gy end
  end
end
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
      math.floor(clamp(r, 0, 255)), math.floor(clamp(g, 0, 255)), math.floor(clamp(b, 0, 255))), 950)
  end
  -- the screen transform (v0.9): (fx, fy) of the visible screen, fy from the top, w and h in screen px -> gui units.
  local SX, SY, GT = CFG.sx_scale, CFG.sy_scale, CFG.gy_top
  if not S.xf_logged then
    S.xf_logged = true
    say(string.format("transform: screen %dx%d sx_scale %.4f sy_scale %.4f gy_top %.1f -> visible gui x 0..%.1f, y %.1f (top)..%.1f (bottom)",
      sw, sh, SX, SY, GT, sw / SX, GT, GT - sh / SY))
  end
  if not CAL.bw then cal_init(sw, sh) end
  if not IN.probed then probe() end
  -- F8: calibration on/off (saved both ways)
  if kpressed("toggle") then
    CAL.on = not CAL.on
    if not CAL.on then hold_give(); CAL.drag = nil end
    cal_save(CAL.on and "calibration on (F8)" or "calibration off (F8)", sw, sh)
  end
  local function gbox(x, y, w, h, a, r, g, b) box(x, y, w, h, a, r, g, b) end
  local gx, gy
  if CAL.on then
    read_mouse(sw, sh)
    if IN.mx then gx, gy = IN.mx / SX, GT - IN.my / SY end
    cal_input(sw, sh, gx, gy)
    if CAL.dirty and S.t - CAL.last_save >= 0.5 then cal_save("changed", sw, sh) end
  elseif IN.hold then hold_give() end
  local ax0, ay0, ax1, ay1 = CAL.x0, CAL.y0, CAL.x1, CAL.y1
  local aw, ah = ax1 - ax0, ay1 - ay0
  local sc = aw / CAL.bw
  if CAL.on then
    local t1, t2 = 3 / SX, 3 / SY                                           -- 3 screen px lines
    gbox(ax0, ay0, aw, ah, 45, 40, 120, 255)                                 -- the area, see-through blue
    gbox(ax0, ay1 - t2, aw, t2, 230, 255, 255, 255); gbox(ax0, ay0, aw, t2, 230, 255, 255, 255)
    gbox(ax0, ay0, t1, ah, 230, 255, 255, 255); gbox(ax1 - t1, ay0, t1, ah, 230, 255, 255, 255)
    local hw, hh = 40 / SX, 40 / SY                                          -- corner handles, 40 px
    gbox(ax0, ay1 - hh, hw, hh, 240, 255, 0, 0)                              -- top-left: red
    gbox(ax1 - hw, ay1 - hh, hw, hh, 240, 0, 255, 0)                         -- top-right: green
    gbox(ax0, ay0, hw, hh, 240, 0, 80, 255)                                  -- bottom-left: blue
    gbox(ax1 - hw, ay0, hw, hh, 240, 255, 255, 0)                            -- bottom-right: yellow
    local cx, cy = ax0 + aw / 2, ay0 + ah / 2                                -- centre cross, 80 x 6 px
    gbox(cx - 40 / SX, cy - 3 / SY, 80 / SX, 6 / SY, 240, 255, 255, 255); gbox(cx - 3 / SX, cy - 40 / SY, 6 / SX, 80 / SY, 240, 255, 255, 255)
    local tx, ty, tw, th = slider_rect()                                     -- the scale slider: track, fill, knob
    gbox(tx, ty, tw, th, 200, 60, 60, 60)
    local kx = knob_x(tx, tw)
    gbox(tx, ty, kx - tx, th, 220, 0, 200, 255)
    gbox(kx - 10 / SX, ty - 10 / SY, 20 / SX, th + 20 / SY, 250, 255, 255, 255)
    local one = tx + tw * (1 - SMIN) / (SMAX - SMIN)                         -- (a yellow tick where scale 1.0 is)
    gbox(one - 1 / SX, ty - 6 / SY, 2 / SX, th + 12 / SY, 200, 255, 255, 0)
  end
  -- the bars: centred at (bars_fx, bars_fy) of the area (fy from its top), sized with the area
  local u = sh / 1080 * CFG.size * sc
  local segw, segh, gap = 160 * u / SX, 22 * u / SY, 12 * u / SX
  local x0 = ax0 + CFG.bars_fx * aw - (segw * 3 + gap * 2) / 2
  local yc = ay1 - CFG.bars_fy * ah - segh / 2                               -- (bottom edge of the centre bar)
  local ox, oy = 2 / SX, 2 / SY
  local oa = clamp(200 * CFG.opacity, 60, 255)
  for i = 1, 3 do
    local x = x0 + (i - 1) * (segw + gap)
    local y = yc + ((i == 2) and 0 or 8 * u / SY)          -- side bars a little higher (gui y runs up)
    gbox(x - ox, y - oy, segw + 2 * ox, segh + 2 * oy, oa, 255, 255, 255)
    gbox(x, y, segw, segh, 200, 20, 20, 20)
    local h = clamp(S.heat[i], 0, 3)
    if CFG.bar_debug and h < 0.5 then h = 0.5 end
    if h >= 0.02 then
      local g = (h <= 1) and 220 or 220 * (1 - (h - 1) / 2)
      local a = 255 * CFG.opacity * clamp(0.35 + 0.65 * h, 0, 1)
      gbox(x, y, segw * (CFG.bar_debug and 0.5 or 1), segh, a, 255, g, 30)
    end
    if S.rect_logs < 3 then
      say(string.format("bar %d: gui x %d y %d w %d h %d = screen px x %d y %d (top) heat %.2f (screen %dx%d, area scale %.3f)",
        i, math.floor(x), math.floor(y), math.floor(segw), math.floor(segh), math.floor(x * SX), math.floor((GT - y - segh) * SY), h, sw, sh, sc))
    end
  end
  if CAL.on and gx then                                                      -- my cursor: 12 px white square, black edge
    gbox(gx - 8 / SX, gy - 8 / SY, 16 / SX, 16 / SY, 255, 0, 0, 0)
    gbox(gx - 6 / SX, gy - 6 / SY, 12 / SX, 12 / SY, 255, 255, 255, 255)
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
  if S.t >= S.next_known then S.next_known = S.t + 0.25; known_pass(w) end
  if S.t >= next_threat then next_threat = S.t + 0.1; threat() end
  local k = 1 - math.exp(-dt * 6)
  for i = 1, 3 do S.heat[i] = S.heat[i] + (S.target[i] - S.heat[i]) * k end
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
    for i = 1, S.nknown do
      local e = S.known[i]
      local x, y = pos(e.u)
      if x and S.px then local dx, dy = x - S.px, y - S.py; if dx * dx + dy * dy < CFG.range * CFG.range then nd = nd + 1 end end
    end
    say(string.format("scan: cam %s | known enemies alive %d (within %dm %d), candidates %d | threat L %.2f C %.2f R %.2f | heat L %.2f C %.2f R %.2f | draws ok %d failed %d%s",
      S.px and string.format("%.0f,%.0f fwd %.2f,%.2f", S.px, S.py, S.fx, S.fy) or "none", S.nknown, CFG.range, nd, S.ntracked,
      S.target[1], S.target[2], S.target[3], S.heat[1], S.heat[2], S.heat[3], S.draw_ok, S.draw_fail,
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
say(string.format("Rear Heat HUD %s loaded: detect=%s discovery=%s range %d, %d known enemy kinds", VERSION, CFG.detect, tostring(CFG.discovery), CFG.range, nk))
say("LOCALAPPDATA = " .. tostring(os.getenv("LOCALAPPDATA")) .. " | APPDATA = " .. tostring(os.getenv("APPDATA")))
say("ini: " .. CFG_PATH .. " (" .. tostring(cfg_state) .. ")")
say("discovery summary: " .. SUMMARY_PATH)
return true
