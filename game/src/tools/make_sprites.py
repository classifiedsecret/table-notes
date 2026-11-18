"""Builds game sprite strips from the CC0 0x72 Dungeon Tileset II atlas.
Usage: python3 -I make_sprites.py <game_dir>"""
import sys
from PIL import Image
G = sys.argv[1]
S = G + '/assets/sprites/'
A = Image.open(S + '0x72_atlas.png').convert('RGBA')
T = {l.split()[0]: tuple(map(int, l.split()[1:5])) for l in open(S + '0x72_tile_list.txt') if len(l.split()) >= 5}

def hexc(h): return tuple(int(h[i:i+2], 16) for i in (1, 3, 5)) + (255,)

def strip(names, recolor=None, out=None):
    ims = []
    for n in names:
        x, y, w, h = T[n]; ims.append(A.crop((x, y, x + w, y + h)))
    W = max(i.width for i in ims); H = max(i.height for i in ims)
    st = Image.new('RGBA', (W * len(ims), H), (0, 0, 0, 0))
    for k, im in enumerate(ims):
        st.paste(im, (k * W, H - im.height), im)
    if recolor:
        m = {hexc(a): hexc(b) for a, b in recolor.items()}
        px = st.load()
        for yy in range(st.height):
            for xx in range(st.width):
                if px[xx, yy] in m: px[xx, yy] = m[px[xx, yy]]
    st.save(S + out); return W, H

frames = lambda base, kinds: [f'{base}_{k}_anim_f{i}' for k, c in kinds for i in range(c)]
# Boar-vhal: dwarf_m with a boar-hide hood and stone-grey Goliath skin.
bv = strip(frames('dwarf_m', [('idle', 4), ('run', 4), ('hit', 1)]), {
    '#da4e38': '#6b4a3a', '#e46e33': '#8f6a4c',   # hood -> boar hide
    '#d8a57d': '#a3adb3', '#c38d70': '#7f8c95',   # skin -> stone grey
}, 'boarvhal.png')

def outline(fname, fw, rgba):
    # Soft 1px light rim (kept inside each frame) so the hero reads against dark walls.
    im = Image.open(S + fname).convert('RGBA'); px = im.load(); W, H = im.size
    add = []
    for y in range(H):
        for x in range(W):
            if px[x, y][3] > 0: continue
            lx = x % fw
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if not (0 <= ny < H) or not (0 <= lx + dx < fw): continue
                if px[nx, ny][3] > 128: add.append((x, y)); break
    for x, y in add: px[x, y] = rgba
    im.save(S + fname)
outline('boarvhal.png', bv[0], (255, 236, 190, 150))
gm = strip(frames('goblin', [('idle', 4), ('run', 4)]), None, 'goblin_minion.png')
gw = strip(frames('goblin', [('idle', 4), ('run', 4)]), {
    '#3d734f': '#55682f', '#314152': '#6e2f2a'}, 'goblin_warrior.png')
# Bugbear Chief: the ogre with brown fur skin and a dark red hide.
bb = strip(frames('ogre', [('idle', 4), ('run', 4)]), {
    '#3d734f': '#8a5a34', '#8f4029': '#5b3a22', '#314152': '#4a2a24', '#62232f': '#7a2b22'}, 'bugbear_chief.png')
