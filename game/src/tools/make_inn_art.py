"""Original pixel-art furniture for the Gryphon's Roost Inn, drawn to sit with the 0x72 palette.
Writes assets/sprites/inn_props.png and scripts/data/inn_props.gd (atlas rects). Usage: make_inn_art.py <game_dir>"""
import sys
from PIL import Image, ImageDraw
G = sys.argv[1]
O = (34, 34, 34, 255)            # 0x72 outline
W1, W2, W3, W4 = (138, 80, 62, 255), (181, 128, 87, 255), (107, 62, 46, 255), (211, 160, 110, 255)   # woods
ST1, ST2 = (123, 137, 148, 255), (86, 96, 110, 255)
RED1, RED2 = (176, 52, 60, 255), (128, 34, 44, 255)
GOLD = (250, 203, 62, 255)
CREAM = (253, 247, 237, 255)
items = {}


def canvas(w, h):
    return Image.new('RGBA', (w, h), (0, 0, 0, 0))


def box(d, x0, y0, x1, y1, fill, outline=O):
    d.rectangle([x0, y0, x1, y1], fill=fill, outline=outline)


def table():
    im = canvas(32, 16); d = ImageDraw.Draw(im)
    box(d, 0, 0, 31, 3, W2); d.line([1, 1, 30, 1], fill=W4)
    box(d, 13, 3, 18, 13, W1); box(d, 8, 13, 23, 15, W3)
    d.point((6, -1 + 1), fill=None)
    return im


def stool():
    im = canvas(10, 10); d = ImageDraw.Draw(im)
    box(d, 0, 0, 9, 2, W2); box(d, 1, 2, 2, 9, W1); box(d, 7, 2, 8, 9, W1); d.line([2, 6, 7, 6], fill=W3)
    return im


def chair(flip=False):
    im = canvas(12, 20); d = ImageDraw.Draw(im)
    box(d, 0, 0, 2, 19, W1)              # back post
    box(d, 0, 9, 11, 11, W2)             # seat
    box(d, 9, 11, 10, 19, W1)            # front leg
    d.line([1, 3, 1, 8], fill=W4)
    return im.transpose(Image.FLIP_LEFT_RIGHT) if flip else im


def bench():
    im = canvas(32, 9); d = ImageDraw.Draw(im)
    box(d, 0, 0, 31, 2, W2); box(d, 2, 2, 4, 8, W1); box(d, 27, 2, 29, 8, W1)
    return im


def bar_segment():
    im = canvas(16, 26); d = ImageDraw.Draw(im)
    box(d, -1, 0, 16, 4, W4); d.line([0, 1, 15, 1], fill=CREAM)
    box(d, -1, 4, 16, 25, W1)
    d.rectangle([2, 8, 13, 21], outline=W3); d.line([3, 9, 12, 9], fill=W2)
    return im


def bar_end():
    im = canvas(6, 26); d = ImageDraw.Draw(im)
    box(d, 0, 0, 5, 4, W4); box(d, 0, 4, 5, 25, W3)
    return im


