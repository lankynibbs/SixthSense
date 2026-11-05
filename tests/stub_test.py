import lupa.lua51 as l
r=l.LuaRuntime()
r.execute(r'''
os.getenv=function(k) return "/tmp/rh" end
local W={}; cam={}; enemy={}; ov={}; rt={}; local tt=0
rects=0
Application={worlds=function() return {W} end, resolution=function() return 1920,1080 end}
World={num_units=function() return 4 end, units=function() return {cam,enemy,rt,ov} end,
 create_screen_gui=function() return {} end, destroy_gui=function() end, units_by_resource=function(w,id) if id=="1a7fcdff98c664b0" then return {enemy} end return {} end}
local names={[cam]="#ID[aaaaaaaaaaaaaaaa]",[enemy]="#ID[1a7fcdff98c664b0]",[rt]="#ID[46cab355bd8d4d37]",[ov]="#ID[1234567890abcdef]"}
Unit={alive=function() return true end, num_cameras=function(u) return u==cam and 1 or 0 end, camera=function() return "c" end,
 resource_name=function(u) return setmetatable({},{__tostring=function() return names[u] end}) end,
 has_animation_state_machine=function(u) return u~=cam end,
 world_position=function(u) if u==rt then error("CRASH: runtime unit asked") end tt=tt+1 if u==ov then return {5,-15+(tt%7)*2,0} end return {0,-10,0} end}
Camera={world_position=function() return {0,0,0} end, world_rotation=function() return "q" end}
Quaternion={forward=function() return {0,1,0} end}
Vector3=setmetatable({to_elements=function(v) return v[1],v[2],v[3] end},{__call=function(_,a,b,c) return {a,b,c} end})
IdString64={from_hex=function(h) return h end}
Vector2=function(a,b) return {a,b} end
Color=function(a,r,g,b) return {a,r,g,b} end
Gui={rect=function() rects=rects+1 end, text=function() end}
Application.main_world=function() return W end
Application.back_buffer_size=function() return BBW or 2560, BBH or 1440 end
stingray={Vector3=Vector3,Vector2=Vector2,Color=Color}
Vector3=nil; Vector2={}
''')
r.execute(open('src/sixth_sense.lua').read().replace('\\\\','/'))
for i in range(4000): r.eval('update')(0.016)
print('rects',r.eval('rects'))

# ---------------------------------------------------------------- v1.0: calibration with simulated mouse and keys
import os, re
LOGDIR = '/tmp/rh/CowboyBingus/Helldivers2/Logs'
os.makedirs(LOGDIR, exist_ok=True)
INI = LOGDIR + '/sixth_sense.ini'
if os.path.exists(INI): os.remove(INI)
if os.path.exists(LOGDIR + '/rear_heat_hud.ini'): os.remove(LOGDIR + '/rear_heat_hud.ini')
open(INI, 'w').write('transform_ref_h=1440\n' + 'calibrate=true\nbar_debug=true\narea_x0=300\narea_y0=200\narea_x1=1366.67\narea_y1=971.45\n')   # an older ini with a saved area (scale 0.5)
SRC = open('src/sixth_sense.lua').read().replace('\\\\', '/')
PRE = r'''
MX, MY, LMB, WHEEL, DZ = 960, 540, 0, 0, {1, 0.05}
PRESSED, HELD = {}, {}
local KEYS = {["f7"]=1, left=2, right=3, up=4, down=5, ["left shift"]=6, ["right shift"]=7, ["numpad +"]=8, ["="]=9, ["numpad -"]=10, ["-"]=11, ["["]=12, ["]"]=13, [";"]=14, ["'"]=15}
Mouse = {axis_index=function(n) return ({cursor=0, mouse=1, wheel=2})[n] end, button_index=function(n) return n=="left" and 0 or nil end,
  axis=function(i) if i==0 then return stingray.Vector3(MX, MY, 0) elseif i==2 then return stingray.Vector3(0, WHEEL, 0) end return stingray.Vector3(0,0,0) end,
  button=function(i) return LMB end, num_axes=function() return 3 end, num_buttons=function() return 5 end,
  dead_zone=function(i) return DZ[1], DZ[2] end, set_dead_zone=function(i, m, s) DZ = {m, s} end}
Keyboard = {button_index=function(n) return KEYS[n] end, pressed=function(i) return PRESSED[i] == true end,
  button=function(i) return (HELD[i] or PRESSED[i]) and 1 or 0 end}
Window = {get_main_window=function() return "win" end, show_cursor=function() return true end}
'''
def runtime():
    r = l.LuaRuntime()
    r.execute(open('tests/stub_test.py').read().split("r.execute(r'''")[1].split("''')")[0])
    r.execute(PRE)
    r.execute(SRC)
    return r
r = runtime()
G = r.globals()
upd = r.eval('update')
def frames(n=1):
    for _ in range(n):
        upd(0.016)
        r.execute('PRESSED = {}'); G.WHEEL = 0
def area(): c = G.SIXTH_SENSE_CAL; return c.x0, c.y0, c.x1, c.y1
def scale(): c = G.SIXTH_SENSE_CAL; return (c.x1 - c.x0) / c.bw
SW, SH, RW, RH, SX, SY, GT = 2560, 1440, 1920, 1080, 1.2, 0.9333, 1080
def to_window(gx, gy):       # gui -> the cursor axis (window px, from the bottom, y up)
    px, py = gx * SX, (GT - gy) * SY
    return px * RW / SW, (SH - py) * RH / SH
def click_tab(rr, i):
    gg = rr.globals(); u = rr.eval('update')
    x, y, w, h = rr.eval('function(i) return SIXTH_SENSE_TAB(i) end')(i)
    gg.MX, gg.MY = to_window(x + w / 2, y + h / 2); u(0.016); gg.LMB = 1; u(0.016); gg.LMB = 0; u(0.016)
def tab(rr): return rr.eval('SIXTH_SENSE_TAB()')
def key(name): r.execute('PRESSED[%d] = true' % {'f7':1,'left':2,'right':3,'up':4,'down':5,'plus':8,'minus':10}[name]); frames(1)
fails = []
def check(ok, what): print(('PASS ' if ok else 'FAIL ') + what); (None if ok else fails.append(what))
frames(200)                              # settle + first draws
# v1.4.2: the old gui area + radar_fx 0.5 / radar_fy 0.78 / radar_size 0.35 migrated once to screen fractions
c = G.SIXTH_SENSE_CAL
YB = min(1, GT * SY / SH)                # v1.4.6: fractions of the drawable area (the window cut at the gui's bottom)
ecx = (300 + 0.5 * 1066.67) * SX / SW; ecy = (GT - (971.45 - 0.78 * 771.45)) * SY / SH / YB; ed = 0.35 * 771.45 * SY / SH / YB
check(abs(c.cx - ecx) < 1e-4 and abs(c.cy - ecy) < 1e-4 and abs(c.d - ed) < 1e-4, 'migrated radar_cx %.4f radar_cy %.4f radar_d %.4f (want %.4f %.4f %.4f)' % (c.cx, c.cy, c.d, ecx, ecy, ed))
ini = open(INI).read()
check('v142_migrated=true' in ini and 'radar_cx=%.4f' % ecx in ini and 'area_x0=300' in ini, 'migration saved once; the old area keys left as they were')
SLR = r.eval('function(i) return SIXTH_SENSE_SLIDER(i) end')
GR = r.eval('function() return {SIXTH_SENSE_GRAB()} end')
def grab(): return tuple(GR().values())
def drag(x, y, dxw, dyw, n=10):
    G.MX, G.MY = to_window(x, y); frames(1); G.LMB = 1; frames(1)
    for _ in range(n): G.MX += dxw / n; G.MY += dyw / n; frames(1)
    mid = tuple(SLR(i) for i in (1, 4)); G.LMB = 0; frames(1); return mid
