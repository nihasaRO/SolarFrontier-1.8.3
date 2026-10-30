"""Regenerates the Connect IQ Store images in store/, showing a range of combinations:
cover (app icon) with both gauge styles, hero image, and eight varied screenshots.
Circle modes other than weather come from tools/circle_modes/*.png.
Run: python3 tools/store_assets.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import assets
import preview as PV
from preview2 import on_watch, panel_mask

TOOLS = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(TOOLS), "store")
F = assets.all_fonts()
os.makedirs(OUT, exist_ok=True)
yy, xx = np.mgrid[0:176, 0:176]
INSIDE = ((xx - 144.5) ** 2 + (yy - 30.5) ** 2) <= 31 ** 2


def face(v, layout="rows", state="normal", circle=None):
    """The face pixels; `circle` swaps the weather circle for another mode (dark theme)."""
    im = PV.render(v, F, layout, state)
    if circle:
        a = np.asarray(im.convert("L")) > 0
        c = np.asarray(Image.open(os.path.join(TOOLS, "circle_modes", circle + ".png")).convert("L")) > 0
        a[INSIDE] = c[INSIDE]
        im = Image.fromarray((a * 255).astype(np.uint8)).convert("1")
    return im


def disc(im, size, crop=0.88):
    w = on_watch(im, 4)
    W, H = w.size
    s = int(min(W, H) * crop)
    w = w.crop(((W - s) // 2, (H - s) // 2, (W + s) // 2, (H + s) // 2)).resize((size, size), Image.LANCZOS)
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).ellipse((0, 0, size - 1, size - 1), fill=255)
    return w, m


S = PV.SAMPLE
ROWS_BLOCKS = face(dict(S, gaugeStyle=1, colon=2,
                       rowsSpec=[("I_STEPS", "12.5K", 125, False), ("I_BOLT", "64", 64, False), ("F_ZIG", "28", 28, False)],
                       slots=dict(icon="S_ALARM", text=("13:23Z", None), value=("I_BOLT", "64"), ramp=("I_BOLT", 6),
                                  row3=("text", "BMNT 5:41"))), "rows", circle="hr")
CHART_BAR = face(dict(S, colon=3, colsSpec=[(("ARROW", 300), "14"), ("F_DROP", "64%"), ("N_THERMO", "18\u00b0")]), "rim")

# ---- cover (app icon): 500 x 500, solid background, 10 px padding, no text; both gauge styles
for bg, suffix in (((231, 230, 226), ""), ((226, 96, 40), "-orange")):
    out = Image.new("RGB", (500, 500), bg)
    back, bm = disc(ROWS_BLOCKS, 330)
    front, fm = disc(CHART_BAR, 330)
    out.paste(back, (10, 10), bm)
    shadow = Image.new("L", (500, 500), 0)
    ImageDraw.Draw(shadow).ellipse((156, 156, 494, 494), fill=110)
    out = Image.composite(Image.new("RGB", (500, 500), (20, 20, 20)), out, shadow.filter(ImageFilter.GaussianBlur(10)))
    out.paste(front, (160, 160), fm)
    out.save(os.path.join(OUT, f"app-icon-500{suffix}.png"), optimize=True)

# ---- hero: 1440 x 720, both gauge styles
W, H = 1440, 720
hero = Image.new("RGB", (W, H), (17, 18, 19))
glow = Image.new("L", (W, H), 0); ImageDraw.Draw(glow).ellipse((700, 30, 1440, 710), fill=70)
hero = Image.composite(Image.new("RGB", (W, H), (40, 42, 44)), hero, glow.filter(ImageFilter.GaussianBlur(120)))
back, bm = disc(face(dict(S, gaugeStyle=1, colon=1, slots=dict(icon="S_STORM", row3=("text", "D-12 T-21:44")),
                       rowsSpec=[("F_STAIRS", "7", 70, False), ("I_BOLT", "64", 64, False), ("I_HEART", "92", 1, True)]),
                  "rows", circle="moon"), 430)
front, fm = disc(CHART_BAR, 500)
shadow = Image.new("L", (W, H), 0); ImageDraw.Draw(shadow).ellipse((930, 120, 1430, 620), fill=160)
hero.paste(back, (735, 170), bm)
hero = Image.composite(Image.new("RGB", (W, H), (8, 8, 9)), hero, shadow.filter(ImageFilter.GaussianBlur(18)).point(lambda p: p // 2))
hero.paste(front, (925, 110), fm)
d = ImageDraw.Draw(hero)
fd = assets.FONT_DIR
d.text((80, 200), "SOLAR", font=ImageFont.truetype(os.path.join(fd, "SairaSemiCondensed-ExtraBold.ttf"), 96), fill=(236, 236, 230))
d.text((80, 298), "FRONTIER", font=ImageFont.truetype(os.path.join(fd, "SairaSemiCondensed-ExtraBold.ttf"), 96), fill=(236, 236, 230))
d.rectangle((84, 420, 204, 426), fill=(226, 96, 40))
sub = ImageFont.truetype(os.path.join(fd, "SairaSemiCondensed-SemiBold.ttf"), 34)
small = ImageFont.truetype(os.path.join(fd, "SairaSemiCondensed-SemiBold.ttf"), 26)
d.text((80, 450), "Tactical watch face for the", font=sub, fill=(190, 190, 184))
d.text((80, 490), "Instinct 3 Solar", font=sub, fill=(190, 190, 184))
d.text((80, 570), "Health, weather and tactical data", font=small, fill=(140, 140, 134))
d.text((80, 606), "Two layouts  ·  two gauge styles  ·  everything optional", font=small, fill=(140, 140, 134))
hero.save(os.path.join(OUT, "hero-1440x720.jpg"), quality=88, optimize=True)
hero.quantize(colors=128, method=Image.MEDIANCUT).save(os.path.join(OUT, "hero-1440x720-small.png"), optimize=True)

# ---- screenshots: every one shows different rows, columns, line 3, circle and options
SHOTS = [
    ("01-chart-wind-humidity-bmnt", "Chart, bar gauges; default top lines; wind / humidity / feels-like; BMNT",
     face(dict(S, colon=3, colsSpec=[(("ARROW", 300), "14"), ("F_DROP", "64%"), ("N_THERMO", "18\u00b0")],
               slots=dict(row3=("text", "BMNT 5:41"))), "rim")),
    ("02-rows-countdown-intensity-today", "Rows, block gauges; alarm + Zulu time, Body Battery bar, countdown; daily intensity row",
     face(dict(S, gaugeStyle=1, colon=2,
               rowsSpec=[("I_STEPS", "12.5K", 125, False), ("I_RUN", "22", 73, False), ("F_ZIG", "28", 28, False)],
               slots=dict(icon="S_ALARM", text=("13:23Z", None), value=("I_BOLT", "64"), ramp=("I_BOLT", 6),
                          row3=("text", "D-12 T-21:44"))), "rows", circle="hr")),
    ("03-chart-health-new-moon", "Chart, block gauges; Do Not Disturb + date, resting HR + intensity-today bar, new moon",
     face(dict(S, gaugeStyle=1, colon=1, colsSpec=[("N_HEART_O", "52"), ("N_LUNGS", "14"), ("F_MOUNT", "312")],
               slots=dict(icon="S_DND", text=("06 OCT", None), value=("N_HEART_O", "52"), ramp=("I_RUN", 7),
                          row3=("text", "NEW MOON 12D"))), "rim", circle="moon")),
    ("04-rows-storm-risk", "Rows, bar gauges; storm alert + week, stress bar, thunderstorm risk; floors / move / daylight",
     face(dict(S, colon=0, rowsSpec=[("F_STAIRS", "7", 70, False), ("G_MOVE", "2", 40, False), ("I_SUNHZ", "3:12", 27, False)],
               slots=dict(icon="S_STORM", text=("W41 TUE", None), value=("F_ZIG", "28"), ramp=("F_ZIG", 3),
                          row3=("text", "STORM HIGH"))), "rows", circle="wind")),
    ("05-chart-wrist-raise-weather", "Chart on wrist raise; Bluetooth + date, battery days + battery bar, day length; UV max / rain today / freezing level",
     face(dict(S, colon=3, colsSpec=[("N_UV", "8"), ("N_RAIN", "12"), ("N_FREEZE", "2400")],
               slots=dict(icon="S_BT", text=("OCT 06", None), value=("F_BATT", "41D"), ramp=("F_BATT", 10),
                          row3=("text", "DAY 11:12 -3M"))), "rim", "raise", circle="dual")),
    ("06-rows-wrist-raise-solstice", "Rows on wrist raise; notifications + date, heart rate + zone bar, days to solstice",
     face(dict(S, gaugeStyle=1, colon=2,
               slots=dict(icon="F_MAIL", text=("06.10", None), value=("I_HEART", "92"), ramp=("I_HEART", 2),
                          row3=("text", "SOLSTICE 73D"))), "rows", "raise", circle="sun")),
    ("07-light-theme-pollen", "Light theme; phone + date, notifications + steps-goal bar, pollen; humidity / air quality / rain chance bars",
     face(dict(S, colon=1, rowsSpec=[("F_DROP", "64%", 64, False), ("N_AIR", "2", 25, False), ("N_UMBRELLA", "40%", 40, False)],
               slots=dict(icon="C_PHONE", value=("F_MAIL", "3"), ramp=("I_STEPS", 8), row3=("text", "GRASS HIGH"))), "rows", "light")),
    ("08-chart-minimal", "Everything can be switched off: no icon, gauges, circle, bar or line 3; steps to goal / watch temperature / new snow",
     face(dict(S, gaugeL=9, gaugeR=9, colon=2, circleOff=True, colsSpec=[("I_STEPS", "-4327"), ("N_THERMO", "31\u00b0"), ("N_SNOW", "4.5")],
               slots=dict(icon=None, text=("WED", "28"), ramp=None, row3=None)), "rim")),
]
shots = [(name, im) for name, _, im in SHOTS]
mask = panel_mask() > 0
for f in os.listdir(OUT):
    if f.startswith(("screenshot-", "native-")):
        os.remove(os.path.join(OUT, f))
for name, im in shots:
    on_watch(im, 3).save(os.path.join(OUT, f"screenshot-{name}.png"))
    a = (np.asarray(im.convert("L")) > 0) & mask
    native = Image.fromarray((a * 255).astype(np.uint8))
    native.save(os.path.join(OUT, f"native-{name}-176.png"))
    native.resize((528, 528), Image.NEAREST).save(os.path.join(OUT, f"native-{name}-528.png"))
for f in ("app-icon-500-chart.png", "app-icon-500-chart-orange.png", "app-icon-500-rows.png", "app-icon-500-rows-orange.png"):
    if os.path.exists(os.path.join(OUT, f)):
        os.remove(os.path.join(OUT, f))
print("store assets written to", OUT)
