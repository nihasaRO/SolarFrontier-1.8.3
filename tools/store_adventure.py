"""Store images for 1.9: four adventure scenarios, "A day with Context", and an anatomy image per layout.
Faces are drawn by the same code as the previews (fonts, icons, panel mask, watch frame); the legend counts are
read from the real option lists (tools/settings_text.json).
Run: SAIRA_FONT_DIR=... python3 tools/store_adventure.py  ->  store/adventure-1..4.png, context-day.png,
     anatomy-rows.png, anatomy-chart.png
"""
import json, math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import store_versatility as SV
from preview2 import Dc, panel_mask

TOOLS = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(TOOLS), "store")
FD = os.environ.get("SAIRA_FONT_DIR", "/tmp/fonts")
F = SV.F
ORANGE, WHITE, MUTED = (242, 96, 34), (245, 244, 240), (178, 182, 186)


def font(size, weight="Bold"):
    return ImageFont.truetype(os.path.join(FD, f"SairaSemiCondensed-{weight}.ttf"), size)


# ---------------------------------------------------------------- one face from a plain description
def face(spec):
    """spec: layout 'rim' or 'rows', circle (a circle view name), time 'HH:MM', l1 (text, day), value, ramp, l3,
    cols / rows, gauges ((index, value), (index, value)) or None, chart (series key) or None, big (text),
    light (bool), raise (bool)."""
    rim = spec["layout"] == "rim"
    v = dict(SV.PV.SAMPLE)
    hh, mm = spec["time"].split(":")
    v.update(hh=hh, mm=mm, colon=(3 if rim else 2), gaugeStyle=spec.get("gaugeStyle", 0))
    g = spec.get("gauges")
    v["gaugeL"], v["stress"] = g[0] if g else (9, 0)
    v["gaugeR"], v["bb"] = g[1] if g else (9, 0)
    v["slots"] = dict(icon=spec.get("icon"), text=spec.get("l1", ("", None)), value=spec.get("value"),
                      ramp=spec.get("ramp"), row3=("text", spec["l3"]) if spec.get("l3") else None)
    if rim:
        v["colsSpec"] = spec["cols"]
        if spec.get("series"):
            v["chartSeries"], v["chartRange"] = spec["series"], spec["range"]
        elif spec.get("chart"):
            v["chartSeries"] = SV.CHARTS[spec["chart"]]
            v["chartRange"] = SV.RANGE[spec["chart"]]
        else:
            v["chartOff"] = True
    else:
        v["rowsSpec"] = spec["rows"]
    im = SV.PV.render(v, F, "rim" if rim else "rows", "raise" if spec.get("raise") else "normal")
    a = np.asarray(im.convert("L")) > 0
    a[SV.INSIDE] = SV.circle_layer(spec["circle"])[SV.INSIDE]
    im = Image.fromarray((a * 255).astype(np.uint8)).convert("1")
    if spec.get("big"):
        dc = Dc(); dc.im = im.convert("1"); dc.d = ImageDraw.Draw(dc.im)
        t = spec["big"]
        bf = F["big"] if dc.text_w(F["big"], t) <= 120 else F["small"]
        assert bf is F["big"], f"big text too wide: {t}"
        dc.text(88 - dc.text_w(bf, t) // 2, 149, bf, t)
        im = dc.im
    if spec.get("light"):
        a = np.asarray(im.convert("L")) > 0
        im = Image.fromarray(((~a) & (panel_mask() > 0)).astype(np.uint8) * 255).convert("1")
    hidden = int(((np.asarray(im.convert("L")) > 0) & ~(panel_mask() > 0)).sum())
    return im, hidden


def screen(im, S, pad=None):
    """The Instinct's screen at S x: its chamfered shape, light pixels on near-black, and the orange ring
    around the round sub-screen. RGBA, transparent outside the screen and ring."""
    pad = pad if pad is not None else 4 * S
    N = 176 * S
    a = np.asarray(im.convert("L").resize((N, N), Image.NEAREST)) > 0
    m = np.asarray(Image.fromarray(((panel_mask() > 0) * 255).astype(np.uint8), "L").resize((N, N), Image.NEAREST)) > 0
    rgb = np.zeros((N, N, 3), np.uint8); rgb[:] = (10, 11, 12); rgb[a] = (236, 236, 228)
    out = Image.new("RGBA", (N + 2 * pad, N + 2 * pad), (0, 0, 0, 0))
    d = ImageDraw.Draw(out)
    d.rounded_rectangle((pad - S * 2, pad - S * 2, pad + N + S * 2, pad + N + S * 2), radius=S * 10, fill=(40, 42, 44, 255))
    body = Image.fromarray(rgb, "RGB").convert("RGBA")
    body.putalpha(Image.fromarray((m * 255).astype(np.uint8), "L"))
    out.alpha_composite(body, (pad, pad))
    cx, cy, r = pad + 145.5 * S, pad + 31 * S, 32.5 * S
    d = ImageDraw.Draw(out)
    d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=ORANGE + (255,), width=max(2, int(1.6 * S)))
    return out