# Gryphon's Roost cast (recolours of 0x72 characters).
INN = {
    'npc_ceridwen': ('wizzard_f', {'#5698cc': '#8a5cc4', '#5956bd': '#5d3a99', '#fdf7ed': '#d2452c', '#d3bfa9': '#962d1f', '#b58057': '#f6e4d8', '#8a503e': '#d6b8aa'}),
    'npc_erwar': ('knight_m', {'#72d6ce': '#e8c35a', '#417089': '#a8782c', '#da4e38': '#fdf7ed', '#ee8e2e': '#d8d3e8'}),
    'npc_lyburnum': ('knight_m', {'#72d6ce': '#55555f', '#417089': '#2e2e38', '#da4e38': '#4ba747', '#ee8e2e': '#3d734f'}),
    'npc_suilean': ('elf_f', None),
    'npc_galinnadin': ('elf_m', {'#4ba747': '#3b3b48', '#3d734f': '#2a2a33', '#facb3e': '#4a3426', '#ee8e2e': '#33241a'}),
    'npc_orfi': ('dwarf_f', {'#facb3e': '#8a3324', '#ee8e2e': '#6b2418', '#dc4a7b': '#e8952e', '#9f294e': '#b8641c'}),
    'npc_dm': ('doc', None),
    'npc_kieran': ('dwarf_m', None),
    'npc_server': ('lizard_f', None),
    'npc_dishwasher': ('wogol', None),
    'npc_bard': ('lizard_m', None),
    'npc_patron_a': ('orc_shaman', None),
    'npc_patron_b': ('masked_orc', None),
    'npc_patron_c': ('pumpkin_dude', None),
}
inn_sizes = {}
for out, (base, rc) in INN.items():
    inn_sizes[out] = strip(frames(base, [('idle', 4), ('run', 4)]), rc, out + '.png')
# Boar-vhal as an inn patron (when someone else is the hero).
Image.open(S + 'boarvhal.png').crop((0, 0, 16 * 8, 28)).save(S + 'npc_boarvhal.png')
inn_sizes['npc_boarvhal'] = (16, 28)

# Playable party heroes: the inn recolours with a hit frame and the same light rim as Boar-vhal.
HEROES = {'hero_ceridwen': 'npc_ceridwen', 'hero_erwar': 'npc_erwar', 'hero_lyburnum': 'npc_lyburnum', 'hero_suilean': 'npc_suilean'}
for out, npc in HEROES.items():
    base, rc = INN[npc]
    strip(frames(base, [('idle', 4), ('run', 4), ('hit', 1)]), rc, out + '.png')
    outline(out + '.png', 16, (255, 236, 190, 150))

# Wild Shape forms: original pixel art (no bear or spider in the 0x72 set).
from PIL import ImageDraw
def form_strip(draw_frame, fw, fh, n_idle, n_run, out, rim=True):
    st = Image.new('RGBA', (fw * (n_idle + n_run + 1), fh), (0, 0, 0, 0))
    for i in range(n_idle + n_run + 1):
        fr = Image.new('RGBA', (fw, fh), (0, 0, 0, 0))
        kind = 'idle' if i < n_idle else ('run' if i < n_idle + n_run else 'hit')
        draw_frame(ImageDraw.Draw(fr), kind, i if kind == 'idle' else i - n_idle)
        st.paste(fr, (i * fw, 0), fr)
    st.save(S + out)
    if rim:
        outline(out, fw, (255, 236, 190, 140))

def bear(d, kind, k):
    O = (24, 16, 14, 255); F1 = (58, 40, 30, 255); F2 = (84, 60, 42, 255); SN = (150, 118, 86, 255)
    bob = (1 if k % 2 else 0) if kind == 'idle' else 0
    step = [0, 1, 0, -1][k % 4] if kind == 'run' else 0
    y0 = 4 + bob
    d.rounded_rectangle([2, y0 + 1, 18, y0 + 10], 4, fill=F1, outline=O)        # body
    d.rounded_rectangle([4, y0 + 1, 15, y0 + 5], 3, fill=F2)                     # back shine
    d.ellipse([14, y0 - 2, 23, y0 + 6], fill=F1, outline=O)                      # head
    d.ellipse([15, y0 - 4, 18, y0 - 1], fill=F1, outline=O)                      # ear
    d.rectangle([20, y0 + 2, 23, y0 + 4], fill=SN)                               # snout
    d.point((23, y0 + 2), fill=O); d.point((19, y0), fill=(240, 220, 160, 255))  # nose, eye
    for x, ph in ((4, step), (8, -step), (12, step), (16, -step)):              # legs
        d.rectangle([x, y0 + 10, x + 2, min(17, y0 + 13 + ph)], fill=F1, outline=O)
    if kind == 'hit':
        d.line([3, y0 + 3, 9, y0 + 6], fill=(220, 80, 60, 255))

