"""Original pixel art for the top-down (3/4) Gryphon's Roost: wood floor and wall pieces that
join up, and furniture drawn from above-and-in-front (tables, chairs, bar, beds, rugs, couch,
stairs, trapdoor, doors). Writes assets/sprites/td_inn.png and scripts/td/td_art_rects.gd.
Also the Goblin Warren's cave walls, dirt floor and cave props.
Run: python3 tools/make_td_inn_art.py game"""
import sys
from PIL import Image, ImageDraw

G = sys.argv[1]
O = (34, 30, 30, 255)
W1, W2, W3, W4 = (138, 80, 62, 255), (181, 128, 87, 255), (107, 62, 46, 255), (211, 160, 110, 255)
D1, D2 = (78, 48, 34, 255), (58, 36, 26, 255)          # dark woods (wall mass, seams)
F1, F2, F3 = (150, 100, 66, 255), (136, 88, 58, 255), (118, 76, 50, 255)  # floorboards
RED1, RED2, REDD = (176, 52, 60, 255), (128, 34, 44, 255), (92, 24, 32, 255)
GOLD, CREAM = (250, 203, 62, 255), (253, 247, 237, 255)
PURP, PURP2 = (110, 72, 170, 255), (80, 50, 130, 255)
LEAF1, LEAF2, LEAF3 = (58, 120, 62, 255), (86, 160, 80, 255), (40, 86, 46, 255)
FUR1, FUR2 = (92, 66, 46, 255), (122, 92, 64, 255)
GREY1, GREY2 = (150, 140, 120, 255), (120, 112, 96, 255)
items = {}


def canvas(w, h):
    return Image.new('RGBA', (w, h), (0, 0, 0, 0))


def box(d, x0, y0, x1, y1, fill, outline=O):
    d.rectangle([x0, y0, x1, y1], fill=fill, outline=outline)


def item(fn):
    items[fn.__name__] = fn
    return fn


# ---------------- tiles (16 x 16) ----------------

def floor_tile(seed):
    im = canvas(16, 16); d = ImageDraw.Draw(im)
    rows = [(0, 3), (4, 7), (8, 11), (12, 15)]
    for i, (y0, y1) in enumerate(rows):
        c = (F1, F2, F1, F3)[(i + seed) % 4]
        d.rectangle([0, y0, 15, y1], fill=c)
        d.line([0, y1, 15, y1], fill=F3 if c != F3 else D1)
        j = (seed * 5 + i * 7) % 16                     # staggered board joints
        d.line([j, y0, j, y1 - 1], fill=D1)
        if (seed + i) % 3 == 0:
            d.point(((j + 6) % 16, y0 + 1), fill=F3)      # a knot
    return im


for k in range(4):
    items['floor_%d' % (k + 1)] = (lambda k=k: floor_tile(k))


@item
def wall_face():          # the front of a wall: vertical planks over a baseboard
    im = canvas(16, 16); d = ImageDraw.Draw(im)
    for x0 in (0, 4, 8, 12):
        d.rectangle([x0, 0, x0 + 3, 12], fill=(W2, W1, W2, W1)[x0 // 4])
        d.line([x0, 0, x0, 12], fill=W3)
    d.point((2, 5), fill=W3); d.point((10, 8), fill=W3)
    d.rectangle([0, 13, 15, 15], fill=D1); d.line([0, 13, 15, 13], fill=W4)
    return im


@item
def wall_cap():           # the top of a wall seen from above, with its front lip
    im = canvas(16, 16); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 15, 15], fill=D1)
    d.rectangle([0, 10, 15, 13], fill=W3); d.line([0, 10, 15, 10], fill=W4)
    d.rectangle([0, 14, 15, 15], fill=D2)
    d.line([0, 4, 15, 4], fill=D2)
    return im


@item
def wall_mass():          # the thick top of a wall (seen from above)
    im = canvas(16, 16); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 15, 15], fill=D1)
    d.line([0, 4, 15, 4], fill=D2); d.line([0, 12, 15, 12], fill=D2)
    d.point((6, 8), fill=D2)
    return im