def shelf():
    im = canvas(48, 30); d = ImageDraw.Draw(im)
    for y in (10, 22):
        box(d, 0, y, 47, y + 2, W2)
    cols = [(86, 152, 204, 255), (75, 167, 71, 255), (218, 78, 56, 255), (250, 203, 62, 255), (89, 86, 189, 255), (238, 142, 46, 255)]
    x = 2; i = 0
    for row_y in (10, 22):
        x = 2 + (row_y // 11)
        while x < 44:
            c = cols[i % len(cols)]; i += 1
            h = 6 + (i * 3) % 4
            box(d, x, row_y - h, x + 3, row_y - 1, c)
            d.point((x + 1, row_y - h + 1), fill=CREAM)
            box(d, x + 1, row_y - h - 2, x + 2, row_y - h, O)
            x += 6 + i % 2
    return im


def couch():
    im = canvas(44, 20); d = ImageDraw.Draw(im)
    box(d, 2, 2, 41, 12, RED2)                    # back
    box(d, 0, 6, 6, 17, RED1); box(d, 37, 6, 43, 17, RED1)   # arms
    box(d, 5, 10, 38, 16, RED1)                   # seat cushions
    d.line([21, 11, 21, 15], fill=RED2)
    d.line([6, 4, 36, 4], fill=(200, 90, 96, 255))
    box(d, 2, 17, 4, 19, W3); box(d, 39, 17, 41, 19, W3)
    return im


def fireplace():
    im = canvas(48, 48); d = ImageDraw.Draw(im)
    box(d, 0, 4, 47, 47, ST1)
    for y in range(8, 46, 6):
        off = 0 if (y // 6) % 2 else 6
        for x in range(off, 47, 12):
            d.rectangle([x + 1, y, x + 10, y + 4], outline=ST2)
    box(d, -1, 0, 48, 6, W2)                       # mantel
    d.line([0, 2, 47, 2], fill=W4)
    box(d, 10, 18, 37, 47, (20, 14, 16, 255))      # firebox
    d.pieslice([10, 10, 37, 30], 180, 360, fill=(20, 14, 16, 255), outline=O)
    box(d, 14, 42, 33, 45, W3)                      # logs
    return im


def barrel():
    im = canvas(14, 18); d = ImageDraw.Draw(im)
    d.ellipse([0, 0, 13, 17], fill=W1, outline=O)
    d.rectangle([2, 1, 11, 16], fill=W1)
    for y in (4, 13):
        d.line([1, y, 12, y], fill=ST2)
    d.line([4, 2, 4, 15], fill=W2)
    return im


def window():
    im = canvas(24, 30); d = ImageDraw.Draw(im)
    box(d, 0, 0, 23, 29, W3)
    box(d, 3, 3, 20, 26, (40, 52, 92, 255))
    d.line([11, 3, 11, 26], fill=W3, width=2); d.line([3, 14, 20, 14], fill=W3, width=2)
    for p in [(6, 6), (16, 9), (8, 20), (18, 22)]:
        d.point(p, fill=CREAM)
    d.ellipse([14, 4, 18, 8], fill=(240, 236, 200, 255))
    return im


def lantern():
    im = canvas(8, 14); d = ImageDraw.Draw(im)
    d.line([3, 0, 3, 3], fill=O); d.line([4, 0, 4, 3], fill=O)
    box(d, 1, 4, 6, 12, GOLD); box(d, 2, 6, 5, 10, (255, 236, 160, 255), None)
    box(d, 0, 12, 7, 13, ST2)
    return im


def rug():
    im = canvas(48, 4); d = ImageDraw.Draw(im)
    box(d, 0, 0, 47, 3, RED2); d.line([2, 1, 45, 1], fill=GOLD)
    return im


def bed():
    im = canvas(34, 18); d = ImageDraw.Draw(im)
    box(d, 0, 0, 3, 17, W1); box(d, 30, 6, 33, 17, W1)
    box(d, 3, 9, 30, 14, W2)
    box(d, 3, 6, 30, 10, CREAM); box(d, 4, 5, 10, 9, (220, 220, 230, 255))
    box(d, 11, 6, 30, 10, (89, 86, 189, 255))
    return im


def stage():
    im = canvas(96, 12); d = ImageDraw.Draw(im)
    box(d, 0, 0, 95, 11, W1)
    d.line([1, 1, 94, 1], fill=W4)
    for x in range(12, 95, 16):
        d.line([x, 3, x, 10], fill=W3)
    return im


def curtain():
    im = canvas(16, 72); d = ImageDraw.Draw(im)
    box(d, 0, 0, 15, 71, RED1)
    for x in (4, 9, 13):
        d.line([x, 2, x, 70], fill=RED2)
    box(d, 0, 0, 15, 4, GOLD)
    return im


def chalkboard():
    im = canvas(52, 40); d = ImageDraw.Draw(im)
    box(d, 0, 0, 51, 39, W1); box(d, 3, 3, 48, 36, (36, 52, 44, 255), None)
    return im


def plank_floor():
    im = canvas(16, 4); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 15, 3], fill=W2); d.line([0, 0, 15, 0], fill=W4); d.line([10, 1, 10, 3], fill=W3)
    return im