def fr(): return (c.cx, c.cy, c.d)
# a drag on the radar away from the handles does nothing; the wheel away from the radar does nothing
f0 = fr(); drag((c.x0 + c.x1) / 2 + 30, (c.y0 + c.y1) / 2 - 20, 200, 100)
G.MX, G.MY = to_window(c.x1 + 200, c.y1 + 100); frames(1); G.WHEEL = 5; frames(1)
check(fr() == f0, 'Display: a drag on the radar body and the wheel off the radar do nothing')
# the grab handle moves it: +200 window px right, +100 up
P0 = tuple(SLR(i) for i in (1, 4))
gx_, gy_, gw_, gh_ = grab()
mid = drag(gx_ + gw_ / 2, gy_ + gh_ / 2, 200, 100)
check(abs(c.cx - (f0[0] + 200 / RW)) < 1e-3 and abs(c.cy - (f0[1] - 100 / (RH * YB))) < 1e-3 and c.d == f0[2], 'grab handle drag moved the radar by 200, 100 window px (%.4f, %.4f)' % (c.cx - f0[0], c.cy - f0[1]))
check(mid == P0, 'mid-drag the slider panel stays put (re-placed only on drop)')
check('ini: saved dropped' in open(LOGDIR + '/sixth_sense.log').read(), 'saved on drop')
# the wheel over the radar resizes
d0 = c.d; G.MX, G.MY = to_window((c.x0 + c.x1) / 2, (c.y0 + c.y1) / 2); frames(1); G.WHEEL = 3; upd(0.016); G.WHEEL = 0; frames(1)
check(c.d > d0 * 1.05, 'wheel over the radar resized %.3f -> %.3f' % (d0, c.d))
# a corner handle resizes about the centre
d0 = c.d; cx0 = c.cx; drag(c.x1 - 5 / SX, c.y0 + 5 / SY, -60, 60)
check(c.d < d0 - 0.01 and abs(c.cx - cx0) < 1e-9, 'corner drag (inwards) resized %.3f -> %.3f about the centre' % (d0, c.d))
s0 = c.d; key('plus'); key('minus'); check(abs(c.d - s0) < 1e-12, '+/- keys do not scale (mouse only)')
x0 = c.x0; key('left'); check(abs(c.x0 - (x0 - 2 / SX)) < 1e-6, 'left arrow nudged 2 px')
r.execute('HELD[6] = true'); x0 = c.x0; key('right'); check(abs(c.x0 - (x0 + 20 / SX)) < 1e-6, 'shift+right nudged 20 px'); r.execute('HELD = {}')
y1 = c.y1; key('up'); check(abs(c.y1 - (y1 + 2 / SY)) < 1e-6, 'up arrow moved the radar up (gui y +)')
# tabs: Settings: the handle, wheel and arrows do nothing
check(tab(r) == 'display', 'calibration opens on the Display tab')
click_tab(r, 2); check(tab(r) == 'settings', 'clicking the Settings tab switches to it')
f0 = fr(); gx_, gy_, gw_, gh_ = grab(); drag(gx_ + gw_ / 2, gy_ + gh_ / 2, 150, 60)
G.MX, G.MY = to_window((c.x0 + c.x1) / 2, (c.y0 + c.y1) / 2); frames(1); G.WHEEL = 5; frames(1); key('left')
check(fr() == f0, 'Settings tab: the handle, wheel and arrows leave the radar where it is')
# the Size slider sets the diameter
tx, ty, tw, th = SLR(1)
kx = tx + tw * (c.d - 0.08) / (1.0 - 0.08)
G.MX, G.MY = to_window(kx, ty + th / 2); frames(1); G.LMB = 1; frames(1)
G.MX, G.MY = to_window(tx + tw * 0.3, ty + th / 2); frames(3); MIDS = tuple(SLR(1)); G.LMB = 0; frames(1)
check(abs(c.d - (0.08 + 0.92 * 0.3)) < 0.01, 'Size slider set the diameter to %.3f' % c.d)
check(MIDS == (tx, ty, tw, th), 'the panel stays put while the Size slider is dragged')
PN = tuple(r.eval('function() return {SIXTH_SENSE_PANEL()} end')().values())
ov = max(0, min(PN[4], c.x1) - max(PN[2], c.x0)) * max(0, min(PN[5], c.y1) - max(PN[3], c.y0))
check(ov == 0 or 'least' in open(LOGDIR + '/sixth_sense.log').read(), 'the panel was placed off the radar (overlap %.0f)' % ov)
# Reset on Settings: slider defaults (two clicks)
RS = r.eval('SIXTH_SENSE_RESET')
click_tab(r, 3); check(RS() and abs(c.d - (0.08 + 0.92 * 0.3)) < 0.01, 'Reset: one click only arms it')
click_tab(r, 3); ini = open(INI).read()
check(not RS() and abs(c.d - 0.35) < 1e-9 and 'sensitivity=1.00' in ini and 'dot_size=medium' in ini and 'reset (Settings, confirmed)' in open(LOGDIR + '/sixth_sense.log').read(), 'Reset confirmed on Settings: slider defaults, saved and logged')
click_tab(r, 1)
# Reset on Display: armed expires after 3 s; confirmed -> centred, 75% down, default size
gx_, gy_, gw_, gh_ = grab(); drag(gx_ + gw_ / 2, gy_ + gh_ / 2, -150, 80)
f0 = fr(); click_tab(r, 3); frames(int(3.2 / 0.016)); click_tab(r, 3)
check(fr() == f0 and RS(), 'Reset: a second click after 3 s only re-arms')
click_tab(r, 3); yb = min(1, GT * SY / SH)
check(abs(c.cx - 0.5) < 1e-6 and abs(c.cy - 0.5) < 1e-4 and abs(c.d - 0.35) < 1e-6 and re.search(r'^radar_layouts=(.*)$', open(INI).read(), re.M) and ('%dx%d:' % (SW, SH)) not in re.search(r'^radar_layouts=(.*)$', open(INI).read(), re.M).group(1), 'Reset confirmed on Display: centred in the drawable area, default size, saved (%.3f, %.3f)' % (c.cx, c.cy))
# drag far down and right: clamped inside the drawable screen
gx_, gy_, gw_, gh_ = grab(); drag(gx_ + gw_ / 2, gy_ + gh_ / 2, 800, -800, 20)
check(c.y0 >= -1e-6 and c.x1 <= c.bw + 1e-6, 'drag down-right: clamped (bottom gy %.2f, right %.1f of %.1f)' % (c.y0, c.x1, c.bw))
lg = open(LOGDIR + '/sixth_sense.log').read()
check('drawable gui bounds' in lg and 'area clamped (move)' in lg, 'bounds and clamp logged')
# resolution change: 2560x1440 -> 3840x1080: same screen fractions, new transform logged
f0 = fr(); G.BBW, G.BBH = 3840, 1080; frames(70)
check(abs(c.cx - 0.5) < 1e-9 and abs(c.cy - 0.5) < 1e-9 and 'transform (resolution change from 2560x1440): screen 3840x1080' in open(LOGDIR + '/sixth_sense.log').read() and 'viewport (resolution change from 2560x1440): screen 3840x1080' in open(LOGDIR + '/sixth_sense.log').read(), 'resolution change to unsaved 3840x1080: centred default; transform and viewport logged')
check(abs(c.bw - 3840 / (1.2 * 1080 / 1440)) < 1e-6, 'height model: sx_scale scales with the height (visible gui %.1f wide)' % c.bw)
G.BBW, G.BBH = None, None; frames(70)
check(abs(c.cx - f0[0]) < 1e-9 and abs(c.cy - f0[1]) < 1e-9, 'back to 2560x1440: its saved layout restored')
# F7 held 3 s: the whole layout reset
gx_, gy_, gw_, gh_ = grab(); drag(gx_ + gw_ / 2, gy_ + gh_ / 2, -200, 50)
r.execute('HELD[1] = true'); frames(int(3.2 / 0.016)); r.execute('HELD = {}'); frames(1)
check(abs(c.cx - 0.5) < 1e-9 and c.on and 'layout reset (F7 held 3 s)' in open(LOGDIR + '/sixth_sense.log').read(), 'F7 held 3 s: layout reset, calibration on')
frames(40)
a = area()
# F8: off, saved, mouse given back, only the bars drawn
key('f7'); ini = open(INI).read()
check('calibrate=false' in ini and 'toggle_key=f7' in ini, 'F7 saved calibrate=false')
check(abs(r.eval('DZ[2]') - 0.05) < 1e-9, 'mouse dead zone untouched / given back')
n0 = r.eval('rects'); frames(1); rd = G.SIXTH_SENSE_RADAR; check(r.eval('rects') - n0 == rd.rects and rd.rects <= 300, 'calibrate off: only the radar drawn (%d rects incl. player marker; radar %d)' % (r.eval('rects') - n0, rd.rects))
log = open(LOGDIR + '/sixth_sense.log').read()
check('area calibration off (f7): gui left' in log and 'screen px' in log, 'edges logged in gui and screen px')
check('input: mouse move 1: cursor axis raw' in log, 'raw mouse moves logged')
# restart: the area loads from the ini, calibration stays off
r2 = runtime(); u2 = r2.eval('update')
for _ in range(200): u2(0.016)
c2 = r2.globals().SIXTH_SENSE_CAL
check(abs(c2.x0 - a[0]) < 0.01 and abs(c2.y1 - a[3]) < 0.01 and not c2.on, 'restart loads the saved area, calibration off')
# hidden game cursor: the mouse is held (dead zone) and the cursor axis moves still move the drawn cursor
r3 = runtime(); r3.execute('Window.show_cursor = function() return false end'); os.remove(INI)
r3 = runtime(); r3.execute('Window.show_cursor = function() return false end'); u3 = r3.eval('update')
for _ in range(200): u3(0.016)
g3 = r3.globals(); g3.MX = 300; u3(0.016); g3.MX = 340; u3(0.016)
check(r3.eval('DZ[2]') == 917351, 'hidden cursor: the mouse is held while calibrating')
# ---------------------------------------------------------------- v1.1: tracking, sectors, smoothing, migration
ini = open(INI).read()
check('bar_debug=false' in ini and 'v110_migrated=true' in ini, 'bar_debug forced false once in the older ini')
r4 = runtime(); r4.execute('''
EX, EY, EALIVE = 0, -10, true
Unit.world_position = function(u) if u == rt then error("CRASH") end if u == enemy then JIT = (JIT or 0) + 1; return stingray.Vector3(EX + 0.1 * math.sin(JIT * 0.7), EY, 0) end return stingray.Vector3(50, 50, 0) end
Unit.alive = function(u) if u == enemy then return EALIVE end return true end
Window.show_cursor = function() return true end''')
u4 = r4.eval('update'); g4 = r4.globals()
def run4(sec):
    for _ in range(int(sec / 0.016)): u4(0.016)
# reach the mod's state table S through update -> step upvalues
r4.execute('''
local function find(fn, name) for i = 1, 200 do local n, v = debug.getupvalue(fn, i); if not n then return end if n == name then return v end end end
local step = find(update, "step"); HUD_S = find(step, "S")''')
S4 = g4.HUD_S
run4(4)
def H(): return [S4.heat[i] for i in (1, 2, 3)]
check(H()[1] > 0.5 and H()[0] < 0.01 and H()[2] < 0.01, 'enemy straight behind -> centre bar %s' % H())
# steady: sample every frame for 3 s, heat must not dip
mins = 9
for _ in range(190): u4(0.016); mins = min(mins, S4.heat[2])
check(mins > 0.5, 'steady centre heat while the enemy stays behind (min %.2f)' % mins)
# left-rear: fwd is +y, x right; enemy at (-6, -6) is behind-left (bearing -135)
g4.EX, g4.EY = -6, -6; run4(4)
check(H()[0] > 0.3 and H()[2] < 0.01, 'behind-left -> L bar (not mirrored) %s' % H())
g4.EX, g4.EY = 6, -6; run4(4)
check(H()[2] > 0.3 and H()[0] < 0.01, 'behind-right -> R bar %s' % H())
# rear 180: bearing 100 (just behind the side) counts, bearing 80 does not
import math
g4.EX, g4.EY = 10 * math.sin(math.radians(100)), 10 * math.cos(math.radians(100)); run4(4)
check(H()[2] > 0.3, 'bearing +100 counts in R %s' % H())
g4.EX, g4.EY = 10 * math.sin(math.radians(80)), 10 * math.cos(math.radians(80)); run4(4)
check(sum(H()) < 0.01, 'bearing +80 (in front of the side) counts nowhere %s' % H())
# rise ~0.15 s, hold 1 s, fade 1.5 s
g4.EX, g4.EY = 0, -10; run4(0.16); h1 = S4.heat[2]; tg = S4.target[2]
check(h1 > 0.9 * tg, 'rise: %.2f of target %.2f after 0.16 s' % (h1, tg))
run4(2); peak = S4.heat[2]
g4.EX, g4.EY = 0, 10; run4(0.9); hh = S4.heat[2]
check(abs(hh - peak) < 0.02 * peak, 'hold: unchanged 0.9 s after the enemy moved in front (%.2f)' % hh)
run4(0.8); hm = S4.heat[2]
check(0.05 < hm < peak, 'fading after the hold (%.2f)' % hm)
run4(1.2); check(S4.heat[2] < 0.01, 'faded out by 2.7 s (%.3f)' % S4.heat[2])
# dead: dropped from tracking
g4.EX, g4.EY = 0, -10; run4(1); g4.EALIVE = False; run4(0.2)
check(S4.nT == 0 or S4.target[2] == 0, 'dead enemy dropped (tracked %d, target %.2f)' % (S4.nT, S4.target[2]))
lg = open(LOGDIR + '/sixth_sense.log').read()
check(re.search(r'nearest 1a7fcdff98c664b0 known .* bearing [-+]\d+ \((left|right)\) -> (bar [LCR]|front, no bar)', lg) is not None, 'nearest threat logged with id, distance, bearing and bar')
ini2 = open(INI).read()
check(all(k in ini2 for k in ('area_x0=', 'area_y0=', 'area_x1=', 'area_y1=')), 'area keys still in the ini')
# ---------------------------------------------------------------- v1.2: sensitivity and repeat_rate
open(INI, 'w').write('transform_ref_h=1440\n' + 'calibrate=true\nbar_debug=false\nv110_migrated=true\nrange=40\narea_x0=300\narea_y0=200\narea_x1=1366.67\narea_y1=971.45\narea_scale=0.5\nswap_sides=false\n')
r5 = runtime(); r5.execute('''
EX, EY = 0, -10
Unit.world_position = function(u) if u == rt then error("CRASH") end if u == enemy then JIT = (JIT or 0) + 1; return stingray.Vector3(EX + 0.1 * math.sin(JIT * 0.7), EY, 0) end return stingray.Vector3(50, 50, 0) end
local function find(fn, name) for i = 1, 200 do local n, v = debug.getupvalue(fn, i); if not n then return end if n == name then return v end end end
local step = find(update, "step"); HUD_S = find(step, "S"); HUD_CFG = find(step, "CFG") or find(find(step, "threat") or step, "CFG")''')
u5 = r5.eval('update'); g5 = r5.globals()
def run5(sec):
    for _ in range(max(1, int(sec / 0.016))): u5(0.016); r5.execute('PRESSED = {}'); g5.WHEEL = 0
S5 = g5.HUD_S
CFG5 = g5.HUD_CFG
run5(3.5)
check(CFG5 is not None and abs(CFG5.sensitivity - 1) < 1e-9 and abs(CFG5.repeat_rate - 1) < 1e-9, 'defaults sensitivity 1.0, repeat_rate 1.0')
def press5(i): r5.execute('PRESSED[%d] = true' % i); run5(0.016)
for k in (12, 13, 14, 15): press5(k)
r5.execute('HELD[6] = true'); press5(12); press5(13); r5.execute('HELD = {}')
check(abs(CFG5.sensitivity - 1) < 1e-9 and abs(CFG5.repeat_rate - 1) < 1e-9, "[ ] ; ' keys do nothing (sliders are mouse only)")
click_tab(r5, 2)
def drag_slider(i, frac):
    tx, ty, tw, th = r5.eval('function(i) return SIXTH_SENSE_SLIDER(i) end')(i)
    kx = None
    g5.MX, g5.MY = to_window(tx + tw * 0.5, ty + th / 2); run5(0.02)
    g5.LMB = 1; run5(0.02)
    g5.MX, g5.MY = to_window(tx + tw * frac, ty + th / 2); run5(0.05)
    g5.LMB = 0; run5(0.02)