def wrap(d, text, f, width):
    """Lines of text that fit width px."""
    lines, cur = [], ""
    for word in text.split():
        t = (cur + " " + word).strip()
        if d.textlength(t, font=f) <= width or not cur:
            cur = t
        else:
            lines.append(cur); cur = word
    return lines + ([cur] if cur else [])


def gradient(top, bottom, size=(1440, 1440)):
    w, h = size
    t = np.linspace(0, 1, h)[:, None, None]
    arr = (np.array(top)[None, None, :] * (1 - t) + np.array(bottom)[None, None, :] * t).repeat(w, axis=1)
    return Image.fromarray(arr.astype(np.uint8), "RGB")


def save(img, name):
    path = os.path.join(OUT, name)
    img.convert("RGB").save(path, optimize=True)                  # full colour: the orange stays true
    return os.path.getsize(path)


DEG, UP, DN, PDN, MT = "\u00b0", "\u00a3", "\u00a4", "\u00a6", "\u00a9"

# ---------------------------------------------------------------- 1-4: adventure scenarios
SCENARIOS = [
    dict(name="ALPINE", tag="Altitude, freezing level and wind, at a glance.", colors=((18, 26, 34), (58, 78, 96)),
         notes=[("0" + DEG + " AT 2400 M", "freezing level from the forecast"),
                ("FORCE 5", "wind on the Beaufort scale"),
                ("ALTITUDE CHART", "the climb over the last hours")],
         spec=dict(layout="rim", circle="Pressure + trend", time="06:42", l1=("TUE", "06"), value=("I_BOLT", "71"),
                   ramp=("F_BATT", 8), l3="0" + DEG + " AT 2400 M",
                   cols=[("N_GUST", "5"), ("N_THERMO", "-4" + DEG), ("F_MOUNT", "2240")],
                   gauges=((1, 71), (8, 64)),
                   series=[1380 + 860 * (i / 53.0) ** 1.15 + 25 * math.sin(i / 2.7) for i in range(54)], range=("2240", "1380"))),
    dict(name="RAIN", tag="Roughly when it starts, and when it stops.", colors=((14, 22, 30), (44, 62, 78)),
         notes=[("RAIN ~30M", "Context: rain on its way"),
                ("NEXT 3 HOURS", "temperature and rain chance, hour by hour"),
                ("DRY ~25M", "once it rains: when it should stop")],
         spec=dict(layout="rim", circle="Next 3 hours", time="11:20", l1=("06 OCT", None), value=("I_BOLT", "58"),
                   ramp=("N_UMBRELLA", 7), l3="GUST 38 KMH",
                   cols=[("N_UMBRELLA", "70%"), ("F_DROP", "93%"), ("N_RAIN", "4.2")],
                   gauges=((10, 93), (11, 70)), big="RAIN ~30M")),
    dict(name="SUN", tag="UV, daylight and solar charge, readable in full sun.", colors=((54, 34, 14), (150, 98, 40)),
         notes=[("UV 8 HIGH", "Context: time for sun protection"),
                ("DAYLIGHT", "time left until sunset"),
                ("LIGHT THEME", "dark on light for bright days")],
         spec=dict(layout="rows", circle="Next sun event", time="16:23", l1=("FEELS 31" + DEG, None),
                   value=("F_BATT", "41D"), ramp=("N_UV", 7), l3="UV 8 HIGH",
                   rows=[("N_UV", "8", 73, False), ("I_SUNHZ", "2:27", 20, False), ("G_SOLAR", "64%", 64, False)],
                   gauges=((3, 64), (2, 76)), light=True)),
    dict(name="NIGHT", tag="Moon, first light and snow on the way.", colors=((6, 8, 20), (26, 30, 62)),
         notes=[("SNOW ~2H", "when the snow should start"),
                ("FIRST 6:12", "first light for an early start"),
                ("MOON 29%", "phase and how much of it is lit")],
         spec=dict(layout="rim", circle="Moon (large)", time="21:48", l1=("FIRST 6:12", None),
                   value=("N_HEART_O", "52"), ramp=("N_MOON", 9), l3="SNOW ~2H",
                   cols=[("N_THERMO", "-8" + DEG), ("N_SNOW", "12"), ("F_BARO", "-1.8")],
                   gauges=((1, 24), (0, 18)), chart="pressure")),
]


