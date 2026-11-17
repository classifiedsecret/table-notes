"""Authors the Goblin Warren room layouts as text grids and checks them against the hero's jump.
Jump: 3.6 tiles up, 4.4 tiles across on the flat. Rules enforced: gaps <= 3, steps <= 3, platforms 3 apart.
Legend: # solid, = one-way platform, ^ spikes, S start, X exit, g goblin, G goblin warrior, a goblin archer,
B boss, C chest, F campfire, D dart trap firing left, d dart trap firing right, b banner, h wall hole, c column."""
import sys, os
OUT = sys.argv[1]
H = 17
FLOOR = 13  # first solid row of the floor


class Room:
    def __init__(self, w):
        self.w = w
        self.g = [['.'] * w for _ in range(H)]
        for x in range(w):
            self.g[0][x] = '#'
            for y in range(FLOOR, H):
                self.g[y][x] = '#'
        for y in range(H):
            self.g[y][0] = self.g[y][w - 1] = '#'

    def put(self, x, y, ch): self.g[y][x] = ch
    def plat(self, x0, x1, y):
        for x in range(x0, x1 + 1): self.g[y][x] = '='
    def block(self, x0, x1, top):
        for x in range(x0, x1 + 1):
            for y in range(top, FLOOR): self.g[y][x] = '#'
    def pit(self, x0, x1, spikes=True):
        assert x1 - x0 + 1 <= 3, "pit too wide to jump"
        for x in range(x0, x1 + 1):
            self.g[FLOOR][x] = '.'
            self.g[FLOOR + 1][x] = '^' if spikes else '.'
    def ends(self):
        self.put(2, FLOOR - 1, 'S'); self.put(self.w - 3, FLOOR - 1, 'X')
    def deco(self, items):
        for x, ch in items:
            y = {'b': 4, 'h': 3, 'c': FLOOR - 1}[ch]
            if self.g[y][x] == '.': self.g[y][x] = ch
    def text(self):
        return '\n'.join(''.join(r) for r in self.g) + '\n'


rooms = {}

r = Room(46); r.ends(); r.plat(12, 17, 10); r.plat(28, 33, 10)
for x, ch in [(30, 'g'), (36, 'g'), (40, 'G')]: r.put(x, FLOOR - 1, ch)
r.deco([(8, 'b'), (20, 'h'), (34, 'b'), (16, 'c'), (25, 'c')]); rooms['warren_combat_1'] = r

r = Room(54); r.ends(); r.block(22, 29, 11); r.plat(10, 15, 10); r.plat(33, 38, 9); r.plat(24, 28, 8)
for x, ch, y in [(26, 'G', 10), (36, 'a', 8), (44, 'g', 12), (47, 'g', 12)]: r.put(x, y, ch)
r.deco([(6, 'b'), (18, 'h'), (40, 'b'), (14, 'c'), (42, 'c')]); rooms['warren_combat_2'] = r

r = Room(52); r.ends(); r.pit(24, 26); r.plat(8, 13, 10); r.plat(20, 30, 10); r.plat(36, 41, 10)
for x, ch, y in [(25, 'a', 9), (34, 'g', 12), (40, 'G', 12), (45, 'g', 12)]: r.put(x, y, ch)
r.deco([(5, 'b'), (16, 'h'), (33, 'b'), (46, 'h'), (18, 'c'), (31, 'c')]); rooms['warren_combat_3'] = r

r = Room(64); r.ends()
for a in (14, 26, 38): r.pit(a, a + 2)
r.block(48, 51, 11)
r.put(62, FLOOR - 1, '#'); r.put(62, FLOOR - 2, '#')
r.put(61, FLOOR - 1, 'D'); r.put(61, 9, 'D'); r.put(1, 10, 'd')
r.plat(30, 34, 10)
r.put(56, FLOOR - 1, 'g'); r.put(59, FLOOR - 1, '.'); r.put(r.w - 3, FLOOR - 1, '.'); r.put(r.w - 4, FLOOR - 1, 'X')
r.deco([(8, 'b'), (20, 'h'), (32, 'b'), (44, 'h'), (54, 'b')]); rooms['warren_gauntlet_1'] = r

r = Room(60); r.ends()
# stepping stones: 3-wide spike gaps between 2-wide pillars of floor
for a in (10, 15, 20, 25, 30, 35, 40):
    r.pit(a, a + 2)
r.plat(13, 17, 10); r.plat(28, 32, 10)
r.put(1, 11, 'd'); r.put(58, 9, 'D')
r.put(50, FLOOR - 1, 'a')
r.deco([(6, 'b'), (22, 'h'), (37, 'b'), (52, 'h')]); rooms['warren_gauntlet_2'] = r

r = Room(38); r.ends(); r.block(16, 22, 11); r.plat(8, 12, 10); r.plat(25, 29, 10)
r.put(19, 10, 'C'); r.put(26, 9, 'g'); r.put(31, 12, 'g')
r.deco([(6, 'b'), (14, 'h'), (24, 'b'), (32, 'h')]); rooms['warren_treasure_1'] = r

r = Room(34); r.ends(); r.put(17, FLOOR - 1, 'F')
r.deco([(6, 'b'), (12, 'h'), (22, 'b'), (28, 'h'), (9, 'c'), (25, 'c')]); rooms['warren_campfire_1'] = r

r = Room(56); r.ends(); r.plat(12, 17, 10); r.plat(24, 31, 10); r.plat(38, 43, 10); r.block(46, 49, 11)
for x, ch, y in [(14, 'a', 9), (42, 'a', 9), (30, 'G', 12), (36, 'G', 12), (48, 'g', 10)]: r.put(x, y, ch)
r.deco([(7, 'b'), (21, 'h'), (35, 'b'), (50, 'h'), (20, 'c'), (33, 'c')]); rooms['warren_elite_1'] = r

r = Room(34); r.put(3, FLOOR - 1, 'S'); r.put(24, FLOOR - 1, 'B'); r.put(29, FLOOR - 1, 'a')
r.deco([(6, 'b'), (12, 'b'), (18, 'b'), (24, 'b'), (9, 'h'), (27, 'h')]); rooms['warren_boss'] = r

# The Gryphon's Roost Inn: ground-floor taproom, upper floor (rooms to let and the party's rooms) from col 1 to 48,
# reached by a 45-degree staircase rising from x=56 tiles (floor) to x=49 tiles (upper floor). Cellar door at the far right.
r = Room(64)
for x in range(1, 49):
    r.put(x, 6, '#')
r.put(2, FLOOR - 1, 'S'); r.put(61, FLOOR - 1, 'X')
rooms['inn_gryphons_roost'] = r

os.makedirs(OUT, exist_ok=True)
for name, rr in rooms.items():
    t = rr.text()
    assert t.count('S') == 1, name
    assert name == 'warren_boss' or t.count('X') == 1, name
    open(os.path.join(OUT, name + '.txt'), 'w').write(t)
import subprocess
chk = subprocess.run([sys.executable, '-I', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'check_rooms.py'), OUT])
assert chk.returncode == 0, 'a room has a platform the hero cannot reach'
print(len(rooms), 'rooms written and checked')
print(rooms['warren_gauntlet_1'].text())