a_before = area()
c5 = g5.SIXTH_SENSE_CAL
a_before = (c5.x0, c5.y0, c5.x1, c5.y1); sc_before = (c5.x1 - c5.x0) / c5.bw
drag_slider(2, (2.0 - 0.25) / 2.75); check(abs(CFG5.sensitivity - 2.0) < 0.02, 'orange slider drag set sensitivity %.3f' % CFG5.sensitivity)
drag_slider(3, (2.0 - 0.25) / 2.75); check(abs(CFG5.repeat_rate - 2.0) < 0.02, 'magenta slider drag set repeat_rate %.3f' % CFG5.repeat_rate)
check(abs((c5.x1 - c5.x0) / c5.bw - sc_before) < 1e-9 and abs(c5.x0 - a_before[0]) < 1e-9 and abs(c5.y1 - a_before[3]) < 1e-9, 'setting sliders leave the area and its scale alone')
# effect on range: sens 2 -> 80 m; an enemy behind at 60 m counts; at sens 1 it doesn't
r5.execute('HUD_CFG.sensitivity = 2.0'); g5.EX, g5.EY = 0, -60; run5(0.5)
check(abs(S5.eff_range - 80) < 1e-9 and S5.target[2] > 0, 'sensitivity 2: range 80 m, enemy at 60 m counts (%.2f)' % S5.target[2])
t2 = None
r5.execute('HUD_CFG.sensitivity = 1.0'); run5(0.5)
check(abs(S5.eff_range - 40) < 1e-9 and S5.target[2] == 0, 'sensitivity 1: range 40 m, enemy at 60 m ignored')
r5.execute('HUD_CFG.sensitivity = 3.0'); run5(0.5); check(abs(S5.eff_range - 120) < 1e-9, 'range clamps at 120 m')
# gain: same enemy at 10 m, sens 2 gives twice the threat of sens 1
g5.EX, g5.EY = 0, -10
r5.execute('HUD_CFG.sensitivity = 1.0'); run5(0.3); t1 = S5.target[2]
r5.execute('HUD_CFG.sensitivity = 2.0'); run5(0.3); t2 = S5.target[2]
check(t1 > 0 and t2 > 2 * t1 * 0.99, 'sensitivity 2 raises the gain (%.2f vs %.2f; range also grew)' % (t2, t1))
r5.execute('HUD_CFG.sensitivity = 1.0')
# hold and fade at repeat_rate 2: hold 0.5 s, fade 0.75 s
r5.execute('HUD_CFG.repeat_rate = 2.0'); run5(1.5); peak = S5.heat[2]
g5.EX, g5.EY = 0, 10; run5(0.4); check(abs(S5.heat[2] - peak) < 1e-6, 'rate 2: still held at 0.4 s')
run5(0.35); check(S5.heat[2] < peak, 'rate 2: fading by 0.75 s (%.2f < %.2f)' % (S5.heat[2], peak))
run5(0.6); check(S5.heat[2] < 0.01, 'rate 2: gone by 1.35 s (hold 0.5 + fade 0.75)')
# re-acquire interval 0.5 / rate
r5.execute('HUD_CFG.repeat_rate = 2.0'); run5(0.1); n0 = S5.next_known - S5.t
check(0 < n0 <= 0.25 + 1e-6, 'rate 2: known enemies re-acquired every 0.25 s (next in %.3f)' % n0)
# saved to the ini (throttled), area keys untouched by settings
r5.execute('HUD_CFG.sensitivity = 1.55; HUD_CFG.repeat_rate = 0.8; SIXTH_SENSE_CAL.dirty = true'); run5(1.0)
ini5 = open(INI).read(); vals = dict(re.findall(r'^(\w+)=(.*)$', ini5, re.M))
check(vals.get('sensitivity') == '1.55' and vals.get('repeat_rate') == '0.80', 'ini has sensitivity %s repeat_rate %s' % (vals.get('sensitivity'), vals.get('repeat_rate')))
check('radar_cx' in vals and abs(float(vals['area_x0']) - 300) < 0.01 and abs(float(vals['area_y1']) - 971.45) < 0.01 and vals.get('range') == '40' and vals.get('swap_sides') == 'false', 'area and other ini keys untouched')
lg = open(LOGDIR + '/sixth_sense.log').read()
r6 = runtime(); r6.execute('''local function find(fn, name) for i = 1, 200 do local n, v = debug.getupvalue(fn, i); if not n then return end if n == name then return v end end end
HUD_CFG = find(find(update, "step"), "CFG")''')
C6 = r6.globals().HUD_CFG
check(abs(C6.sensitivity - 1.55) < 1e-9 and abs(C6.repeat_rate - 0.8) < 1e-9, 'restart loads sensitivity and repeat_rate from the ini')
check('settings changed: sensitivity' in lg and 'sens_' not in lg and 'input: key plus' not in lg, 'settings logged; no slider key lookups')
# ---------------------------------------------------------------- v1.3: the radar
open(INI, 'w').write('transform_ref_h=1440\n' + 'calibrate=false\nv110_migrated=true\nrange=40\narea_x0=0\narea_y0=0\narea_x1=2133.33\narea_y1=1080\narea_scale=1\nsensitivity=1.00\nrepeat_rate=1.00\n')
def radar_rt(extra=''):
    rr = runtime(); rr.execute('''
EX, EY, EALIVE = 0, 20, true
DOTS = {}
FWDX, FWDY = 0, 1
Quaternion.forward = function() return {FWDX, FWDY, 0} end
Unit.world_position = function(u) if u == rt then error("CRASH") end if u == enemy then JIT = (JIT or 0) + 1; return stingray.Vector3(EX + 0.1 * math.sin(JIT * 0.7), EY, 0) end return stingray.Vector3(500, 500, 0) end
Unit.alive = function(u) if u == enemy then return EALIVE end return true end
Gui.rect = function(g, p, sz, c) rects = rects + 1; if c[2] == 255 and c[3] == 40 and c[4] == 40 then DOTS[#DOTS + 1] = {p[1] + sz[1] / 2, p[2] + sz[2] / 2, sz[1], sz[2], c[1]} end end
local function find(fn, name) for i = 1, 200 do local n, v = debug.getupvalue(fn, i); if not n then return end if n == name then return v end end end
local step = find(update, "step"); HUD_S = find(step, "S"); HUD_CFG = find(step, "CFG")''' + extra)
    return rr
r7 = radar_rt(); u7 = r7.eval('update'); g7 = r7.globals()
def run7(sec):
    for _ in range(max(1, int(sec / 0.016))): r7.execute('DOTS = {}'); u7(0.016)
run7(3.5)
I7 = g7.SIXTH_SENSE_RADAR
def dot7():
    D = g7.DOTS
    if not D or len(D) == 0: return None
    d = D[1]; return ((d[1] - I7.cx) / I7.rx, (d[2] - I7.cy) / I7.ry, d[3], d[5])
def ghost7():
    for d in (g7.DOTS or {}).values():
        y = (d[2] - I7.cy) / I7.ry
        if abs(y + 0.5) < 0.05: return ((d[1] - I7.cx) / I7.rx, y, d[3], d[5])
    return None
check(I7.style == 'dots', 'no texture support in the stub -> style dots')
# camera faces +y; x is right
for (ex, ey, want, what) in ((0, 20, (0, 0.5), 'front 20 m -> up, half radius'), (0, -20, (0, -0.5), 'behind -> down'),
                             (-20, 0, (-0.5, 0), 'left -> left'), (20, 0, (0.5, 0), 'right -> right'),
                             (0, -40 / 3, (0, -1 / 3), 'behind at 1/3 range -> on the inner ring')):
    g7.EX, g7.EY = ex, ey; run7(0.1); p = dot7()
    check(p is not None and abs(p[0] - want[0]) < 0.02 and abs(p[1] - want[1]) < 0.02, '%s %s' % (what, p and ('%.3f, %.3f' % p[:2])))
# the camera turned to face +x: an enemy at +x is now in front (up), one at +y is on the left
g7.FWDX, g7.FWDY = 1, 0
g7.EX, g7.EY = 20, 0; run7(0.1); p = dot7(); check(p and abs(p[0]) < 0.02 and abs(p[1] - 0.5) < 0.02, 'camera turned to +x: enemy at +x is up %s' % (p and '%.2f,%.2f' % p[:2]))
g7.EX, g7.EY = 0, 20; run7(0.1); p = dot7(); check(p and abs(p[0] + 0.5) < 0.02 and abs(p[1]) < 0.02, 'camera turned to +x: enemy at +y is left %s' % (p and '%.2f,%.2f' % p[:2]))
g7.FWDX, g7.FWDY = 0, 1
# beyond range: on the rim, faded
g7.EX, g7.EY = 0, -50; run7(0.1); p = dot7()
check(p and abs(p[1] + 1) < 0.02 and p[3] < 240 * 0.5, 'beyond range (50 m of 40) -> on the rim, faded (alpha %.0f)' % (p[3] if p else -1))
# sensitivity 2: 50 m is inside an 80 m range
r7.execute('HUD_CFG.sensitivity = 2.0'); run7(0.1); p = dot7()
check(p and abs(p[1] + 50 / 80) < 0.02 and p[3] >= 239, 'sensitivity 2: 50 m sits at 50/80 of the radius %s' % (p and '%.3f' % p[1]))
r7.execute('HUD_CFG.sensitivity = 1.0')
# dot sizes (v1.4.4): large class 44 px x 0.75/1/1.35 (gui = px / 1.2 wide) at 1440 tall: x 1440/1080
for name, px in (('small', 44 * 0.75), ('medium', 44), ('large', 44 * 1.35)):
    r7.execute('HUD_CFG.dot_size = "%s"' % name); g7.EX, g7.EY = 0, 10; run7(0.05); p = dot7()
    want = math.floor(px * 1440 / 1080 / 1.2 * g7.SIXTH_SENSE_CAL.d / 0.35)   # (the stub enemy is a Charger: large, 22 px at medium; box() floors)
    check(p and abs(p[2] - want) <= 1, 'dot_size %s = %.1f px (large class, Charger) (gui w %.0f, want %d)' % (name, px, p[2] if p else -1, want))
r7.execute('HUD_CFG.dot_size = "medium"')
# lost: lingers for the hold, then fades, then goes
g7.EX, g7.EY = 0, -20; run7(0.5); g7.EALIVE = False; run7(0.1); p = dot7()
check(p is not None and abs(p[1] + 0.5) < 0.02 and p[3] < 200, 'killed: a short fade where it fell (alpha %.0f)' % (p[3] if p else -1))
run7(0.3); check(dot7() is None, 'killed: gone within 0.4 s (no repeat_rate hold for the dead)')
# lost from tracking (ran out past range + 15 m): lingers for the hold, then fades
g7.EALIVE = True; g7.EX, g7.EY = 0, -20; run7(1.0); g7.EX, g7.EY = 0, -80; run7(0.5); p = ghost7()
check(p is not None and abs(p[1] + 0.5) < 0.02, 'lost from tracking: lingers at its last spot')
run7(1.6); p = ghost7(); check(p is not None and p[3] < 200, 'then fades (alpha %.0f)' % (p[3] if p else -1))
run7(1.0); check(ghost7() is None, 'gone after hold + fade (2.5 s)')
g7.EX, g7.EY = 0, -20; run7(1.0); r7.execute('HUD_CFG.repeat_rate = 2.0'); g7.EX, g7.EY = 0, -80; run7(1.0); check(ghost7() is not None, 'rate 2: still there at 1.0 s')
run7(0.4); check(ghost7() is None, 'rate 2: gone by 1.4 s (hold 0.5 + fade 0.75)')
r7.execute('HUD_CFG.repeat_rate = 1.0')
check(I7.rects <= 300, 'radar rects per frame %d (<= 300)' % I7.rects)
# texture path: the engine answers -> drawn with Gui.bitmap, no rim dots
EXTRA = '''
BITMAPS = 0
Application.can_get = function(kind, id) return (kind == "material" and id == "e2d6ed90906c1e8b") or (kind == "texture" and id == "03c798e2775e07a4") end
Gui.material = function(g, id) return {mat = id} end
Material = {set_texture = function(m, slot, tex) SET = {slot, tex} end}
Gui.bitmap = function(g, mat, p, sz, c) BITMAPS = BITMAPS + 1 end'''
r8 = radar_rt(EXTRA); u8 = r8.eval('update')
for _ in range(220): u8(0.016)
I8 = r8.globals().SIXTH_SENSE_RADAR
check(I8.style == 'texture' and r8.eval('BITMAPS') > 50 and r8.eval('SET[2]') == '03c798e2775e07a4' and I8.rects < 10, 'texture path: Gui.bitmap draws the disc (%s, %d bitmaps, %d rects)' % (I8.style, r8.eval('BITMAPS'), I8.rects))
lg8 = open(LOGDIR + '/sixth_sense.log').read()
check('radar: texture bitmap draw succeeded' in lg8, 'texture success logged')
r9 = radar_rt(EXTRA + '\nGui.bitmap = function() error("refused") end'); u9 = r9.eval('update')
for _ in range(220): u9(0.016)
I9 = r9.globals().SIXTH_SENSE_RADAR
lg9 = open(LOGDIR + '/sixth_sense.log').read()
check(I9.style == 'dots' and I9.rects > 100 and 'radar: texture bitmap draw failed: ' in lg9, 'bitmap refused -> rect dots, logged')
r10 = radar_rt(EXTRA + '\nHUD_CFG.radar_style = "dots"'); u10 = r10.eval('update')
for _ in range(220): u10(0.016)
check(r10.globals().SIXTH_SENSE_RADAR.style == 'dots' and r10.eval('BITMAPS') == 0, 'radar_style=dots never tries the texture')
# dot_size slider: 3 snaps, saved
r11 = radar_rt(); r11.execute('HUD_CFG.calibrate = true'); u11 = r11.eval('update'); g11 = r11.globals()
open(INI, 'a').write('calibrate=true\n')
r11 = radar_rt(); u11 = r11.eval('update'); g11 = r11.globals()
for _ in range(220): u11(0.016)
click_tab(r11, 2)
def run11(sec):
    for _ in range(max(1, int(sec / 0.016))): u11(0.016)
