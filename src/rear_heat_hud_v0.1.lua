-- HD2-Addon: mods/darryl/rear_heat_hud
-- Rear Heat HUD for Bingus Shared Loader (HellForge, game build 25480438, LuaJIT).
-- Three segments at the bottom of the screen (left-rear, rear, right-rear) glow from clear to yellow to red
-- with the threat of living enemies behind you. Read-only: it changes nothing in the game.
-- Config: %APPDATA%\Arrowhead\Helldivers2\rear_heat_hud.ini (written with defaults on first run).

local MOD = "rear_heat_hud"

-- ---------------------------------------------------------------- engine access (every call pcall'd)
local function ns(name)
  local t = rawget(_G, name)
  if type(t) ~= "table" then local sr = rawget(_G, "stingray"); t = type(sr) == "table" and rawget(sr, name) or nil end
  return type(t) == "table" and t or nil
end
local function fn(nsname, f)
  local t = ns(nsname); local v = t and rawget(t, f)
  if type(v) == "function" then return v end
  if t then local ok, w = pcall(function() return t[f] end); if ok and type(w) == "function" then return w end end
  return nil
end
local function call(nsname, f, ...)
  local g = fn(nsname, f); if not g then return nil end
  local ok, a, b, c, d = pcall(g, ...)
  if ok then return a, b, c, d end
  return nil
end
local function ctor(name, ...)   -- Vector3(...), Vector2(...), Color(...) as globals, else stingray.<name>
  local g = rawget(_G, name)
  if g == nil then local sr = rawget(_G, "stingray"); g = type(sr) == "table" and rawget(sr, name) or nil end
  if g == nil then return nil end
  local ok, v = pcall(g, ...); if ok then return v end
  return nil
end

-- ---------------------------------------------------------------- log
local LOGDIR = (os.getenv("LOCALAPPDATA") or ".") .. "\\CowboyBingus\\Helldivers2\\Logs\\"
local logf
do
  local L = rawget(_G, "CowboyBingusModLoader")
  if type(L) == "table" and type(L.open_log) == "function" then local ok, f = pcall(L.open_log, MOD .. ".log"); if ok then logf = f end end
  if not logf then logf = io.open(LOGDIR .. MOD .. ".log", "w") end
end
local log_lines = 0
local function say(s)
  if not logf or log_lines > 2000 then return end
  log_lines = log_lines + 1
  pcall(function() logf:write(os.date("%H:%M:%S "), s, "\n"); logf:flush() end)
end

-- ---------------------------------------------------------------- config
local CFG = { range = 40, opacity = 0.85, position = "bottom", offset_y = 0.06, size = 1.0,
              scan_interval = 0.25, swap_sides = false, debug = false }
local CFG_PATH = (os.getenv("APPDATA") or ".") .. "\\Arrowhead\\Helldivers2\\rear_heat_hud.ini"
local CFG_TEXT = [[
; Rear Heat HUD settings. Edit, save, restart the game.
; range: metres (10-100). opacity: 0.1-1. position: bottom or top. offset_y: share of screen height from that edge.
; size: 0.5-2 (scale). swap_sides: true if left/right appear mirrored. debug: true logs every scan.
range=40
opacity=0.85
position=bottom
offset_y=0.06
size=1.0
scan_interval=0.25
swap_sides=false
debug=false
]]
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
do
  local f = io.open(CFG_PATH, "r")
  if not f then
    local w = io.open(CFG_PATH, "w"); if w then w:write(CFG_TEXT); w:close() end
  else
    for line in f:lines() do
      local k, v = line:match("^%s*([%w_]+)%s*=%s*([^;%s]+)")
      if k and CFG[k] ~= nil then
        if type(CFG[k]) == "number" then CFG[k] = tonumber(v) or CFG[k]
        elseif type(CFG[k]) == "boolean" then CFG[k] = (v == "true" or v == "1")
        else CFG[k] = v end
      end
    end
    f:close()
  end
  CFG.range = clamp(CFG.range, 10, 100); CFG.opacity = clamp(CFG.opacity, 0.1, 1)
  CFG.offset_y = clamp(CFG.offset_y, 0, 0.9); CFG.size = clamp(CFG.size, 0.5, 2)
  CFG.scan_interval = clamp(CFG.scan_interval, 0.1, 2)
end

-- ---------------------------------------------------------------- enemies: resource id -> tier (1 light, 2 medium, 3 heavy)
-- From Treasure Radar 0.7.x by Th3chef (ids taken on the 2026 build; most are older units and should match 25480438).
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
local TIER_WEIGHT = { 1.0, 2.5, 5.0 }
local ENEMY_HEX, ENEMY_TIER = {}, {}
for hex, t in pairs(TIER) do ENEMY_HEX[#ENEMY_HEX + 1] = hex; ENEMY_TIER[#ENEMY_TIER + 1] = t end

-- ---------------------------------------------------------------- state (reset whenever the world changes)
local S = { world = nil, cam_unit = nil, gui = nil, cam_retry = 0, ids = nil, t = 0, next_scan = 0,
            target = { 0, 0, 0 }, heat = { 0, 0, 0 }, fails = 0, scans = 0 }
local function reset(w)
  if S.gui and S.world then call("World", "destroy_gui", S.world, S.gui) end
  S.world, S.cam_unit, S.gui, S.cam_retry, S.ids = w, nil, nil, 0, nil
  S.target[1], S.target[2], S.target[3] = 0, 0, 0
end

-- the game world: the one with the most units (unverified heuristic)
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

-- the camera unit: first live unit with a camera (as Chef Shared Loader finds it). Asked again with backoff.
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
        if type(nc) == "number" and nc > 0 then S.cam_unit = u; say("camera unit found"); return u end
      end
    end
  end
  S.cam_retry = S.t + 2
  return nil
end
local function camera(w)
  local u = find_camera(w); if not u then return nil end
  local c = call("Unit", "camera", u, 1); if not c then return nil end
  local px, py, pz = call("Vector3", "to_elements", call("Camera", "world_position", c))
  local rot = call("Camera", "world_rotation", c)
  local fx, fy = call("Vector3", "to_elements", rot and call("Quaternion", "forward", rot))
  if type(px) ~= "number" or type(fx) ~= "number" then return nil end
  local l = math.sqrt(fx * fx + fy * fy); if l < 1e-4 then return nil end
  return px, py, pz, fx / l, fy / l
end

-- ---------------------------------------------------------------- scan: threat per rear sector
-- Only enemy resource ids are asked for positions, never World.units' runtime-built units (asking those ends the game).
local REAR = math.rad(100)    -- beyond 100 degrees off your view = behind
local MID = math.rad(150)     -- beyond 150 = straight behind
local function scan(w)
  local px, py, pz, fx, fy = camera(w)
  local t1, t2, t3 = 0, 0, 0
  if not px then S.target[1], S.target[2], S.target[3] = 0, 0, 0; return end
  if not S.ids then
    S.ids = {}
    for i = 1, #ENEMY_HEX do S.ids[i] = call("IdString64", "from_hex", ENEMY_HEX[i]) or false end
  end
  local R, near, count = CFG.range, 0, 0
  for i = 1, #ENEMY_HEX do
    local id = S.ids[i]
    if id then
      local us = call("World", "units_by_resource", w, id)
      if type(us) == "table" then
        for j = 1, #us do
          local u = us[j]
          if call("Unit", "alive", u) == true and call("Unit", "has_animation_state_machine", u) == true then
            count = count + 1
            local x, y = call("Vector3", "to_elements", call("Unit", "world_position", u, 1))
            if type(x) == "number" then
              local dx, dy = x - px, y - py
              local d = math.sqrt(dx * dx + dy * dy)
              if d < R and d > 0.5 then
                near = near + 1
                local dot, cross = dx * fx + dy * fy, fx * dy - fy * dx
                local a = math.atan2(cross, dot)          -- + = left of view (z up), unverified sign
                if CFG.swap_sides then a = -a end
                local aa = math.abs(a)
                if aa > REAR then
                  local k = 1 - d / R
                  local v = TIER_WEIGHT[ENEMY_TIER[i]] * (0.25 + 0.75 * k * k)
                  if aa >= MID then t2 = t2 + v elseif a > 0 then t1 = t1 + v else t3 = t3 + v end
                end
              end
            end
          end
        end
      end
    end
  end
  S.target[1], S.target[2], S.target[3] = t1, t2, t3
  S.scans = S.scans + 1
  if CFG.debug or S.scans % 40 == 1 then
    say(string.format("scan %d: cam %.0f,%.0f,%.0f fwd %.2f,%.2f | live enemies %d, within %dm %d | rear L %.2f C %.2f R %.2f",
      S.scans, px, py, pz, fx, fy, count, R, near, t1, t2, t3))
  end
end

-- ---------------------------------------------------------------- draw (rects only: no fonts, so no font ids to go stale)
local function heat_color(h, alpha)   -- 0 clear, 1 yellow, 3+ red
  if h < 0.02 then return nil end
  local r, g
  if h < 1 then r, g = 255, 220 else local k = clamp((h - 1) / 2, 0, 1); r, g = 255, 220 * (1 - k) end
  local a = 255 * alpha * clamp(h, 0, 1)
  return ctor("Color", math.floor(a), math.floor(r), math.floor(g), 30)
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
  local total = segw * 3 + gap * 2
  local x0 = (sw - total) / 2
  local y0 = CFG.position == "top" and (sh * (1 - CFG.offset_y) - segh) or (sh * CFG.offset_y)  -- bottom-left origin (unverified)
  local frame = ctor("Color", math.floor(70 * CFG.opacity), 255, 255, 255)
  for i = 1, 3 do
    local x = x0 + (i - 1) * (segw + gap)
    local lift = (i == 2) and 0 or 6 * u        -- side segments raised a little: a shallow arc
    rect(x, y0 + lift, segw, 2 * u, frame, 900)  -- faint outline so you know where it is
    local c = heat_color(S.heat[i], CFG.opacity)
    if c then rect(x, y0 + lift, segw, segh, c, 901) end
  end
end

-- ---------------------------------------------------------------- per frame
local function step(dt)
  dt = (type(dt) == "number" and dt > 0 and dt < 1) and dt or 0.016
  S.t = S.t + dt
  local w = pick_world()
  if w == nil then return end
  if w ~= S.world then reset(w); say("world changed") end
  if S.t >= S.next_scan then S.next_scan = S.t + CFG.scan_interval; scan(w) end
  local k = 1 - math.exp(-dt * 6)              -- ~0.17 s fade
  for i = 1, 3 do S.heat[i] = S.heat[i] + (S.target[i] - S.heat[i]) * k end
  draw()
end

local inner_update = rawget(_G, "update")
local function wrapped(...)
  local r1, r2
  if inner_update then r1, r2 = inner_update(...) end
  if S.fails < 50 then
    local ok, err = pcall(step, (...))
    if not ok then S.fails = S.fails + 1; if S.fails <= 5 then say("error: " .. tostring(err)) end
      if S.fails == 50 then say("50 errors: HUD stopped for this launch") end end
  end
  return r1, r2
end
_G.update = wrapped
local inner_shutdown = rawget(_G, "shutdown")
_G.shutdown = function(...)
  pcall(function() if logf then logf:close(); logf = nil end end)
  if inner_shutdown then return inner_shutdown(...) end
end
say(string.format("loaded: range %d, opacity %.2f, position %s, %d enemy kinds", CFG.range, CFG.opacity, CFG.position, #ENEMY_HEX))
return true
