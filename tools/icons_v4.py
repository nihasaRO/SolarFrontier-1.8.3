"""Build 2 icons for the circle modes (supersampled, thresholded to 1-bit)."""
import wx_icons as WI


def i_drop(h):
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


def checker(w, h):
    return [[(x + y) % 2 == 0 for x in range(w)] for y in range(h)]


ICONS_V4 = {"C_DROP": i_drop(14), "C_DROPS": i_drop(13), "C_MOUNT": i_mountain(), "C_MAIL": i_envelope(),
            "M_D6": checker(6, 7), "M_D13": checker(13, 7)}