run11(3.5)
C11 = g11.HUD_CFG
tx, ty, tw, th = r11.eval('function(i) return SIXTH_SENSE_SLIDER(i) end')(4)
for frac, want in ((0.05, 'small'), (0.6, 'medium'), (0.95, 'large')):
    g11.MX, g11.MY = to_window(tx + tw * 0.5, ty + th / 2); run11(0.02); g11.LMB = 1; run11(0.02)
    g11.MX, g11.MY = to_window(tx + tw * frac, ty + th / 2); run11(0.05); g11.LMB = 0; run11(0.02)
    check(C11.dot_size == want, 'dot_size slider at %.2f -> %s (%s)' % (frac, want, C11.dot_size))
run11(1.0)
ini11 = open(INI).read(); v11 = dict(re.findall(r'^(\w+)=(.*)$', ini11, re.M))
check(v11.get('dot_size') == 'large' and v11.get('area_x1') == '2133.33' and v11.get('sensitivity') == '1.00' and v11.get('repeat_rate') == '1.00', 'dot_size saved; area, sensitivity and repeat_rate untouched')
for k in (12, 13, 14, 15): r11.execute('PRESSED[%d] = true' % k); run11(0.02)
check(C11.dot_size == 'large', 'no key changes dot_size')
# ---------------------------------------------------------------- v1.3.1: round disc, labels
open(INI, 'w').write('transform_ref_h=1440\n' + 'calibrate=true\nv110_migrated=true\nrange=40\narea_x0=0\narea_y0=0\narea_x1=2133.33\narea_y1=1080\narea_scale=1\nradar_fx=0.3\nradar_fy=0.6\n')
EXTRA2 = EXTRA.replace('Gui.material = function(g, id) return {mat = id} end', 'TEXOF = {}\nGui.material = function(g, id) return g end').replace(
  'Material = {set_texture = function(m, slot, tex) SET = {slot, tex} end}', 'Material = {set_texture = function(m, slot, tex) SET = {slot, tex}; TEXOF[m] = tex end}').replace(
  'Gui.bitmap = function(g, mat, p, sz, c) BITMAPS = BITMAPS + 1 end',
  'BM = {}\nGui.bitmap = function(g, mat, p, sz, c) BITMAPS = BITMAPS + 1; BM[TEXOF[g]] = {p[1], p[2], sz[1], sz[2]} end').replace(
  '(kind == "texture" and id == "03c798e2775e07a4")', '(kind == "texture")')
r12 = radar_rt(EXTRA2); u12 = r12.eval('update'); g12 = r12.globals()
for _ in range(260): u12(0.016)
click_tab(r12, 2)
for _ in range(3): u12(0.016)
I12 = g12.SIXTH_SENSE_RADAR; bm = tuple(g12.BM['03c798e2775e07a4'].values())
check(bm is not None and abs(bm[2] / bm[3] - 1.25) < 1e-6, 'disc bitmap 1.25x wider than tall in screen px by default (%.1f x %.1f)' % (bm[2], bm[3]))
rpx = I12.ry * 0.9333
check(abs(bm[3] - 2 * rpx / (250 / 256)) < 0.5 and abs(bm[2] - 2 * I12.rx * 1.2 / (250 / 256)) < 0.5, 'disc rim = the overlay ellipse on both axes (w %.1f, overlay %.1f)' % (bm[2], 2 * I12.rx * 1.2 / (250 / 256)))
# the disc's centre (bottom-left + half its px size mapped back to gui units) is the radar centre
check(abs(bm[0] + bm[2] / 2 / 1.2 - I12.cx) < 0.01 and abs(bm[1] + bm[3] / 2 / 0.9333 - I12.cy) < 0.01, 'disc centred on the overlay')
check(abs(I12.cx - 0.3 * 2133.33) < 0.1, 'the user placement keys are respected (radar_fx 0.3)')
L12 = g12.SIXTH_SENSE_LABELS
check(all(L12[k] == 'texture' for k in ('size', 'sensitivity', 'repeat_rate', 'dot_size')), 'slider labels drawn as word textures %s' % dict(L12))
check(L12['tab_display'] == 'texture' and L12['tab_settings'] == 'texture', 'tab buttons drawn with their word textures')
lg12 = open(LOGDIR + '/sixth_sense.log').read()
check('bitmap label sensitivity: draw succeeded' in lg12, 'label bitmap result logged')
# trim: radar_aspect 1.2 widens disc and overlay together
r12.execute('local function find(fn, name) for i = 1, 200 do local n, v = debug.getupvalue(fn, i); if not n then return end if n == name then return v end end end; find(find(update, "step"), "CFG").radar_aspect = 1.2')
for _ in range(3): u12(0.016)
bm = tuple(g12.BM['03c798e2775e07a4'].values())
check(abs(bm[2] / bm[3] - 1.2) < 1e-6 and abs(I12.rx * 1.2 / (I12.ry * 0.9333) - 1.2) < 1e-6, 'radar_aspect 1.2 trims disc and overlay alike')
# labels refused -> pixel font (rects), disc still a texture
r13 = radar_rt(EXTRA2.replace('Gui.bitmap = function(g, mat, p, sz, c)', 'Gui.bitmap = function(g, mat, p, sz, c) if TEXOF[g] ~= "03c798e2775e07a4" then error("no") end'))
u13 = r13.eval('update'); g13 = r13.globals()
for _ in range(260): u13(0.016)
click_tab(r13, 2)
for _ in range(3): u13(0.016)
L13 = g13.SIXTH_SENSE_LABELS
check(all(L13[k] == 'pixel' for k in ('size', 'sensitivity', 'repeat_rate', 'dot_size')) and g13.SIXTH_SENSE_RADAR.style == 'texture', 'label textures refused -> pixel font labels; the disc stays a texture')
lg13 = open(LOGDIR + '/sixth_sense.log').read()
check('error' not in lg13.lower().replace('last error nil', ''), 'no errors in the log')
# calibrate off: no labels, no slider drawing
r14 = radar_rt(EXTRA2); r14.execute('BMCOUNT = 0'); u14 = r14.eval('update')
open(INI, 'w').write('transform_ref_h=1440\n' + 'calibrate=false\nv110_migrated=true\n')
r14 = radar_rt(EXTRA2); u14 = r14.eval('update')
for _ in range(260): u14(0.016)
check(len(list(r14.globals().SIXTH_SENSE_LABELS.keys())) == 0 and list(r14.globals().BM.keys()) == ['03c798e2775e07a4'], 'calibrate off: only the disc bitmap, no labels')
# pixel font sanity: every glyph is 35 cells

# ---------------------------------------------------------------- v1.3.2: pods, fallers, persistence, death, sizes, aspect migration
open(INI, 'w').write('transform_ref_h=1440\n' + 'calibrate=false\nv110_migrated=true\nrange=40\narea_x0=10\narea_y0=20\narea_x1=900\narea_y1=700\narea_scale=1\nsensitivity=1.00\nrepeat_rate=1.00\nradar_fx=0.4\nradar_fy=0.7\nradar_size=0.3\nradar_aspect=1.0\nignore_ids=3828e2051aa9e897\n')
EXTRA32 = """
POD, STR, FALL, CAND, IGN, VOT, HARV = {}, {}, {}, {}, {}, {}, {}
P = { [enemy] = {0, -20, 0}, [POD] = {3, -15, 0}, [STR] = {-10, -10, 30}, [FALL] = {10, -10, 40}, [CAND] = {-15, -5, 0},
      [IGN] = {12, 5, 0}, [VOT] = {-5, 15, 0}, [HARV] = {5, 25, 0} }
NM = { [enemy] = "1a7fcdff98c664b0", [POD] = "583ecde0d7718126", [STR] = "19e18b46ec55d94a", [FALL] = "1a7fcdff98c664b0",
       [CAND] = "aabbccddeeff0011", [IGN] = "3828e2051aa9e897", [VOT] = "78e1497571012c47", [HARV] = "965eae5a51acdd4a" }
BYID = {}; for u, h in pairs(NM) do BYID[h] = BYID[h] or {}; table.insert(BYID[h], u) end
ALIVE, ASM, STATE = {}, {}, {}
World.units = function() local r = {cam, rt}; for u in pairs(NM) do r[#r + 1] = u end return r end
World.units_by_resource = function(w, id) return BYID[id] or {} end
Unit.resource_name = function(u) local h = NM[u] or (u == cam and "aaaaaaaaaaaaaaaa") or (u == rt and "46cab355bd8d4d37") or "1234567890abcdef"
  return setmetatable({}, {__tostring = function() return "#ID[" .. h .. "]" end}) end
Unit.alive = function(u) return ALIVE[u] ~= false end
Unit.has_animation_state_machine = function(u) if u == cam then return false end return ASM[u] ~= false end
Unit.animation_get_state = function(u) return STATE[u] or 5, 0, 0, 0 end
FR = 0
Unit.world_position = function(u) if u == rt then error("CRASH") end
  local p = P[u]; if not p then return stingray.Vector3(500, 500, 0) end
  if u == CAND and CFROZEN then return stingray.Vector3(p[1], p[2], p[3]) end
  return stingray.Vector3(p[1] + 0.1 * math.sin(FR * 0.7), p[2], p[3]) end
"""
r32 = radar_rt(EXTRA32); u32 = r32.eval('update'); g32 = r32.globals()
def run32(sec, fall=True):
    for _ in range(max(1, int(sec / 0.016))):
        r32.execute('FR = FR + 1; if P[CAND] then P[CAND][1] = CSTEP and (P[CAND][1] + CSTEP) or (-15 + (FR % 3) * 1.5) end; P[STR][3] = P[STR][3] - 0.4; P[FALL][3] = P[FALL][3] - 0.4' if fall else 'FR = FR + 1; if P[CAND] then P[CAND][1] = CSTEP and (P[CAND][1] + CSTEP) or (-15 + (FR % 3) * 1.5) end')
        u32(0.016)
def ent(name):
    u = g32[name]; return g32.HUD_S.T[u]
while g32.HUD_S.px is None or g32.HUD_S.t < (g32.HUD_S.settle_until or 0): run32(0.1, fall=False)   # (settle after the world change)
for _ in range(400):
    run32(0.016)
    if ent('CAND') is not None: break
r32.execute('CSTEP = 0.03'); run32(0.2); c = ent('CAND'); check(c is not None and not c.show, 'candidate: tracked but not shown before 0.5 s')
r32.execute('P[STR][3], P[FALL][3] = 30, 40'); run32(0.4)
check(ent('POD') is None, 'Hellpod 583ecde0d7718126 never tracked')
check(ent('IGN') is None, 'ini ignore_ids (3828e2051aa9e897) never tracked')
check(ent('CAND') is not None and ent('CAND').show, 'candidate shown after 0.5 s')
check(ent('FALL') is not None and not ent('FALL').show, 'a fast-falling non-flyer (25 m/s, no horizontal move) is hidden')
check(ent('STR') is not None and ent('STR').show, 'a diving Stingray (flyer) stays shown')
run32(2.5, fall=False)
check(ent('FALL').show, 'the faller shows again 2 s after it landed')
for nm, want in (('VOT', 'tiny'), ('enemy', 'large'), ('HARV', 'xlarge'), ('CAND', 'medium'), ('STR', 'medium')):
    check(ent(nm).size == want, 'size class %s -> %s (%s)' % (nm, want, ent(nm).size))
lg32 = open(LOGDIR + '/sixth_sense.log').read()
check('size: aabbccddeeff0011' in lg32 and 'not in the size map' in lg32, 'unknown kind logged with its size class')
# dot sizes: a Harvester's dot is 2.2/0.6 of a Voteless's
r32.execute('DOTS = {}'); run32(0.02, fall=False)
I32 = g32.SIXTH_SENSE_RADAR
def dot_at(x, y):
    for d in g32.DOTS.values():
        if abs(d[1] - (I32.cx + x / 40 * I32.rx)) < 3 and abs(d[2] - (I32.cy + y / 40 * I32.ry)) < 3: return d
