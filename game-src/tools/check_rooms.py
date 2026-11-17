"""Reachability check for room grids against Boar-vhal's jump (3.6 tiles up, 4.4 across).
A surface is a run of tiles you can stand on (top of '#' or '=') at one height.
From one surface you can reach another if: rising r tiles (r<=3) with a horizontal gap of at most
4 / 3 / 2 tiles for r = 1 / 2 / 3 (and 4 on the flat); dropping down allows a slightly longer gap.
Usage: python3 check_rooms.py rooms_dir"""
import sys, os, collections

GAP_UP = {0: 4, 1: 4, 2: 3, 3: 2}


def surfaces(g):
    H, W = len(g), len(g[0])
    out = []
    for s in range(1, H):
        x = 0
        while x < W:
            ok = lambda xx: g[s][xx] in '#=' and g[s - 1][xx] not in '#'
            if ok(x):
                x0 = x
                while x < W and ok(x):
                    x += 1
                out.append((s, x0, x - 1))
            else:
                x += 1
    return out


def gap(a, b):
    if a[2] < b[1]:
        return b[1] - a[2] - 1
    if b[2] < a[1]:
        return a[1] - b[2] - 1
    return 0


def can(a, b):
    rise = a[0] - b[0]
    gp = gap(a, b)
    if rise > 3:
        return False
    if rise >= 0:
        return gp <= GAP_UP[rise]
    return gp <= 4 + min(2, -rise)


def check(path):
    g = [l.rstrip('\n') for l in open(path) if l.strip()]
    surf = surfaces(g)
    start = next((y, x) for y, r in enumerate(g) for x, c in enumerate(r) if c in 'SP')
    s0 = next(s for s in surf if s[0] == start[0] + 1 and s[1] <= start[1] <= s[2])
    seen = {s0}
    q = collections.deque([s0])
    while q:
        a = q.popleft()
        for b in surf:
            if b not in seen and can(a, b):
                seen.add(b)
                q.append(b)
    bad = []
    for s in surf:
        if s in seen or s[0] <= 1:
            continue
        kind = 'platform' if g[s[0]][s[1]] == '=' else 'ledge'
        bad.append('%s row %d cols %d-%d unreachable' % (kind, s[0], s[1], s[2]))
    return bad


if __name__ == '__main__':
    total = 0
    for f in sorted(os.listdir(sys.argv[1])):
        if not f.startswith('warren_'):
            continue
        bad = check(os.path.join(sys.argv[1], f))
        total += len(bad)
        print(f, 'OK' if not bad else '')
        for b in bad:
            print('   ', b)
    sys.exit(1 if total else 0)
