"""Store images that show versatility: 4 images, each with the same 4 variations of the face
(Chart, Chart with big text, Rows, Light), every slot filled with a different metric.

Rule: no metric appears twice within an image; across the 4 images each slot takes the metric used least
so far, so repeats only happen where a slot type runs out of options.
Run: SAIRA_FONT_DIR=... python3 tools/store_versatility.py  ->  store/versatility-1..4.png
"""
import math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import assets, preview as PV, preview_circle as PC
from preview2 import Dc, on_watch, panel_mask

TOOLS = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(TOOLS), "store")
F = assets.all_fonts()
G = {n: i for i, n in enumerate(PV.GLYPHS) if n}          # gauge option index by glyph
G["G_INT_DAY"] = 15

# ---------------------------------------------------------------- catalogue: key -> forms (sample values)
SUN, DOT, SUN2 = "\u00a1", "\u00a8", "\u00a2"
UP, DN, PDN, MT, ST = "\u00a3", "\u00a4", "\u00a6", "\u00a9", "\u00aa"
C = {
    "steps":       dict(col=("I_STEPS", "8432"), row=("I_STEPS", "12.5K", 125), ramp=("I_STEPS", 8), gauge=(4, 84), l3=ST + "8432", l1=ST + "8432", big=ST + "12.5K"),
    "steps_goal":  dict(col=("I_STEPS", "-4327"), l3=ST + "-4327", l1=ST + "-4327", big=ST + "-4327"),
    "int_today":   dict(col=("I_RUN", "22"), row=("I_RUN", "22", 73), ramp=("I_RUN", 7), gauge=(15, 73)),
    "int_week":    dict(col=("F_WEEK", "96"), row=("I_RUN", "96", 64), gauge=(5, 64)),
    "hr":          dict(col=("I_HEART", "92"), row=("I_HEART", "92", 1, True), value=("I_HEART", "92"), circle="Heart rate", chart="hr"),
    "hr_zone":     dict(ramp=("I_HEART", 2)),
    "rest_hr":     dict(col=("N_HEART_O", "52"), value=("N_HEART_O", "52")),
    "bb":          dict(col=("I_BOLT", "64"), row=("I_BOLT", "64", 64), ramp=("I_BOLT", 6), gauge=(1, 64), value=("I_BOLT", "64"),
                        circle="Body Battery ring", chart="bb"),
    "bb_change":   dict(col=("I_BOLT", "+12"), l3="BB 64 +12", l1="BB 64 +12", big="BB 64 +12"),
    "stress":      dict(col=("F_ZIG", "28"), row=("F_ZIG", "28", 28), ramp=("F_ZIG", 3), gauge=(0, 28), value=("F_ZIG", "28"), chart="stress"),
    "breath":      dict(col=("N_LUNGS", "14"), l3="BREATH 14", l1="BREATH 14"),
    "spo2":        dict(chart="spo2"),
    "floors":      dict(col=("F_STAIRS", "7"), row=("F_STAIRS", "7", 70), gauge=(6, 70)),
    "floors_down": dict(col=("N_STAIRS_D", "5")),
    "climbed":     dict(col=("F_MOUNT", "184")),
    "distance":    dict(col=("F_DIST", "8.4")),
    "calories":    dict(col=("F_FLAME", "2140")),
    "move":        dict(row=("G_MOVE", "2", 40), gauge=(7, 40)),
    "battery":     dict(row=("F_BATT", "76%", 76), ramp=("F_BATT", 8), gauge=(2, 76), value=("battery", "76")),
    "battery_days": dict(col=("F_BATT", "41"), value=("F_BATT", "41D"), circle="Battery days + ring"),
    "solar":       dict(row=("G_SOLAR", "64%", 64), ramp=(None, 6), gauge=(3, 64), chart="solar"),
    "daylight":    dict(row=("I_SUNHZ", "3:12", 27), gauge=(8, 27)),
    "humidity":    dict(col=("F_DROP", "64%"), row=("F_DROP", "64%", 64), ramp=("F_DROP", 6), gauge=(10, 64), l3="HUMID 64%"),
    "rain_chance": dict(col=("N_UMBRELLA", "40%"), row=("N_UMBRELLA", "40%", 40), ramp=("N_UMBRELLA", 4), gauge=(11, 40),
                        l3="RAIN 3H 40%", circle="Rain chance"),
    "cloud":       dict(col=("N_CLOUD", "30%"), row=("N_CLOUD", "30%", 30), ramp=("N_CLOUD", 3), gauge=(12, 30), l3="CLOUD 30%"),
    "moon":        dict(col=("N_MOON", "24%"), row=("N_MOON", "24%", 24), ramp=("N_MOON", 2), gauge=(13, 24), l3="MOON 24%",
                        circle="Moon (large)", icon="moon"),
    "uv":          dict(col=("N_UV", "6"), row=("N_UV", "6", 55), ramp=("N_UV", 6), gauge=(14, 55), l3="UV 6", l1="UV 6"),
    "air":         dict(col=("N_AIR", "2"), row=("N_AIR", "2", 25), ramp=("N_AIR", 2), gauge=(16, 25), l3="AIR FAIR", big="AIR FAIR"),
    "wind":        dict(col=(("ARROW", 300), "14"), circle="Wind", big="WIND 14 KMH"),
    "gusts":       dict(col=("N_GUST", "38"), l3="GUST 38 KMH"),
    "feels":       dict(col=("N_THERMO", "11\u00b0"), l3="FEELS 11\u00b0", l1="FEELS 11\u00b0"),
    "dew":         dict(col=("N_DEW", "9\u00b0"), l3="DEW 9\u00b0", l1="DEW 9\u00b0"),
    "hilo":        dict(col=("N_THERMO", "24/12"), l3=UP + "24" + DN + "12", l1=UP + "24" + DN + "12", circle="Today high / low"),
    "visibility":  dict(col=("N_EYE", "24")),
    "rain_1h":     dict(col=("N_RAIN", "0.4")),
    "rain_day":    dict(col=("N_RAIN", "12"), l3="RAIN 12 MM", big="RAIN 12 MM"),
    "precip_next": dict(col=("N_UMBRELLA", "~25M"), l3="RAIN ~25M", big="RAIN ~25M"),
    "uv_max":      dict(col=("N_UV", "8"), l3="UV MAX 8", big="UV MAX 8"),
    "storm":       dict(col=("S_STORM", "850"), l3="TSTORM HIGH", big="TSTORM HIGH"),
    "pollen":      dict(col=("N_POLLEN", "3"), l3="GRASS HIGH", big="GRASS HIGH"),
    "freezing":    dict(col=("N_FREEZE", "2400"), l3="0\u00b0 AT 2400 M", big="0\u00b0 AT 2400 M"),
    "snow":        dict(col=("N_SNOW", "4.5"), l3="SNOW 12 CM", big="SNOW 12 CM"),
    "pressure":    dict(col=("F_BARO", "1013"), l3=PDN + "1013 HPA", l1=PDN + "1013 HPA", circle="Pressure + trend", chart="pressure"),
    "press_change": dict(col=("F_BARO", "-2.4"), l3="3H -2.4 HPA", big="3H -2.4 HPA"),
    "altitude":    dict(col=("F_MOUNT", "2240"), l3=MT + "2240 M", l1=MT + "2240 M", circle="Altitude", chart="altitude"),
    "watch_temp":  dict(col=("N_THERMO", "31\u00b0"), l3="WATCH 31\u00b0", l1="WATCH 31\u00b0", chart="temp"),
    "next_sun":    dict(l3=SUN + "18:50" + DOT + "2:27", circle="Next sun event", big=SUN + "18:50" + DOT + "2:27"),
    "sun_both":    dict(l3="7:17" + SUN2 + "18:50", big="7:17" + SUN2 + "18:50"),
    "tz2":         dict(l1="UTC+3 13:23", circle="Second time zone"),
    "zulu":        dict(l1="13:23Z"),
    "daylength":   dict(l3="DAY 11:12 -3M", big="DAY 11:12 -3M"),
    "noon":        dict(l3="NOON 12:51", l1="NOON 12:51"),
    "golden":      dict(l3="GOLD 18:12", big="GOLD 18:12"),
    "first_last":  dict(l3="FIRST 6:12", l1="FIRST 6:12"),
    "bmnt":        dict(l3="BMNT 5:41", l1="BMNT 5:41", big="BMNT 5:41"),
    "fullmoon":    dict(l3="FULL 12D", l1="FULL 12D"),
    "newmoon":     dict(col=("N_MOON", "12D"), l3="NEW MOON 12D"),
    "solstice":    dict(col=("I_SUNHZ", "73D"), l3="SOLSTICE 73D", big="SOLSTICE 73D"),
    "sun_elev":    dict(col=("I_SUNHZ", "32\u00b0"), l3="SUN 32\u00b0", l1="SUN 32\u00b0", big="SUN 32\u00b0"),
    "coords":      dict(l3="45.65N 25.60E", big="45.65N 25.60E"),
    "countdown":   dict(col=("F_WEEK", "D-12"), l3="D-12 T-21:44", big="D-12 T-21:44"),
    "date":        dict(l1=None),                     # the date: formats vary per face (DATES)
    "notif":       dict(col=("F_MAIL", "3"), value=("F_MAIL", "3"), icon="F_MAIL", circle="Notifications"),
    "seconds":     dict(l3="SEC 42", big="SEC 42"),
    "tomorrow":    dict(circle="Tomorrow"),
    "next3h":      dict(circle="Next 3 hours"),
    "wx_now":      dict(circle="Weather now"),
    "alarm":       dict(icon="S_ALARM"), "dnd": dict(icon="S_DND"), "bt": dict(icon="S_BT"),
    "phone":       dict(icon="C_PHONE"), "storm_alert": dict(icon="S_STORM"),
}
# related metrics count as the same information within an image
SAME = [{"steps", "steps_goal"}, {"hr", "hr_zone"}, {"bb", "bb_change"}, {"uv", "uv_max"}, {"pressure", "press_change", "storm_alert"},
        {"battery", "battery_days"}, {"moon", "fullmoon", "newmoon"}, {"rain_chance", "precip_next"}, {"rain_1h", "rain_day"},
        {"next_sun", "sun_both", "first_last"}, {"sun_elev", "daylight"}, {"tz2", "zulu"}]