@item
def wall_side_l():        # a west wall: its inner edge on the right (floor to the east)
    im = items['wall_mass']()
    d = ImageDraw.Draw(im)
    d.rectangle([11, 0, 15, 15], fill=W3); d.line([11, 0, 11, 15], fill=W4); d.line([15, 0, 15, 15], fill=D2)
    return im


@item
def wall_side_r():        # an east wall: inner edge on the left
    im = items['wall_mass']()
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 4, 15], fill=W3); d.line([4, 0, 4, 15], fill=W4); d.line([0, 0, 0, 15], fill=D2)
    return im


@item
def wall_south():         # the south wall, seen from above: its top with the inner lip at the top
    im = items['wall_mass']()
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 15, 4], fill=W3); d.line([0, 4, 15, 4], fill=W4); d.line([0, 0, 15, 0], fill=D2)
    return im


@item
def wall_corner_sw():     # where a west wall meets the south wall (inner corner at top-right)
    im = items['wall_mass']()
    d = ImageDraw.Draw(im)
    d.rectangle([11, 0, 15, 4], fill=W3); d.line([11, 0, 11, 4], fill=W4); d.line([11, 4, 15, 4], fill=W4)
    return im


@item
def wall_corner_se():
    im = items['wall_mass']()
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 4, 4], fill=W3); d.line([4, 0, 4, 4], fill=W4); d.line([0, 4, 4, 4], fill=W4)
    return im


@item
def wall_cap_l():         # cap over a wall face where the west wall joins (the side edge carries on)
    im = items['wall_cap']()
    d = ImageDraw.Draw(im)
    d.rectangle([11, 0, 15, 9], fill=W3); d.line([11, 0, 11, 9], fill=W4)
    return im


@item
def wall_cap_r():
    im = items['wall_cap']()
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 4, 9], fill=W3); d.line([4, 0, 4, 9], fill=W4)
    return im


# ---------------- furniture ----------------

@item
def table():              # 32 x 24: top surface, front apron, legs
    im = canvas(32, 24); d = ImageDraw.Draw(im)
    for x in (2, 27):
        box(d, x, 14, x + 2, 23, W3)
    box(d, 0, 0, 31, 12, W2)
    for y in (3, 6, 9):
        d.line([1, y, 30, y], fill=W1)
    d.line([1, 1, 30, 1], fill=W4)
    box(d, 1, 12, 30, 15, W3)
    return im


@item
def table_small():        # 20 x 22
    im = canvas(20, 22); d = ImageDraw.Draw(im)
    for x in (2, 15):
        box(d, x, 13, x + 2, 21, W3)
    box(d, 0, 0, 19, 11, W2)
    d.line([1, 4, 18, 4], fill=W1); d.line([1, 8, 18, 8], fill=W1); d.line([1, 1, 18, 1], fill=W4)
    box(d, 1, 11, 18, 14, W3)
    return im


@item
def chair_front():        # facing the viewer: seat and the backrest behind it
    im = canvas(12, 18); d = ImageDraw.Draw(im)
    box(d, 1, 0, 10, 7, W1); d.line([3, 2, 8, 2], fill=W3)
    box(d, 0, 7, 11, 11, W2)
    box(d, 1, 11, 2, 17, W3); box(d, 9, 11, 10, 17, W3)
    return im


@item
def chair_back():         # facing away (backrest in front)
    im = canvas(12, 18); d = ImageDraw.Draw(im)
    box(d, 1, 11, 2, 17, W3); box(d, 9, 11, 10, 17, W3)
    box(d, 0, 6, 11, 10, W2)
    box(d, 1, 0, 10, 9, W1); d.line([5, 1, 5, 8], fill=W3); d.line([3, 1, 3, 8], fill=W3); d.line([8, 1, 8, 8], fill=W3)
    return im


@item
def chair_side():         # seen from the side, back on the left (flip for the other side)
    im = canvas(12, 18); d = ImageDraw.Draw(im)
    box(d, 0, 0, 2, 17, W3)
    box(d, 0, 9, 11, 12, W2)
    box(d, 9, 12, 10, 17, W3)
    return im