r32.execute('DOTS = {}'); u32(0.016)
dv, dh = dot_at(-5, 15), dot_at(5, 25)
check(dv is not None and dh is not None and dh[3] / dv[3] > 3.0, 'Harvester dot much bigger than a Voteless dot (%s / %s)' % (dh and dh[3], dv and dv[3]))
# death by animation state (Voteless state 31): gone within ~0.4 s, no hold
r32.execute('STATE[VOT] = 31'); run32(0.05, fall=False)
check(not ent('VOT').show, 'Voteless in its death state (31) hidden at once')
run32(0.4, fall=False); r32.execute('DOTS = {}'); u32(0.016)
check(dot_at(-5, 15) is None, 'dead Voteless cleared within 0.5 s')
# death by state machine loss (and learning): the Harvester
r32.execute('ASM[HARV] = false'); run32(0.4, fall=False); r32.execute('DOTS = {}'); u32(0.016)
check(dot_at(5, 25) is None and ent('HARV') is None, 'state machine gone -> cleared within 0.4 s')
# stillness: the candidate stops (no jitter, no state change) -> hidden after still_hide 1 s, then shows again when it moves
r32.execute('CSTEP = 0; CFROZEN = true')
run32(1.3, fall=False)
check(ent('CAND') is not None and not ent('CAND').show, 'a body that stays still (no move, same state) is hidden after 1 s (%s)' % (ent('CAND') and ent('CAND').still))
r32.execute('P[CAND][1] = P[CAND][1] + 1'); run32(0.05, fall=False)
check(ent('CAND').show, 'it shows again once it moves')
# aspect migration: 1.0 -> 1.25 once; placement keys untouched
ini = open(INI).read()
check('radar_aspect=1.25' in ini and 'v132_migrated=true' in ini, 'ini radar_aspect 1.0 migrated to 1.25 once')
check(all(k in ini for k in ('area_x0=10', 'area_y0=20', 'area_x1=900', 'area_y1=700', 'radar_fx=0.4', 'radar_fy=0.7', 'radar_size=0.3', 'sensitivity=1.00', 'repeat_rate=1.00')), 'placement, sensitivity and repeat_rate keys untouched')
open(INI, 'w').write('transform_ref_h=1440\n' + ini.replace('radar_aspect=1.25', 'radar_aspect=1.0'))
r33 = radar_rt(); u33 = r33.eval('update')
for _ in range(5): u33(0.016)
check('radar_aspect=1.0' in open(INI).read(), 'migration runs only once (a later 1.0 stays)')

# ---------------------------------------------------------------- v1.4.0: rename, ini carried over, enemy structures
for f in ('sixth_sense.ini', 'rear_heat_hud.ini'):
    if os.path.exists(LOGDIR + '/' + f): os.remove(LOGDIR + '/' + f)
OLD = 'calibrate=false\nv110_migrated=true\nv132_migrated=true\nrange=40\narea_x0=11\narea_y0=22\narea_x1=933\narea_y1=744\nsensitivity=1.70\nrepeat_rate=0.60\ndot_size=large\nradar_fx=0.2\nradar_aspect=1.1\n'
open(LOGDIR + '/rear_heat_hud.ini', 'w').write('transform_ref_h=1440\n' + OLD)
r40 = radar_rt(); g40 = r40.globals(); u40 = r40.eval('update')
for _ in range(3): u40(0.016)
C40 = g40.HUD_CFG
check(os.path.exists(INI) and OLD in open(INI).read(), 'first load: rear_heat_hud.ini copied to sixth_sense.ini')
check(abs(C40.sensitivity - 1.7) < 1e-9 and abs(C40.repeat_rate - 0.6) < 1e-9 and C40.dot_size == 'large' and abs(C40.radar_fx - 0.2) < 1e-9 and abs(C40.radar_aspect - 1.1) < 1e-9 and abs(C40.area_x0 - 11) < 1e-9, 'its sliders, area and radar keys are used')
lg40 = open(LOGDIR + '/sixth_sense.log').read()
check('Sixth Sense 1.6.0 loaded' in lg40 and 'settings copied from' in lg40, 'log is sixth_sense.log, copy logged')
open(LOGDIR + '/rear_heat_hud.ini', 'w').write('sensitivity=3.00\n')
r41 = radar_rt(); u41 = r41.eval('update'); u41(0.016)
check(abs(r41.globals().HUD_CFG.sensitivity - 1.7) < 1e-9, 'once only: an existing sixth_sense.ini is not overwritten')
open(INI, 'w').write('transform_ref_h=1440\n' + 'calibrate=false\nv110_migrated=true\nv132_migrated=true\nrange=40\narea_x0=0\narea_y0=0\narea_x1=2133.33\narea_y1=1080\nstatic_ids=abcdef0123456789\n')
EXTRA40 = """
TUR, ALT, LATE, TT, UNK, USER = {}, {}, {}, {}, {}, {}
P = { [enemy] = {20, 20, 0}, [TUR] = {0, -20, 0}, [ALT] = {3, 3, 0}, [LATE] = {4, -4, 0}, [TT] = {20, 21, 0}, [UNK] = {-10, 10, 0}, [USER] = {-20, 0, 0} }
NM = { [enemy] = "1a7fcdff98c664b0", [TUR] = "2cf3488c4845f8bd", [ALT] = "ef85d6cf58e31d70", [LATE] = "ff5cc825b9571052",
       [TT] = "aeaef7a1851e6c9d", [UNK] = "0123abcd0123abcd", [USER] = "abcdef0123456789" }
NOASM = { [TUR] = true, [ALT] = true, [LATE] = true, [TT] = true, [UNK] = true, [USER] = true }
LIST = {cam, rt, enemy, TUR, ALT, TT, UNK, USER}
ALIVE, MESH = {}, {}
World.units = function() local r = {}; for i, u in ipairs(LIST) do r[i] = u end return r end
World.units_by_resource = function(w, id) if id == "1a7fcdff98c664b0" then return {enemy} end return {} end
Unit.resource_name = function(u) local h = NM[u] or (u == cam and "aaaaaaaaaaaaaaaa") or (u == rt and "46cab355bd8d4d37") or "1234567890abcdef"
  return setmetatable({}, {__tostring = function() return "#ID[" .. h .. "]" end}) end
Unit.alive = function(u) return ALIVE[u] ~= false end
Unit.has_animation_state_machine = function(u) if u == cam or NOASM[u] then return false end return true end
Unit.animation_get_state = function(u) if NOASM[u] then error("CRASH: state of a unit with no state machine") end return 5, 0, 0, 0 end
Unit.mesh = function(u, i) return MESH[u] end
Mesh = { visibility = function(m) return m.vis end }
FR = 0
Unit.world_position = function(u) if u == rt then error("CRASH") end
  local p = P[u]; if not p then return stingray.Vector3(500, 500, 0) end
  if NOASM[u] then return stingray.Vector3(p[1], p[2], p[3]) end
  return stingray.Vector3(p[1] + 0.1 * math.sin(FR * 0.7), p[2], p[3]) end
SQ = 0
local oldrect = Gui.rect
Gui.rect = function(g, p, sz, c) if c[2] == 255 and c[3] == 40 and c[4] == 40 and sz[1] / sz[2] > 0.9 then SQ = SQ + 1 end   -- (v1.5.3: red; diamond bars are not the dots' square shape)
if c[2] == 255 and c[3] == 110 and c[4] == 20 then ORANGE = (ORANGE or 0) + 1 end return oldrect(g, p, sz, c) end
"""
r42 = radar_rt(EXTRA40); u42 = r42.eval('update'); g42 = r42.globals()
def run42(sec):
    for _ in range(max(1, int(sec / 0.016))): r42.execute('FR = FR + 1; SQ = 0'); u42(0.016)
while g42.HUD_S.px is None or g42.HUD_S.passes < 2: run42(0.1)
r42.execute('table.insert(LIST, LATE)')      # a turret dropped in next to me after landing (a stratagem)
run42(3.0)
def e42(n): return g42.HUD_S.T[g42[n]]
check(e42('TUR') is not None and e42('TUR').kind == 'static' and e42('TUR').show and e42('TUR').size == 'medium', 'Cannon Turret (no state machine, never moves) tracked as static, shown, medium')
check(e42('USER') is not None and e42('USER').show, 'ini static_ids adds a structure')
check(g42.SQ >= 6 and not g42.ORANGE, 'structures drawn as red (255,40,40) diamonds, no orange (%d rects)' % g42.SQ)
check(e42('ALT') is None, 'our gatling sentry (ef85d6cf58e31d70) never shown')
check(e42('LATE') is None, 'a listed turret appearing near me after landing is taken as ours')
check(e42('TT') is None, 'a turret on a tracked Tank (within 6 m) is not a second dot')
lg42 = open(LOGDIR + '/sixth_sense.log').read()
check('static?: 0123abcd0123abcd at 14 m' in lg42, 'unknown non-animated kind near me logged with its distance')
check('static: 2cf3488c4845f8bd Cannon Turret at 20 m: shown' in lg42 and 'taken as ours' in lg42, 'shown and ours logged')
check('CRASH' not in lg42 and 'error' not in lg42.lower().replace('last error nil', ''), 'no state asked of a unit without a state machine; no errors')
# destroyed: first mesh hidden -> gone within 0.4 s; not alive -> gone
r42.execute('MESH[TUR] = {vis = false}'); run42(0.4)
check(e42('TUR') is None and g42.HUD_S.ghost[g42.TUR] is None, 'destroyed turret (mesh hidden) cleared within 0.4 s')
r42.execute('ALIVE[USER] = false'); run42(0.4)
check(e42('USER') is None, 'a structure no longer alive is dropped')

# ---------------------------------------------------------------- v1.4.1: panel on top and placed off the radar; size spread
open(INI, 'w').write('transform_ref_h=1440\n' + 'calibrate=true\nv110_migrated=true\nv132_migrated=true\nrange=40\narea_x0=0\narea_y0=600\narea_x1=900\narea_y1=1080\n')
r50 = radar_rt('\nLAYERS = {}\nlocal oldr = Gui.rect\nGui.rect = function(g, p, sz, c) LAYERS[#LAYERS + 1] = p[3]; return oldr(g, p, sz, c) end')
u50 = r50.eval('update'); g50 = r50.globals()
for _ in range(220): u50(0.016)
PN = tuple(r50.eval('function() return {SIXTH_SENSE_PANEL()} end')().values()); c50 = g50.SIXTH_SENSE_CAL
ov = max(0, min(PN[4], c50.x1) - max(PN[2], c50.x0)) * max(0, min(PN[5], c50.y1) - max(PN[3], c50.y0))
check(ov == 0 and (PN[0], PN[1]) != (0.03, 0.08), 'radar at the top-left: the panel moved off it (%.2f, %.2f)' % PN[:2])
r50.execute('LAYERS = {}'); u50(0.016)
L = list(g50.LAYERS.values())
check(990 in L and L.index(990) > max(i for i, v in enumerate(L) if v == 950) and min(L) >= 950, 'panel rects drawn last, on layer 990 above the radar (950)')
import re as _re
lua = open('src/sixth_sense.lua').read()
for h, want in (('67dc32dca4f02d33', 'large'), ('f22d027b37bef107', 'large'), ('965eae5a51acdd4a', 'xlarge'), ('d37e8d120d2836e3', 'xlarge'), ('78e1497571012c47', 'tiny')):
    m = _re.search(r'\["%s"\] = "(\w+)"' % h, lua); check(m and m.group(1) == want, 'size map %s -> %s' % (h, want))
check('CLASS_PX = { tiny = 12, medium = 24, large = 44, xlarge = 58 }  -- v1.4.4: dots start out about twice as big' in lua and 'DOT_MUL = { small = 0.75, medium = 1.0, large = 1.35 }' in lua, 'base sizes 12/24/44/58 px, x 0.75/1/1.35')