DATES = [("TUE", "06"), ("06 OCT", None), ("OCT 06", None), ("06.10", None), ("W41 TUE", None)]
CHARTS = {  # 54 bars, realistic shapes
    "hr": [62 + 18 * max(0, math.sin((i - 12) / 6.0)) + 6 * math.sin(i / 2.3) + (i * 7 % 5) for i in range(54)],
    "pressure": [1018 - i * 0.16 + 0.6 * math.sin(i / 4.0) for i in range(54)],
    "altitude": [900 + 1300 * math.sin(min(math.pi, i / 30.0 * math.pi)) * (0.6 + 0.4 * (i < 30)) + 30 * math.sin(i) for i in range(54)],
    "solar": [max(0.0, 100 * math.sin((i - 3) / 50.0 * math.pi)) + 8 * math.sin(i / 1.7) for i in range(54)],
    "stress": [25 + 20 * abs(math.sin(i / 3.1)) + (18 if 20 < i < 27 else 0) + (i * 11 % 7) for i in range(54)],
    "bb": [92 - i * 0.9 + (14 if i > 44 else 0) + 2 * math.sin(i) for i in range(54)],
    "spo2": [96 + 1.5 * math.sin(i / 3.0) + (i * 5 % 3) * 0.5 for i in range(54)],
    "temp": [24 + 6 * math.sin((i - 10) / 54.0 * math.pi * 1.6) + 0.7 * math.sin(i) for i in range(54)],
}
RANGE = {"hr": ("152", "48"), "pressure": ("1018", "1009"), "altitude": ("2240", "880"), "solar": ("100", "0"),
         "stress": ("71", "18"), "bb": ("94", "38"), "spo2": ("99", "93"), "temp": ("31", "17")}