def scenario_image(i, sc):
    out = gradient(*sc["colors"])
    d = ImageDraw.Draw(out)
    d.text((90, 84), f"{i + 1} / 4", font=font(34, "SemiBold"), fill=ORANGE)
    d.text((86, 118), sc["name"], font=font(150), fill=WHITE)
    d.text((92, 300), sc["tag"], font=font(46, "SemiBold"), fill=MUTED)
    im, hidden = face(sc["spec"])
    sc_img = screen(im, 4)
    out.paste(sc_img, ((1440 - sc_img.width) // 2, 410), sc_img)
    y = 1230
    xs = [90, 540, 990]
    for (k, t), x in zip(sc["notes"], xs):
        d.ellipse((x, y + 14, x + 16, y + 30), fill=ORANGE)
        d.text((x + 30, y - 2), k, font=font(38), fill=WHITE)
        for j, ln in enumerate(wrap(d, t, font(28, "SemiBold"), 400)):
            d.text((x + 30, y + 46 + j * 34), ln, font=font(28, "SemiBold"), fill=MUTED)
    return out, hidden


# ---------------------------------------------------------------- 5: a day with Context
DAY = [("07:30", "QUIET MORNING", "DRY 12H+", "Nothing urgent: a calm outlook.", 86, "8", 10, 95),
       ("11:20", "CHANGE AHEAD", "RAIN ~30M", "Worth knowing before you leave.", 70, "18", 70, 62),
       ("14:00", "ACT NOW", "GUST 72 KMH", "Strong wind comes first.", 55, "38", 40, 38),
       ("17:05", "LIGHT RUNNING OUT", "LIGHT 0:35", "Time left before sunset.", 38, "22", 20, 6),
       ("21:00", "RAIN SETTLED IN", "RAIN +14MM", "How much is still to come.", 30, "10", 90, 0)]


def context_day():
    out = gradient((16, 18, 20), (36, 40, 44))
    d = ImageDraw.Draw(out)
    d.text((86, 70), "A DAY WITH CONTEXT", font=font(96), fill=WHITE)
    d.text((92, 196), "One field that shows what matters next, and stays calm when nothing does.",
           font=font(40, "SemiBold"), fill=MUTED)
    hidden = []
    pos = [(70, 300), (510, 300), (950, 300), (290, 850), (730, 850)]
    for (t, label, msg, note, bb, wind, rain, light), (x, y) in zip(DAY, pos):
        spec = dict(layout="rim", circle="Pressure + trend", time=t, l1=("TUE", "06"), value=("I_BOLT", str(bb)),
                    ramp=("N_UMBRELLA", max(1, rain // 10)), l3="MOON 29%",
                    cols=[((("ARROW", 300)), wind), ("N_UMBRELLA", f"{rain}%"), ("N_THERMO", "12" + DEG)],
                    gauges=((1, bb), (8, light)), big=msg)
        im, h = face(spec)
        hidden.append(h)
        sc_img = screen(im, 2, pad=10)
        out.paste(sc_img, (x, y), sc_img)
        cx = x + sc_img.width // 2
        for text, f, col, dy in ((t, font(40), ORANGE, 380), (label, font(30), WHITE, 428), (note, font(25, "SemiBold"), MUTED, 468)):
            tw = d.textlength(text, font=f)
            d.text((cx - tw / 2, y + dy), text, font=f, fill=col)
    return out, hidden


# ---------------------------------------------------------------- 6-7: anatomy, one per layout
T = json.load(open(os.path.join(TOOLS, "settings_text.json")))


def n(title):
    return len([x for x in T["o"][T["t"].index(title)] if x != "Off"])


def anatomy(layout):
    rim = layout == "rim"
    spec = dict(layout=layout, circle="Next 3 hours", time="10:08", l1=("TUE", "06"), value=("I_BOLT", "64"),
                ramp=("N_UMBRELLA", 7), l3="RAIN ~30M", gauges=((1, 64), (8, 40)))
    if rim:
        spec.update(cols=[((("ARROW", 300)), "14"), ("N_UMBRELLA", "70%"), ("F_MOUNT", "2240")], chart="pressure")
    else:
        spec.update(rows=[("I_STEPS", "8432", 84, False), ("I_RUN", "96", 64, False), ("I_HEART", "92", 1, True)])
    im, hidden = face(spec)
    S, PX, PY = 4, 60, 290                                   # the screen at 4x, at (PX, PY)
    out = gradient((16, 18, 20), (36, 40, 44))
    d = ImageDraw.Draw(out)
    d.text((86, 70), ("CHART" if rim else "ROWS") + " LAYOUT", font=font(96), fill=WHITE)
    d.text((92, 196), "Every numbered zone is yours to set, on the watch or in Garmin Connect.", font=font(40, "SemiBold"), fill=MUTED)
    sc_img = screen(im, S, pad=0)
    out.paste(sc_img, (PX, PY), sc_img)
    # zones: number, badge (panel px, placed where it hides nothing), the zone it points to (or None), title, text
    zones = [(1, (11, 17), None, "LINE 1", f"Icon + text: {n('Line 1 icon')} icons, {n('Line 1 text')} texts, {n('Date format')} date formats"),
             (2, (11, 35), None, "LINE 2", f"A number ({n('Line 2 number')} choices) and a bar ({n('Line 2 bar')})"),
             (3, (11, 58), None, "LINE 3", f"{n('Line 3')} metrics, Context and rain timing included"),
             (4, (117, 64), (126, 52), "CIRCLE", f"{n('Circle shows')} views: weather, wind, moon, 2nd time zone and more"),
             (5, (105, 68), None, "TIME", "12 or 24 h, 4 colon and 4 minute styles"),
             (6, (11, 150), (4, 128), "SIDE GAUGES", f"Left and right, {n('Left gauge')} metrics each, as a bar or blocks")]
    if rim:
        zones += [(7, (64, 121), None, "COLUMNS", f"Three columns, {n('Column 1')} metrics each"),
                  (8, (166, 151), (140, 160), "CHART OR BIG TEXT", f"8 histories over 1, 3 or 4 h, or {n('Big text shows')} metrics in large type")]
    else:
        zones += [(7, (166, 151), (152, 144), "ROWS", f"Three progress rows, {n('Row 1')} metrics each")]
    r, f_num = 22, font(30)
    for num, (bx, by), target, title, line in zones:
        ax, ay = PX + bx * S, PY + by * S
        if target:
            tx, ty = PX + target[0] * S, PY + target[1] * S
            d.line((ax, ay, tx, ty), fill=ORANGE, width=4)
            d.ellipse((tx - 6, ty - 6, tx + 6, ty + 6), fill=ORANGE)
        d.ellipse((ax - r, ay - r, ax + r, ay + r), fill=ORANGE, outline=(16, 16, 16), width=4)
        tw = d.textlength(str(num), font=f_num)
        d.text((ax - tw / 2, ay - 21), str(num), font=f_num, fill=WHITE)
    LX, ly = 830, 290
    for num, _, _, title, line in zones:
        d.ellipse((LX, ly + 4, LX + 44, ly + 48), fill=ORANGE)
        tw = d.textlength(str(num), font=f_num)
        d.text((LX + 22 - tw / 2, ly + 5), str(num), font=f_num, fill=WHITE)
        d.text((LX + 64, ly), title, font=font(36), fill=WHITE)
        lines = wrap(d, line, font(26, "SemiBold"), 1440 - LX - 64 - 60)
        for j, ln in enumerate(lines):
            d.text((LX + 64, ly + 46 + j * 32), ln, font=font(26, "SemiBold"), fill=MUTED)
        ly += 62 + 32 * len(lines) + 22
    foot = "Wrist raise adds exact values to the gauges, rows and chart. All settings work on the watch itself, no phone needed."
    for j, ln in enumerate(wrap(d, foot, font(30, "SemiBold"), 680)):
        d.text((92, 1050 + j * 40), ln, font=font(30, "SemiBold"), fill=MUTED)
    d.line((92, 1300, 1348, 1300), fill=(70, 74, 78), width=2)
    d.text((92, 1322), "SOLAR FRONTIER", font=font(40), fill=WHITE)
    tw = d.textlength("FOR INSTINCT 3 SOLAR", font=font(30, "SemiBold"))
    d.text((1348 - tw, 1330), "FOR INSTINCT 3 SOLAR", font=font(30, "SemiBold"), fill=ORANGE)
    return out, hidden


if __name__ == "__main__":
    report = []
    for i, sc in enumerate(SCENARIOS):
        img, h = scenario_image(i, sc)
        report.append((f"adventure-{i + 1}.png", save(img, f"adventure-{i + 1}.png"), h))
    img, h = context_day()
    report.append(("context-day.png", save(img, "context-day.png"), h))
    for lay, name in (("rows", "anatomy-rows.png"), ("rim", "anatomy-chart.png")):
        img, h = anatomy(lay)
        report.append((name, save(img, name), h))
    for name, size, h in report:
        print(f"{name:20s} {size / 1024:6.1f} KB | pixels outside the panel: {h}")
