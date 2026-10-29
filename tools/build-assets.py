#!/usr/bin/env python3
"""Build assets/ for Merge Bastion from free CC0 / OFL sources.

  python3 tools/build-assets.py <kenney-mirror-dir> <RussoOne-Regular.ttf>

<kenney-mirror-dir> is a checkout of https://github.com/ETdoFresh/kenney.nl (a mirror of
Kenney's CC0 packs). The font comes from https://github.com/google/fonts/tree/main/ofl/russoone.

Outputs:
  assets/atlas.png   one texture atlas with every sprite
  assets/bundle.js   sprite rects + sounds (MP3, base64) + font (base64), so the game also
                     works from file:// where fetch()/fonts are blocked
  assets/CREDITS.md  source and licence of every file
Needs Pillow and ffmpeg (libmp3lame).
"""
import base64, json, os, subprocess, sys, tempfile
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets')

SS = 'spaceshooter/PNG'                       # Space Shooter Redux
UI = 'uipack-space/PNG'                       # UI Pack: Space Extension
PP = 'particlePack_1.1/PNG (Transparent)'     # Particle Pack

# name -> (path in mirror, max size or None). Particle textures are 512px, downscaled.
SPRITES = {}
for n in (1, 2, 3):
    for c in ('blue', 'green', 'orange', 'red'):
        SPRITES[f'ship{n}_{c}'] = (f'{SS}/playerShip{n}_{c}.png', None)
for c in ('Black', 'Blue', 'Green', 'Red'):
    for n in range(1, 6):
        SPRITES[f'enemy{c}{n}'] = (f'{SS}/Enemies/enemy{c}{n}.png', None)
SPRITES.update({
    'beam_blue': (f'{SS}/Lasers/laserBlue14.png', None), 'hit_blue': (f'{SS}/Lasers/laserBlue08.png', None),
    'beam_green': (f'{SS}/Lasers/laserGreen06.png', None), 'hit_green': (f'{SS}/Lasers/laserGreen14.png', None),
    'beam_red': (f'{SS}/Lasers/laserRed14.png', None), 'hit_red': (f'{SS}/Lasers/laserRed08.png', None),
    'fire': (f'{SS}/Effects/fire13.png', None), 'fire_blue': (f'{SS}/Effects/fire04.png', None),
    'star1': (f'{SS}/Effects/star1.png', None), 'star2': (f'{SS}/Effects/star2.png', None), 'star3': (f'{SS}/Effects/star3.png', None),
    'shield': (f'{SS}/Effects/shield3.png', None),
    'meteor1': (f'{SS}/Meteors/meteorBrown_big1.png', None), 'meteor2': (f'{SS}/Meteors/meteorGrey_big3.png', None),
    'meteor3': (f'{SS}/Meteors/meteorBrown_med1.png', None), 'meteor4': (f'{SS}/Meteors/meteorGrey_small1.png', None),
    'star_gold': (f'{SS}/Power-ups/star_gold.png', None), 'bolt_gold': (f'{SS}/Power-ups/bolt_gold.png', None),
    'coin': (f'{UI}/dotYellow.png', None), 'hand': (f'{UI}/cursor_hand.png', None),
    'glass': (f'{UI}/glassPanel.png', None), 'glass_tab': (f'{UI}/glassPanel_corners.png', None),
    'bar_bg_l': (f'{UI}/barHorizontal_shadow_left.png', None), 'bar_bg_m': (f'{UI}/barHorizontal_shadow_mid.png', None), 'bar_bg_r': (f'{UI}/barHorizontal_shadow_right.png', None),
    'bg_tile': ('spaceshooter/Backgrounds/darkPurple.png', None),
    'p_light': (f'{PP}/light_01.png', 128), 'p_ring': (f'{PP}/circle_02.png', 128), 'p_dot': (f'{PP}/circle_05.png', 64),
    'p_star': (f'{PP}/star_07.png', 96), 'p_spark': (f'{PP}/star_04.png', 64), 'p_smoke': (f'{PP}/smoke_04.png', 128),
    'p_scorch': (f'{PP}/scorch_02.png', 128), 'p_flare': (f'{PP}/flare_01.png', 96), 'p_twirl': (f'{PP}/twirl_01.png', 128),
    'p_magic': (f'{PP}/magic_04.png', 128), 'p_muzzle': (f'{PP}/muzzle_02.png', 64),
})
for c in ('blue', 'green', 'red', 'yellow'):
    for part in ('left', 'mid', 'right'):
        SPRITES[f'bar_{c}_{part[0]}'] = (f'{UI}/barHorizontal_{c}_{part}.png', None)