CIRCLES = [n for n, _ in PC.MODES]

# ---------------------------------------------------------------- assignment
use = {k: 0 for k in C}
use_form = {}
rng = random.Random(41)


def group(k):
    for g in SAME:
        if k in g:
            return g
    return {k}


BARLIKE = ("ramp", "row", "gauge")          # slots that need a 0-100 % value


def pick(form, used, extra=None):
    cands = [k for k in C if form in C[k] and not (group(k) & used) and (extra is None or extra(k))]
    if form not in BARLIKE:                   # text-like slots leave the scarce percentage metrics alone
        plain = [k for k in cands if not any(b in C[k] for b in BARLIKE)]
        cands = plain or cands
    if not cands:
        return None
    rng.shuffle(cands)
    # least shown in this kind of slot first, then least shown overall: repeats spread across forms
    k = min(cands, key=lambda k: (use_form.get((k, form), 0), use[k]))
    used |= group(k)
    use[k] += 1
    use_form[(k, form)] = use_form.get((k, form), 0) + 1
    return k


def plan_image(kinds, circles, u):
    """All four faces of one image, slot type by slot type (scarce slots first, shared fairly);
    u = metrics already used in this image."""
    faces = []
    for kind, cm in zip(kinds, circles):
        ck = [k for k in C if C[k].get("circle") == cm][0]       # reserved for the image beforehand
        faces.append(dict(kind=kind, circle=(cm, ck), rim=kind in ("chart", "big", "light-chart")))
    for f in faces:
        if f["kind"] in ("chart", "light-chart"):
            f["chart"] = pick("chart", u)
    for f in faces:                                            # line 2: few options, so early
        f["value"] = pick("value", u)
    for slot in range(3):                                      # rows / columns, one per face per round
        for f in faces:
            f.setdefault("cols" if f["rim"] else "rows", []).append(pick("col" if f["rim"] else "row", u))
    for f in faces:                                            # line-2 bar, then both gauges
        f["ramp"] = pick("ramp", u)
    for f in faces:                                            # gauges in pairs: both or none (never lopsided);
        f["gauges"] = [None, None]                             # the light face is the clean one, without gauges
        if f["kind"] == "light-chart":
            continue
        avail = [k for k in C if "gauge" in C[k] and not (group(k) & u)]
        if len(avail) - len({frozenset(group(k)) for k in avail}) < 0 or len({frozenset(group(k)) for k in avail}) < 2:
            continue
        f["gauges"] = [pick("gauge", u), pick("gauge", u)]
    for f in faces:                                            # text slots last: many text-only metrics
        if f["kind"] == "big":
            f["big"] = pick("big", u)
    for f in faces:
        f["l3"] = pick("l3", u)
    for f in faces:
        f["l1"] = pick("l1", u)
    for f in faces:
        f["icon"] = pick("icon", u)
    return faces


