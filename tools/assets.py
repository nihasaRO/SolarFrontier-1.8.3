"""Asset generator for the Enduro C watch face (Instinct 3 Solar, 176x176, 1-bit).

Produces:
  - BMFont text fonts (.fnt + 24-bit .bmp page, white on black), the format
    Connect IQ's resource compiler accepts
  - pixel-art icons as run-length arrays, emitted into source/Gen.mc
Everything here is shared with preview.py so the preview shows the same pixels.
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wx_icons
import icons_v3
import icons_v4

FONT_DIR = os.environ.get("SAIRA_FONT_DIR", os.path.join(os.path.dirname(os.path.abspath(__file__)), "fonts"))  # folder with the Saira Semi Condensed TTFs

# ---------------------------------------------------------------- fonts

def _tilde(size, minus):
    """A hand-drawn "~" (the font's own is nearly flat at these sizes and reads as a minus): one sine wave with a
    2 px stroke, centred on the minus sign's height. Returns (img, xoff, yoff from baseline, advance)."""
    import math
    w, h = (7, 4) if size <= 14 else ((9, 5) if size <= 18 else (8, 4))   # the column font's is narrow: 47 px columns
    t = 2
    g = Image.new("L", (w, h), 0)
    px = g.load()
    amp = (h - t) / 2.0
    for x in range(w):
        y0 = int(round(amp * (1 - math.sin(2 * math.pi * x / (w - 1)))))
        for y in range(y0, min(h, y0 + t)):
            px[x, y] = 255
    mg, mxo, myo, madv = minus
    gap = 1 if size > 18 else 2                       # 1 px of space in the column font, 2 elsewhere
    return (g, gap - 1 if size > 18 else 1, myo + mg.size[1] // 2 - h // 2, w + gap)


def build_font(ttf, size, chars, tracking=0, dither=False, outline=False):
    """Rasterise each char with antialiasing off. Returns a font dict:
    {base, line, glyphs: {ch: (img, xoff, yoff, adv)}}; yoff is relative to
    the line top, where line top = baseline - base."""
    f = ImageFont.truetype(os.path.join(FONT_DIR, ttf), size)
    raw = {}
    cap = 0
    for ch in chars:
        im = Image.new("L", (size * 3, size * 3), 0)
        d = ImageDraw.Draw(im)
        d.fontmode = "1"
        ox, oy = size, size * 2  # baseline origin
        d.text((ox, oy), ch, font=f, fill=255, anchor="ls")
        bb = im.getbbox()
        adv = int(round(f.getlength(ch))) + tracking
        if bb is None:  # space
            raw[ch] = (None, 0, 0, adv)
            continue
        g = im.crop(bb).point(lambda v: 255 if v > 127 else 0)
        raw[ch] = (g, bb[0] - ox, bb[1] - oy, adv)  # yoff relative to baseline (negative = above)
        if ch.isdigit() or ch.isupper():
            cap = max(cap, oy - bb[1])
    if "~" in raw and "-" in raw:
        raw["~"] = _tilde(size, raw["-"])
    base = cap
    glyphs = {}
    for ch, (g, xo, yo, adv) in raw.items():
        if g is not None and outline:
            src = g.copy().load()
            px = g.load()
            w0, h0 = g.size
            for y in range(h0):
                for x in range(w0):
                    if src[x, y]:
                        inside = all(0 <= x + dx < w0 and 0 <= y + dy < h0 and src[x + dx, y + dy]
                                     for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                        if inside:
                            px[x, y] = 0
        if g is not None and dither:
            px = g.load()
            for y in range(g.size[1]):
                for x in range(g.size[0]):
                    if (x + y) % 2 == 1:
                        px[x, y] = 0
        glyphs[ch] = (g, xo, (yo + base) if g is not None else 0, adv)
    lowest = max((yo + g.size[1]) for (g, xo, yo, adv) in glyphs.values() if g is not None)
    return {"base": base, "line": max(base + 1, lowest), "glyphs": glyphs}


def _pack(sizes, max_w):
    """Shelf packing, tallest first: returns ({index: (x, y)}, page_w, page_h)."""
    order = sorted(range(len(sizes)), key=lambda i: -sizes[i][1])
    pos, x, y, shelf_h, page_w = {}, 0, 0, 0, 0
    for i in order:
        w, h = sizes[i]
        if x and x + w > max_w:
            x, y, shelf_h = 0, y + shelf_h + 1, 0
        pos[i] = (x, y)
        x += w + 1
        shelf_h = max(shelf_h, h)
        page_w = max(page_w, x - 1)
    return pos, page_w, y + shelf_h


def write_bmfont(font, name, outdir, face):
    """Pack glyphs into the smallest page (shelves, best width tried) and write NAME.fnt + NAME.bmp.
    The watch keeps the page in memory, so its area is what costs."""
    items = [(ch, v) for ch, v in font["glyphs"].items()]
    sizes = [((v[0].size[0], v[0].size[1]) if v[0] is not None else (1, 1)) for ch, v in items]
    widest = max(w for w, h in sizes)
    best = None
    for max_w in list(range(widest, sum(w + 1 for w, h in sizes) + 1, 4)) + [sum(w + 1 for w, h in sizes)]:
        pos, W, H = _pack(sizes, max_w)
        if best is None or W * H < best[1] * best[2]:
            best = (pos, W, H)
    pos, W, H = best
    page = Image.new("RGB", (W, H), (0, 0, 0))
    lines = [
        f'info face="{face}" size=-{font["base"]} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1 outline=0',
        f'common lineHeight={font["line"]} base={font["base"]} scaleW={W} scaleH={H} pages=1 packed=0 alphaChnl=1 redChnl=0 greenChnl=0 blueChnl=0',
        f'page id=0 file="{name}.bmp"',
        f"chars count={len(items)}",
    ]
    for i, (ch, (g, xo, yo, adv)) in enumerate(items):
        x, y = pos[i]
        w, h = sizes[i]
        if g is not None:
            page.paste(Image.merge("RGB", (g, g, g)), (x, y))
        lines.append(f"char id={ord(ch)} x={x} y={y} width={w} height={h} xoffset={xo} yoffset={yo} xadvance={adv} page=0 chnl=15")
    page.save(os.path.join(outdir, name + ".bmp"), "BMP")
    with open(os.path.join(outdir, name + ".fnt"), "w", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")


SMALL_CHARS = "0123456789:%-.+/ABCDEFGHIJKLMNOPQRSTUVWXYZ \u00b0~"
MID_CHARS = "0123456789-%\u00b0"
MED_CHARS = "0123456789-%:.\u00b0"
TIME_CHARS = "0123456789"


SMALL_ZERO = [
    ".#####.",
    "##...##",
    "##...##",
    "##...##",
    "##...##",
    "##...##",
    "##...##",
    "##...##",
    "##...##",
    "##...##",
    ".#####.",
]


def override_glyph(font, ch, rows, adv):
    g = Image.new("L", (len(rows[0]), len(rows)), 0)
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c == "#":
                g.putpixel((x, y), 255)
    font["glyphs"][ch] = (g, 0, font["base"] - len(rows), adv)


def _bitmap(rows):
    """Icon rows (bools or '#'-strings) -> 'L' image, 255 where set."""
    rows = [[c == "#" for c in r] if isinstance(r, str) else r for r in rows]
    im = Image.new("L", (len(rows[0]), len(rows)), 0)
    px = im.load()
    for y, r in enumerate(rows):
        for x, v in enumerate(r):
            if v:
                px[x, y] = 255
    return im


# Line-3 pictograms as characters of the small font, so line 3 is always plain text.
# Offsets (from the text top) and advances copy the old drawing code exactly:
#   sun icon y+3, gap 3 before the time; triangles y+4 (flat dash y+5); dot 2x2 at y+5;
#   mountain / steps centred in an 11 px box, text 14 px after the icon.
LINE3_SYMBOLS = {
    "\u00a1": ("I_SUNHZ", 0, 3, 16),              # next sunrise/set: icon, then the time
    "\u00a2": ("I_SUNHZ", 3, 3, 19),              # sunrise & sunset: 3 px gap, icon, 3 px gap
    "\u00a3": (["..#..", ".###.", "#####"], 0, 4, 8),          # high: up triangle
    "\u00a4": (["#####", ".###.", "..#.."], 8, 4, 16),         # low: 8 px gap, down triangle
    "\u00a5": (["..#..", ".###.", "#####"], 0, 4, 9),          # pressure rising
    "\u00a6": (["#####", ".###.", "..#.."], 0, 4, 9),          # pressure falling
    "\u00a7": (["#####"], 0, 5, 9),                            # pressure steady
    "\u00a8": (["##", "##"], 3, 5, 7),                          # separator dot
    "\u00a9": ("F_MOUNT", None, None, 14),        # altitude: mountain in an 11 px box
    "\u00aa": ("I_STEPS", None, None, 14),        # steps: icon in an 11 px box
}


def add_line3_symbols(font, dy=0):
    """dy: extra downward shift, so the symbols sit on a bigger font's baseline (big text)."""
    for ch, (src, xo, yo, adv) in LINE3_SYMBOLS.items():
        img = _bitmap(ICONS[src] if isinstance(src, str) else src)
        if xo is None:                              # centred in an 11 x 11 box
            xo, yo = (11 - img.size[0]) // 2, (11 - img.size[1]) // 2
        font["glyphs"][ch] = (img, xo, yo + dy, adv)


def all_fonts():
    small = build_font("SairaSemiCondensed-Bold.ttf", 14, SMALL_CHARS)
    override_glyph(small, "0", SMALL_ZERO[:small["base"]], 8)
    g, xo, yo, adv = small["glyphs"][" "]
    small["glyphs"][" "] = (g, xo, yo, 4)
    add_line3_symbols(small)
    big = build_font("SairaSemiCondensed-Bold.ttf", 18, SMALL_CHARS)      # Chart layout "Big text"
    add_line3_symbols(big, big["base"] - small["base"])
    return {
        "small": small,
        "mid": build_font("SairaSemiCondensed-ExtraBold.ttf", 26, MID_CHARS),
        "time": build_font("SairaSemiCondensed-Bold.ttf", 59, TIME_CHARS, tracking=1),
        "timed": build_font("SairaSemiCondensed-Bold.ttf", 59, TIME_CHARS, tracking=1, dither=True),
        "timeo": build_font("SairaSemiCondensed-Bold.ttf", 59, TIME_CHARS, tracking=1, outline=True),
        "med": build_font("SairaSemiCondensed-ExtraBold.ttf", 20, MED_CHARS),
        "data": build_font("SairaSemiCondensed-Bold.ttf", 21, "0123456789-%.K/D+\u00b0T:NOWMRYEHU~", tracking=-1),
        "tiny": build_font("SairaSemiCondensed-SemiBold.ttf", 10, "0123456789-", tracking=1),
        "big": big,
    }

# ---------------------------------------------------------------- icons

def from_art(rows):
    return [[c == "#" for c in r] for r in rows]


def from_draw(w, h, fn):
    im = Image.new("1", (w, h), 0)
    fn(ImageDraw.Draw(im))
    return [[bool(im.getpixel((x, y))) for x in range(w)] for y in range(h)]


def cloud_shape(d, ox=0, oy=0, fill=1):
    # bumps + flat bottom, 19 x 11
    d.ellipse((ox + 1, oy + 4, ox + 9, oy + 11), fill=fill)
    d.ellipse((ox + 5, oy + 0, ox + 15, oy + 10), fill=fill)
    d.ellipse((ox + 11, oy + 4, ox + 18, oy + 11), fill=fill)
    d.rectangle((ox + 4, oy + 7, ox + 15, oy + 11), fill=fill)


def icon_cloud():
    return from_draw(19, 12, lambda d: cloud_shape(d))


def icon_rain():
    def f(d):
        cloud_shape(d)
        for x in (5, 10, 15):
            d.line((x, 14, x - 2, 17), fill=1)
    return from_draw(19, 18, f)


def icon_snow():
    def f(d):
        cloud_shape(d)
        for x, y in ((5, 15), (10, 17), (15, 15)):
            d.point((x, y), fill=1)
            d.point((x - 1, y), fill=1); d.point((x + 1, y), fill=1)
            d.point((x, y - 1), fill=1); d.point((x, y + 1), fill=1)
    return from_draw(19, 19, f)


def icon_storm():
    px = from_draw(19, 20, lambda d: cloud_shape(d))
    bolt = ["...##", "..##.", ".####", "..##.", ".##..", "##..."]
    for r, row in enumerate(bolt):
        for c, ch in enumerate(row):
            if ch == "#":
                px[13 + r][7 + c] = True
    return px


def icon_sun():
    return from_art([
        ".......#.......",
        "..#....#....#..",
        "...#.......#...",
        "......###......",
        ".....#####.....",
        "....#######....",
        "##..#######..##",
        "....#######....",
        ".....#####.....",
        "......###......",
        "...#.......#...",
        "..#....#....#..",
        ".......#.......",
    ])


def icon_moon():
    return from_art([
        "....####....",
        "..####......",
        ".####.......",
        ".###........",
        "####........",
        "####........",
        "####........",
        "####.......#",
        ".####.....##",
        ".##########.",
        "..########..",
        "....####....",
    ])


def icon_partly():
    def f(d):
        # small sun top-left, cloud lower-right with a 1px gap cut around it
        d.ellipse((2, 2, 9, 9), fill=1)
        for (a, b, c, e) in ((5, -1, 5, 0), (-1, 5, 0, 5), (1, 1, 1, 1), (9, 1, 9, 1)):
            d.line((a, b, c, e), fill=1)
        cloud_shape(d, 3, 4, fill=0)
        d.rectangle((2, 15, 21, 16), fill=0)
        cloud_shape(d, 4, 5, fill=1)
    return from_draw(23, 17, f)


def icon_fog():
    return from_art([
        "..###############..",
        "...................",
        "###################",
        "...................",
        ".###############...",
        "...................",
        "...###############.",
        "...................",
        "..############.....",
    ])


def icon_wind():
    return from_art([
        "...........###.....",
        "..............#....",
        "#############.#....",
        "............##.....",
        "...................",
        "################...",
        "................#..",
        "..........###...#..",
        ".............###...",
    ])


ICONS = {
    **{name: fn() for name, fn in wx_icons.WX.items()},
    **icons_v3.ICONS_V3,
    **icons_v4.ICONS_V4,
    "I_STEPS": from_art([
        ".##......",
        "####.....",
        "####..##.",
        "####.####",
        ".##..####",
        ".....####",
        ".##...##.",
        ".##......",
        "......##.",
        "......##.",
    ]),
    "I_RUN": from_art([
        "......##..",
        "......##..",
        "...#####..",
        "..#.###.#.",
        ".#..##...#",
        "....##....",
        "...####...",
        "..##..##..",
        ".##....#..",
        "##.....##.",
    ]),
    "I_HEART": from_art([
        ".###...###.",
        "#####.#####",
        "###########",
        "###########",
        "###########",
        ".#########.",
        "..#######..",
        "...#####...",
        "....###....",
        ".....#.....",
    ]),
    "I_SUNHZ": from_art([
        "......#......",
        "..#...#...#..",
        "...#.....#...",
        ".....###.....",
        "....#####....",
        "...#######...",
        "#############",
    ]),
    "I_STRESS": from_art([
        "..#...#..",
        ".#.#.#.#.",
        "#...#...#",
    ]),
    "I_BOLT": from_art([
        "....##",
        "...##.",
        "..##..",
        ".#####",
        "...##.",
        "..##..",
        ".##...",
        "##....",
    ]),
}

# Solar bar: 10 elements (triangle, 8 stripes, triangle), 11 rows tall.
# Each element is a list of (x, y, len) runs in absolute screen pixels.
SOLAR_L, SOLAR_TOP = 59, 27
SOLAR_OFF = [5, 5, 4, 4, 3, 3, 2, 2, 1, 1, 0]  # stripe shift per row (top leans right)


def solar_elements():
    L, T, R = SOLAR_L, SOLAR_TOP, SOLAR_L + 40
    rows = range(len(SOLAR_OFF))
    els = [[(L, T + r, SOLAR_OFF[r] + 1) for r in rows]]
    for k in range(1, 9):
        els.append([(L + SOLAR_OFF[r] + 3 + (k - 1) * 4, T + r, 2) for r in rows])
    els.append([(L + SOLAR_OFF[r] + 35, T + r, R - (L + SOLAR_OFF[r] + 35) + 1) for r in rows])
    return els


# Edge gauges follow the visible panel: a 176 px square with 40 px chamfers at three
# corners (measured from Garmin's simulator mask). Paths start at the bottom centre.
GAUGE_HALF = 2.5
GAUGE_LEFT = [(82, 171.5), (41.45, 171.5), (3.5, 133.55), (3.5, 44.0)]     # stress
GAUGE_RIGHT = [(94, 171.5), (134.55, 171.5), (171.5, 134.55), (171.5, 84.0)]  # Body Battery


def gauge_segments(path):
    """Per segment: quad (4 points) and its 1 px centre line, piece by piece."""
    import math
    segs = []
    for (ax, ay), (bx, by) in zip(path, path[1:]):
        L = math.hypot(bx - ax, by - ay)
        n = int((L + 2) // 6)
        pitch = L / n
        ux, uy = (bx - ax) / L, (by - ay) / L
        nx, ny = -uy, ux
        for i in range(n):
            s0 = i * pitch + 1
            s1 = s0 + pitch - 2
            p0 = (ax + ux * s0, ay + uy * s0)
            p1 = (ax + ux * s1, ay + uy * s1)
            h = GAUGE_HALF
            q = [(p0[0] + nx * h, p0[1] + ny * h), (p1[0] + nx * h, p1[1] + ny * h),
                 (p1[0] - nx * h, p1[1] - ny * h), (p0[0] - nx * h, p0[1] - ny * h)]
            q = [(int(round(x)), int(round(y))) for x, y in q]
            ln = (int(round(p0[0])), int(round(p0[1])), int(round(p1[0])), int(round(p1[1])))
            segs.append((q, ln))
    return segs


def hybrid_elements(path):
    """9 numbers per element, from the bottom centre outwards:
    bar:     [0, x, y, w, h, lx, ly, lw, lh]   (lit rectangle, unlit 1 px line)
    diamond: [1, cx, cy, 0, 0, 0, 0, 0, 0]     (radius 3)"""
    import math
    out = []
    for (ax, ay), (bx, by) in zip(path, path[1:]):
        L = math.hypot(bx - ax, by - ay)
        ux, uy = (bx - ax) / L, (by - ay) / L
        if abs(abs(ux) - abs(uy)) < 0.2:          # 45-degree corner piece: diamonds
            pitch, margin = 8.0, 3.5
            n = int((L - 2 * margin) // pitch) + 1
            s0 = (L - (n - 1) * pitch) / 2.0
            for i in range(n):
                s = s0 + i * pitch
                out += [1, int(round(ax + ux * s)), int(round(ay + uy * s)), 0, 0, 0, 0, 0, 0]
        else:                                      # straight piece: bars
            for q, ln in gauge_segments([(ax, ay), (bx, by)]):
                xs = [p[0] for p in q]; ys = [p[1] for p in q]
                lx = sorted((ln[0], ln[2])); ly = sorted((ln[1], ln[3]))
                out += [0, min(xs), min(ys), max(xs) - min(xs) + 1, max(ys) - min(ys) + 1,
                        lx[0], ly[0], lx[1] - lx[0] + 1, ly[1] - ly[0] + 1]
    return out


def runs(px):
    out = []
    for y, row in enumerate(px):
        x = 0
        while x < len(row):
            if row[x]:
                s = x
                while x < len(row) and row[x]:
                    x += 1
                out += [s, y, x - s]
            else:
                x += 1
    return out


def size(px):
    return len(px[0]), len(px)

# ---------------------------------------------------------------- Monkey C emit

def emit_gen_mc(path, fonts):
    L = ["// Generated by tools/assets.py. Do not edit by hand.",
         "import Toybox.Lang;", "", "module Gen {"]
    for name, px in ICONS.items():
        w, h = size(px)
        data = [w, h] + runs(px)
        L.append(f"    const {name} = {data};")
    for cname, gpath in (("GAUGE_LEFT", GAUGE_LEFT), ("GAUGE_RIGHT", GAUGE_RIGHT)):
        flat = hybrid_elements(gpath)
        L.append(f"    // {len(flat) // 9} elements: bar [0,x,y,w,h,lx,ly,lw,lh] or diamond [1,cx,cy,...]")
        L.append(f"    const {cname} = {flat};")
    L.append(f"    const TIME_DIGIT_H = {fonts['time']['base']};")
    L.append(f"    const SMALL_CAP_H = {fonts['small']['base']};")
    L.append(f"    const MID_CAP_H = {fonts['mid']['base']};")
    L.append("}")
    with open(path, "w", newline="\n") as fh:
        fh.write("\n".join(L) + "\n")


def icon_sheet(path, scale=10):
    items = list(ICONS.items())
    W = sum(size(p)[0] + 3 for _, p in items) * scale
    H = max(size(p)[1] for _, p in items) * scale + 20
    im = Image.new("RGB", (W, H), (30, 30, 30))
    d = ImageDraw.Draw(im)
    x0 = 0
    for name, px in items:
        w, h = size(px)
        for y in range(h):
            for x in range(w):
                if px[y][x]:
                    d.rectangle((x0 + x * scale, y * scale, x0 + (x + 1) * scale - 2, (y + 1) * scale - 2), fill=(230, 232, 225))
        d.text((x0, H - 16), name, fill=(200, 120, 80))
        x0 += (w + 3) * scale
    im.save(path)


if __name__ == "__main__":
    os.makedirs("/home/claude/gen/out", exist_ok=True)
    icon_sheet("/home/claude/gen/out/icons.png")
    print("icons ok")


# ---------------------------------------------------------------- lean build: icon font + JSON resources

def icon_order():
    return list(ICONS.keys())


def write_icon_font(outdir, name="icons"):
    """Every icon becomes one glyph (char 65 + index), top-left aligned, advance = width."""
    order = icon_order()
    H = max(len(ICONS[k]) for k in order)
    glyphs = {}
    for i, k in enumerate(order):
        px = ICONS[k]
        w, h = len(px[0]), len(px)
        g = Image.new("L", (w, h), 0)
        for y in range(h):
            for x in range(w):
                if px[y][x]:
                    g.putpixel((x, y), 255)
        glyphs[chr(65 + i)] = (g, 0, 0, w)
    font = {"base": H, "line": H, "glyphs": glyphs}
    write_bmfont(font, name, outdir, "Instinct Solar Command Icons")


def emit_icon_module(path, tables=None):
    order = icon_order()
    L = ["// Generated by tools/assets.py. Icon glyphs live in the Icons font (char 65 + index).",
         "import Toybox.Lang;", "", "module Ic {"]
    for i, k in enumerate(order):
        L.append(f"    const {k} = {i};")
    W = [len(ICONS[k][0]) for k in order]
    Hs = [len(ICONS[k]) for k in order]
    L.append(f"    const W = {W}b;")
    L.append(f"    const H = {Hs}b;")
    # option -> icon tables, as bytes (255 = no icon); built here instead of in the face's code
    for name, names in (tables or {}).items():
        L.append(f"    const {name} = [" + ", ".join("255" if n is None else str(order.index(n)) for n in names) + "]b;")
    L.append("}")
    with open(path, "w", newline="\n") as fh:
        fh.write("\n".join(L) + "\n")


def write_gauges_json(path):
    import json
    with open(path, "w", newline="\n") as fh:
        json.dump({"l": hybrid_elements(GAUGE_LEFT), "r": hybrid_elements(GAUGE_RIGHT)}, fh, separators=(",", ":"))


def rim_gauges():
    """Rim face gauges: G0's bottom bars and corner diamonds, plus a 12-block side
    (rows 85..132, the same on both sides). Pieces map to 0-25 %, 25-50 %, 50-100 %."""
    out = {}
    for key, path, x0, lx in (("l", GAUGE_LEFT, 1, 4), ("r", GAUGE_RIGHT, 169, 172)):
        els = hybrid_elements(path)
        items = [els[i:i + 9] for i in range(0, len(els), 9)]
        bottom, corner = [], []
        for e in items:
            if e[0] == 1:
                corner.append(e)
            elif not corner:
                bottom.append(e)
        side = []
        for i in range(12):                     # from the bottom up, 3 px blocks, 1 px gaps
            y0 = 130 - 4 * i
            side.append([0, x0, y0, 6, 3, lx, y0, 1, 3])
        flat = [v for e in bottom + corner + side for v in e]
        out[key] = flat
        out[key + "p"] = [len(bottom), len(corner), len(side)]
    return out


# ---------------------------------------------------------------- unified icons (one 11 px grid, solid, 2 px strokes)
def _art(rows):
    return [[c == "#" for c in r] for r in rows]


UNIFIED_ICONS = {
    "I_STEPS": _art([".......###.", "......#####", "......#####", ".###..#####", "#####..###.", "#####......",
                     "#####..###.", ".###...###.", "...........", ".###.......", ".###......."]),
    "I_RUN": _art(["......##...", "......##...", "....####...", "...##.###..", "..##..##.##", "......##...",
                   ".....####..", "....##..##.", "...##....#.", "..##.....#.", ".##........"]),
    "I_HEART": _art([".###...###.", "#####.#####", "###########", "###########", ".#########.",
                     "..#######..", "...#####...", "....###....", ".....#....."]),
    "I_BOLT": _art(["......###..", ".....###...", "....###....", "...#######.", "......###..", ".....###...",
                    "....###....", "...##......", "..#........"]),
    "F_ZIG": _art(["....#......", "...###.....", "..##.##...#", ".##...##.##", "##.....###.", "#.......#.."]),
    "G_STRESS": _art(["....#......", "...###.....", "..##.##...#", ".##...##.##", "##.....###.", "#.......#.."]),
    "I_SUNHZ": _art(["......#......", "..#.......#..", "....#####....", "#..#######..#", "..#########..",
                     ".............", "#############"]),
}
ICONS.update(UNIFIED_ICONS)

# row-1 status icons (top slots)
ICONS.update({
    "S_ALARM": _art(["....#....", "..#####..", ".#######.", ".#######.", ".#######.", "#########", "#########",
                     "....#....", "...###..."]),
    "S_DND": _art(["..#####..", ".#######.", "#########", "##.....##", "#########", ".#######.", "..#####.."]),
    "S_BT": _art(["..#...", "..##..", "#.#.#.", ".###..", "..#...", ".###..", "#.#.#.", "..##..", "..#..."]),
})


def time_ink_module(font, path):
    """Per digit: ink offset from the pen position and ink width, so the watch can place
    digits by their ink (equal gaps around the colon)."""
    xs, ws, adv_ = [], [], []
    for d in "0123456789":
        g, xo, yo, adv = font["glyphs"][d]
        bb = g.getbbox()
        xs.append(xo + bb[0]); ws.append(bb[2] - bb[0]); adv_.append(adv)
    with open(path, "w", newline="\n") as fh:
        fh.write("// Generated by tools/assets.py: ink offset, ink width and advance of the time digits 0-9.\n")
        fh.write("import Toybox.Lang;\n\nmodule TimeInk {\n")
        fh.write(f"    const X = {xs}b;\n    const W = {ws}b;\n    const A = {adv_}b;   // the font's xadvance (solid and outlined fonts alike)\n}}\n")
    return xs, ws, adv_


# ---------------- metrics added in Solar Frontier 1.0 (same 11 px grid, solid, 2 px strokes)
NEW_ICONS_V5 = {
    "N_THERMO": _art(["...###....", "...#.#....", "...#.#.###", "...#.#....", "...#.#.##.", "...###....", "..#####...", ".#######..", ".#######..", "..#####..."]),
    "N_DEW": _art(["....#......", "...###.....", "..#####....", "..#####....", "...###.....", "...........", "###########"]),
    "N_UMBRELLA": _art([".....#.....", "..#######..", ".#########.", "###########", ".....#.....", ".....#.....", ".....#.....", "...#.#.....", "....#......"]),
    "N_GUST": _art(["########...", "........#..", "..######...", "...........", "#########..", ".........#.", "....#####.."]),
    "N_CLOUD": _art(["....###....", "..#######..", ".#########.", "###########", "###########", ".#########."]),
    "N_EYE": _art(["...#####...", ".##.....##.", "#...###...#", "#..#####..#", "#...###...#", ".##.....##.", "...#####..."]),
    "N_LUNGS": _art([".....#.....", ".....#.....", ".##..#..##.", "####.#.####", "####...####", "####...####", "####...####", ".###...###."]),
    "N_HEART_O": _art([".###...###.", "#...#.#...#", "#....#....#", "#.........#", ".#.......#.", "..#.....#..", "...#...#...", "....#.#....", ".....#....."]),
    "N_STAIRS_D": _art(["####......", "####......", "..####....", "..####....", "....####..", "....####..", "......####", "......####"]),
    "N_RAIN": _art(["....###....", "..#######..", ".#########.", "###########", ".#########.", "...........", ".#..#..#...", "#..#..#...."]),
    "S_STORM": _art(["....###....", "..#######..", ".#########.", "###########", ".####.####.", ".....#.....", "....##.....", "...##......", "....#......"]),
}
NEW_ICONS_V5.update({
    "N_MOON": _art(["...####..", ".###.....", ".##......", "###......", "###......", "###......", ".##......", ".###.....", "...####.."]),
    "N_UV": _art([".....#.....", ".#...#...#.", "..#.....#..", "....###....", "...#####...", "##.#####.##", "...#####...", "....###....", "..#.....#..", ".#...#...#.", ".....#....."]),
})
NEW_ICONS_V5["N_SNOW"] = _art(["....#....", ".#..#..#.", "..#.#.#..", "...###...", "#########", "...###...", "..#.#.#..", ".#..#..#.", "....#...."])
NEW_ICONS_V5["N_POLLEN"] = _art(["..#...#..", ".###.###.", ".#######.", "..#####..", ".###.###.", "..#...#..", "....#....", "..#.#.#..", "...###...", "....#...."])
NEW_ICONS_V5["N_FREEZE"] = _art(["....#....", "..#.#.#..", "...###...", "..#.#.#..", "....#....", ".........", "#########", ".........", "#.#.#.#.#"])
NEW_ICONS_V5["N_AIR"] = _art(["...........", ".###..###..", "#...##...#.", "...........", ".###..###..", "#...##...#."])
ICONS.update(NEW_ICONS_V5)


# minutes dither: drawn in the background colour over solid minutes, knocking out every other pixel
# 42 rows: covers the minutes whether the watch draws the time font from row 74 or 75 (its line height is 42)
ICONS["M_CHK"] = [[(x + y) % 2 == 0 for x in range(16)] for y in range(42)]
ICONS.pop("I_STRESS", None)
