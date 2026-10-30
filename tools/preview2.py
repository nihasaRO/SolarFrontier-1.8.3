"""Pixel preview of Enduro C v2. Mirrors source/SolarFrontierView.mc and shows the face
on the real Instinct 3 Solar panel shape. Also reports drawn pixels that would be hidden."""
import os
import sys
import math
import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import assets

W = 176
SUB_BOX = (114, 0, 62, 62)          # what WatchUi.getSubscreen() reports in the simulator
RING_C, RING_R, SUB_R = (144.5, 30.5), 43, 31


def panel_mask():
    yy, xx = np.mgrid[0:W, 0:W]
    ring = (xx - RING_C[0]) ** 2 + (yy - RING_C[1]) ** 2
    main = (xx + yy >= 41) & (yy - xx <= 135) & (xx + yy <= 311) & (ring >= RING_R ** 2)
    sub = ring <= SUB_R ** 2
    return np.where(main, 1, np.where(sub, 2, 0))


class Dc:
    def __init__(self):
        self.im = Image.new("1", (W, W), 0)
        self.d = ImageDraw.Draw(self.im)

    def fill(self, x, y, w, h):
        if w > 0 and h > 0:
            self.d.rectangle((x, y, x + w - 1, y + h - 1), fill=1)

    def rect(self, x, y, w, h):
        self.d.rectangle((x, y, x + w - 1, y + h - 1), outline=1)

    def line(self, x0, y0, x1, y1):
        self.d.line((x0, y0, x1, y1), fill=1)

    def poly(self, pts):
        self.d.polygon([tuple(p) for p in pts], fill=1)

    def text_w(self, font, s):
        return sum(font["glyphs"][c][3] for c in s)

    def text(self, x, y, font, s, just="L"):
        w = self.text_w(font, s)
        x = x - w // 2 if just == "C" else (x - w if just == "R" else x)
        for c in s:
            g, xo, yo, adv = font["glyphs"][c]
            if g is not None:
                self.im.paste(1, (x + xo, y + yo), g.convert("1"))
            x += adv

    def icon(self, name, x, y):
        for yy, row in enumerate(assets.ICONS[name]):
            for xx, v in enumerate(row):
                if v:
                    self.d.point((x + xx, y + yy), fill=1)


def render(v, F):
    dc = Dc()
    sx, sy, sw, sh = SUB_BOX
    sub_cx, sub_cy, sub_top = sx + sw // 2, sy + sh // 2, sy

    for path, val in ((assets.GAUGE_LEFT, v["stress"]), (assets.GAUGE_RIGHT, v["bb"])):
        segs = assets.gauge_segments(path)
        lit = 0 if val is None else min(len(segs), int(val * len(segs) / 100.0 + 0.5))
        for i, (q, ln) in enumerate(segs):
            dc.poly(q) if i < lit else dc.line(*ln)
    dc.icon("I_STRESS", 5, 37)
    dc.icon("I_BOLT", 169, 73)

    ic = assets.ICONS[v["icon"]]
    iw, ih = len(ic[0]), len(ic)
    dc.icon(v["icon"], sub_cx - iw // 2, sub_cy - 23 + (23 - ih) // 2)
    num = v["temp"].rstrip("°")
    dc.text(sub_cx - dc.text_w(F["mid"], num) // 2, sub_cy + 5, F["mid"], num + "°")

    dc.text(68, 9, F["small"], v["date"], "C")
    dc.rect(16, 28, 13, 10)
    dc.fill(29, 31, 2, 4)
    dc.fill(18, 30, min(9, int(v["battery"] * 9 / 100.0 + 0.5)), 6)
    dc.text(34, 27, F["small"], str(int(v["battery"] + 0.5)))
    lit = 0 if v["solar"] <= 0 else min(10, (v["solar"] + 9) // 10)
    for el in assets.solar_elements()[:lit]:
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

    vals = [b for b in v["hrbars"] if b is not None]
    if vals:
        lo, hi = min(vals), max(vals)
        for i, b in enumerate(v["hrbars"]):
            if b is not None:
                h = 6 if hi == lo else 1 + ((b - lo) * 12) // (hi - lo)
                dc.fill(26 + 2 * i, 149 - h, 1, h)

    hw = dc.text_w(F["small"], v["hr"])
    gx = 88 - (11 + 3 + hw) // 2
    dc.icon("I_HEART", gx, 155)
    dc.text(gx + 14, 155, F["small"], v["hr"])
    return dc.im


def clip_report(face):
    a = np.asarray(face.convert("L")) > 0
    hidden = a & (panel_mask() == 0)
    return int(hidden.sum())


def on_watch(face, scale=4):
    pad = 30
    S = (W + 2 * pad) * scale
    out = Image.new("RGB", (S, S), (231, 230, 226))
    d = ImageDraw.Draw(out)
    c = S // 2
    d.ellipse((c - 116 * scale, c - 116 * scale, c + 116 * scale, c + 116 * scale), fill=(40, 42, 40))
    d.ellipse((c - 104 * scale, c - 104 * scale, c + 104 * scale, c + 104 * scale), fill=(26, 27, 26))
    big = np.asarray(face.convert("L").resize((W * scale, W * scale), Image.NEAREST)) > 0
    m = np.kron(panel_mask(), np.ones((scale, scale), dtype=np.int64))
    rgb = np.zeros((W * scale, W * scale, 3), dtype=np.uint8)
    rgb[:] = (26, 27, 26)
    rgb[m > 0] = (8, 9, 8)
    rgb[(m > 0) & big] = (226, 229, 220)
    yy, xx = np.mgrid[0:W * scale, 0:W * scale]
    r = np.hypot(xx / scale - RING_C[0], yy / scale - RING_C[1])
    rgb[(r > 34) & (r < 37)] = (214, 96, 40)
    out.paste(Image.fromarray(rgb), (pad * scale, pad * scale))
    return out


SAMPLE = {
    "stress": 75, "bb": 12, "icon": "W_SUN", "temp": "24°", "rise": "7:19", "set": "18:48",
    "date": "TUE 06", "battery": 96, "solar": 56, "hh": "16", "mm": "04",
    "active": "30", "steps": "5673", "hr": "98",
    "hrbars": [95 + int(8 * math.sin(i / 5.0)) + (i % 7) for i in range(61)],
}

if __name__ == "__main__":
    F = assets.all_fonts()
    face = render(SAMPLE, F)
    print("hidden pixels:", clip_report(face))
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "preview.png")
    on_watch(face).save(out)
    print("saved", out)