@item
def stool():
    im = canvas(12, 14); d = ImageDraw.Draw(im)
    box(d, 2, 6, 3, 13, W3); box(d, 8, 6, 9, 13, W3)
    d.ellipse([0, 0, 11, 7], fill=W2, outline=O); d.line([3, 2, 8, 2], fill=W4)
    return im


@item
def bar_top():            # north end of a north-south bar counter
    im = canvas(18, 16); d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 2, 17, 17], 3, fill=W2, outline=O)
    d.line([3, 5, 14, 5], fill=W4)
    return im


@item
def bar_mid():
    im = canvas(18, 16); d = ImageDraw.Draw(im)
    box(d, 0, -1, 17, 16, W2)
    d.line([1, 8, 16, 8], fill=W1); d.line([2, 0, 2, 15], fill=W4)
    return im


@item
def bar_end():            # south end: the counter's front panel shows
    im = canvas(18, 28); d = ImageDraw.Draw(im)
    box(d, 0, -1, 17, 10, W2); d.line([2, 0, 2, 9], fill=W4)
    box(d, 0, 10, 17, 27, W1); box(d, 3, 13, 14, 24, W3, W3)
    d.line([0, 10, 17, 10], fill=W4)
    return im


@item
def keg_rack():           # two kegs lying on a rack, ends toward the viewer
    im = canvas(34, 22); d = ImageDraw.Draw(im)
    box(d, 1, 16, 32, 21, W3)
    for x in (2, 18):
        d.ellipse([x, 2, x + 13, 16], fill=W2, outline=O)
        d.ellipse([x + 3, 5, x + 10, 13], fill=W1, outline=W3)
        d.point((x + 6, 9), fill=O)
    return im


@item
def couch_back():         # a couch seen from behind (it faces the fireplace)
    im = canvas(46, 20); d = ImageDraw.Draw(im)
    box(d, 2, 15, 5, 19, D1); box(d, 40, 15, 43, 19, D1)
    d.rounded_rectangle([0, 0, 45, 16], 4, fill=RED2, outline=O)
    d.line([3, 3, 42, 3], fill=RED1)
    d.line([15, 4, 15, 14], fill=REDD); d.line([30, 4, 30, 14], fill=REDD)
    return im



@item
def couch_side():         # 22 x 42 a couch against the west wall, seen from above: back on the left, facing east
    im = canvas(22, 42); d = ImageDraw.Draw(im)
    box(d, 2, 38, 5, 41, D1); box(d, 16, 38, 19, 41, D1)              # front feet
    d.rounded_rectangle([0, 0, 21, 38], 3, fill=RED2, outline=O)      # frame
    d.rectangle([1, 2, 6, 36], fill=REDD)                              # the backrest
    d.line([6, 2, 6, 36], fill=O)
    d.rectangle([1, 0, 20, 5], fill=RED2); d.line([1, 5, 20, 5], fill=O)      # north arm
    d.rectangle([1, 32, 20, 37], fill=RED2); d.line([1, 32, 20, 32], fill=O)  # south arm
    d.rectangle([7, 6, 20, 18], fill=RED1); d.rectangle([7, 19, 20, 31], fill=RED1)   # two seat cushions
    d.line([7, 18, 20, 18], fill=REDD)
    d.line([9, 8, 18, 8], fill=(206, 82, 88, 255)); d.line([9, 21, 18, 21], fill=(206, 82, 88, 255))
    return im


@item
def table_round():        # 28 x 24 a round table on a pedestal
    im = canvas(28, 24); d = ImageDraw.Draw(im)
    box(d, 11, 14, 16, 22, W3)
    d.ellipse([7, 20, 20, 23], fill=W3, outline=O)
    d.ellipse([0, 0, 27, 17], fill=W1, outline=O)
    d.ellipse([3, 2, 24, 13], fill=W2)
    d.arc([3, 2, 24, 13], 200, 340, fill=W4)
    return im