def mug():
    im = canvas(6, 6); d = ImageDraw.Draw(im)
    box(d, 0, 1, 4, 5, (220, 220, 220, 255)); d.line([1, 1, 3, 1], fill=CREAM); box(d, 4, 2, 5, 4, None)
    return im


def book():
    im = canvas(8, 4); d = ImageDraw.Draw(im)
    box(d, 0, 0, 7, 3, (89, 86, 189, 255)); d.line([1, 1, 6, 1], fill=CREAM)
    return im


def railing():
    im = canvas(16, 14); d = ImageDraw.Draw(im)
    box(d, 0, 0, 15, 2, W2)
    for x in (2, 7, 12):
        box(d, x, 2, x + 1, 13, W1, None)
    return im


# ---------------- the party's private rooms ----------------
STONE1, STONE2 = (150, 146, 140, 255), (110, 106, 102, 255)
FUR1, FUR2 = (92, 66, 46, 255), (122, 92, 64, 255)
STEEL1, STEEL2, STEEL3 = (196, 204, 214, 255), (140, 150, 164, 255), (96, 104, 118, 255)
NAVY, VIOLET = (36, 40, 84, 255), (110, 72, 170, 255)
LEAF1, LEAF2, LEAF3 = (58, 120, 62, 255), (86, 160, 80, 255), (40, 86, 46, 255)
GREEN_B = (46, 110, 66, 255)
SKY = (120, 170, 220, 255)


def big_bed():          # goliath-sized bed with a fur blanket
    im = canvas(48, 18); d = ImageDraw.Draw(im)
    box(d, 0, 0, 4, 17, W3); box(d, 43, 5, 47, 17, W3)
    box(d, 4, 10, 43, 15, W1)
    box(d, 4, 7, 12, 11, CREAM)
    box(d, 12, 6, 43, 11, FUR1); d.line([14, 7, 41, 7], fill=FUR2); d.line([16, 9, 40, 9], fill=FUR2)
    return im


def pelt():             # bear-skin rug, seen from the side as it lies on the floor
    im = canvas(42, 8); d = ImageDraw.Draw(im)
    d.polygon([(2, 7), (6, 2), (12, 4), (18, 1), (26, 1), (31, 4), (34, 2), (36, 7)], fill=FUR1, outline=O)
    d.line([8, 5, 32, 5], fill=FUR2); d.line([14, 3, 26, 3], fill=FUR2)
    d.ellipse([34, 1, 41, 7], fill=FUR1, outline=O); d.point((38, 3), fill=CREAM); d.point((40, 5), fill=O)
    return im


def axe_rack():         # wall rack holding a greataxe
    im = canvas(26, 26); d = ImageDraw.Draw(im)
    box(d, 2, 3, 23, 5, W3); box(d, 2, 18, 23, 20, W3)
    d.line([13, 1, 13, 25], fill=W1, width=2)
    d.polygon([(14, 2), (24, 0), (25, 9), (14, 7)], fill=STEEL1, outline=O)
    d.polygon([(12, 2), (2, 0), (1, 9), (12, 7)], fill=STEEL2, outline=O)
    return im


def boar_head():        # hunting trophy
    im = canvas(22, 18); d = ImageDraw.Draw(im)
    box(d, 3, 2, 18, 15, W2)
    d.ellipse([5, 3, 17, 14], fill=FUR1, outline=O)
    box(d, 8, 10, 14, 15, FUR2); d.point((9, 13), fill=O); d.point((13, 13), fill=O)
    d.line([7, 12, 5, 9], fill=CREAM); d.line([15, 12, 17, 9], fill=CREAM)
    d.point((8, 7), fill=(240, 80, 50, 255)); d.point((14, 7), fill=(240, 80, 50, 255))
    return im