# name -> (path in mirror, trim seconds or None)
SB, DA, IS, MJ = 'spaceshooter/Bonus', 'kenney_digitalaudio/Audio', 'kenney_interfacesounds/Audio', 'kenney_musicjingles/Audio'
SOUNDS = {
    'shoot': (f'{SB}/sfx_laser1.ogg', None), 'shoot2': (f'{SB}/sfx_laser2.ogg', None),
    'kill': (f'{DA}/spaceTrash1.ogg', 0.7), 'boom': (f'{DA}/spaceTrash4.ogg', None),
    'coin': (f'{DA}/pepSound1.ogg', 0.3), 'buy': (f'{IS}/maximize_006.ogg', None),
    'pick': (f'{IS}/select_001.ogg', None), 'drop': (f'{IS}/drop_002.ogg', None),
    'click': (f'{IS}/click_002.ogg', None), 'error': (f'{IS}/error_006.ogg', None),
    'merge': (f'{DA}/powerUp7.ogg', None), 'reward': (f'{DA}/powerUp11.ogg', None),
    'unlock': (f'{MJ}/8-Bit jingles/jingles_NES00.ogg', None), 'cleared': (f'{MJ}/8-Bit jingles/jingles_NES03.ogg', None),
    'wave': (f'{MJ}/Hit jingles/jingles_HIT00.ogg', None), 'bosswave': (f'{MJ}/Hit jingles/jingles_HIT05.ogg', None),
    'hurt': (f'{SB}/sfx_shieldDown.ogg', None), 'rage': (f'{SB}/sfx_shieldUp.ogg', None), 'lose': (f'{SB}/sfx_lose.ogg', None),
}

PACKS = {
    'spaceshooter': 'Space Shooter Redux', 'uipack-space': 'UI Pack: Space Extension', 'particlePack_1.1': 'Particle Pack',
    'kenney_digitalaudio': 'Digital Audio', 'kenney_interfacesounds': 'Interface Sounds', 'kenney_musicjingles': 'Music Jingles',
}


def pack(images, max_w=1024, pad=2):
    """Shelf packer: tallest first, rows left to right."""
    order = sorted(images, key=lambda k: -images[k].height)
    x = y = row_h = 0
    rects = {}
    for k in order:
        im = images[k]
        if x + im.width + pad > max_w:
            x, y, row_h = 0, y + row_h + pad, 0
        rects[k] = (x, y, im.width, im.height)
        x += im.width + pad
        row_h = max(row_h, im.height)
    h = y + row_h
    atlas = Image.new('RGBA', (max_w, (h + 3) // 4 * 4), (0, 0, 0, 0))
    for k, (rx, ry, _, _) in rects.items():
        atlas.paste(images[k], (rx, ry))
    return atlas, rects


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    kenney, font = sys.argv[1], sys.argv[2]
    os.makedirs(OUT, exist_ok=True)

    images = {}
    for name, (path, max_size) in SPRITES.items():
        im = Image.open(os.path.join(kenney, path)).convert('RGBA')
        if max_size and max(im.size) > max_size:
            im.thumbnail((max_size, max_size), Image.LANCZOS)
        images[name] = im
    atlas, rects = pack(images)
    atlas_path = os.path.join(OUT, 'atlas.png')
    atlas.save(atlas_path, optimize=True)

    sounds = {}
    with tempfile.TemporaryDirectory() as tmp:
        for name, (path, trim) in SOUNDS.items():
            dst = os.path.join(tmp, name + '.mp3')
            af = 'loudnorm=I=-16:TP=-1.5:LRA=11'
            if trim:
                af = f'atrim=0:{trim},afade=t=out:st={trim * 0.6:.2f}:d={trim * 0.4:.2f},' + af
            subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', os.path.join(kenney, path), '-af', af,
                            '-ac', '1', '-ar', '44100', '-b:a', '64k', dst], check=True)
            sounds[name] = 'data:audio/mpeg;base64,' + base64.b64encode(open(dst, 'rb').read()).decode()

    font_uri = 'data:font/ttf;base64,' + base64.b64encode(open(font, 'rb').read()).decode()
    bundle = {'atlas': 'assets/atlas.png', 'size': atlas.size, 'sprites': rects, 'sounds': sounds, 'font': font_uri}
    with open(os.path.join(OUT, 'bundle.js'), 'w') as f:
        f.write('// Generated by tools/build-assets.py — sources and licences in assets/CREDITS.md\n')
        f.write('window.MB_ASSETS = ' + json.dumps(bundle, separators=(',', ':')) + ';\n')

    used = sorted({p.split('/')[0] for p, _ in list(SPRITES.values()) + list(SOUNDS.values())})
    with open(os.path.join(OUT, 'CREDITS.md'), 'w') as f:
        f.write('# Credits\n\n')
        f.write('Graphics and sounds: **Kenney** (https://kenney.nl), licence **CC0 1.0** (public domain).\n')
        f.write('Taken from the mirror https://github.com/ETdoFresh/kenney.nl\n\n')
        for p in used:
            f.write(f'- {PACKS.get(p, p)} (`{p}`)\n')
        f.write('\nFont: **Russo One** by Jovanny Lemonad, licence **SIL Open Font License 1.1** '
                '(https://github.com/google/fonts/tree/main/ofl/russoone). Embedded in bundle.js.\n\n')
        f.write('## Files\n\n| id | source |\n|---|---|\n')
        for name, (path, _) in {**SPRITES, **SOUNDS}.items():
            f.write(f'| {name} | {path} |\n')

    kb = lambda p: os.path.getsize(p) // 1024
    print(f'atlas {atlas.size[0]}x{atlas.size[1]} {kb(atlas_path)} KB, '
          f'bundle {kb(os.path.join(OUT, "bundle.js"))} KB, {len(rects)} sprites, {len(sounds)} sounds')


if __name__ == '__main__':
    main()