@item
def table_round_small():  # 20 x 18
    im = canvas(20, 18); d = ImageDraw.Draw(im)
    box(d, 8, 10, 11, 16, W3)
    d.ellipse([5, 14, 14, 17], fill=W3, outline=O)
    d.ellipse([0, 0, 19, 12], fill=W1, outline=O)
    d.ellipse([2, 2, 17, 9], fill=W2)
    return im


def rug(w, h, base, edge, star):
    im = canvas(w, h); d = ImageDraw.Draw(im)
    d.ellipse([0, 0, w - 1, h - 1], fill=edge)
    d.ellipse([2, 2, w - 3, h - 3], fill=base)
    d.ellipse([w // 2 - 8, h // 2 - 5, w // 2 + 8, h // 2 + 5], outline=star)
    d.ellipse([6, 4, w - 7, h - 5], outline=edge)
    return im


items['rug_big'] = lambda: rug(64, 40, RED1, GOLD, GOLD)
items['rug_round'] = lambda: rug(36, 24, (60, 90, 140, 255), CREAM, CREAM)


@item
def runner():             # hallway runner, tiles left-right
    im = canvas(16, 16); d = ImageDraw.Draw(im)
    d.rectangle([0, 2, 15, 13], fill=RED2)
    d.line([0, 3, 15, 3], fill=GOLD); d.line([0, 12, 15, 12], fill=GOLD)
    d.point((7, 7), fill=GOLD); d.point((8, 8), fill=GOLD)
    return im


@item
def stage():              # a low wooden stage: planks on top, its front edge below
    im = canvas(96, 30); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 95, 22], fill=W2)
    for y in range(3, 22, 4):
        d.line([0, y, 95, y], fill=W1)
    for x in range(10, 95, 23):
        d.line([x, 0, x, 21], fill=W3)
    d.rectangle([0, 23, 95, 29], fill=W3); d.line([0, 23, 95, 23], fill=W4); d.rectangle([0, 0, 95, 29], outline=O)
    return im


@item
def stairs_up():          # stairs climbing north into the wall
    im = canvas(32, 52); d = ImageDraw.Draw(im)
    box(d, 0, 0, 31, 51, D1)
    for i in range(8):
        y = 51 - i * 6
        shade = tuple(min(255, int(c * (0.75 + i * 0.04))) for c in W2[:3]) + (255,)
        d.rectangle([3, y - 6, 28, y - 1], fill=shade)
        d.line([3, y - 6, 28, y - 6], fill=W4)
        d.line([3, y - 1, 28, y - 1], fill=W3)
    d.line([2, 0, 2, 51], fill=W3); d.line([29, 0, 29, 51], fill=W3)
    return im


@item
def stairs_down():        # an opening in the floor with steps going down
    im = canvas(32, 32); d = ImageDraw.Draw(im)
    box(d, 0, 0, 31, 31, (20, 14, 12, 255))
    for i in range(5):
        y = 4 + i * 6
        shade = tuple(int(c * (1.0 - i * 0.16)) for c in W2[:3]) + (255,)
        d.rectangle([3, y, 28, y + 4], fill=shade); d.line([3, y, 28, y], fill=W4 if i == 0 else W3)
    d.rectangle([0, 0, 31, 31], outline=W3)
    return im


@item
def trapdoor():           # the cellar trapdoor, propped open, a ladder going down
    im = canvas(32, 34); d = ImageDraw.Draw(im)
    box(d, 2, 10, 29, 33, (16, 12, 12, 255), W3)
    for y in range(13, 32, 5):
        d.line([9, y, 22, y], fill=W1)
    d.line([9, 11, 9, 33], fill=W2); d.line([22, 11, 22, 33], fill=W2)
    box(d, 3, 0, 28, 10, W2)                    # the open hatch, leaning back
    d.line([3, 4, 28, 4], fill=W1); d.line([3, 7, 28, 7], fill=W1)
    d.rectangle([13, 1, 18, 3], fill=(90, 90, 100, 255))
    return im


@item
def door_wood():          # a door set into a wall face (with its frame)
    im = canvas(22, 30); d = ImageDraw.Draw(im)
    box(d, 0, 0, 21, 29, W3)
    box(d, 3, 3, 18, 29, W1)
    for x in (7, 11, 15):
        d.line([x, 4, x, 28], fill=W3)
    d.rectangle([15, 16, 16, 18], fill=GOLD)
    return im


