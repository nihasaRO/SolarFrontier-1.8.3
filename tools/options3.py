"""Options for v3: gauge shapes that suit the octagonal panel, a moon-phase icon,
and a bigger Celsius-only temperature. Preview only (nothing is built)."""
import math
import numpy as np
from PIL import Image, ImageDraw
import assets
import preview2 as P

LEFT = assets.GAUGE_LEFT     # stress: bottom centre -> left -> chamfer -> up the left side
RIGHT = assets.GAUGE_RIGHT   # Body Battery


def pieces(path):
    out = []
    for (ax, ay), (bx, by) in zip(path, path[1:]):
        L = math.hypot(bx - ax, by - ay)
        out.append(((ax, ay), ((bx - ax) / L, (by - ay) / L), L))
    return out


def stations(path, pitch, margin):
    """Evenly spaced centres per straight piece, with the piece direction."""
    out = []
    for (a, u, L) in pieces(path):
        n = int((L - 2 * margin) // pitch) + 1
        span = (n - 1) * pitch
        s0 = (L - span) / 2.0
        for i in range(n):
            s = s0 + i * pitch
            out.append(((a[0] + u[0] * s, a[1] + u[1] * s), u))
    return out


def lit_count(n, value):
    return 0 if value is None else min(n, int(value * n / 100.0 + 0.5))


# ---------------------------------------------------------------- A: chevrons
def gauge_chevrons(dc, path, value):
    st = stations(path, 7.0, 2.5)
    lit = lit_count(len(st), value)
    for i, (c, u) in enumerate(st):
        n = (-u[1], u[0])
        a, w = 1.5, 3.0
        A = (c[0] + u[0] * a, c[1] + u[1] * a)
        B1 = (c[0] - u[0] * a + n[0] * w, c[1] - u[1] * a + n[1] * w)
        B2 = (c[0] - u[0] * a - n[0] * w, c[1] - u[1] * a - n[1] * w)
        R = lambda p: (int(round(p[0])), int(round(p[1])))
        if i < lit:
            t = 2.0
            A2 = (A[0] - u[0] * t, A[1] - u[1] * t)
            B1b = (B1[0] - u[0] * t, B1[1] - u[1] * t)
            B2b = (B2[0] - u[0] * t, B2[1] - u[1] * t)
            dc.poly([R(A), R(B1), R(B1b), R(A2), R(B2b), R(B2)])
        else:
            dc.line(*R(A), *R(B1))
            dc.line(*R(A), *R(B2))


# ---------------------------------------------------------------- B: diamonds
def gauge_diamonds(dc, path, value):
    st = stations(path, 8.0, 3.0)
    lit = lit_count(len(st), value)
    for i, (c, u) in enumerate(st):
        x, y = int(round(c[0])), int(round(c[1]))
        pts = [(x, y - 3), (x + 3, y), (x, y + 3), (x - 3, y)]
        if i < lit:
            dc.poly(pts)
        else:
            dc.d.polygon(pts, outline=1)


# ---------------------------------------------------------------- C: channel (fuel gauge)
def offset_path(path, d):
    """Offset a polyline sideways by d (positive = towards the screen centre)."""
    segs = pieces(path)
    pts = []
    for k, (a, u, L) in enumerate(segs):
        n = (-u[1], u[0])
        # orient normal towards the centre (88, 88)
        if (88 - a[0]) * n[0] + (88 - a[1]) * n[1] < 0:
            n = (-n[0], -n[1])
        p0 = (a[0] + n[0] * d, a[1] + n[1] * d)
        p1 = (a[0] + u[0] * L + n[0] * d, a[1] + u[1] * L + n[1] * d)
        pts.append((p0, p1))
    out = [pts[0][0]]
    for (p0, p1), (q0, q1) in zip(pts, pts[1:]):
        # intersection of consecutive offset lines
        d1 = (p1[0] - p0[0], p1[1] - p0[1]); d2 = (q1[0] - q0[0], q1[1] - q0[1])
        den = d1[0] * d2[1] - d1[1] * d2[0]
        t = ((q0[0] - p0[0]) * d2[1] - (q0[1] - p0[1]) * d2[0]) / den
        out.append((p0[0] + d1[0] * t, p0[1] + d1[1] * t))
    out.append(pts[-1][1])
    return out


def cut(poly, frac):
    """First frac of a polyline's length."""
    lens = [math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(poly, poly[1:])]
    goal = sum(lens) * frac
    out = [poly[0]]
    for (a, b), L in zip(zip(poly, poly[1:]), lens):
        if goal <= L:
            t = goal / L if L else 0
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
            return out
        out.append(b)
        goal -= L
    return out


def gauge_channel(dc, path, value):
    outer = offset_path(path, -2.5)
    inner = offset_path(path, 2.5)
    R = lambda p: (int(round(p[0])), int(round(p[1])))
    # track: two thin rails plus end caps
    for poly in (outer, inner):
        for a, b in zip(poly, poly[1:]):
            dc.line(*R(a), *R(b))
    dc.line(*R(outer[0]), *R(inner[0]))
    dc.line(*R(outer[-1]), *R(inner[-1]))
    frac = 0 if value is None else max(0.0, min(1.0, value / 100.0))
    if frac > 0:
        o, i = cut(outer, frac), cut(inner, frac)
        dc.poly([R(p) for p in o] + [R(p) for p in reversed(i)])
    # notches every 10% (cut through the fill)
    for k in range(1, 10):
        o, i = cut(outer, k / 10.0)[-1], cut(inner, k / 10.0)[-1]
        dc.d.line((*R(o), *R(i)), fill=0)


# ---------------------------------------------------------------- moon phase
NEW_MOON_EPOCH = 947182440  # 2000-01-06 18:14 UTC
SYNODIC = 29.530588853


def moon_age(unix_sec):
    return ((unix_sec - NEW_MOON_EPOCH) / 86400.0) % SYNODIC


def draw_moon(dc, cx, cy, r, age, southern=False):
    """Integer per-row rasterisation (same as the watch code): 1 px ring + lit part."""
    phi = 2 * math.pi * age / SYNODIC
    k = math.cos(phi)
    waxing = (age < SYNODIC / 2) != southern
    R2 = (r + 0.5) ** 2
    def half(dy):
        return int(math.floor(math.sqrt(R2 - dy * dy))) if dy * dy <= R2 else -1
    for dy in range(-r, r + 1):
        w = half(dy)
        wn = half(abs(dy) + 1)            # width of the row nearer the edge
        edge = max(1, w - max(wn, 0))      # ring thickness on this row
        if abs(dy) == r:
            dc.fill(cx - w, cy + dy, 2 * w + 1, 1)
        else:
            dc.fill(cx - w, cy + dy, edge, 1)
            dc.fill(cx + w - edge + 1, cy + dy, edge, 1)
        t = int(math.ceil(k * w))
        if waxing:
            a, b = cx + t, cx + w
        else:
            a, b = cx - w, cx - t
        if b >= a:
            dc.fill(a, cy + dy, b - a + 1, 1)


# ---------------------------------------------------------------- full face
def render(v, F, style):
    dc = P.Dc()
    for path, val in ((LEFT, v["stress"]), (RIGHT, v["bb"])):
        {"A": gauge_chevrons, "B": gauge_diamonds, "C": gauge_channel}[style](dc, path, val)
    dc.icon("I_STRESS", 5, 37)
    dc.icon("I_BOLT", 169, 73)

    sub_cx, sub_cy = 145, 31
    ic = assets.ICONS[v["icon"]]
    iw, ih = len(ic[0]), len(ic)
    dc.icon(v["icon"], sub_cx - iw // 2, sub_cy - 25 + (23 - ih) // 2)
    num = v["temp"]
    dc.text(sub_cx - dc.text_w(F["mid"], num) // 2, sub_cy + 2, F["mid"], num + "°")

    # moon beside the date, in the top-left chamfer
    draw_moon(dc, 40, 14, 6, v["moon_age"])
    dc.text(73, 9, F["small"], v["date"], "C")

    dc.rect(16, 28, 13, 10)
    dc.fill(29, 31, 2, 4)
    dc.fill(18, 30, min(9, int(v["battery"] * 9 / 100.0 + 0.5)), 6)
    dc.text(34, 27, F["small"], str(v["battery"]))
    for el in assets.solar_elements()[:min(10, (v["solar"] + 9) // 10)]:
        for (x, y, n) in el:
            dc.fill(x, y, n, 1)
    dc.line(15, 44, 101, 44)
    dc.line(101, 44, 107, 38)
    dc.text(46, 50, F["small"], v["rise"], "R")
    dc.icon("I_SUNHZ", 49, 54)
    dc.text(64, 50, F["small"], v["set"], "L")

    wH, wM = dc.text_w(F["time"], v["hh"]), dc.text_w(F["timed"], v["mm"])
    x = 88 - (wH + wM) // 2
    dc.text(x, 74, F["time"], v["hh"])
    dc.text(x + wH, 74, F["timed"], v["mm"])

    dc.icon("I_RUN", 30, 121)
    dc.text(43, 120, F["small"], v["active"])
    dc.icon("I_STEPS", 92, 121)
    dc.text(104, 120, F["small"], v["steps"])
    vals = v["hrbars"]
    lo, hi = min(vals), max(vals)
    for i, b in enumerate(vals):
        h = 1 + ((b - lo) * 12) // (hi - lo)
        dc.fill(26 + 2 * i, 149 - h, 1, h)
    hw = dc.text_w(F["small"], v["hr"])
    gx = 88 - (11 + 3 + hw) // 2
    dc.icon("I_HEART", gx, 155)
    dc.text(gx + 14, 155, F["small"], v["hr"])
    return dc.im


if __name__ == "__main__":
    F = assets.all_fonts()
    F["mid"] = assets.build_font("SairaSemiCondensed-ExtraBold.ttf", 26, assets.MID_CHARS)
    import time
    v = dict(P.SAMPLE, icon="W_PARTLY", temp="-12", stress=62, bb=45, battery=98, solar=56,
             hh="16", mm="23", rise="7:17", set="18:50", active="30", steps="5673", hr="92",
             moon_age=moon_age(time.time()))
    print("moon age today: %.1f days" % v["moon_age"])
    faces = {s: render(v, F, s) for s in "ABC"}
    for s, f in faces.items():
        print(s, "hidden pixels:", P.clip_report(f))
    tiles = [P.on_watch(faces[s], 4) for s in "ABC"]
    W, H = tiles[0].size
    sheet = Image.new("RGB", (W * 3 + 40, H + 50), (231, 230, 226))
    d = ImageDraw.Draw(sheet)
    for i, (s, name) in enumerate(zip("ABC", ("A  Chevrons", "B  Diamonds", "C  Channel"))):
        sheet.paste(tiles[i], (i * (W + 20), 50))
        d.text((i * (W + 20) + 20, 18), name, fill=(30, 30, 30))
    sheet.save("/home/claude/gen/out/options3.png")

    # moon phase strip (8 phases) at 8x
    strip = Image.new("RGB", (8 * 130, 150), (231, 230, 226))
    sd = ImageDraw.Draw(strip)
    names = ["new", "waxing cres.", "first qtr", "waxing gib.", "full", "waning gib.", "last qtr", "waning cres."]
    for i in range(8):
        dc = P.Dc()
        draw_moon(dc, 8, 8, 6, (i + 0.0001) * SYNODIC / 8)
        tile = dc.im.crop((0, 0, 17, 17)).convert("L").point(lambda p: 230 if p else 12).resize((17 * 6, 17 * 6), Image.NEAREST)
        strip.paste(tile.convert("RGB"), (i * 130 + 12, 10))
        sd.text((i * 130 + 12, 120), names[i], fill=(30, 30, 30))
    strip.save("/home/claude/gen/out/moon_phases.png")