# ---------------------------------------------------------------- v1.4.2: load-time recovery
open(INI, 'w').write('transform_ref_h=1440\n' + 'calibrate=false\nv110_migrated=true\nv132_migrated=true\nv142_migrated=true\nv146_migrated=true\nradar_layouts=2560x1440:1.4000,0.3000,0.3000\n')
r60 = radar_rt(); u60 = r60.eval('update')
for _ in range(220): u60(0.016)
c60 = r60.globals().SIXTH_SENSE_CAL
check(c60.x1 <= c60.bw + 1e-6 and c60.cx < 1 and 'area clamped (load)' in open(LOGDIR + '/sixth_sense.log').read(), 'load: an offscreen radar (radar_cx 1.4) is clamped back in (%.3f)' % c60.cx)
open(INI, 'w').write('transform_ref_h=1440\n' + 'calibrate=false\nv110_migrated=true\nv132_migrated=true\nv142_migrated=true\nv146_migrated=true\nradar_layouts=2560x1440:9,0.3000,0.3000\n')
r61 = radar_rt(); u61 = r61.eval('update')
for _ in range(220): u61(0.016)
c61 = r61.globals().SIXTH_SENSE_CAL
check(abs(c61.cx - 0.5) < 1e-9 and 'no saved layout for 2560x1440' in open(LOGDIR + '/sixth_sense.log').read(), 'load: an invalid saved layout is ignored (centred default)')
# ---------------------------------------------------------------- v1.4.4: dot migration, visibility
open(INI, 'w').write('transform_ref_h=1440\n' + 'calibrate=false\nv110_migrated=true\nv132_migrated=true\nv142_migrated=true\nradar_cx=0.5\nradar_cy=0.7\nradar_d=0.35\ndot_size=small\n')
r70 = radar_rt(); u70 = r70.eval('update'); g70 = r70.globals()
for _ in range(220): u70(0.016)
ini70 = open(INI).read(); v70 = dict(re.findall(r'^(\w+)=(.*)$', ini70, re.M))
check(g70.HUD_CFG.dot_size == 'medium' and v70.get('dot_size') == 'medium' and v70.get('v144_migrated') == 'true' and v70.get('visibility') == 'shown' and v70.get('v145_migrated') == 'true' and '; visibility (v1.4.5)' in ini70, 'v1.4.4 migration: saved small -> medium once; visibility=shown written with its comment')
g70.HUD_CFG.dot_size = 'small'; r71 = None
open(INI, 'a').write('dot_size=small\n')
r71 = radar_rt(); u71 = r71.eval('update')
for _ in range(50): u71(0.016)
check(r71.globals().HUD_CFG.dot_size == 'small', 'v144_migrated=true: small chosen afterwards is kept')
def vis_rt(mode, extra=''):
    open(INI, 'w').write('transform_ref_h=1440\n' + 'calibrate=false\nv110_migrated=true\nv132_migrated=true\nv142_migrated=true\nv144_migrated=true\nradar_cx=0.5\nradar_cy=0.7\nradar_d=0.35\nvisibility=%s\n' % mode)
    rr = radar_rt(extra); uu = rr.eval('update')
    for _ in range(220): uu(0.016)
    return rr, uu
rv, uv = vis_rt('hidden'); Iv = rv.globals().SIXTH_SENSE_RADAR; Iv.dots = -1
uv(0.016); check(Iv.dots == -1, 'visibility=hidden: radar not drawn')
rv.execute('PRESSED[1] = true'); uv(0.016); rv.execute('PRESSED = {}'); Iv.dots = -1
for _ in range(5): uv(0.016)
check(rv.globals().SIXTH_SENSE_CAL.on and Iv.dots >= 0, 'visibility=hidden: F7 page opens and shows the radar')
for old in ('hud', 'always'):
    rv, uv = vis_rt(old); Iv = rv.globals().SIXTH_SENSE_RADAR; Iv.dots = -1; uv(0.016)
    vv = dict(re.findall(r'^(\w+)=(.*)$', open(INI).read(), re.M))
    check(rv.globals().HUD_CFG.visibility == 'shown' and vv.get('visibility') == 'shown' and vv.get('v145_migrated') == 'true' and Iv.dots >= 0, 'v1.4.5 migration: visibility=%s -> shown once, radar drawn' % old)
lua5 = open('src/sixth_sense.lua').read()
check('HUD_CANDS' not in lua5 and 'hud_shown' not in lua5 and 'HUDV' not in lua5 and 'visibility: probe' not in lua5, 'HUD probing code removed')
# the Shown / Hidden buttons on the Settings tab (mouse)
open(INI, 'w').write('transform_ref_h=1440\n' + 'calibrate=true\nv110_migrated=true\nv132_migrated=true\nv142_migrated=true\nv144_migrated=true\nv145_migrated=true\nradar_cx=0.5\nradar_cy=0.7\nradar_d=0.35\n')
r11 = radar_rt(); u11 = r11.eval('update'); g11 = r11.globals()
for _ in range(220): u11(0.016)
check(g11.HUD_CFG.visibility == 'shown', 'default visibility is shown')
click_tab(r11, 2); run11(0.5)
VR = r11.eval('function(i) return SIXTH_SENSE_VIS(i) end')
def click_vis(i):
    x, y, w, h = VR(i); g11.MX, g11.MY = to_window(x + w / 2, y + h / 2); run11(0.02); g11.LMB = 1; run11(0.02); g11.LMB = 0; run11(0.02)
for i, want in ((2, 'hidden'), (1, 'shown'), (2, 'hidden')):
    click_vis(i); check(g11.HUD_CFG.visibility == want, 'visibility button %d -> %s (%s)' % (i, want, g11.HUD_CFG.visibility))
run11(1.0)
check(dict(re.findall(r'^(\w+)=(.*)$', open(INI).read(), re.M)).get('visibility') == 'hidden', 'visibility saved to the ini')
for k in (12, 13, 14, 15): r11.execute('PRESSED[%d] = true' % k); run11(0.02)
check(g11.HUD_CFG.visibility == 'hidden', 'no key changes visibility')
PB = list(r11.eval('function() return {SIXTH_SENSE_PANEL()} end')().values())
x, y, w, h = VR(2); tx, ty, tw, th = r11.eval('function(i) return SIXTH_SENSE_SLIDER(i) end')(4)
check(PB[3] <= y and PB[4] >= x + w and y + h < ty, 'buttons under the last slider, inside the panel backing')
open(INI, 'w').write(open(INI).read().replace('visibility=hidden', 'visibility=shown'))   # (the next run's smoke test draws)
# ---------------------------------------------------------------- v1.4.6: viewport, per-resolution layouts
USC = '/tmp/rh/Arrowhead/Helldivers2/user_settings.config'
BASE146 = 'transform_ref_h=1440\ncalibrate=false\nv110_migrated=true\nv132_migrated=true\nv142_migrated=true\nv144_migrated=true\nv145_migrated=true\n'
def lay(rr): return {k: tuple(v.values()) for k, v in rr.globals().SIXTH_SENSE_LAYOUTS.items()}
def inilay(): m = re.search(r'^radar_layouts=(.*)$', open(INI).read(), re.M); return m.group(1) if m else None
def runr(rr, n):
    u = rr.eval('update')
    for _ in range(n): u(0.016)
# migration: radar_cx/cy/d -> the 3840x1080 layout (cy, d over the drawable share of the height at 3840x1080)
open(INI, 'w').write(BASE146 + 'radar_cx=0.4000\nradar_cy=0.5000\nradar_d=0.3000\n')
r80 = radar_rt('\nBBW, BBH = 3840, 1080'); runr(r80, 220); c80 = r80.globals().SIXTH_SENSE_CAL
yb38 = min(1, 1080 * 0.9333 * (1080 / 1440) / 1080)
L80 = lay(r80).get('3840x1080')
check(L80 and abs(L80[0] - 0.4) < 1e-6 and abs(L80[1] - 0.5 / yb38) < 1e-6 and abs(L80[2] - 0.3 / yb38) < 1e-6, 'v1.4.6 migration: radar_cx/cy/d -> the 3840x1080 layout %s' % (L80,))
check(inilay() and inilay().startswith('3840x1080:0.4000,') and 'v146_migrated=true' in open(INI).read() and '; radar_layouts (v1.4.6)' in open(INI).read(), 'migration saved once: radar_layouts=%s, v146_migrated, commented' % inilay())
check(c80.has_saved and abs(c80.cx - 0.4) < 1e-6 and abs(c80.cy - 0.5 / yb38) < 1e-6, 'at 3840x1080 the migrated layout is used (saved)')
lg80 = open(LOGDIR + '/sixth_sense.log').read()
check('viewport (load): screen 3840x1080' in lg80 and 'drawable rect x 0..3840' in lg80, 'viewport: line logged with screen, drawable rect and gui size')
# unseen resolution: from the nearest saved layout; moved there -> saved for it; going back restores each
r80.execute('BBW, BBH = 2560, 1440'); runr(r80, 80)
lg80 = open(LOGDIR + '/sixth_sense.log').read()
check(not c80.has_saved and abs(c80.cx - 0.5) < 1e-9 and abs(c80.cy - 0.5) < 1e-9 and abs(c80.d - 0.35) < 1e-9 and 'viewport: no saved layout for 2560x1440, using centered default' in lg80, 'unseen 2560x1440: centred default (no nearest-layout fallback), logged, not saved yet')
r80.execute('SIXTH_SENSE_CAL.cx, SIXTH_SENSE_CAL.cy, SIXTH_SENSE_CAL.d, SIXTH_SENSE_CAL.pos_set, SIXTH_SENSE_CAL.dirty, SIXTH_SENSE_CAL.on = 0.25, 0.4, 0.3, true, true, true'); runr(r80, 60)
L = lay(r80)
check('2560x1440' in L and abs(L['2560x1440'][0] - 0.25) < 1e-6 and '2560x1440:0.2500,0.4000,0.3000' in inilay() and abs(L['3840x1080'][0] - 0.4) < 1e-6, 'moved at 2560x1440: saved for 2560x1440 only (%s)' % inilay())
r80.execute('BBW, BBH = 3840, 1080'); runr(r80, 80)
check(c80.has_saved and abs(c80.cx - 0.4) < 1e-6 and abs(c80.d - 0.3 / yb38) < 1e-6, 'back to 3840x1080: its layout restored')
r80.execute('BBW, BBH = 2560, 1440'); runr(r80, 80)
check(c80.has_saved and abs(c80.cx - 0.25) < 1e-6 and abs(c80.cy - 0.4) < 1e-6, 'back to 2560x1440: its layout restored')
r80.execute('BBW, BBH = 1920, 1200'); runr(r80, 80)
check('viewport: no saved layout for 1920x1200, using centered default' in open(LOGDIR + '/sixth_sense.log').read() and abs(c80.cx - 0.5) < 1e-9 and abs(c80.cy - 0.5) < 1e-9, 'unseen 1920x1200 with other layouts saved: still the centred default')
# no layouts at all: default, centred in the drawable area
open(INI, 'w').write(BASE146 + 'v146_migrated=true\nradar_layouts=\n')
r81 = radar_rt('\nBBW, BBH = 1920, 1080'); runr(r81, 220); c81 = r81.globals().SIXTH_SENSE_CAL
check(abs(c81.cx - 0.5) < 1e-9 and abs(c81.cy - 0.5) < 1e-9 and 'viewport: no saved layout for 1920x1080, using centered default' in open(LOGDIR + '/sixth_sense.log').read(), 'no saved layouts: default, logged')
# drawable-area normalisation: render_resolution 1920x1080 in a 2560x1440 window -> the top-left 1920x1080 is drawable
os.makedirs(os.path.dirname(USC), exist_ok=True)
open(USC, 'w').write('render_settings = {\n render_resolution = [ 1920 1080 ]\n}\nscreen_resolution = [ 2560 1440 ]\n')
open(INI, 'w').write(BASE146 + 'v146_migrated=true\nradar_layouts=2560x1440:0.5000,0.5000,0.3000\n')
r82 = radar_rt(); runr(r82, 220); c82 = r82.globals().SIXTH_SENSE_CAL; vp = r82.globals().SIXTH_SENSE_VP
sy82 = 0.9333 * 1440 / 1440; hb = min(1080, 1080 * sy82)
cxp = (c82.x0 + c82.x1) / 2 * 1.2 * 1440 / 1440; cyp = (1080 - (c82.y0 + c82.y1) / 2) * sy82
check(vp.w == 1920 and abs(vp.h - hb) < 1e-6 and 'render_resolution 1920x1080' in vp.src, 'viewport: render_resolution 1920x1080 in a 2560x1440 window -> drawable %.0fx%.0f (%s)' % (vp.w, vp.h, vp.src))
check(abs(cxp - 960) < 1 and abs(cyp - hb / 2) < 1, 'a centred radar sits at the drawable centre (%.0f, %.0f px), not the window centre' % (cxp, cyp))
check(c82.x1 * 1.2 <= 1920 + 1, 'clamped inside the drawable area')
os.remove(USC)
# Reset (Display, two clicks) clears only the current resolution's layout; the Display tab shows the resolution
open(INI, 'w').write(BASE146.replace('calibrate=false', 'calibrate=true') + 'v146_migrated=true\nradar_layouts=2560x1440:0.3000,0.4000,0.3000;3840x1080:0.6000,0.5000,0.3000\n')
r83 = radar_rt(); runr(r83, 220); c83 = r83.globals().SIXTH_SENSE_CAL
check(c83.status == '2560x1440 SAVED LAYOUT', 'Display tab shows the resolution and SAVED LAYOUT (%s)' % c83.status)
click_tab(r83, 3); click_tab(r83, 3); runr(r83, 60)
check(inilay() == '3840x1080:0.6000,0.5000,0.3000' and abs(c83.cx - 0.5) < 1e-9 and abs(c83.cy - 0.5) < 1e-9 and not c83.has_saved, 'Reset cleared only 2560x1440 (%s)' % inilay())
runr(r83, 5); check(c83.status == '2560x1440 NO SAVED LAYOUT', 'then NO SAVED LAYOUT (%s)' % c83.status)
# ---------------------------------------------------------------- v1.4.7: HellForge profiles settings file
import shutil
HF = '/tmp/hf/userdata'
shutil.rmtree('/tmp/hf', ignore_errors=True)
def prof(name, scr, ren):
    d = HF + '/profiles/' + name; os.makedirs(d, exist_ok=True)
    open(d + '/user_settings.config', 'w').write('fullscreen = false\nborderless_fullscreen = false\nrender_resolution_factor_index = 3\nrender_settings = {\n}\nscreen_resolution = [ %d %d ]\nrender_resolution = [ %d %d ]\n' % (scr + ren))