@item
def doormat():
    im = canvas(28, 10); d = ImageDraw.Draw(im)
    box(d, 0, 0, 27, 9, (140, 110, 70, 255))
    for x in range(3, 26, 3):
        d.line([x, 2, x, 7], fill=(110, 84, 52, 255))
    return im


@item
def sconce():             # a wall torch
    im = canvas(10, 14); d = ImageDraw.Draw(im)
    box(d, 3, 7, 6, 13, (90, 90, 100, 255))
    d.ellipse([2, 0, 7, 7], fill=(255, 150, 40, 255)); d.ellipse([3, 2, 6, 6], fill=(255, 230, 120, 255))
    return im


def bed(w, h, blanket, blanket2, pillow=CREAM, frame=W3):
    im = canvas(w, h); d = ImageDraw.Draw(im)
    box(d, 0, 0, w - 1, 6, frame)                              # headboard
    box(d, 1, 6, w - 2, h - 4, (230, 224, 210, 255))          # mattress
    box(d, 3, 7, w - 4, 12, pillow)                            # pillow
    box(d, 1, 13, w - 2, h - 4, blanket)
    d.line([2, 15, w - 3, 15], fill=blanket2)
    box(d, 0, h - 4, w - 1, h - 1, frame)                      # footboard
    return im


items['bed_purple'] = lambda: bed(22, 36, PURP, PURP2)
items['bed_fur'] = lambda: bed(28, 44, FUR1, FUR2, frame=D1)
items['cot'] = lambda: bed(18, 32, GREY1, GREY2, frame=W1)
items['bed_moss'] = lambda: bed(22, 34, LEAF1, LEAF3, pillow=(200, 220, 170, 255), frame=W3)


@item
def pelt():               # a bear skin, flat on the floor
    im = canvas(36, 28); d = ImageDraw.Draw(im)
    d.polygon([(4, 6), (10, 2), (26, 2), (32, 6), (34, 14), (30, 24), (6, 24), (2, 14)], fill=FUR1, outline=O)
    for x, y in ((2, 4), (34, 4), (2, 24), (34, 24)):
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=FUR1, outline=O)
    d.ellipse([13, 0, 23, 9], fill=FUR2, outline=O); d.point((16, 4), fill=CREAM); d.point((20, 4), fill=CREAM)
    d.line([10, 13, 26, 13], fill=FUR2)
    return im


@item
def counter_kitchen():    # a serving hatch under the kitchen door, for flavour
    im = canvas(30, 12); d = ImageDraw.Draw(im)
    box(d, 0, 0, 29, 11, W1); d.line([1, 2, 28, 2], fill=W4)
    return im


@item
def mug_pair():
    im = canvas(14, 8); d = ImageDraw.Draw(im)
    for x in (0, 8):
        box(d, x, 1, x + 4, 7, (220, 200, 160, 255)); d.rectangle([x + 1, 1, x + 3, 2], fill=CREAM)
    return im


@item
def plate():
    im = canvas(10, 6); d = ImageDraw.Draw(im)
    d.ellipse([0, 0, 9, 5], fill=CREAM, outline=GREY2); d.ellipse([3, 1, 6, 4], fill=(200, 120, 60, 255))
    return im


@item
def candle():
    im = canvas(4, 8); d = ImageDraw.Draw(im)
    d.rectangle([1, 3, 2, 7], fill=CREAM); d.point((1, 1), fill=GOLD); d.point((1, 2), fill=(255, 140, 40, 255))
    return im




# ---------------- the Goblin Warren: cave rock that joins like the wood walls ----------------
R1, R2, R3, R4 = (96, 82, 74, 255), (122, 106, 94, 255), (70, 60, 56, 255), (150, 132, 114, 255)
RD1, RD2 = (48, 40, 40, 255), (34, 28, 30, 255)
DIRT1, DIRT2, DIRT3 = (92, 78, 64, 255), (82, 70, 58, 255), (70, 60, 50, 255)


