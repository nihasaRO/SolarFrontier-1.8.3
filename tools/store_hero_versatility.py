"""Hero image (1440 x 720) with the face's real numbers, counted from the option lists:
76 metrics (31 weather, 20 outdoors = sun & moon + tactical, 21 health & activity, 4 watch),
16 circle views, 8 chart sources, 2 layouts, 16 slots, 660 options.
Faces are taken from store/versatility-*.png (run tools/store_versatility.py first).
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

TOOLS = os.path.dirname(os.path.abspath(__file__))
STORE = os.path.join(os.path.dirname(TOOLS), "store")
FONTS = os.environ.get("SAIRA_FONT_DIR", "/tmp/fonts")
BG, INK, ORANGE, MUTED = (231, 230, 226), (28, 28, 28), (222, 92, 36), (90, 90, 90)


def font(weight, size):
    return ImageFont.truetype(os.path.join(FONTS, f"SairaSemiCondensed-{weight}.ttf"), size)


def face(image_no, position, size):
    """One watch disc from a versatility image (2 x 2 grid of 600 px discs at +60, +40 in 720 px cells)."""
    im = Image.open(os.path.join(STORE, f"versatility-{image_no}.png")).convert("RGB")
    x, y = (position % 2) * 720 + 60, (position // 2) * 720 + 40
    disc = im.crop((x, y, x + 600, y + 600)).resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    return disc, mask


out = Image.new("RGB", (1440, 720), BG)
# three faces in a row, each overlapping only the right edge (gauge column) of the one before:
# rows, chart with big text, light chart
for (img, pos, size, x, y) in ((4, 2, 360, 0, 120), (2, 1, 360, 205, 240), (1, 3, 360, 410, 120)):
    disc, mask = face(img, pos, size)
    shadow = Image.new("L", out.size, 0)
    ImageDraw.Draw(shadow).ellipse((x + 8, y + 14, x + size + 8, y + size + 14), fill=90)
    out = Image.composite(Image.new("RGB", out.size, (30, 30, 30)), out, shadow.filter(ImageFilter.GaussianBlur(14)))
    out.paste(disc, (x, y), mask)

d = ImageDraw.Draw(out)
X = 800
d.text((X, 70), "76 METRICS.", font=font("ExtraBold", 76), fill=INK)
d.text((X, 150), "YOUR WAY.", font=font("ExtraBold", 76), fill=ORANGE)
d.text((X, 252), "16 slots  \u00b7  660 options  \u00b7  billions of combinations", font=font("SemiBold", 30), fill=MUTED)

stats = [("31", "WEATHER"), ("20", "OUTDOORS"), ("21", "HEALTH &\nACTIVITY"),
         ("15", "CIRCLE\nVIEWS"), ("8", "CHARTS"), ("2", "LAYOUTS")]
big, small = font("ExtraBold", 84), font("Bold", 25)
for i, (num, label) in enumerate(stats):
    cx, cy = X + (i % 3) * 205, 310 + (i // 3) * 178
    d.text((cx, cy), num, font=big, fill=ORANGE)
    d.multiline_text((cx + 2, cy + 94), label, font=small, fill=INK, spacing=2)
d.line((X, 668, 1400, 668), fill=(200, 199, 195), width=2)
d.text((X, 676), "SOLAR FRONTIER  \u00b7  GARMIN INSTINCT 3 SOLAR", font=font("Bold", 22), fill=MUTED)
# 64-colour palette: visually identical for this flat image, and well under 150 KB
out.quantize(colors=64, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).save(
    os.path.join(STORE, "hero-versatility-1440x720.png"), optimize=True)
print("written", out.size)
