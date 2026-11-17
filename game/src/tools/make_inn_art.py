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


makers = {'table': table, 'stool': stool, 'chair_r': lambda: chair(False), 'chair_l': lambda: chair(True), 'bench': bench,
          'bar': bar_segment, 'bar_end': bar_end, 'shelf': shelf, 'couch': couch, 'fireplace': fireplace,
          'barrel': barrel, 'window': window, 'lantern': lantern, 'rug': rug, 'bed': bed, 'stage': stage,
          'curtain': curtain, 'chalkboard': chalkboard, 'plank': plank_floor, 'mug': mug, 'book': book, 'railing': railing}
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
print(len(rects), 'props', sheet.size)