def _rock_mass(im, seed=0):
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 15, 15], fill=RD1)
    for (x, y) in ((3, 4), (10, 2), (7, 10), (13, 12), (1, 13)):
        d.point(((x + seed) % 16, y), fill=RD2)
    d.line([2, 7, 5, 6], fill=RD2); d.line([9, 13, 12, 12], fill=RD2)
    return d


@item
def cave_face():          # the rock face of a cave wall: lumpy stone with a dark foot
    im = canvas(16, 16); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 15, 15], fill=R1)
    for (x0, y0, x1, y1, c) in ((0, 1, 6, 5, R2), (8, 0, 15, 4, R2), (3, 7, 10, 10, R2), (11, 6, 15, 10, R3), (0, 6, 2, 11, R3)):
        d.rectangle([x0, y0, x1, y1], fill=c)
    d.line([0, 6, 15, 6], fill=R3); d.line([7, 0, 7, 6], fill=R3); d.line([10, 6, 10, 11], fill=R3)
    d.point((2, 2), fill=R4); d.point((12, 1), fill=R4); d.point((5, 8), fill=R4)
    d.rectangle([0, 12, 15, 15], fill=RD1); d.line([0, 12, 15, 12], fill=R3)
    return im


@item
def cave_cap():           # top of a cave wall above its face, with a pale lip
    im = canvas(16, 16); _rock_mass(im); d = ImageDraw.Draw(im)
    d.rectangle([0, 11, 15, 15], fill=R3); d.line([0, 11, 15, 11], fill=R4)
    d.point((4, 12), fill=R1); d.point((11, 13), fill=R1)
    return im


@item
def cave_mass():
    im = canvas(16, 16); _rock_mass(im); return im


@item
def cave_side_l():        # a cave wall with floor to its east: the lip on the right
    im = canvas(16, 16); _rock_mass(im); d = ImageDraw.Draw(im)
    d.rectangle([11, 0, 15, 15], fill=R3); d.line([11, 0, 11, 15], fill=R4)
    d.point((13, 4), fill=R1); d.point((12, 11), fill=R1)
    return im


@item
def cave_side_r():
    im = canvas(16, 16); _rock_mass(im); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 4, 15], fill=R3); d.line([4, 0, 4, 15], fill=R4)
    d.point((2, 6), fill=R1); d.point((3, 13), fill=R1)
    return im


@item
def cave_south():         # a cave wall with floor to its north: the lip along the top
    im = canvas(16, 16); _rock_mass(im); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 15, 4], fill=R3); d.line([0, 4, 15, 4], fill=R4)
    return im


@item
def cave_corner_sw():
    im = canvas(16, 16); _rock_mass(im); d = ImageDraw.Draw(im)
    d.rectangle([11, 0, 15, 4], fill=R3); d.line([11, 0, 11, 4], fill=R4); d.line([11, 4, 15, 4], fill=R4)
    return im


@item
def cave_corner_se():
    im = canvas(16, 16); _rock_mass(im); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 4, 4], fill=R3); d.line([4, 0, 4, 4], fill=R4); d.line([0, 4, 4, 4], fill=R4)
    return im


@item
def cave_cap_l():
    im = items['cave_cap'](); d = ImageDraw.Draw(im)
    d.rectangle([11, 0, 15, 10], fill=R3); d.line([11, 0, 11, 10], fill=R4)
    return im


@item
def cave_cap_r():
    im = items['cave_cap'](); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 4, 10], fill=R3); d.line([4, 0, 4, 10], fill=R4)
    return im


def dirt_tile(seed):
    im = canvas(16, 16); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 15, 15], fill=(DIRT1, DIRT2, DIRT1, DIRT2)[seed])
    pts = [(2, 3), (9, 1), (13, 7), (5, 10), (11, 13), (1, 14), (7, 5)]
    for i, (x, y) in enumerate(pts):
        x = (x + seed * 5) % 16; y = (y + seed * 3) % 16
        d.point((x, y), fill=DIRT3 if i % 2 else R2)
    if seed == 1:
        d.rectangle([4, 6, 6, 7], fill=R1); d.point((5, 6), fill=R4)      # a pebble
    if seed == 3:
        d.line([8, 9, 12, 10], fill=DIRT3); d.line([12, 10, 14, 13], fill=DIRT3)   # a crack
    return im


