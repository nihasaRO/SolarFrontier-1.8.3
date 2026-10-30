"""Subscreen ('circle') modes. Preview only. Each tile is drawn in the real 62 px subscreen."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image, ImageDraw
import assets, wx_icons as WI
import preview2 as P
import options3 as O

F = assets.all_fonts()
BIG = F["mid"]
MED = F["med"]
SM = F["small"]
CX, CY = 145, 31


def icon_px(fn):
    return fn()


def draw_px(dc, px, x, y):
    for yy, row in enumerate(px):
        for xx, v in enumerate(row):
            if v:
                dc.d.point((x + xx, y + yy), fill=1)


def centered(dc, font, s, y, cx=CX, hang_last=0):
    """Centre text on everything except the last `hang_last` characters (e.g. a degree sign)."""
    core = s[:len(s) - hang_last] if hang_last else s
    dc.text(cx - dc.text_w(font, core) // 2, y, font, s)


# ---- small icons drawn supersampled
def i_drop(h=14):
    w = 10
    im, d = WI.canvas(w, h)
    WI.disc(d, 5, h - 5, 4.6)
    d.polygon([(WI.S(5), WI.S(0.2)), (WI.S(1.0), WI.S(h - 6)), (WI.S(9.0), WI.S(h - 6))], fill=255)
    return WI.finish(im, w, h)


def i_mountain():
    w, h = 17, 11
    im, d = WI.canvas(w, h)
    d.polygon([(WI.S(0), WI.S(11)), (WI.S(6), WI.S(2)), (WI.S(9), WI.S(6)), (WI.S(11.5), WI.S(0.5)), (WI.S(17), WI.S(11))], fill=255)
    return WI.finish(im, w, h)


def i_envelope():
    w, h = 17, 12
    im, d = WI.canvas(w, h)
    d.rectangle((WI.S(0.5), WI.S(0.5), WI.S(16.5), WI.S(11.5)), outline=255, width=int(WI.S(1.6)))
    d.line((WI.S(1), WI.S(1), WI.S(8.5), WI.S(7), WI.S(16), WI.S(1)), fill=255, width=int(WI.S(1.6)))
    return WI.finish(im, w, h)


def tri(dc, x, y, up=True):
    pts = [(x, y + 4), (x + 4, y), (x + 8, y + 4)] if up else [(x, y), (x + 8, y), (x + 4, y + 4)]
    dc.poly(pts)


def wind_arrow(dc, cx, cy, bearing, L=11):
    """Arrow pointing the way the wind blows (from bearing + 180)."""
    a = math.radians(bearing + 180 - 90)
    ux, uy = math.cos(a), math.sin(a)
    nx, ny = -uy, ux
    tip = (cx + ux * L, cy + uy * L)
    base = (cx - ux * L, cy - uy * L)
    head = (cx + ux * (L - 8), cy + uy * (L - 8))
    R = lambda p: (int(round(p[0])), int(round(p[1])))
    dc.poly([R(tip), R((head[0] + nx * 6, head[1] + ny * 6)), R((head[0] - nx * 6, head[1] - ny * 6))])
    dc.poly([R((head[0] + nx * 2, head[1] + ny * 2)), R((head[0] - nx * 2, head[1] - ny * 2)),
             R((base[0] - nx * 2, base[1] - ny * 2)), R((base[0] + nx * 2, base[1] + ny * 2))])


def ring(dc, value, segs=24, r0=25.5, r1=29.5, start=240, sweep=300):
    """Segmented progress ring, open at the bottom; lit segments solid, unlit as dots."""
    lit = int(value * segs / 100 + 0.5)
    step = sweep / segs
    for i in range(segs):
        a0 = math.radians(start - i * step - 1.4)
        a1 = math.radians(start - (i + 1) * step + 1.4)
        if i < lit:
            pts = [(CX + r0 * math.cos(a), CY - r0 * math.sin(a)) for a in (a0, a1)] + \
                  [(CX + r1 * math.cos(a), CY - r1 * math.sin(a)) for a in (a1, a0)]
            dc.poly([(int(round(x)), int(round(y))) for x, y in pts])
        else:
            am = (a0 + a1) / 2
            dc.d.point((int(round(CX + 27.5 * math.cos(am))), int(round(CY - 27.5 * math.sin(am)))), fill=1)


def sec_ticks(dc, s):
    for i in range(60):
        a = math.radians(90 - i * 6)
        r0 = 25.5 if i % 5 else 23.5
        if i <= s:
            dc.line(int(round(CX + r0 * math.cos(a))), int(round(CY - r0 * math.sin(a))),
                    int(round(CX + 29 * math.cos(a))), int(round(CY - 29 * math.sin(a))))
        elif i % 5 == 0:
            dc.d.point((int(round(CX + 28 * math.cos(a))), int(round(CY - 28 * math.sin(a)))), fill=1)


# ---------------------------------------------------------------- modes
def m_weather(dc):
    px = assets.ICONS["W_PARTLY"]
    draw_px(dc, px, CX - len(px[0]) // 2, CY - 25 + (23 - len(px)) // 2)
    centered(dc, BIG, "-12°", CY + 2, hang_last=1)


def m_hilo(dc):
    tri(dc, CX - 13, 11, True); dc.text(CX - 2, 8, SM, "27")
    centered(dc, BIG, "18°", CY - 9, hang_last=1)
    tri(dc, CX - 13, 47, False); dc.text(CX - 2, 44, SM, "11")


def m_next3h(dc):
    centered(dc, SM, "+3H", 6)
    px = assets.ICONS["W_RAIN"]
    draw_px(dc, px, CX - 26, CY - 13)
    dc.text(CX + 3, CY - 7, MED, "16°")
    draw_px(dc, i_drop(13), CX - 19, 44)
    dc.text(CX - 6, 45, SM, "70%")


def m_tomorrow(dc):
    centered(dc, SM, "WED", 6)
    px = assets.ICONS["W_SUN"]
    draw_px(dc, px, CX - 26, CY - 12)
    tri(dc, CX + 1, CY - 9, True); dc.text(CX + 11, CY - 12, SM, "24")
    tri(dc, CX + 1, CY + 5, False); dc.text(CX + 11, CY + 2, SM, "12")
    draw_px(dc, i_drop(13), CX - 19, 44)
    dc.text(CX - 6, 45, SM, "10%")


def m_rain(dc):
    draw_px(dc, i_drop(14), CX - 5, 5)
    centered(dc, BIG, "40%", 21)
    centered(dc, SM, "RAIN", 45)


def m_wind(dc):
    centered(dc, SM, "NW", 6)                     # compass letters, as on the watch (wind from 300 deg)
    centered(dc, BIG, "14", 22)
    centered(dc, SM, "KMH", 45)


def m_hr(dc):
    draw_px(dc, assets.ICONS["I_HEART"], CX - 5, 8)
    centered(dc, BIG, "62", 21)
    centered(dc, SM, "BPM", 45)


def m_bb_ring(dc):                                   # no ring on the watch any more: the dotted arc shows the level
    draw_px(dc, assets.ICONS["I_BOLT"], CX - 3, 9)
    centered(dc, BIG, "64", 18)
    centered(dc, SM, "BB", 40)


def m_seconds(dc):
    sec_ticks(dc, 38)
    centered(dc, BIG, "38", CY - 9)


def m_dual(dc):
    centered(dc, SM, "UTC", 9)
    centered(dc, MED, "13:23", CY - 6)
    centered(dc, SM, "-3H", 44)


def m_sun(dc):
    draw_px(dc, assets.ICONS["I_SUNHZ"], CX - 6, 10)
    centered(dc, MED, "18:50", CY - 7)
    centered(dc, SM, "IN 2:27", 44)


def m_moon(dc):
    O.draw_moon(dc, CX, CY - 5, 12, 24.7)
    centered(dc, SM, "29%", 45, hang_last=1)


def m_alt(dc):
    draw_px(dc, i_mountain(), CX - 8, 8)
    centered(dc, BIG, "312", 21)
    centered(dc, SM, "M", 45)


def m_pressure(dc):
    tri(dc, CX - 4, 10, False)
    centered(dc, MED, "1013", 23)
    centered(dc, SM, "HPA", 44)


def m_notif(dc):
    draw_px(dc, i_envelope(), CX - 8, 7)
    centered(dc, BIG, "3", 21)
    centered(dc, SM, "NEW", 45)


def m_battery(dc):
    dc.rect(CX - 8, 9, 14, 8); dc.fill(CX + 6, 11, 2, 4); dc.fill(CX - 6, 11, 10, 4)
    centered(dc, BIG, "41", 18)
    centered(dc, SM, "DAYS", 40)


MODES = [
    ("Weather now", m_weather), ("Today high / low", m_hilo), ("Next 3 hours", m_next3h),
    ("Tomorrow", m_tomorrow), ("Rain chance", m_rain), ("Wind", m_wind),
    ("Heart rate", m_hr), ("Body Battery ring", m_bb_ring),
    ("Second time zone", m_dual), ("Next sun event", m_sun), ("Moon (large)", m_moon),
    ("Altitude", m_alt), ("Pressure + trend", m_pressure), ("Notifications", m_notif),
    ("Battery days + ring", m_battery),
]

# sample values for the modes that show a dotted arc (the others have none, or their own ring)
ARC = {"Weather now": 40, "Today high / low": 44, "Wind": 28, "Heart rate": 35, "Second time zone": 56,
       "Next sun event": 21, "Moon (large)": 84, "Pressure + trend": 63,
       "Body Battery ring": 64, "Battery days + ring": 98}


if __name__ == "__main__":
    scale = 6
    yy, xx = np.mgrid[0:176, 0:176]
    outside = ((xx - 144.5) ** 2 + (yy - 30.5) ** 2) > 31 ** 2
    tiles = []
    for name, fn in MODES:
        dc = P.Dc()
        fn(dc)
        # the dotted arc, as on the watch: only the filled dots, clockwise from the top
        pct = ARC.get(name)
        if pct is not None:
            for i in range(min(30, int(pct * 30 / 100.0 + 0.5))):
                a = math.radians(i * 12 - 90)
                x, y = int(CX + 28 * math.cos(a) + 0.5), int(CY + 28 * math.sin(a) + 0.5)
                dc.fill(x - 1 if x > CX else x, y - 1 if y > CY else y, 2, 2)
        a = np.asarray(dc.im.convert("L")) > 0
        bad = int((a & outside).sum())
        if bad:
            print(f"{name}: {bad} px outside the circle")
        w = P.on_watch(dc.im, scale)
        pad = 30 * scale
        tiles.append((name, w.crop((pad + 108 * scale, pad - 4 * scale, pad + 180 * scale, pad + 68 * scale))))
    tw, th = tiles[0][1].size
    cols = 4
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (tw + 16) + 16, rows * (th + 40) + 20), (231, 230, 226))
    d = ImageDraw.Draw(sheet)
    for i, (name, t) in enumerate(tiles):
        x = 16 + (i % cols) * (tw + 16)
        y = 14 + (i // cols) * (th + 40)
        sheet.paste(t, (x, y + 22))
        d.text((x + 4, y + 4), f"{i + 1}. {name}", fill=(30, 30, 30))
    sheet.save(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "preview-circle.png"))
    print(sheet.size)
