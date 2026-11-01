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
ecx = (300 + 0.5 * 1066.67) * SX / SW; ecy = (GT - (971.45 - 0.78 * 771.45)) * SY / SH; ed = 0.35 * 771.45 * SY / SH
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
check(abs(c.cx - (f0[0] + 200 / RW)) < 1e-3 and abs(c.cy - (f0[1] - 100 / RH)) < 1e-3 and c.d == f0[2], 'grab handle drag moved the radar by 200, 100 window px (%.4f, %.4f)' % (c.cx - f0[0], c.cy - f0[1]))
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
check(abs(c.cx - 0.5) < 1e-6 and abs(c.cy - 0.75 * yb) < 1e-4 and abs(c.d - 0.35) < 1e-6 and 'radar_cx=0.5000' in open(INI).read(), 'Reset confirmed on Display: centred, 75%% down, default size, saved (%.3f, %.3f)' % (c.cx, c.cy))
# drag far down and right: clamped inside the drawable screen
gx_, gy_, gw_, gh_ = grab(); drag(gx_ + gw_ / 2, gy_ + gh_ / 2, 800, -800, 20)
check(c.y0 >= -1e-6 and c.x1 <= c.bw + 1e-6, 'drag down-right: clamped (bottom gy %.2f, right %.1f of %.1f)' % (c.y0, c.x1, c.bw))
lg = open(LOGDIR + '/sixth_sense.log').read()
check('drawable gui bounds' in lg and 'area clamped (move)' in lg, 'bounds and clamp logged')
# resolution change: 2560x1440 -> 3840x1080: same screen fractions, new transform logged
f0 = fr(); G.BBW, G.BBH = 3840, 1080; frames(70)
check(abs(c.cx - f0[0]) < 1e-9 and abs(c.cy - f0[1]) < 0.01 and 'transform (resolution change from 2560x1440): screen 3840x1080' in open(LOGDIR + '/sixth_sense.log').read(), 'resolution change: the radar keeps its screen fractions; transform logged')
check(abs(c.bw - 3840 / (1.2 * 1080 / 1440)) < 1e-6, 'height model: sx_scale scales with the height (visible gui %.1f wide)' % c.bw)
G.BBW, G.BBH = None, None; frames(70)
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
check('Sixth Sense 1.4.5 loaded' in lg40 and 'settings copied from' in lg40, 'log is sixth_sense.log, copy logged')
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
Gui.rect = function(g, p, sz, c) if c[2] == 255 and c[3] == 110 and c[4] == 20 then SQ = SQ + 1 end return oldrect(g, p, sz, c) end
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
check(g42.SQ >= 6, 'structures drawn as orange-red diamonds (%d rects)' % g42.SQ)
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
open(INI, 'w').write('transform_ref_h=1440\n' + 'calibrate=false\nv110_migrated=true\nv132_migrated=true\nv142_migrated=true\nradar_cx=1.40\nradar_cy=0.30\nradar_d=0.30\n')
r60 = radar_rt(); u60 = r60.eval('update')
for _ in range(220): u60(0.016)
c60 = r60.globals().SIXTH_SENSE_CAL
check(c60.x1 <= c60.bw + 1e-6 and c60.cx < 1 and 'area clamped (load)' in open(LOGDIR + '/sixth_sense.log').read(), 'load: an offscreen radar (radar_cx 1.4) is clamped back in (%.3f)' % c60.cx)
open(INI, 'w').write('transform_ref_h=1440\n' + 'calibrate=false\nv110_migrated=true\nv132_migrated=true\nv142_migrated=true\nradar_cx=9\nradar_cy=0.30\nradar_d=0.30\n')
r61 = radar_rt(); u61 = r61.eval('update')
for _ in range(220): u61(0.016)
c61 = r61.globals().SIXTH_SENSE_CAL
check(abs(c61.cx - 0.5) < 1e-9 and 'invalid position' in open(LOGDIR + '/sixth_sense.log').read(), 'load: an invalid position is reset')
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
os.remove(LOGDIR + '/rear_heat_hud.ini')
print('calibration test:', 'PASS' if not fails else 'FAIL %d' % len(fails))
if fails: raise SystemExit(1)