for k in range(4):
    items['dirt_%d' % (k + 1)] = (lambda k=k: dirt_tile(k))


@item
def stalagmite():         # 14 x 22 rock spire
    im = canvas(14, 22); d = ImageDraw.Draw(im)
    d.polygon([(7, 0), (12, 16), (13, 21), (0, 21), (2, 15)], fill=R1, outline=O)
    d.line([7, 2, 9, 15], fill=R2); d.line([5, 8, 4, 18], fill=R3)
    d.point((7, 1), fill=R4); d.point((8, 6), fill=R4)
    d.rectangle([1, 19, 12, 20], fill=RD1)
    return im


@item
def rocks():              # 18 x 11 a pile of loose stones
    im = canvas(18, 11); d = ImageDraw.Draw(im)
    for (x0, y0, x1, y1) in ((0, 4, 8, 10), (6, 0, 14, 8), (11, 5, 17, 10)):
        d.ellipse([x0, y0, x1, y1], fill=R1, outline=O)
    d.point((9, 2), fill=R4); d.point((3, 6), fill=R4); d.point((14, 7), fill=R4)
    return im


@item
def bones():              # 16 x 8 scattered bones (flat)
    im = canvas(16, 8); d = ImageDraw.Draw(im)
    bone = (226, 216, 196, 255)
    d.line([1, 6, 9, 2], fill=bone, width=2); d.point((0, 6), fill=bone); d.point((10, 1), fill=bone)
    d.line([8, 6, 15, 6], fill=bone, width=1); d.ellipse([11, 0, 15, 4], fill=bone, outline=O)
    d.point((12, 2), fill=O); d.point((14, 2), fill=O)
    return im


@item
def glowcap():            # 12 x 10 glowing cave mushrooms
    im = canvas(12, 10); d = ImageDraw.Draw(im)
    for (x, h, c) in ((2, 6, (120, 230, 200, 255)), (7, 8, (150, 250, 220, 255)), (10, 4, (110, 210, 190, 255))):
        d.line([x, 9, x, 9 - h + 2], fill=(200, 190, 170, 255))
        d.ellipse([x - 2, 9 - h, x + 2, 9 - h + 3], fill=c, outline=(40, 90, 80, 255))
    return im


@item
def puddle():             # 28 x 12 a dark pool (flat)
    im = canvas(28, 12); d = ImageDraw.Draw(im)
    d.ellipse([0, 0, 27, 11], fill=(40, 52, 66, 255), outline=(30, 34, 44, 255))
    d.ellipse([4, 2, 20, 8], fill=(52, 70, 88, 255))
    d.line([8, 3, 13, 3], fill=(120, 150, 170, 255))
    return im


@item
def tunnel():             # 28 x 30 the way on: a dark passage in a cave face
    im = canvas(28, 30); d = ImageDraw.Draw(im)
    d.rectangle([0, 6, 27, 29], fill=R3)
    d.ellipse([0, 0, 27, 20], fill=R3)
    d.ellipse([3, 3, 24, 22], fill=(16, 12, 14, 255))
    d.rectangle([3, 12, 24, 29], fill=(16, 12, 14, 255))
    for (x, y) in ((1, 9), (25, 12), (2, 20), (24, 24), (13, 1)):
        d.point((x, y), fill=R4)
    d.rectangle([0, 27, 27, 29], fill=RD1)
    return im


@item
def tunnel_barred():      # the same, barred with goblin-lashed planks until the room is cleared
    im = items['tunnel'](); d = ImageDraw.Draw(im)
    for x in (6, 12, 18):
        d.rectangle([x, 4, x + 3, 28], fill=W3, outline=O)
    d.rectangle([3, 10, 24, 12], fill=W1, outline=O); d.rectangle([3, 20, 24, 22], fill=W1, outline=O)
    return im