HFENV = """
os.getenv = function(k) if k == "LOCALAPPDATA" then return "/tmp/hf/userdata/environment/Local" elseif k == "APPDATA" then return "/tmp/hf/userdata/environment/Roaming" end return "/tmp/rh" end
POPENS = 0
io.popen = function(cmd) POPENS = POPENS + 1; LASTCMD = cmd; return { read = function() return PROFILES or "" end, close = function() end } end
"""
prof('alt', (5120, 1440), (5120, 1440)); prof('default', (3840, 1080), (2960, 832))
open(INI, 'w').write(BASE146 + 'v146_migrated=true\nradar_layouts=\n')
r90 = radar_rt(HFENV + '\nBBW, BBH = 3840, 1080\nPROFILES = "alt\\r\\ndefault\\r\\n"'); runr(r90, 220)
c90 = r90.globals().SIXTH_SENSE_CAL; vp90 = r90.globals().SIXTH_SENSE_VP
lg90 = open(LOGDIR + '/sixth_sense.log').read()
check(vp90.rw == 2960 and vp90.rh == 832 and 'profiles/default/user_settings.config (HellForge profile, 2 found, screen_resolution matches the window' in lg90, 'HellForge: of 2 profiles the one whose screen_resolution is the window (default, 3840x1080) is used, logged')
check('profiles' in (r90.eval('LASTCMD') or '') and 'Roaming/Arrowhead/Helldivers2/user_settings.config' in lg90, 'AppData tried first (not found), then the profiles folder listed')
sy90 = 0.9333 * 1080 / 1440; hb90 = min(832, 1080 * sy90)
check(vp90.w == 2960 and abs(vp90.h - hb90) < 1e-6 and 'render 2960x832' in lg90 and 'drawable rect x 0..2960' in lg90, 'render 2960x832 in a 3840x1080 window: drawable %.0fx%.0f (the gui clip %.0f is lower)' % (vp90.w, vp90.h, 1080 * sy90))
sx90 = 1.2 * 1080 / 1440
cx90 = (c90.x0 + c90.x1) / 2 * sx90; cy90 = (1080 - (c90.y0 + c90.y1) / 2) * sy90
check(abs(cx90 - 1480) < 1 and abs(cy90 - hb90 / 2) < 1 and c90.x1 * sx90 <= 2960 + 1 and (1080 - c90.y0) * sy90 <= hb90 + 1, 'centred radar at the drawable centre (%.0f, %.0f px), inside 2960x%.0f' % (cx90, cy90, hb90))
# no profile matches the window: the first listed (newest folder) when there are no modification times
r91 = radar_rt(HFENV + '\nBBW, BBH = 1920, 1080\nPROFILES = "alt\\ndefault\\n"'); runr(r91, 220)
check(r91.globals().SIXTH_SENSE_VP.rw == 5120 and 'first listed' in open(LOGDIR + '/sixth_sense.log').read(), 'no screen_resolution match: newest-listed profile used')
# lfs present: the most recently modified wins
os.utime(HF + '/profiles/alt/user_settings.config', (1000, 1000)); os.utime(HF + '/profiles/default/user_settings.config', (2000, 2000))
LFS = '\nlfs = { dir = function(d) local t, i = {"alt", "default"}, 0; return function() i = i + 1; return t[i] end end, attributes = function(p, a) local f = io.popen and nil; if p:find("alt") then return 1000 end return 2000 end }'
r92 = radar_rt(HFENV + LFS + '\nBBW, BBH = 1920, 1080'); runr(r92, 220)
check(r92.globals().SIXTH_SENSE_VP.rw == 2960 and 'most recently modified' in open(LOGDIR + '/sixth_sense.log').read() and r92.eval('POPENS') == 0, 'no match, lfs times: the most recently modified profile (default) used, no dir listing')
# AppData file present: used first, profiles not listed
os.makedirs('/tmp/hf/userdata/environment/Roaming/Arrowhead/Helldivers2', exist_ok=True)
open('/tmp/hf/userdata/environment/Roaming/Arrowhead/Helldivers2/user_settings.config', 'w').write('screen_resolution = [ 3840 1080 ]\nrender_resolution = [ 1920 1080 ]\n')
r93 = radar_rt(HFENV + '\nBBW, BBH = 3840, 1080\nPROFILES = "default\\n"'); runr(r93, 220)
check(r93.globals().SIXTH_SENSE_VP.rw == 1920 and r93.eval('POPENS') == 0 and 'Roaming/Arrowhead/Helldivers2/user_settings.config' in r93.globals().SIXTH_SENSE_VP.src + open(LOGDIR + '/sixth_sense.log').read(), 'AppData user_settings.config found: used first, profiles not searched')
# render >= window: the whole window is drawable
open('/tmp/hf/userdata/environment/Roaming/Arrowhead/Helldivers2/user_settings.config', 'w').write('render_resolution = [ 3840 1080 ]\n')
r94 = radar_rt(HFENV + '\nBBW, BBH = 3840, 1080'); runr(r94, 220)
check(r94.globals().SIXTH_SENSE_VP.w == 3840 and 'window (back buffer)' in r94.globals().SIXTH_SENSE_VP.src, 'render_resolution = window: the whole window is drawable')
shutil.rmtree('/tmp/hf', ignore_errors=True)
# ---------------------------------------------------------------- v1.5.0: Mark and Pick removed
check('SIXTH_SENSE_PICK' not in lua and 'mark_click' not in lua and 'pick_click' not in lua and 'picked_ids' not in lua and 'tab_mark' not in lua and 'tab_pick' not in lua, 'v1.5.0: no Mark / Pick code, labels or picked_ids')
open(INI, 'w').write(BASE146.replace('calibrate=false', 'calibrate=true') + 'v146_migrated=true\nradar_layouts=\n')
rp = radar_rt(''); runr(rp, 220)
for i in (4, 5): click_tab(rp, i); runr(rp, 2)
lgp = open(LOGDIR + '/sixth_sense.log').read()
check(not re.search(r' (MARK|PICK)\b', lgp) and 'MARKED' not in lgp and 'picked_ids' not in open(INI).read(), 'v1.5.0: clicks where Mark / Pick were log nothing; no picked_ids in the ini')
# ---------------------------------------------------------------- v1.5.1/v1.5.2: radar colours (mouse only), the radar display only
PAL = {'green': (90, 255, 140), 'white': (235, 235, 235), 'yellow': (255, 225, 60), 'red': (255, 70, 60), 'light_blue': (110, 200, 255)}
ORDER = ['green', 'white', 'yellow', 'red', 'light_blue']
FINDCFG = 'local function find(fn, name) for i = 1, 200 do local n, v = debug.getupvalue(fn, i); if not n then return end if n == name then return v end end end\nHUD_CFG = find(find(update, "step"), "CFG")'
COLX = '\nCOLS = {}\nlocal gr = Gui.rect\nGui.rect = function(g, p, sz, c) COLS[c[2] .. "," .. c[3] .. "," .. c[4]] = true; if c[2] == 255 and c[3] == 40 and c[4] == 40 and sz[1] / sz[2] > 0.9 then TURRED = (TURRED or 0) + 1 end return gr(g, p, sz, c) end\nHUD_CFG.radar_style = "dots"\nTURX = {}\nlocal wu = World.units\nWorld.units = function(w) local t = wu(w); t[#t + 1] = TURX; return t end\nlocal rn = Unit.resource_name\nUnit.resource_name = function(u) if u == TURX then return setmetatable({}, {__tostring = function() return "#ID[2cf3488c4845f8bd]" end}) end return rn(u) end\nlocal wp = Unit.world_position\nUnit.world_position = function(u) if u == TURX then return stingray.Vector3(-15, 5, 0) end return wp(u) end\nlocal am = Unit.has_animation_state_machine\nUnit.has_animation_state_machine = function(u) if u == TURX then return false end return am(u) end'
open(INI, 'w').write(BASE146.replace('calibrate=false', 'calibrate=true') + 'v146_migrated=true\nradar_layouts=\n')
rc = radar_rt(COLX); uc = rc.eval('update'); gc = rc.globals(); CC = gc.HUD_CFG
def runc(sec):
    for _ in range(max(1, int(sec / 0.016))): uc(0.016)
def cols(): rc.execute('COLS = {}; TURRED = 0'); runc(0.1); return set(k for k, v in gc.COLS.items())
def inival(k): return dict(re.findall(r'^(\w+)=(.*)$', open(INI).read(), re.M)).get(k)
runc(3.5)
check(CC.radar_color == 'green', 'default radar_color is green')
cs = cols(); check('90,255,140' in cs and '255,40,40' in cs, 'default: green rings / cross hairs, red enemy dots')
click_tab(rc, 2); runc(0.5)
tx, ty, tw, th = rc.eval('function(i) return SIXTH_SENSE_SLIDER(i) end')(5)
for name in ['white', 'yellow', 'red', 'light_blue', 'green']:
    frac = min(max(ORDER.index(name) / 4, 0.02), 0.98)
    gc.MX, gc.MY = to_window(tx + tw * 0.5, ty + th / 2); runc(0.02); gc.LMB = 1; runc(0.02)
    gc.MX, gc.MY = to_window(tx + tw * frac, ty + th / 2); runc(0.05); gc.LMB = 0; runc(1.2)
    ring_ = PAL[name]; cs = cols()
    check(CC.radar_color == name and inival('radar_color') == name and '; radar_color (v1.5.1)' in open(INI).read(), 'Radar color slider -> %s, saved with its comment (ini %s)' % (name, inival('radar_color')))
    others = [PAL[o] for o in ORDER if o != name]
    check('%d,%d,%d' % ring_ in cs and '255,40,40' in cs and not any('%d,%d,%d' % o in cs for o in others), '%s: rings / cross hairs %s only; enemy dots still red 255,40,40' % (name, ring_))
    check('255,110,20' not in cs and gc.TURRED >= 3, '%s: turret diamonds red 255,40,40 (%d bars), no orange' % (name, gc.TURRED))
CC.radar_color = 'yellow'
for k in range(2, 16): rc.execute('PRESSED[%d] = true' % k); runc(0.02); rc.execute('PRESSED = {}'); runc(0.02)
check(CC.radar_color == 'yellow', 'radar_color is mouse only: no key changes it')
rc.execute('SIXTH_SENSE_CAL.dirty = true'); runc(1.2)
r2c = runtime(); r2c.execute(FINDCFG)
check(r2c.globals().HUD_CFG.radar_color == 'yellow', 'restart loads radar_color=yellow from the ini')
click_tab(rc, 3); runc(0.1); click_tab(rc, 3); runc(1.2)
check(CC.radar_color == 'green' and inival('radar_color') == 'green', 'Reset on Settings restores radar_color=green (saved)')
open(INI, 'a').write('radar_color=purple\n')
r3c = runtime(); r3c.execute(FINDCFG)
check(r3c.globals().HUD_CFG.radar_color == 'green', 'unknown radar_color -> green')
TEXC = EXTRA.replace('Gui.bitmap = function(g, mat, p, sz, c) BITMAPS = BITMAPS + 1 end', 'TINTS = {}\nGui.bitmap = function(g, mat, p, sz, c) BITMAPS = BITMAPS + 1; TINTS[c[2] .. "," .. c[3] .. "," .. c[4]] = true end') + '\nHUD_CFG.radar_color = "light_blue"'
rt_ = radar_rt(TEXC); ut_ = rt_.eval('update')
for _ in range(220): ut_(0.016)
tints = set(k for k, v in rt_.globals().TINTS.items())
check(rt_.globals().SIXTH_SENSE_RADAR.style == 'texture' and '110,200,255' in tints, 'texture disc tinted light_blue (%s)' % sorted(tints))
# ---------------------------------------------------------------- v1.5.4: control scheme (keyboard / mouse or controller)
PADX = '''
PADON, PADB = true, {}
local NM = {"a", "b", "x", "y", "d_up", "d_down", "d_left", "d_right", "left_shoulder", "right_shoulder", "back", "start"}
Pad1 = {active = function() return PADON end, num_buttons = function() return #NM end, button_name = function(i) return NM[i + 1] end,
  button = function(i) return PADB[NM[i + 1]] and 1 or 0 end, name = function() return "Test Pad" end}'''