def mountain_painting():
    im = canvas(26, 18); d = ImageDraw.Draw(im)
    box(d, 0, 0, 25, 17, W2); box(d, 2, 2, 23, 15, SKY, None)
    d.polygon([(2, 15), (9, 5), (14, 11), (18, 6), (23, 15)], fill=STONE2)
    d.polygon([(9, 5), (11, 8), (7, 8)], fill=CREAM); d.polygon([(18, 6), (20, 9), (16, 9)], fill=CREAM)
    return im


def bookcase():
    im = canvas(26, 42); d = ImageDraw.Draw(im)
    box(d, 0, 0, 25, 41, W3)
    cols = [(176, 52, 60, 255), (89, 86, 189, 255), (86, 152, 204, 255), (75, 167, 71, 255), (250, 203, 62, 255), (110, 72, 170, 255)]
    for row, y in enumerate((3, 13, 23, 33)):
        x = 2
        i = row
        while x < 23:
            w = 2 + (i % 2)
            hgt = 7 - (i % 3)
            d.rectangle([x, y + 8 - hgt, x + w - 1, y + 7], fill=cols[i % len(cols)])
            x += w + (1 if i % 4 == 0 else 0)
            i += 1
        d.line([1, y + 8, 24, y + 8], fill=W1)
    return im


def desk():             # wizard's desk: open spellbook and candle
    im = canvas(30, 18); d = ImageDraw.Draw(im)
    box(d, 0, 6, 29, 9, W2); box(d, 2, 9, 4, 17, W1); box(d, 25, 9, 27, 17, W1)
    box(d, 6, 3, 18, 6, CREAM); d.line([12, 3, 12, 6], fill=W3)
    d.line([8, 4, 10, 4], fill=VIOLET); d.line([14, 4, 16, 4], fill=VIOLET)
    box(d, 23, 2, 24, 6, CREAM, None); d.point((23, 0), fill=GOLD); d.point((23, 1), fill=(255, 140, 40, 255))
    return im


def star_chart():
    im = canvas(26, 22); d = ImageDraw.Draw(im)
    box(d, 0, 0, 25, 21, NAVY, (200, 180, 120, 255))
    for x, y in ((4, 4), (9, 7), (15, 3), (20, 9), (7, 15), (14, 13), (21, 17), (11, 18)):
        d.point((x, y), fill=CREAM)
    d.line([4, 4, 9, 7], fill=(150, 150, 200, 255)); d.line([9, 7, 15, 3], fill=(150, 150, 200, 255)); d.line([7, 15, 14, 13], fill=(150, 150, 200, 255))
    d.arc([14, 9, 24, 19], 0, 360, fill=GOLD)
    return im


def crystal_ball():
    im = canvas(10, 12); d = ImageDraw.Draw(im)
    d.ellipse([1, 0, 9, 8], fill=(150, 200, 240, 255), outline=O); d.point((3, 2), fill=CREAM); d.point((4, 2), fill=CREAM)
    box(d, 2, 8, 8, 11, W3)
    return im


def altar():            # small stone altar with a sun symbol
    im = canvas(26, 20); d = ImageDraw.Draw(im)
    box(d, 2, 6, 23, 19, STONE1); d.line([3, 7, 22, 7], fill=CREAM)
    box(d, 0, 4, 25, 7, STONE2)
    d.ellipse([10, 10, 16, 16], fill=GOLD, outline=O)
    for a, b2 in (((13, 8), (13, 9)), ((13, 17), (13, 18)), ((8, 13), (9, 13)), ((17, 13), (18, 13))):
        d.line([a, b2], fill=GOLD)
    box(d, 3, 1, 4, 4, CREAM, None); d.point((3, 0), fill=GOLD)
    box(d, 21, 1, 22, 4, CREAM, None); d.point((21, 0), fill=GOLD)
    return im


