"""Rear Heat HUD slider labels: one texture per word (white, dark outline, transparent), Poppins Bold (SIL OFL,
from Treasure-Radar/src/fonts). Drawn 4x and scaled down. Writes assets/label_<key>.png and prints the Lua table."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont
HERE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HERE.parent / 'BingusSharedLoader/scripts'))
from archive import resource_hash
FONT = HERE.parent / 'Treasure-Radar/src/fonts/Poppins-Bold.ttf'
LABELS = [('tab_display', 'Display'), ('tab_settings', 'Settings'), ('tab_reset', 'Reset'), ('size', 'Size'), ('sensitivity', 'Sensitivity'), ('repeat_rate', 'Repeat rate'), ('dot_size', 'Dot size'), ('radar_color', 'Radar color'), ('visibility', 'Visibility'), ('vis_shown', 'Shown'), ('vis_hidden', 'Hidden')]
H = 48                                   # texture height; text cap about 30 px

def label(text):
    k = 4; f = ImageFont.truetype(str(FONT), 30 * k)
    w = int(ImageDraw.Draw(Image.new('L', (1, 1))).textlength(text, font=f)) + 16 * k
    W = (w // k + 3) // 4 * 4 * k
    m = Image.new('L', (W, H * k), 0)
    ImageDraw.Draw(m).text((8 * k, 4 * k), text, font=f, fill=255)
    outline = m.filter(ImageFilter.MaxFilter(13)).filter(ImageFilter.GaussianBlur(3))
    img = Image.new('RGBA', m.size, (0, 0, 0, 0))
    dark = Image.new('RGBA', m.size, (8, 12, 8, 255)); dark.putalpha(outline.point(lambda p: round(p * 0.85)))
    img = Image.alpha_composite(img, dark)
    white = Image.new('RGBA', m.size, (255, 255, 255, 255)); white.putalpha(m)
    img = Image.alpha_composite(img, white)
    return img.resize((W // k, H), Image.LANCZOS)

def main():
    rows = []
    for key, text in LABELS:
        im = label(text); p = HERE / ('assets/label_%s.png' % key); im.save(p)
        rows.append("  %s = { '%016x', %d, %d }," % (key, resource_hash('mods/darryl/rear_heat_hud/label_' + key), im.width, im.height))
    print('local LABEL_TEX = {\n' + '\n'.join(rows) + '\n}')

if __name__ == '__main__':
    main()