@item
def goblin_tent():        # 34 x 28 a hide tent
    im = canvas(34, 28); d = ImageDraw.Draw(im)
    hide, hide2 = (150, 118, 80, 255), (118, 90, 60, 255)
    d.polygon([(17, 0), (33, 27), (0, 27)], fill=hide, outline=O)
    d.polygon([(17, 6), (23, 27), (11, 27)], fill=(30, 22, 20, 255))
    d.line([17, 0, 6, 27], fill=hide2); d.line([17, 0, 28, 27], fill=hide2)
    d.line([15, 0, 19, 0], fill=W3); d.point((17, 0), fill=W4)
    return im


@item
def totem():              # 12 x 26 a goblin totem pole with a skull
    im = canvas(12, 26); d = ImageDraw.Draw(im)
    box(d, 4, 8, 7, 25, W3)
    bone = (226, 216, 196, 255)
    d.ellipse([1, 0, 10, 9], fill=bone, outline=O)
    d.point((4, 4), fill=O); d.point((7, 4), fill=O); d.line([4, 7, 7, 7], fill=O)
    d.line([0, 13, 11, 13], fill=RED1); d.point((0, 14), fill=RED2); d.point((11, 14), fill=RED2)
    return im


@item
def bedroll():            # 20 x 10 a goblin's bedroll (flat)
    im = canvas(20, 10); d = ImageDraw.Draw(im)
    box(d, 0, 1, 19, 9, (110, 90, 70, 255)); d.rectangle([1, 2, 6, 8], fill=(140, 116, 88, 255))
    d.line([7, 2, 7, 8], fill=O)
    return im


@item
def throne():             # 30 x 32 the Bugbear Chief's bone throne
    im = canvas(30, 32); d = ImageDraw.Draw(im)
    bone = (226, 216, 196, 255); bone2 = (190, 178, 156, 255)
    box(d, 2, 0, 27, 20, W3)
    for x in (3, 9, 15, 21):
        d.ellipse([x, 0, x + 5, 5], fill=bone, outline=O)
    box(d, 0, 16, 29, 31, W1)
    d.rectangle([4, 18, 25, 22], fill=RED2)
    box(d, 0, 14, 4, 31, bone2); box(d, 25, 14, 29, 31, bone2)
    return im


@item
def torch_post():         # 8 x 22 a torch on a stake (light source in the warren)
    im = canvas(8, 22); d = ImageDraw.Draw(im)
    box(d, 3, 8, 4, 21, W3)
    d.ellipse([1, 1, 6, 8], fill=(255, 170, 60, 255), outline=(170, 70, 30, 255))
    d.ellipse([2, 2, 5, 6], fill=(255, 235, 150, 255))
    return im


# ---------------- pack ----------------
built = {k: (fn() if callable(fn) else fn) for k, fn in items.items()}
order = sorted(built, key=lambda k: -built[k].size[1])
W = 512
x = y = rowh = 0
rects = {}
for k in order:
    im = built[k]
    if x + im.size[0] > W:
        x = 0; y += rowh + 1; rowh = 0
    rects[k] = (x, y, im.size[0], im.size[1])
    x += im.size[0] + 1
    rowh = max(rowh, im.size[1])
sheet = canvas(W, y + rowh + 1)
for k, (rx, ry, rw, rh) in rects.items():
    sheet.paste(built[k], (rx, ry), built[k])
sheet.save(G + '/assets/sprites/td_inn.png')
with open(G + '/scripts/td/td_art_rects.gd', 'w') as f:
    f.write('class_name TDArtRects\n## Generated by tools/make_td_inn_art.py: regions in td_inn.png.\n\n')
    f.write('const RECTS := {\n')
    for k, r in sorted(rects.items()):
        f.write('\t"%s": Rect2(%d, %d, %d, %d),\n' % (k, *r))
    f.write('}\n')
preview = sheet.resize((sheet.size[0] * 2, sheet.size[1] * 2), Image.NEAREST)
bg = Image.new('RGBA', preview.size, (60, 54, 66, 255)); bg.alpha_composite(preview); bg.save('/tmp/td_inn_sheet.png')
print(len(rects), 'pieces', sheet.size)
