"""Pixel preview of Solar Frontier. Mirrors source/SolarFrontierView.mc.
Renders both layouts (Rows, Rim) in four states: normal, wrist raise, night mode, light theme.
Run: python3 tools/preview.py   (writes preview.png next to the project)"""
import os, sys, math
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import assets
from preview2 import Dc, on_watch, clip_report, panel_mask

SYN = 29.530588853
SHARES = (25.0, 25.0, 50.0)
ARROW = ["###...", "####..", "#####.", "######", "#####.", "####..", "###..."]


def moon(dc, cx, cy, r, age):
    k = math.cos(2 * math.pi * age / SYN); waxing = age < SYN / 2; R2 = (r + 0.5) ** 2
    half = lambda dy: int(math.sqrt(R2 - dy * dy)) if dy * dy <= R2 else -1
    for dy in range(-r, r + 1):
        w = half(dy); wn = max(half(abs(dy) + 1), 0); edge = max(1, w - wn)
        if abs(dy) == r:
            dc.fill(cx - w, cy + dy, 2 * w + 1, 1)
        else:
            dc.fill(cx - w, cy + dy, edge, 1); dc.fill(cx + w - edge + 1, cy + dy, edge, 1)
        t = int(math.ceil(k * w)); a, b = (cx + t, cx + w) if waxing else (cx - w, cx - t)
        if b >= a:
            dc.fill(a, cy + dy, b - a + 1, 1)


