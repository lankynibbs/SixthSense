-- HD2-Addon: mods/darryl/rear_heat_hud
-- Rear Heat HUD v0.2 for Bingus Shared Loader (HellForge, game build 25480438, LuaJIT).
-- Three bars at the bottom (left-rear, rear, right-rear) glow clear -> yellow -> red with the threat behind you.
-- v0.2: enemies are found by walking World.units and reading each unit's resource id (no World.units_by_resource),
-- a discovery mode logs every unit kind near you, and an optional "candidate enemy" heuristic works without a list.
-- Read-only: it changes nothing in the game.

local MOD, VERSION = "rear_heat_hud", "0.2.0"
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
local function ctor(name, ...)
  local g = rawget(_G, name)
  if g == nil then local sr = rawget(_G, "stingray"); g = type(sr) == "table" and rawget(sr, name) or nil end
  if g == nil then return nil end
  local ok, v = pcall(g, ...); if ok then return v end
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
local CFG = { range = 40, opacity = 0.85, position = "bottom", offset_y = 0.06, size = 1.0, swap_sides = false,
              detect = "both", discovery = true, discovery_range = 80, candidate_weight = 1.5, debug = false }
local CFG_TEXT = [[
; Rear Heat HUD v0.2 settings. Edit, save, restart the game.
; range: metres (10-100). opacity: 0.1-1. position: bottom or top. offset_y: share of screen height from that edge.
; size: 0.5-2. swap_sides: true if left/right look mirrored.
; detect: list (known enemy ids only), candidates (moving animated units that are not you), or both.
; discovery: true logs every unit kind near you every 5 s and writes rear_heat_hud_discovery.txt.
; discovery_range: metres for discovery. candidate_weight: threat of one candidate enemy (a light enemy is 1).
range=40
opacity=0.85
position=bottom
offset_y=0.06
size=1.0
swap_sides=false
detect=both
discovery=true
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
  CFG.offset_y = clamp(CFG.offset_y, 0, 0.9); CFG.size = clamp(CFG.size, 0.5, 2)
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
local FRIENDLY = { ['4d1c334d294dfa97'] = true }   -- Helldiver (2026 build id): never a candidate
local TIER_WEIGHT = { 1.0, 2.5, 5.0 }

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
            totals = {}, combat_scans = 0, next_summary = 0, next_disc = 0, passes = 0, ubr_tested = false }
local function reset(w)
  if S.gui and S.world then call("World", "destroy_gui", S.world, S.gui) end
  S.world, S.cam_unit, S.gui, S.cam_retry = w, nil, nil, 0
  S.list, S.li, S.info, S.tracked, S.ntracked, S.build, S.nbuild, S.pass = nil, 0, {}, {}, 0, {}, 0, {}
  S.target[1], S.target[2], S.target[3] = 0, 0, 0
end

local function pick_world()
  local ws = call("Application", "worlds")
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
  if not (known or asm or CFG.discovery) then return end
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
  local weight = nil
  if known and CFG.detect ~= "candidates" then
    if asm then weight = TIER_WEIGHT[known] end           -- a body loses its state machine: skipped
  elseif CFG.detect ~= "list" and asm and not FRIENDLY[h] and d > 3 and inf.moved_at and S.t - inf.moved_at < 20 then
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
    S.next_disc = S.t + 5
    local arr = sorted_pass(pass, "near")
    local total, rt = 0, (pass[RUNTIME_HEX] and pass[RUNTIME_HEX].n or 0)
    for i = 1, #arr do total = total + arr[i].st.n end
    say(string.format("discovery pass %d: %d live units, %d kinds, %d runtime-built skipped, tracked %d, combat %s",
      S.passes, total, #arr, rt, S.ntracked, tostring(combat)))
    local shown = 0
    for i = 1, #arr do
      local a = arr[i]
      if a.h ~= RUNTIME_HEX and a.st.near > 0 and shown < 40 then
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

-- ---------------------------------------------------------------- threat from the tracked list (about 10 times a second)
local REAR, MID = math.rad(100), math.rad(150)
local function threat()
  local t1, t2, t3 = 0, 0, 0
  if S.px then
    local R = CFG.range
    for i = 1, S.ntracked do
      local e = S.tracked[i]
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

-- ---------------------------------------------------------------- draw (rects only)
local function heat_color(h, alpha)
  if h < 0.02 then return nil end
  local r, g
  if h < 1 then r, g = 255, 220 else local k = clamp((h - 1) / 2, 0, 1); r, g = 255, 220 * (1 - k) end
  return ctor("Color", math.floor(255 * alpha * clamp(h, 0, 1)), math.floor(r), math.floor(g), 30)
end
local function rect(x, y, w, h, c, layer)
  local p, s = ctor("Vector3", x, y, layer), ctor("Vector2", w, h)
  if p and s and c then call("Gui", "rect", S.gui, p, s, c) end
end
local function draw()
  if not S.gui then
    S.gui = call("World", "create_screen_gui", S.world, "immediate")
    if not S.gui then return end
    say("screen gui created")
  end
  local sw, sh = call("Application", "resolution")
  if type(sw) ~= "number" then sw, sh = 1920, 1080 end
  local u = sh / 1080 * CFG.size
  local segw, segh, gap = 120 * u, 14 * u, 8 * u
  local x0 = (sw - (segw * 3 + gap * 2)) / 2
  local y0 = CFG.position == "top" and (sh * (1 - CFG.offset_y) - segh) or (sh * CFG.offset_y)
  local frame = ctor("Color", math.floor(70 * CFG.opacity), 255, 255, 255)
  for i = 1, 3 do
    local x = x0 + (i - 1) * (segw + gap)
    local lift = (i == 2) and 0 or 6 * u
    rect(x, y0 + lift, segw, 2 * u, frame, 900)
    local c = heat_color(S.heat[i], CFG.opacity)
    if c then rect(x, y0 + lift, segw, segh, c, 901) end
  end
end

-- ---------------------------------------------------------------- per frame
local next_threat, next_cam_log = 0, 0
local function step(dt)
  dt = (type(dt) == "number" and dt > 0 and dt < 1) and dt or 0.016
  S.t = S.t + dt
  local w = pick_world()
  if w == nil then return end
  if w ~= S.world then reset(w); say("world changed") end
  read_camera(w)
  walk(w)
  if S.t >= next_threat then next_threat = S.t + 0.1; threat() end
  if CFG.debug and S.px and S.t >= next_cam_log then
    next_cam_log = S.t + 5
    say(string.format("cam %.0f,%.0f,%.0f fwd %.2f,%.2f tracked %d threat L %.2f C %.2f R %.2f",
      S.px, S.py, S.pz, S.fx, S.fy, S.ntracked, S.target[1], S.target[2], S.target[3]))
  end
  local k = 1 - math.exp(-dt * 6)
  for i = 1, 3 do S.heat[i] = S.heat[i] + (S.target[i] - S.heat[i]) * k end
  draw()
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
  pcall(function() if logf then logf:close(); logf = nil end end)
  if inner_shutdown then return inner_shutdown(...) end
end
local nk = 0; for _ in pairs(TIER) do nk = nk + 1 end
say(string.format("Rear Heat HUD %s loaded: detect=%s discovery=%s range %d, %d known enemy kinds", VERSION, CFG.detect, tostring(CFG.discovery), CFG.range, nk))
say("LOCALAPPDATA = " .. tostring(os.getenv("LOCALAPPDATA")) .. " | APPDATA = " .. tostring(os.getenv("APPDATA")))
say("ini: " .. CFG_PATH .. " (" .. tostring(cfg_state) .. ")")
say("discovery summary: " .. SUMMARY_PATH)
return true
