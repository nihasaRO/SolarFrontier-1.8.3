"""Bold subscreen weather icons (v3). Drawn at 8x and thresholded to 1-bit."""
import math
from PIL import Image, ImageDraw

SS = 8


def canvas(w, h):
    im = Image.new("L", (w * SS, h * SS), 0)
    return im, ImageDraw.Draw(im)


def finish(im, w, h, thr=128):
    small = im.resize((w, h), Image.BOX)
    return [[small.getpixel((x, y)) >= thr for x in range(w)] for y in range(h)]


def S(v):
    return v * SS


def disc(d, cx, cy, r, fill=255):
    d.ellipse((S(cx - r), S(cy - r), S(cx + r), S(cy + r)), fill=fill)


def ring(d, cx, cy, r, width, fill=255):
    d.ellipse((S(cx - r), S(cy - r), S(cx + r), S(cy + r)), outline=fill, width=int(S(width)))


def thick_line(d, x0, y0, x1, y1, width, fill=255):
    d.line((S(x0), S(y0), S(x1), S(y1)), fill=fill, width=int(S(width)))
    for (x, y) in ((x0, y0), (x1, y1)):
        disc(d, x, y, width / 2.0, fill)


def rays(d, cx, cy, r0, r1, width, angles, fill=255):
    for a in angles:
        t = math.radians(a)
        thick_line(d, cx + r0 * math.cos(t), cy + r0 * math.sin(t),
                   cx + r1 * math.cos(t), cy + r1 * math.sin(t), width, fill)


def cloud(d, ox, oy, sc=1.0, fill=255):
    """Filled cloud, about 28 x 17 at sc=1, top-left at (ox, oy)."""
    disc(d, ox + 8 * sc, oy + 10.5 * sc, 6.5 * sc, fill)
    disc(d, ox + 15.5 * sc, oy + 7.7 * sc, 7.3 * sc, fill)
    disc(d, ox + 22 * sc, oy + 11 * sc, 5.8 * sc, fill)
    d.rounded_rectangle((S(ox + 2 * sc), S(oy + 10 * sc), S(ox + 27.5 * sc), S(oy + 17 * sc)),
                        radius=S(3.5 * sc), fill=fill)


def w_sun():
    w, h = 23, 23
    im, d = canvas(w, h)
    disc(d, 11.5, 11.5, 5.6)
    rays(d, 11.5, 11.5, 8.2, 10.6, 2.0, range(0, 360, 45))
    return finish(im, w, h)


def w_moon():
    w, h = 20, 20
    im, d = canvas(w, h)
    disc(d, 10, 10.5, 9)
    disc(d, 15, 6, 8, 0)
    return finish(im, w, h)


def w_partly():
    w, h = 29, 22
    im, d = canvas(w, h)
    ring(d, 9, 9, 4.6, 2.0)
    rays(d, 9, 9, 7.0, 9.0, 1.8, (180, 225, 270, 315, 0, 135))
    cloud(d, 3.0, 6.0, 0.92, 0)            # cut a gap around the cloud
    d.rectangle((S(4), S(19), S(29), S(22)), fill=0)
    cloud(d, 4.5, 7.0, 0.85)
    return finish(im, w, h)


def w_cloud():
    w, h = 29, 18
    im, d = canvas(w, h)
    cloud(d, 0.5, 0.5)
    return finish(im, w, h)


def cloud_top(d):
    cloud(d, 0.5, 0.0, 0.92)


def w_rain():
    w, h = 27, 23
    im, d = canvas(w, h)
    cloud_top(d)
    for x in (7, 12.5, 18):
        thick_line(d, x + 1.6, 18.2, x - 0.6, 21.8, 2.0)
    return finish(im, w, h)


def w_snow():
    w, h = 27, 23
    im, d = canvas(w, h)
    cloud_top(d)
    for x, y in ((7.5, 19.5), (13.5, 21.0), (19.5, 19.5)):
        thick_line(d, x - 1.8, y, x + 1.8, y, 1.2)
        thick_line(d, x, y - 1.8, x, y + 1.8, 1.2)
    return finish(im, w, h)


def w_storm():
    w, h = 27, 24
    im, d = canvas(w, h)
    cloud_top(d)
    bolt = [(15.5, 12.5), (9.5, 19.0), (13.2, 19.0), (10.5, 24.0), (18.0, 16.2), (14.2, 16.2), (17.0, 12.5)]
    big = [(x * SS, y * SS) for x, y in bolt]
    # gap around the bolt, then the bolt
    d.polygon([(x + dx, y + dy) for x, y in big for dx, dy in [(0, 0)]], fill=0)
    d.line(big + [big[0]], fill=0, width=int(SS * 2.4))
    d.polygon(big, fill=255)
    return finish(im, w, h)


def w_fog():
    w, h = 27, 19
    im, d = canvas(w, h)
    for y, x0, x1 in ((2, 4, 23), (7.5, 1.5, 25.5), (13, 3, 21), (17.5, 7, 25)):
        thick_line(d, x0, y, x1, y, 2.4)
    return finish(im, w, h)


def w_wind():
    w, h = 27, 20
    im, d = canvas(w, h)
    thick_line(d, 1.5, 7.5, 18.0, 7.5, 2.2)
    d.arc((S(14.6), S(1.1), S(21.4), S(7.9)), 180, 90, fill=255, width=int(S(2.2)))
    thick_line(d, 1.5, 12.8, 25.0, 12.8, 2.2)
    thick_line(d, 5.0, 18.0, 18.0, 18.0, 2.2)
    return finish(im, w, h)


WX = {
    "W_SUN": w_sun, "W_MOON": w_moon, "W_PARTLY": w_partly, "W_CLOUD": w_cloud,
    "W_RAIN": w_rain, "W_SNOW": w_snow, "W_STORM": w_storm, "W_FOG": w_fog, "W_WIND": w_wind,
}