def sun_window():       # stained glass
    im = canvas(20, 26); d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, 19, 25], 8, fill=STONE2, outline=O)
    d.rounded_rectangle([2, 2, 17, 23], 7, fill=(240, 170, 60, 255))
    d.ellipse([6, 6, 13, 13], fill=GOLD); d.line([9, 2, 9, 23], fill=O); d.line([2, 15, 17, 15], fill=O)
    d.rectangle([3, 16, 8, 22], fill=(200, 70, 60, 255)); d.rectangle([10, 16, 16, 22], fill=(90, 120, 200, 255))
    return im


def armor_stand(plate=False):
    im = canvas(16, 30); d = ImageDraw.Draw(im)
    box(d, 7, 2, 8, 29, W1, None); box(d, 3, 27, 12, 29, W3)
    if plate:
        box(d, 4, 2, 11, 7, STEEL2); d.line([5, 4, 10, 4], fill=STEEL3)        # helm
        box(d, 2, 8, 13, 19, STEEL1); d.line([7, 9, 7, 18], fill=STEEL2)       # breastplate
        box(d, 0, 8, 2, 12, STEEL2); box(d, 13, 8, 15, 12, STEEL2)             # pauldrons
        box(d, 4, 19, 11, 22, STEEL2)
    else:
        box(d, 3, 7, 12, 19, STEEL2)                                           # chain shirt
        for y in range(8, 19, 2):
            d.line([4, y, 11, y], fill=STEEL3)
        d.ellipse([9, 12, 15, 21], fill=(250, 203, 62, 255), outline=O)        # shield with sun
    return im


def cot():
    im = canvas(34, 12); d = ImageDraw.Draw(im)
    box(d, 0, 4, 33, 7, W1); box(d, 1, 7, 2, 11, W3); box(d, 31, 7, 32, 11, W3)
    box(d, 2, 2, 8, 5, CREAM); box(d, 9, 3, 32, 5, (150, 140, 120, 255))
    return im


def banner_green():     # Lyburnum's tabard banner
    im = canvas(16, 30); d = ImageDraw.Draw(im)
    d.line([0, 1, 15, 1], fill=W3, width=2)
    d.polygon([(2, 2), (13, 2), (13, 25), (7, 29), (2, 25)], fill=GREEN_B, outline=O)
    d.line([7, 7, 7, 21], fill=STEEL1); d.line([4, 10, 10, 10], fill=GOLD); d.point((7, 6), fill=GOLD)
    return im


def sword_rack():
    im = canvas(22, 26); d = ImageDraw.Draw(im)
    box(d, 1, 21, 20, 25, W1)
    d.line([6, 2, 6, 21], fill=STEEL1, width=2); d.line([3, 16, 9, 16], fill=GOLD); d.point((6, 19), fill=W3)
    d.ellipse([10, 5, 21, 21], fill=GREEN_B, outline=O); d.ellipse([13, 9, 18, 17], fill=STEEL2)
    return im


def dummy():            # training dummy
    im = canvas(16, 30); d = ImageDraw.Draw(im)
    box(d, 7, 12, 8, 29, W1, None); box(d, 3, 27, 12, 29, W3)
    d.ellipse([4, 0, 11, 7], fill=(200, 180, 120, 255), outline=O)
    box(d, 3, 8, 12, 18, (190, 168, 110, 255)); d.line([0, 11, 15, 11], fill=W1, width=2)
    d.line([5, 10, 10, 16], fill=(150, 60, 50, 255)); d.line([10, 10, 5, 16], fill=(150, 60, 50, 255))
    return im


def plant_pot(tall=False):
    h = 22 if tall else 16
    im = canvas(14, h); d = ImageDraw.Draw(im)
    box(d, 3, h - 6, 10, h - 1, (170, 96, 64, 255)); d.line([3, h - 5, 10, h - 5], fill=(200, 120, 80, 255))
    for i, (x, y) in enumerate(((7, 1), (3, 4), (11, 4), (5, 8), (9, 9), (2, 10), (12, 10))):
        if y < h - 6:
            d.ellipse([x - 2, y, x + 2, y + 4], fill=(LEAF1, LEAF2, LEAF3)[i % 3], outline=O)
    d.line([7, 3, 7, h - 6], fill=LEAF3)
    return im