VARIANTS = [("chart", "Chart"), ("big", "Chart + big text"), ("rows", "Rows"), (None, "Light")]
TIMES = ["07:42", "11:05", "14:20", "18:47", "06:30", "10:15", "13:40", "20:05", "05:56", "09:30", "15:12", "21:48",
         "08:24", "12:37", "16:58", "23:16"]


# ---------------------------------------------------------------- rendering
def circle_layer(name):
    dc = Dc()
    fn = dict(PC.MODES)[name]
    fn(dc)
    pct = PC.ARC.get(name)
    if pct is not None:
        for i in range(min(30, int(pct * 30 / 100.0 + 0.5))):
            a = math.radians(i * 12 - 90)
            x, y = int(PC.CX + 28 * math.cos(a) + 0.5), int(PC.CY + 28 * math.sin(a) + 0.5)
            dc.fill(x - 1 if x > PC.CX else x, y - 1 if y > PC.CY else y, 2, 2)
    return np.asarray(dc.im.convert("L")) > 0


yy, xx = np.mgrid[0:176, 0:176]
INSIDE = ((xx - 144.5) ** 2 + (yy - 30.5) ** 2) <= 27.5 ** 2


def render_face(f, n):
    kind = f["kind"]
    rim = kind in ("chart", "big", "light-chart")
    v = dict(PV.SAMPLE)
    hh, mm = TIMES[n].split(":")
    v.update(hh=hh, mm=mm, colon=(3 if rim else 2), gaugeStyle=n % 2)
    gl, gr = f["gauges"]
    v["gaugeL"], v["stress"] = (C[gl]["gauge"] if gl else (9, 0))
    v["gaugeR"], v["bb"] = (C[gr]["gauge"] if gr else (9, 0))
    slots = {}
    ic = f["icon"]
    slots["icon"] = C[ic]["icon"] if ic else None
    l1 = f["l1"]
    if l1 == "date":
        slots["text"] = DATES[n % len(DATES)]
    else:
        slots["text"] = (C[l1]["l1"], None) if l1 else ("", None)      # nothing left: line 1 shows only the icon
    if slots["icon"] and l1 != "date" and l1:
        w = Dc().text_w(F["small"], slots["text"][0])
        if w + 17 > 73:
            slots["icon"] = None                       # as on the watch: the icon only when both fit
    val = f["value"]
    slots["value"] = C[val]["value"] if val else None              # nothing left: the number is off
    rp = f["ramp"]
    slots["ramp"] = C[rp]["ramp"] if rp else None
    slots["row3"] = ("text", C[f["l3"]]["l3"]) if f["l3"] else None
    v["slots"] = slots
    state = "raise" if (n % 4 == 0 and n >= 4) else "normal"   # wrist-raise details on two of the chart faces
    if rim:
        v["colsSpec"] = [C[k]["col"] if k else None for k in f["cols"]]
        if "chart" in f:
            v["chartSeries"] = CHARTS[C[f["chart"]]["chart"]]
            v["chartRange"] = RANGE[C[f["chart"]]["chart"]]
        else:
            v["chartOff"] = True
    else:
        v["rowsSpec"] = [C[k]["row"] if len(C[k]["row"]) == 4 else C[k]["row"] + (False,) for k in f["rows"] if k]
    im = PV.render(v, F, "rim" if rim else "rows", state)
    a = np.asarray(im.convert("L")) > 0
    a[INSIDE] = circle_layer(f["circle"][0])[INSIDE]
    im = Image.fromarray((a * 255).astype(np.uint8)).convert("1")
    if kind == "big":
        dc = Dc(); dc.im = im.convert("1"); dc.d = ImageDraw.Draw(dc.im)
        t = C[f["big"]]["big"]
        bf = F["big"] if dc.text_w(F["big"], t) <= 120 else F["small"]
        dc.text(88 - dc.text_w(bf, t) // 2, 149 if bf is F["big"] else 152, bf, t)
        im = dc.im
    if kind.startswith("light"):
        a = np.asarray(im.convert("L")) > 0
        im = Image.fromarray(((~a) & (panel_mask() > 0)).astype(np.uint8) * 255).convert("1")
    return im


def disc(im, size):
    w = on_watch(im, 4)
    W, H = w.size
    s = int(min(W, H) * 0.88)
    w = w.crop(((W - s) // 2, (H - s) // 2, (W + s) // 2, (H + s) // 2)).resize((size, size), Image.LANCZOS)
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).ellipse((0, 0, size - 1, size - 1), fill=255)
    return w, m


font_dir = os.environ.get("SAIRA_FONT_DIR", "/tmp/fonts")
BG, INK = (231, 230, 226), (34, 34, 34)


def main():
    """The previous metric-variety images (store/versatility-1..4.png)."""
    images = []
    order = list(range(16))
    for img in range(4):
        used_img = set()
        circles = [CIRCLES[(img * 4 + j) % len(CIRCLES)] for j in range(4)]   # 15 views for 16 faces
        for cm in circles:                                  # the image's four circles first
            ck = [k for k in C if C[k].get("circle") == cm][0]
            used_img |= group(ck)
            use[ck] += 1
        kinds = [k if k else "light-chart" for k, _ in VARIANTS]
        faces = plan_image(kinds, circles, used_img)
        images.append([(VARIANTS[j][1], faces[j], img * 4 + j) for j in range(4)])
    # within-image check, and the repeats across images
    for img, faces in enumerate(images):
        seen = []
        for _, f, _ in faces:
            keys = [v for kk, v in f.items() if kk in ("chart", "big", "l3", "l1", "value", "ramp", "icon") and v] + \
                   [x for x in f.get("cols", []) + f.get("rows", []) + f["gauges"] if x] + [f["circle"][1]]
            seen += [frozenset(group(k)) for k in keys]
        dup = {s for s in seen if seen.count(s) > 1}
        assert not dup, f"image {img + 1} repeats {dup}"
    shown = {k for k in use if use[k]}
    print(f"metrics shown: {len(shown)} of {len(C)} | used once: {sum(1 for k in use if use[k] == 1)} | "
          f"repeated across images: {sorted((k, v) for k, v in use.items() if v > 1)}")
    print("never shown:", sorted(k for k in use if not use[k]))
    print("same metric in the same slot type more than once:", sorted((k, f, n) for (k, f), n in use_form.items() if n > 1))
    cap = ImageFont.truetype(os.path.join(font_dir, "SairaSemiCondensed-Bold.ttf"), 34)
    hidden = []
    for img, faces in enumerate(images):
        out = Image.new("RGB", (1440, 1440), BG)
        d = ImageDraw.Draw(out)
        for j, (label, f, n) in enumerate(faces):
            im = render_face(f, n)
            a = np.asarray(im.convert("L")) > 0
            hidden.append(int((a & ~(panel_mask() > 0)).sum()))
            w, m = disc(im, 600)
            cx, cy = (j % 2) * 720, (j // 2) * 720
            out.paste(w, (cx + 60, cy + 40), m)
            tw = d.textlength(label.upper(), font=cap)
            d.text((cx + 360 - tw / 2, cy + 654), label.upper(), font=cap, fill=INK)
        # 64-colour palette: visually identical for these flat images, and well under 150 KB
        out.quantize(colors=64, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).save(
            os.path.join(OUT, f"versatility-{img + 1}.png"), optimize=True)
    print("pixels outside the panel per face:", hidden)


if __name__ == "__main__":
    main()
