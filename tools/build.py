"""Build SixthSense.zip (Sixth Sense, formerly Rear Heat HUD): Bingus Shared Loader's build_addon.py packaging (same entry declaration, manifest and zip
layout), plus the radar disc texture in the same patch (Lua type row + texture type row; pixels in .gpu_resources),
written the way Treasure Radar ships its textures (Treasure-Radar/src/patch_writer.py, icon_textures.texture_resource).
  python3 tools/build.py [--no-texture] [--output SixthSense.zip]"""
import argparse, json, struct, sys, uuid, zipfile
from pathlib import Path
HERE = Path(__file__).resolve().parents[1]
RES = HERE.parent
sys.path.insert(0, str(RES / 'BingusSharedLoader/scripts')); sys.path.insert(0, str(RES / 'Treasure-Radar/src'))
from build_addon import entry_source
from archive import ARCHIVE, resource_hash, make_archive
import patch_writer
from PIL import Image

NAME = 'mods/darryl/sixth_sense'
# (the textures keep their v1.3 resource paths: their ids are named in the Lua; the GUID is unchanged)
TEXTURES = [('mods/darryl/rear_heat_hud/radar_disc', 'radar_disc.png')] + [
    ('mods/darryl/rear_heat_hud/label_' + k, 'label_%s.png' % k) for k in ('size', 'sensitivity', 'repeat_rate', 'dot_size', 'visibility', 'vis_shown', 'vis_hidden', 'tab_display', 'tab_settings', 'tab_reset', 'tab_pick')]
LUA, TEXTURE = 0xA14E8DFA2CD117E2, 0xCD4238C6A0C69E32

def texture_resource(w, h):
    """192-byte Stingray header + DDS header with DX10 extension (DXGI 28 RGBA8, one mip): as Treasure Radar's."""
    head = struct.pack('<III', 0, 0, 0xFFFFFFFF) + b'\0' * 180
    dds = b'DDS ' + struct.pack('<7I', 124, 0x100F, h, w, w * 4, 0, 1) + b'\0' * 44
    dds += struct.pack('<2I4s5I', 32, 4, b'DX10', 0, 0, 0, 0, 0)
    dds += struct.pack('<5I', 0x1000, 0, 0, 0, 0)
    dds += struct.pack('<5I', 28, 3, 0, 1, 0)
    out = head + dds; assert len(out) == 340
    return out

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--output', default=str(HERE / 'SixthSense.zip'))
    ap.add_argument('--no-texture', action='store_true')
    a = ap.parse_args()
    src = (HERE / 'src/sixth_sense.lua').read_bytes()
    version = src.split(b'"sixth_sense", "')[1].split(b'"')[0].decode()
    for name, _ in TEXTURES:
        assert ('%016x' % resource_hash(name)).encode() in src, 'the Lua must name the texture id of ' + name
    body = entry_source(NAME, src)
    lua_res = struct.pack('<II', len(body), 2) + body
    if a.no_texture:
        toc, gpu, stream = make_archive({resource_hash(NAME): lua_res}), b'', b''
    else:
        entries = [(resource_hash(NAME), LUA, lua_res, b'', b'', 16)]
        for name, png in TEXTURES:
            img = Image.open(HERE / 'assets' / png).convert('RGBA')
            entries.append((resource_hash(name), TEXTURE, texture_resource(img.width, img.height), img.tobytes(), b'', 64))
        toc, gpu, stream = patch_writer.write(entries, [(LUA, 16), (TEXTURE, 64)], pad_toc=True)
        patch_writer.check(toc, gpu, stream)
    guid = str(uuid.UUID((HERE / 'GUID.txt').read_text().strip()))
    title = 'Sixth Sense v' + version
    desc = 'Requires Bingus Shared Loader v15 or newer / API 1. Enable both and deploy.'
    manifest = {'Version': 1, 'Guid': guid, 'Name': title, 'Description': desc,
                'Options': [{'Name': title, 'Description': desc, 'Include': ['Addon']}]}
    files = {'manifest.json': (json.dumps(manifest, indent=2) + '\n').encode(), 'Addon/' + ARCHIVE: toc,
             'Addon/' + ARCHIVE + '.stream': stream, 'Addon/' + ARCHIVE + '.gpu_resources': gpu}
    with zipfile.ZipFile(a.output, 'w', compression=zipfile.ZIP_DEFLATED) as z:
        for p, c in sorted(files.items()):
            info = zipfile.ZipInfo(p, date_time=(1980, 1, 1, 0, 0, 0)); info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16; z.writestr(info, c)
    print('Built %s (%s, textures %s)' % (a.output, title, 'none' if a.no_texture else len(TEXTURES)))

if __name__ == '__main__':
    main()