def spider(d, kind, k):
    O = (14, 12, 16, 255); L = (128, 108, 84, 255); B1 = (66, 56, 50, 255); B2 = (118, 100, 80, 255); B3 = (150, 128, 96, 255)
    EY = (240, 80, 50, 255)
    ph = k % 4
    bob = 1 if (kind == 'idle' and k % 2) else 0
    # Legs arch up from the body to a knee, then down to the floor; they alternate while running.
    for i, (x, out) in enumerate(((6, -1), (9, -1), (12, 1), (15, 1))):
        lift = ((ph + i) % 2) if kind == 'run' else 0
        kx = x + out * 3
        fx = max(0, min(23, x + out * 6 + (1 if lift else 0) * out))
        d.line([x, 6 + bob, kx, 1 + lift], fill=L)
        d.line([kx, 1 + lift, fx, 13 - lift], fill=L)
    d.ellipse([1, 3 + bob, 11, 10 + bob], fill=B1, outline=O)      # abdomen
    d.line([4, 5 + bob, 8, 5 + bob], fill=B3)
    d.line([3, 7 + bob, 9, 7 + bob], fill=B2)
    d.ellipse([10, 4 + bob, 17, 10 + bob], fill=B1, outline=O)     # head
    for x, y in ((15, 6), (16, 6), (16, 7)):
        d.point((x, y + bob), fill=EY)
    d.line([17, 9 + bob, 19, 11 + bob], fill=O)                    # fangs
    if kind == 'hit':
        d.line([2, 4, 10, 9], fill=(220, 80, 60, 255))

form_strip(bear, 24, 18, 4, 4, 'form_bear.png')
form_strip(spider, 24, 14, 4, 4, 'form_spider.png', rim=False)
print('frame sizes', bv, gm, gw, bb, inn_sizes)
with open(G + '/scripts/data/inn_sprites.gd', 'w') as f:
    f.write('## Generated by tools/make_sprites.py: frame sizes of the inn cast strips (idle 4, run 4).\n')
    f.write('class_name InnSprites\n\nconst SIZES := {\n')
    for k, (w, h) in inn_sizes.items():
        f.write(f'\t"{k}": Vector2i({w}, {h}),\n')
    f.write('}\n')

# Atlas rects used directly by the game (tiles, props, weapons, UI).
want = ['wall_mid', 'wall_top_mid', 'wall_left', 'wall_right', 'floor_1', 'floor_2', 'floor_3', 'floor_4',
        'wall_banner_red', 'wall_banner_blue', 'wall_banner_green', 'wall_banner_yellow', 'column', 'column_wall',
        'wall_hole_1', 'wall_hole_2', 'weapon_double_axe', 'weapon_knife', 'weapon_machete',
        'ui_heart_full', 'ui_heart_half', 'ui_heart_empty', 'skull', 'crate', 'edge_down',
        'floor_spikes_anim_f0', 'floor_spikes_anim_f1', 'floor_spikes_anim_f2', 'floor_spikes_anim_f3',
        'flask_big_red', 'weapon_bow', 'weapon_big_hammer', 'weapon_spear',
        'chest_full_open_anim_f0', 'chest_full_open_anim_f1', 'chest_full_open_anim_f2',
        'chest_empty_open_anim_f0', 'chest_empty_open_anim_f1', 'chest_empty_open_anim_f2',
        'coin_anim_f0', 'coin_anim_f1', 'coin_anim_f2', 'coin_anim_f3', 'doors_leaf_open', 'doors_frame_left', 'doors_frame_right', 'doors_frame_top', 'doors_leaf_closed', 'doors_leaf_open', 'weapon_red_magic_staff', 'weapon_mace', 'weapon_knight_sword', 'weapon_green_magic_staff']
with open(G + '/scripts/data/atlas_rects.gd', 'w') as f:
    f.write('## Generated by tools/make_sprites.py from the 0x72 Dungeon Tileset II tile list (CC0).\n')
    f.write('class_name AtlasRects\n\nconst RECTS := {\n')
    for n in dict.fromkeys(want):
        x, y, w, h = T[n]; f.write(f'\t"{n}": Rect2({x}, {y}, {w}, {h}),\n')
    f.write('}\n')
print('ok')