def hanging_vines():
    im = canvas(28, 24); d = ImageDraw.Draw(im)
    d.line([0, 0, 27, 0], fill=W3, width=2)
    for x, ln in ((3, 18), (9, 23), (15, 14), (21, 20), (26, 12)):
        d.line([x, 1, x + (1 if x % 2 else -1), ln], fill=LEAF3)
        for y in range(3, ln, 4):
            d.point((x + (1 if (y // 4) % 2 else -1), y), fill=LEAF2)
    d.point((9, 22), fill=(220, 90, 120, 255)); d.point((21, 19), fill=(240, 220, 90, 255))
    return im


def herb_rack():
    im = canvas(26, 16); d = ImageDraw.Draw(im)
    d.line([0, 1, 25, 1], fill=W1, width=2)
    for i, x in enumerate((3, 9, 15, 21)):
        d.line([x, 2, x, 5], fill=O)
        d.polygon([(x - 3, 5), (x + 3, 5), (x + 1, 14), (x - 1, 14)], fill=(LEAF2, (150, 130, 70, 255), LEAF1, (130, 90, 150, 255))[i], outline=O)
    return im


def leaf_bed():         # elven bed of moss and leaves
    im = canvas(38, 12); d = ImageDraw.Draw(im)
    box(d, 0, 6, 37, 11, W3)
    d.ellipse([1, 1, 36, 9], fill=LEAF1, outline=O)
    for x in range(4, 34, 5):
        d.ellipse([x, 2 + (x % 3), x + 4, 5 + (x % 3)], fill=LEAF2)
    box(d, 2, 3, 8, 6, (200, 220, 170, 255))
    return im


def mushrooms():
    im = canvas(14, 9); d = ImageDraw.Draw(im)
    for x, c in ((2, (200, 60, 60, 255)), (7, (230, 180, 90, 255)), (11, (180, 120, 200, 255))):
        d.line([x + 1, 4, x + 1, 8], fill=CREAM)
        d.ellipse([x - 1, 1, x + 3, 5], fill=c, outline=O)
    return im


def moon_window():
    im = canvas(22, 22); d = ImageDraw.Draw(im)
    d.ellipse([0, 0, 21, 21], fill=W2, outline=O); d.ellipse([2, 2, 19, 19], fill=NAVY)
    d.ellipse([7, 5, 15, 13], fill=CREAM); d.ellipse([9, 4, 17, 12], fill=NAVY)
    for x, y in ((5, 14), (14, 16), (16, 7)):
        d.point((x, y), fill=CREAM)
    d.line([2, 10, 19, 10], fill=W1); d.line([10, 2, 10, 19], fill=W1)
    return im


def doorway():          # an open doorway between two private rooms (posts and lintel)
    im = canvas(28, 80); d = ImageDraw.Draw(im)
    box(d, 0, 0, 27, 34, W3)                       # wall above the doorway
    for y in range(4, 34, 6):
        d.line([1, y, 26, y], fill=W1)
    box(d, 0, 34, 5, 79, W1); box(d, 22, 34, 27, 79, W1)   # posts
    box(d, 0, 32, 27, 36, W2)                      # lintel
    return im


def wood_tiles():       # 16x16 tiles: back wall planks, solid beam, top trim
    im = canvas(48, 16); d = ImageDraw.Draw(im)
    PL1, PL2, PL3 = (122, 82, 56, 255), (104, 68, 46, 255), (82, 52, 36, 255)
    for x0 in (0, 4, 8, 12):
        c = (PL1, PL2, PL1, PL2)[x0 // 4]
        d.rectangle([x0, 0, x0 + 3, 15], fill=c)
        d.line([x0, 0, x0, 15], fill=PL3)
        d.point((x0 + 1, 5 + x0 % 7), fill=PL3)
    d.line([0, 15, 15, 15], fill=PL3)
    d.line([4, 9, 7, 9], fill=PL3)
    # solid beam
    d.rectangle([16, 0, 31, 15], fill=(92, 58, 40, 255)); d.line([16, 0, 31, 0], fill=(140, 96, 64, 255))
    d.line([16, 7, 31, 7], fill=(72, 44, 30, 255)); d.line([16, 15, 31, 15], fill=(60, 36, 24, 255))
    d.point((20, 3), fill=(60, 36, 24, 255)); d.point((27, 11), fill=(60, 36, 24, 255))
    # trim
    d.rectangle([32, 0, 47, 4], fill=(150, 104, 70, 255)); d.line([32, 4, 47, 4], fill=(70, 44, 30, 255))
    return im


makers = {'table': table, 'stool': stool, 'chair_r': lambda: chair(False), 'chair_l': lambda: chair(True), 'bench': bench,
          'bar': bar_segment, 'bar_end': bar_end, 'shelf': shelf, 'couch': couch, 'fireplace': fireplace,
          'barrel': barrel, 'window': window, 'lantern': lantern, 'rug': rug, 'bed': bed, 'stage': stage,
          'curtain': curtain, 'chalkboard': chalkboard, 'plank': plank_floor, 'mug': mug, 'book': book, 'railing': railing,
          'big_bed': big_bed, 'pelt': pelt, 'axe_rack': axe_rack, 'boar_head': boar_head, 'mountain_painting': mountain_painting,
          'bookcase': bookcase, 'desk': desk, 'star_chart': star_chart, 'crystal_ball': crystal_ball,
          'altar': altar, 'sun_window': sun_window, 'chain_stand': lambda: armor_stand(False), 'cot': cot,
          'plate_stand': lambda: armor_stand(True), 'banner_green': banner_green, 'sword_rack': sword_rack, 'dummy': dummy,
          'plant_pot': lambda: plant_pot(False), 'plant_tall': lambda: plant_pot(True), 'hanging_vines': hanging_vines,
          'herb_rack': herb_rack, 'leaf_bed': leaf_bed, 'mushrooms': mushrooms, 'moon_window': moon_window,
          'doorway': doorway}
ims = {k: f() for k, f in makers.items()}
x = 0
H = max(i.height for i in ims.values())
sheet = Image.new('RGBA', (sum(i.width + 2 for i in ims.values()), H), (0, 0, 0, 0))
rects = {}
for k, im in ims.items():
    sheet.paste(im, (x, 0), im); rects[k] = (x, 0, im.width, im.height); x += im.width + 2
sheet.save(G + '/assets/sprites/inn_props.png')
with open(G + '/scripts/data/inn_props.gd', 'w') as f:
    f.write('## Generated by tools/make_inn_art.py: original pixel furniture for the Gryphon\'s Roost.\nclass_name InnProps\n\n')
    f.write('const TEX := preload("res://assets/sprites/inn_props.png")\n\nconst RECTS := {\n')
    for k, r in rects.items():
        f.write('\t"%s": Rect2(%d, %d, %d, %d),\n' % ((k,) + r))
    f.write('}\n\nstatic var _cache := {}\n\n\nstatic func tex(name: String) -> AtlasTexture:\n\tif not _cache.has(name):\n\t\tvar t := AtlasTexture.new()\n\t\tt.atlas = TEX\n\t\tt.region = RECTS[name]\n\t\t_cache[name] = t\n\treturn _cache[name]\n')
prev = Image.new('RGBA', (sheet.width + 8, H + 8), (60, 54, 66, 255)); prev.paste(sheet, (4, 4), sheet)
prev.resize((prev.width * 3, prev.height * 3), Image.NEAREST).save('/tmp/props.png')
wood_tiles().save(G + '/assets/sprites/inn_tiles.png')
print(len(rects), 'props', sheet.size)