def icon_box(dc, name, x, y, bw, bh):
    px = assets.ICONS[name]
    dc.icon(name, x + (bw - len(px[0])) // 2, y + (bh - len(px)) // 2)


def diamond(dc, x, y, filled):
    for dy in range(-3, 4):
        w = 3 - abs(dy)
        if filled:
            dc.fill(x - w, y + dy, 2 * w + 1, 1)
        else:
            dc.d.point((x - w, y + dy), fill=1); dc.d.point((x + w, y + dy), fill=1)


def quarter_gauge(dc, els, pieces, value):
    if value is None:
        return
    start, idx = 0.0, 0
    for k in range(3):
        n = pieces[k]
        lit = int(max(0.0, min(1.0, (value - start) / SHARES[k])) * n + 0.5)
        for i in range(n):
            e = els[(idx + i) * 9:(idx + i) * 9 + 9]
            if e[0] == 0:
                dc.fill(*(e[1:5] if i < lit else e[5:9]))
            else:
                diamond(dc, e[1], e[2], i < lit)
        idx += n; start += SHARES[k]
    if value > 100:
        t = (idx - 1) * 9
        dc.fill(els[t + 1] + 2, els[t + 2] - 3, 2, 1); dc.fill(els[t + 1] + 1, els[t + 2] - 2, 4, 1)


def ink(f, s):
    x, first, last = 0, None, None
    for c in s:
        g, xo, yo, adv = f["glyphs"][c]
        bb = g.getbbox() if g is not None else None
        if bb:
            a, b = x + xo + bb[0], x + xo + bb[2] - 1
            first = a if first is None else min(first, a); last = b if last is None else max(last, b)
        x += adv
    return first, last


def draw_time(dc, Fh, Fm, hh, mm, style, ampm=None, Ft=None, dither=False):
    half = 0 if style == 0 else (3 if style == 3 else 2)
    if ampm and style == 0:
        half = 2
    hf, hl = ink(Fh, hh); mf, ml = ink(Fm, mm)
    dc.text(88 - half - 4 - hl, 74, Fh, hh)
    if style:
        for cy in (88, 102):
            if style == 1:
                dc.fill(87, cy - 2, 3, 1); dc.fill(86, cy - 1, 5, 3); dc.fill(87, cy + 2, 3, 1)
            elif style == 2:
                dc.fill(86, cy - 2, 5, 5)
            else:
                for dy in range(-3, 4):
                    w = 3 - abs(dy); dc.fill(88 - w, cy + dy, 2 * w + 1, 1)
    dc.text(88 + half + 4 - mf, 74, Fm, mm)
    if dither:
        # mirrors the watch: solid minutes, then every other pixel knocked out, clipped to the minutes
        x0, x1 = 88 + half + 4, 88 + half + 4 - mf + ml
        for yy in range(74, 115):
            for xx in range(x0, x1 + 1):
                if (xx + yy) % 2 == 0:
                    dc.d.point((xx, yy), fill=0)
    if ampm:
        dc.text(88, 76, Ft, ampm[0], "C"); dc.text(88, 107, Ft, "M", "C")


def arc(dc, pct):
    lit = min(30, int(pct * 30 / 100.0 + 0.5))
    for i in range(lit):
        a = math.radians(i * 12 - 90)
        x, y = int(145 + 28 * math.cos(a) + 0.5), int(31 + 28 * math.sin(a) + 0.5)
        dc.fill(x - 1 if x > 145 else x, y - 1 if y > 31 else y, 2, 2)



def arrow_small(dc, cx, cy, bearing):
    import math as _m
    a = _m.radians(bearing + 180)
    dx, dy = _m.sin(a), -_m.cos(a)
    tx, ty = cx + 4 * dx, cy + 4 * dy
    dc.d.line([(cx - 4 * dx, cy - 4 * dy), (tx, ty)], fill=1)
    dc.d.polygon([(tx + dx, ty + dy), (tx - 3 * dx + 3 * dy, ty - 3 * dy - 3 * dx), (tx - 3 * dx - 3 * dy, ty - 3 * dy + 3 * dx)], fill=1)


# gauge options, as on the watch (index 9 = off)
GLYPHS = ["G_STRESS", "I_BOLT", "G_BATT", "G_SOLAR", "G_STEPS", "G_INT", "G_FLOORS", "G_MOVE", "G_DAY", None,
          "F_DROP", "N_UMBRELLA", "N_CLOUD", "N_MOON", "N_UV", "G_INT", "N_AIR"]


def side_gauges(dc, v):
    """Mirrors drawSideGauges: bar (Enduro style) or 12 blocks, ticks at 25/50/75 %, glyph on top."""
    blocks = v.get("gaugeStyle", 0) == 1
    for left, kind, value in ((True, v.get("gaugeL", 0), v["stress"]), (False, v.get("gaugeR", 1), v["bb"])):
        if kind == 9:
            continue
        if blocks:
            bx = 1 if left else 167
            lit = int(value * 12 / 100.0 + 0.5)
            for i in range(12):
                y0 = 130 - 4 * i
                dc.fill(bx, y0, 6, 3) if i < lit else dc.fill(4 if left else 170, y0, 1, 3)
        else:
            dc.fill(2 if left else 171, 85, 1, 48)
            h = int(48 * min(100, value) / 100.0 + 0.5)
            if h:
                dc.fill(1 if left else 169, 133 - h, 4, h)
        tx = (8 if blocks else 6) if left else (162 if blocks else 164)
        for q in range(3):
            ln = 3 if q == 1 else 2
            dc.fill(tx if left else tx + 3 - ln, 121 - 12 * q, ln, 1)
        icon_box(dc, GLYPHS[kind], 0 if left else 163, 73, 11, 9)


DEFAULT_SLOTS = dict(icon="moon", text=("TUE", "06"), value=("battery", "98"), ramp=(None, 6), row3="nextsun")


def top_block(dc, F, v, night, slots=None):
    """Mirrors drawTopBlock / drawRow2 / drawRow3 (slots chosen in settings)."""
    sl = dict(DEFAULT_SLOTS, **(slots or {}))
    s = F["small"]
    # row 1: icon slot + text (date with a larger day number, or a plain text such as a time zone)
    cw = 0 if sl["icon"] is None else 17
    if sl["text"] is None:
        if sl["icon"]:
            icon_box(dc, sl["icon"], 58, 11, 13, 13)
        text, day = "", None
    else:
        text, day = sl["text"]
    w = cw + dc.text_w(s, text) + ((4 + dc.text_w(F["med"], day)) if day else 0)
    x = max(29, 64 - w // 2)
    if sl["text"] is None:
        pass
    elif sl["icon"] == "moon":
        moon(dc, x + 6, 17, 6, v["moon"])
    elif sl["icon"]:
        icon_box(dc, sl["icon"], x, 11, 13, 13)
    dc.text(x + cw, 13, s, text)
    if day:
        dc.text(x + cw + dc.text_w(s, text) + 4, 11, F["med"], day)
    # row 2: value + compact 10-bar ramp (3 px pitch), glyph unless solar; shifts left when wide
    vk, vt = sl["value"] if sl["value"] is not None else (None, "")      # None: the number is off
    glyph, lit = sl["ramp"] if sl["ramp"] is not None else (None, None)
    ramp_on = sl["ramp"] is not None
    tw = dc.text_w(s, vt) if vt else 0; vw = 0 if vk is None else (19 if vk == "battery" else 15); gw = 0 if glyph is None else 11
    w = vw + tw + ((6 if vk else 0) + gw + 29 if ramp_on else 0)
    x = 60 - w // 2
    if x + w > 100:
        x = 100 - w
    x = max(x, 11)
    if vk == "battery":
        dc.rect(x, 31, 13, 10); dc.fill(x + 13, 34, 2, 4); dc.fill(x + 2, 33, 9, 6)
    elif vk:
        icon_box(dc, vk, x, 30, 11, 11)
    if vk:
        dc.text(x + vw, 30, s, vt)
    rx = x + vw + tw + (6 if vk else 0)
    if not ramp_on:
        rx = None
    if rx is not None and glyph:
        icon_box(dc, glyph, rx, 32, 9, 9); rx += gw
    for i in range(10 if rx is not None else 0):
        dc.fill(rx + 3 * i, 39 - i, 2, 2 + i) if i < lit else dc.fill(rx + 3 * i, 40, 2, 1)
    dc.line(14, 47, 101, 47); dc.line(101, 47, 107, 41)
    if night:
        return
    r3 = sl["row3"]
    if r3 is None:
        return
    if isinstance(r3, tuple) and r3[0] == "text":
        lw = dc.text_w(s, r3[1]); x = 60 - lw // 2
        if x + lw > 106:
            x = 106 - lw
        dc.text(max(8, x), 53, s, r3[1])
        return
    if isinstance(r3, tuple) and r3[0] == "wind":
        ww = 12 + dc.text_w(s, r3[2]); x = 60 - ww // 2
        arrow_small(dc, x + 4, 59, r3[1]); dc.text(x + 12, 53, s, r3[2])
        return
    # the original options, as the watch now draws them: one string with pictogram characters, centred on 62
    legacy = {"nextsun": "\u00a118:50\u00a82:27", "bothsun": "7:17\u00a218:50", "pressure": "\u00a61013 HPA",
              "hilo": "\u00a327\u00a411", "altitude": "\u00a9312 M", "steps": "\u00aa5673"}
    if r3 in legacy:
        t = legacy[r3]; lw = dc.text_w(s, t); x = 62 - lw // 2
        if x + lw > 106:
            x = 106 - lw
        dc.text(max(8, x), 53, s, t)


def rows_lower(dc, F, v, awake):
    dc.line(16, 122, 20, 118); dc.line(20, 118, 156, 118); dc.line(156, 118, 160, 122)
    rows = v["rowsSpec"] if "rowsSpec" in v else [("I_STEPS", v["steps"], v["stepsPct"], False), ("I_RUN", v["int"], v["intPct"], False), ("I_HEART", v["hr"], v["zone"], True)]
    for k, row in enumerate(rows):
        if row is None:
            continue
        icon, val, amt, is_zone = row
        y = 123 + k * 15
        icon_box(dc, icon, 28, y, 11, 11)
        if is_zone:
            for i in range(5):
                dc.fill(42 + i * 14, y + 2, 13, 7) if i < amt else dc.icon("M_D13", 42 + i * 14, y + 2)
            txt = f"Z{amt}" if awake else val
        else:
            n = max(0, min(10, int(amt * 10 / 100.0 + 0.5)))
            for i in range(10):
                cx = 42 + i * 7
                if i == 9 and amt > 100:
                    for r, row in enumerate(ARROW):
                        for c, ch in enumerate(row):
                            if ch == "#":
                                dc.d.point((cx + c, y + 2 + r), fill=1)
                elif i < n:
                    dc.fill(cx, y + 2, 6, 7)
                else:
                    dc.icon("M_D6", cx, y + 2)
            txt = f"{amt}%" if awake else val
        dc.text(148 - dc.text_w(F["small"], txt), y, F["small"], txt)


def rim_lower(dc, F, v, awake):
    if awake:
        dc.text(12, 116, F["tiny"], str(v["stress"]))
        dc.text(161 - dc.text_w(F["tiny"], str(v["bb"])), 116, F["tiny"], str(v["bb"]))
    cols = v.get("colsSpec") or list(zip(("I_RUN", "I_STEPS", "I_HEART"), (v["intDay"], v["steps"], v["hr"])))
    for cx, col in zip((40, 88, 136), cols):
        if col is None:
            continue
        icon, val = col
        if isinstance(icon, tuple):
            arrow_small(dc, cx, 122, icon[1])
        else:
            icon_box(dc, icon, cx - 5, 117, 11, 11)
        if dc.text_w(F["data"], val) > 46:
            dc.text(cx, 131, F["small"], val, "C")
        else:
            dc.text(cx, 129, F["data"], val, "C")
    for y in range(118, 144, 2):
        dc.d.point((64, y), fill=1); dc.d.point((112, y), fill=1)
    if v.get("chartOff"):
        return
    chart_minmax = awake and v.get("chartRange")
    hr = v.get("chartSeries") or [95 + int(8 * math.sin(i / 5.0)) + (i % 7) for i in range(54)]
    lo, hi = min(hr), max(hr)
    for i, b in enumerate(hr):
        h = 1 + int((b - lo) * 19 / (hi - lo)); dc.fill(35 + 2 * i, 168 - h, 1, h)
    if chart_minmax:                                   # wrist raise: lowest at the left edge, highest at the right edge
        hiT, loT = v["chartRange"]; lw, hw = dc.text_w(F["tiny"], loT), dc.text_w(F["tiny"], hiT)
        dc.d.rectangle((16, 145, 16 + lw + 8, 154), fill=0); dc.d.rectangle((150 - hw, 145, 158, 154), fill=0)
        dc.fill(17, 148, 5, 1); dc.fill(18, 149, 3, 1); dc.fill(19, 150, 1, 1); dc.text(23, 146, F["tiny"], loT)
        dc.text(151 - hw, 146, F["tiny"], hiT); dc.fill(155, 148, 1, 1); dc.fill(154, 149, 3, 1); dc.fill(153, 150, 5, 1)


def render(v, F, layout="rows", state="normal"):
    dc = Dc()
    night, awake, light = state == "night", state == "raise", state == "light"
    if night:
        moon(dc, 145, 29, 12, v["moon"])
    elif v.get("circleOff"):
        pass
    else:
        ic = assets.ICONS[v["icon"]]
        dc.icon(v["icon"], 145 - len(ic[0]) // 2, 31 - 25 + (23 - len(ic)) // 2)
        dc.text(145 - dc.text_w(F["mid"], v["temp"]) // 2, 33, F["mid"], v["temp"] + "°")
        arc(dc, v["rain"])
    top_block(dc, F, v, night, v.get("slots"))
    draw_time(dc, F["time"], F["time"], v.get("hh", "16"), v.get("mm", "23"),
              v.get("colon", 2 if layout == "rows" else 3), v.get("ampm"), F["tiny"], dither=not light)
    if not night:
        side_gauges(dc, v)
        (rows_lower if layout == "rows" else rim_lower)(dc, F, v, awake)
    im = dc.im
    if light:
        a = np.asarray(im.convert("L")) > 0
        im = Image.fromarray(((~a) & (panel_mask() > 0)).astype(np.uint8) * 255).convert("1")
    return im


SAMPLE = dict(icon="W_PARTLY", temp="24", rain=40, moon=24.7, steps="12.5K", stepsPct=125, int="60", intPct=40,
              hr="92", zone=1, stress=62, bb=45, intDay="30")

if __name__ == "__main__":
    F = assets.all_fonts()
    states = [("normal", "Normal"), ("raise", "Wrist raise (details on)"), ("light", "Light theme")]
    tiles = []
    for layout, lname in (("rows", "Rows"), ("rim", "Chart")):
        for st, sname in states:
            im = render(SAMPLE, F, layout, st)
            print(f"{lname} / {sname}: hidden pixels {clip_report(im)}")
            tiles.append((f"{lname} - {sname}", on_watch(im, 3)))
    tw, th = tiles[0][1].size
    out = Image.new("RGB", (3 * (tw + 14) + 10, 2 * (th + 30) + 10), (231, 230, 226))
    d = ImageDraw.Draw(out)
    for i, (name, t) in enumerate(tiles):
        x, y = 5 + (i % 3) * (tw + 14), 5 + (i // 3) * (th + 30)
        out.paste(t, (x, y + 22)); d.text((x + 8, y + 4), name, fill=(30, 30, 30))
    proj = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(proj, "preview.png")
    out.save(path)
    print("saved", path)

    # top-slot combinations
    combos = [
        ("Default (gauges: bar)", {}, "rows"),
        ("Alarm, time zone | Body Battery | both sun times",
         dict(icon="S_ALARM", text=("UTC 13:23", None), value=("I_BOLT", "64"), ramp=("I_BOLT", 6), row3="bothsun"), "rows"),
        ("Do Not Disturb | stress + intensity goal | pressure",
         dict(icon="S_DND", value=("F_ZIG", "28"), ramp=("I_RUN", 4), row3="pressure"), "rows"),
        ("Bluetooth, 06 OCT | heart rate + battery | high/low",
         dict(icon="S_BT", text=("06 OCT", None), value=("I_HEART", "92"), ramp=("F_BATT", 10), row3="hilo"), "rows"),
        ("Chart: battery days + HR zone | altitude",
         dict(value=("F_BATT", "41D"), ramp=("I_HEART", 2), row3="altitude"), "rim"),
        ("No icon, week | notifications + steps goal | both sun times",
         dict(icon=None, text=("W41 TUE", None), value=("F_MAIL", "3"), ramp=("I_STEPS", 6), row3="bothsun"), "rows"),
    ]
    tiles = []
    for name, slots, layout in combos:
        im = render(dict(SAMPLE, slots=slots), F, layout, "normal")
        print(f"top slots / {name}: hidden pixels {clip_report(im)}")
        tiles.append((name, on_watch(im, 3)))
    out = Image.new("RGB", (3 * (tw + 14) + 10, 2 * (th + 30) + 10), (231, 230, 226))
    d = ImageDraw.Draw(out)
    for i, (name, t) in enumerate(tiles):
        x, y = 5 + (i % 3) * (tw + 14), 5 + (i // 3) * (th + 30)
        out.paste(t, (x, y + 22)); d.text((x + 8, y + 4), name, fill=(30, 30, 30))
    out.save(os.path.join(proj, "preview-top.png"))
    print("saved", os.path.join(proj, "preview-top.png"))