open(INI, 'w').write(BASE146.replace('calibrate=false', 'calibrate=true') + 'v146_migrated=true\nradar_layouts=\n')
rq = radar_rt(PADX); uq = rq.eval('update'); gq = rq.globals(); CQ = gq.HUD_CFG; KQ = gq.SIXTH_SENSE_CAL; PQ = gq.SIXTH_SENSE_PAD
def runq(sec):
    for _ in range(max(1, int(sec / 0.016))): uq(0.016)
def pad(name, hold=0.05): gq.PADB[name] = True; runq(hold); gq.PADB[name] = False; runq(0.05)
def f7(): rq.execute('PRESSED[1] = true'); uq(0.016); rq.execute('PRESSED = {}'); runq(0.05)
def qtab(): return rq.eval('SIXTH_SENSE_TAB()')
def ival(k): return dict(re.findall(r'^(\w+)=(.*)$', open(INI).read(), re.M)).get(k)
runq(3.5)
check(CQ.control == 'keyboard_mouse', 'default control is keyboard_mouse')
# keyboard / mouse mode: the pad is never read, its buttons do nothing
on0, t0 = KQ.on, qtab()
pad('back', 2.5); pad('right_shoulder'); pad('b')
check(KQ.on == on0 and qtab() == t0 and PQ.n is None, 'keyboard / mouse mode: View held 2.5 s, RB and B do nothing; the pad is not read')
f7(); check(KQ.on != on0, 'keyboard / mouse mode: F7 toggles the page'); f7(); check(KQ.on == on0, 'F7 again')
# pick Controller with the mouse (Settings tab)
click_tab(rq, 2); runq(0.2)
x, y, w, h = rq.eval('function(i) return SIXTH_SENSE_CTL(i) end')(2)
gq.MX, gq.MY = to_window(x + w / 2, y + h / 2); uq(0.016); gq.LMB = 1; uq(0.016); gq.LMB = 0; runq(1.2)
check(CQ.control == 'controller' and ival('control') == 'controller' and '; control (v1.5.4)' in open(INI).read(), 'Controls: the Controller button (mouse) sets control=controller, saved with its comment')
runq(2.5)
check(PQ.n == 1 and PQ.name == 'Test Pad', 'controller mode: Pad1 found by its button names')
# controller mode: keys and the mouse do nothing
on0, t0 = KQ.on, qtab(); cx0 = KQ.cx
f7(); check(KQ.on == on0, 'controller mode: F7 does not toggle the page')
click_tab(rq, 1); check(qtab() == t0, 'controller mode: a mouse click on a tab does nothing')
rq.execute('HELD[1] = true'); runq(3.5); rq.execute('HELD = {}'); runq(0.05)
check('F7 held 3 s' not in open(LOGDIR + '/sixth_sense.log').read(), 'controller mode: F7 held 3 s does not reset')
# the pad drives the page
pad('b'); check(not KQ.on, 'B closes the page')
pad('back', 2.3); check(KQ.on and qtab() == 'display', 'View held 2 s opens the page on Display')
cx0, d0 = KQ.cx, KQ.d
for k in range(2, 6): rq.execute('PRESSED[%d] = true' % k); runq(0.02); rq.execute('PRESSED = {}'); runq(0.02)
check(KQ.cx == cx0 and KQ.d == d0, 'controller mode: arrow keys do not move the radar')
pad('d_right'); check(KQ.cx > cx0, 'D-pad right moves the radar right (%.4f -> %.4f)' % (cx0, KQ.cx))
pad('y'); check(KQ.d > d0, 'Y makes it bigger (%.3f -> %.3f)' % (d0, KQ.d))
runq(1.2); check('dropped (controller)' in open(LOGDIR + '/sixth_sense.log').read(), 'let go: saved like a mouse drop')
pad('right_shoulder'); check(qtab() == 'settings', 'RB: Settings tab')
pad('d_down', 0.05); pad('d_down', 0.05); pad('d_down', 0.05)   # row 4: dot size
ds0 = CQ.dot_size; pad('d_right'); check(KQ.sel == 4 and CQ.dot_size != ds0, 'D-pad picks the Dot size row, right changes it (%s -> %s)' % (ds0, CQ.dot_size))
pad('d_down'); pad('d_right'); check(CQ.radar_color == 'white', 'Radar color row: right -> white')
pad('d_down'); pad('d_right'); check(CQ.visibility == 'hidden', 'Visibility row: right -> Hidden'); pad('d_left'); check(CQ.visibility == 'shown', 'left -> Shown')
runq(0.3); check(gq.SIXTH_SENSE_CAL.sel_drawn and gq.SIXTH_SENSE_CAL.sel_drawn > 0, 'the selected row is framed')
pad('x'); pad('x'); runq(0.5)
check(CQ.radar_color == 'green' and CQ.dot_size == 'medium' and CQ.control == 'controller', 'X twice: Settings reset (green, medium); control kept')
# restart keeps controller
rq2 = runtime(); rq2.execute('local function find(fn, name) for i = 1, 200 do local n, v = debug.getupvalue(fn, i); if not n then return end if n == name then return v end end end\nHUD_CFG = find(find(update, "step"), "CFG")')
check(rq2.globals().HUD_CFG.control == 'controller', 'restart loads control=controller')
# View held 5 s: layout reset
pad('back', 5.3); check('layout reset (controller View held 5 s)' in open(LOGDIR + '/sixth_sense.log').read() and KQ.on, 'View held 5 s resets the layout, page open')
# no pad: keyboard / mouse still work (never locked out)
gq.PADON = False; runq(0.3)
on0 = KQ.on; f7(); check(PQ.n is None and KQ.on != on0, 'controller mode with no pad connected: F7 still works')
gq.PADON = True; runq(2.5)
# back to keyboard / mouse from the pad (Controls row, left)
if not KQ.on: pad('back', 2.3)
if qtab() != 'settings': pad('right_shoulder')
for _ in range(8): pad('d_down')
KQ.sel = 7; pad('d_left'); runq(1.2)
check(CQ.control == 'keyboard_mouse' and ival('control') == 'keyboard_mouse', 'Controls row on the pad: left -> keyboard_mouse, saved')
on0 = KQ.on; pad('b'); check(KQ.on == on0, 'back in keyboard / mouse mode: B does nothing')
# ---------------------------------------------------------------- v1.5.5: Help (README.md + CONTROLS.md, embedded at build time)
import sys as _sys; _sys.path.insert(0, 'tools'); import help_pages
HTXT = open('src/sixth_sense.lua').read()
hb = HTXT[HTXT.index(help_pages.BEGIN):HTXT.index(help_pages.END)]
check('==== README (README.md) ====' in hb and '==== CONTROLS (CONTROLS.md) ====' in hb and '## Install' in hb and '## Controller' in hb, 'README.md and CONTROLS.md embedded as text in the Lua')
src_now = open('src/sixth_sense.lua').read(); help_pages.generate(write=True); check(open('src/sixth_sense.lua').read() == src_now, 'the embedded help is current with README.md / CONTROLS.md (build regenerates it)')
HPX = EXTRA.replace('Application.can_get = function(kind, id) return (kind == "material" and id == "e2d6ed90906c1e8b") or (kind == "texture" and id == "03c798e2775e07a4") end', 'Application.can_get = function(kind, id) return true end') + '\nHUD_CFG.radar_style = "dots"\nHTEX = {}\nlocal st = Material.set_texture\nMaterial.set_texture = function(m, slot, tex) HTEX[tex] = true; return st(m, slot, tex) end'
open(INI, 'w').write(BASE146.replace('calibrate=false', 'calibrate=true') + 'v146_migrated=true\nradar_layouts=\n')
rh = radar_rt(HPX + PADX.replace('"back", "start"', '"back", "right_thumb"')); uh = rh.eval('update'); gh = rh.globals(); KH = gh.SIXTH_SENSE_CAL
def runh(sec):
    for _ in range(max(1, int(sec / 0.016))): uh(0.016)
def help_(): return tuple(rh.eval('function() return {SIXTH_SENSE_HELP()} end')().values())
def clickh(gx, gy): gh.MX, gh.MY = to_window(gx, gy); uh(0.016); gh.LMB = 1; uh(0.016); gh.LMB = 0; runh(0.05)
runh(3.5)
check('github.com/lankynibbs/SixthSense' in gh.SIXTH_SENSE_HELP_TEXT, 'v1.5.6: in-game Help carries the public repo URL')
check(gh.SIXTH_SENSE_HELP_TEXT and 'Install' in gh.SIXTH_SENSE_HELP_TEXT and 'Controller' in gh.SIXTH_SENSE_HELP_TEXT, 'HELP_TEXT readable in the mod (README + CONTROLS)')
n_pages = help_()[2]; check(n_pages >= 2, 'help pages: %d' % n_pages)
cx0, d0, lay0 = KH.cx, KH.d, (dict(re.findall(r'^(\w+)=(.*)$', open(INI).read(), re.M)).get('radar_layouts'))
check(not help_()[0], 'Help closed at start')
click_tab(rh, 4); runh(0.2)
check(help_()[0] and help_()[1] == 1 and (KH.help_drawn or 0) > 0, 'the Help button (mouse) opens Help on page 1, drawn as a texture')
hex1 = [k for k in gh.HTEX.keys()]
check(any(h in hb for h in hex1 if isinstance(h, str) and len(h) == 16 and h != '03c798e2775e07a4'), 'a help page texture id from the embedded list was drawn')
hx, hy, hw, hh = list(rh.eval('function() return {SIXTH_SENSE_HELP_RECT()} end')().values())[:4]
clickh(hx + hw * 0.75, hy + hh / 2); check(help_()[1] == 2, 'click on the right half: page 2')
clickh(hx + hw * 0.25, hy + hh / 2); check(help_()[1] == 1, 'click on the left half: page 1')
gh.MX, gh.MY = to_window(hx + hw / 2, hy + hh / 2); gh.WHEEL = -1; uh(0.016); gh.WHEEL = 0; runh(0.05); check(help_()[1] == 2, 'wheel down: next page')
for k in range(2, 16): rh.execute('PRESSED[%d] = true' % k); runh(0.02); rh.execute('PRESSED = {}'); runh(0.02)
check(help_()[0] and help_()[1] == 2 and KH.cx == cx0, 'keys (arrows, [ ] ; \') do nothing to Help or the radar (mouse only)')
clickh(2, 2); check(not help_()[0], 'a click outside the page closes Help')
check(KH.cx == cx0 and KH.d == d0, 'closing Help leaves the radar where it was')
click_tab(rh, 4); runh(0.1); click_tab(rh, 3); runh(0.1)
check(not help_()[0] and not rh.eval('SIXTH_SENSE_RESET')() and KH.d == d0, 'a click on Reset while Help is open only closes Help (Reset not armed)')
click_tab(rh, 4); runh(0.1); click_tab(rh, 4); runh(0.1); check(not help_()[0], 'Help button again closes it')
runh(1.2); check(dict(re.findall(r'^(\w+)=(.*)$', open(INI).read(), re.M)).get('radar_layouts') == lay0, 'radar settings unchanged by Help')
# controller: R3 opens, RB / D-pad turn pages, B closes Help (the page stays open)
gh.HUD_CFG.control = 'controller'; runh(2.5)
def padh(name, hold=0.05): gh.PADB[name] = True; runh(hold); gh.PADB[name] = False; runh(0.05)
padh('right_thumb'); check(help_()[0], 'controller: R3 opens Help')
p0 = help_()[1]; padh('right_shoulder'); check(help_()[1] == min(p0 + 1, n_pages), 'RB: next help page')
padh('d_left'); check(help_()[1] == p0, 'D-pad left: previous help page')
padh('b'); check(not help_()[0] and KH.on, 'B closes Help; the F7 page stays open')
gh.HUD_CFG.control = 'keyboard_mouse'; runh(0.2)
os.remove(LOGDIR + '/rear_heat_hud.ini')
print('calibration test:', 'PASS' if not fails else 'FAIL %d' % len(fails))
if fails: raise SystemExit(1)
