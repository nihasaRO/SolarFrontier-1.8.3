"""Rim face: regenerates fonts (incl. the 15 px data font), the icon font, source/Ic.mc and the
JSON resources (rim gauge geometry with piece counts, settings-menu text).
Put SairaSemiCondensed-Bold.ttf and -ExtraBold.ttf in tools/fonts/ (or set SAIRA_FONT_DIR), then run:
    python3 tools/make_project.py
"""
import os, sys, json, re
from xml.sax.saxutils import escape
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import assets

TOOLS = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(TOOLS)
fonts = assets.all_fonts()
fdir = os.path.join(PROJ, "resources", "fonts")
for key, name in (("small", "small"), ("big", "big"), ("mid", "mid"), ("med", "med"), ("time", "time"),
                  ("timeo", "time_outline"), ("data", "data"), ("tiny", "tiny")):
    # a Modified Version of Saira Semi Condensed (OFL): it may not use the Reserved Font Name "Saira"
    assets.write_bmfont(fonts[key], name, fdir, "Solar Frontier Pixel " + name)
assets.write_icon_font(fdir, "icons")
# which icon goes with which option (None = no icon); index = option index
ICON_TABLES = {
    "ROW": ["I_STEPS", "I_RUN", "I_HEART", "I_BOLT", "F_ZIG", "F_STAIRS", "F_BATT", "G_SOLAR", "G_MOVE", "I_SUNHZ", None,
            "F_DROP", "N_UMBRELLA", "N_CLOUD", "N_MOON", "N_UV", "I_RUN", "N_AIR"],
    "RAMP": [None, "F_BATT", "I_BOLT", "F_ZIG", "I_STEPS", "I_RUN", "I_HEART", None,
             "F_DROP", "N_UMBRELLA", "N_CLOUD", "N_MOON", "N_UV", "I_RUN", "N_AIR"],
    "GAUGE": ["G_STRESS", "I_BOLT", "G_BATT", "G_SOLAR", "G_STEPS", "G_INT", "G_FLOORS", "G_MOVE", "G_DAY", None,
              "F_DROP", "N_UMBRELLA", "N_CLOUD", "N_MOON", "N_UV", "G_INT", "N_AIR"],
    "FIELD": ["I_STEPS", "I_RUN", "F_WEEK", "F_FLAME", "F_DIST", "F_STAIRS", "F_MOUNT", "F_BARO", "F_MAIL", "F_BATT", "I_BOLT", "F_ZIG"],
    "COL": [None, "N_UMBRELLA", "F_DROP", "N_THERMO", "N_DEW", "N_THERMO", "N_HEART_O", "N_LUNGS", "F_MOUNT", "N_STAIRS_D",
            "F_WEEK", "N_GUST", "N_CLOUD", "N_EYE", "N_RAIN", None, "N_UV", "N_MOON", "I_STEPS", "N_THERMO", "F_BARO", "N_MOON", "I_SUNHZ",
            "N_UMBRELLA", "N_AIR", "I_BOLT", "I_SUNHZ",
            "N_UV", "N_RAIN", "S_STORM", "N_POLLEN", "N_FREEZE", "N_SNOW", "N_STAIRS_D", "N_GUST"],
}
assets.emit_icon_module(os.path.join(PROJ, "source", "Ic.mc"), ICON_TABLES)
print("time ink:", assets.time_ink_module(fonts["time"], os.path.join(PROJ, "source", "TimeInk.mc")))
jdir = os.path.join(PROJ, "resources", "jsonData")
os.makedirs(jdir, exist_ok=True)
text = json.load(open(os.path.join(TOOLS, "settings_text.json")))


def display_order(i):
    """Positions of the options of setting i in the order they are shown (stored values unchanged):
    long lists by theme, the update interval by minutes, everything else as stored."""
    title, opts = text["t"][i], text["o"][i]
    if title in text["sorted"]:
        rank = {lab: r for r, lab in enumerate(text["order"])}
        return sorted(range(len(opts)), key=lambda j: (rank.get(opts[j], 999), j))
    if title == "Update every":
        return sorted(range(len(opts)), key=lambda j: int(opts[j].split()[0]))
    return list(range(len(opts)))
# Menu texts in small pieces: each option list is split into chunks of CHUNK options, so the watch never has to
# find one large block of memory for a list (memory is fragmented while the settings menu is open). Identical
# lists (the three columns, line 3 and big text, both gauges, the three rows) share their chunks. A list chunk is
# one text: per option the stored value (two digits), the label's length (two digits), then the label; the watch
# steps over these lengths (no searching). Countdown day / year / time are computed on the watch ("day" ...).
CHUNK = 16
lists, list_of, idx = [], {}, []
for i, (title, opts) in enumerate(zip(text["t"], text["o"])):
    spec = {"Countdown day": "day", "Countdown year": "year", "Countdown time": "time"}.get(title)
    if spec:
        pieces = (spec,)
    else:
        assert len(opts) <= 100 and all(0 < len(o) <= 99 and o.isascii() for o in opts)
        order = display_order(i)
        entries = ["%02d%02d" % (j, len(opts[j])) + opts[j] for j in order]
        pieces = tuple("".join(entries[k:k + CHUNK]) for k in range(0, len(entries), CHUNK))
    if pieces not in list_of:
        list_of[pieces] = len(lists)
        lists.append(pieces)
    idx.append(list_of[pieces])
assert len(lists) < 100
# small single-chunk lists (up to SMALL characters) go into one shared resource
SMALL = 130
small = [c for c, pieces in enumerate(lists) if len(pieces) == 1 and len(pieces[0]) <= SMALL]
small_of = {c: k for k, c in enumerate(small)}
big = [c for c in range(len(lists)) if c not in small_of]
big_of = {c: k for k, c in enumerate(big)}
with open(os.path.join(jdir, "jsonData.xml"), "w", newline="\n") as fh:
    fh.write("<resources>\n")
    # one resource per larger list (an array of its chunks); the small single-chunk lists are kept together in
    # one resource "S" (an array of lists), so the code needs one resource reference for all of them
    for c, pieces in enumerate(lists):
        if c not in small_of:
            fh.write(f'    <jsonData id="L{c}">{escape(json.dumps(list(pieces), separators=(",", ":")))}</jsonData>\n')
    fh.write(f'    <jsonData id="S">{escape(json.dumps([list(lists[c]) for c in small], separators=(",", ":")))}</jsonData>\n')
    fh.write(f'    <jsonData id="T">{escape(json.dumps(text["t"], separators=(",", ":")))}</jsonData>\n')
    fh.write(f'    <jsonData id="G">{escape(json.dumps(text["g"], separators=(",", ":")))}</jsonData>\n')
    fh.write("</resources>\n")
n = len(text["t"])
assert CHUNK == 16, "the watch menu reads 16 options per chunk"
with open(os.path.join(PROJ, "source", "SetText.mc"), "w", newline="\n") as fh:
    fh.write("// Generated by tools/make_project.py: the settings menu's texts, as lists of small chunks (16 options each).\n")
    fh.write("import Toybox.Lang;\nimport Toybox.WatchUi;\n\nmodule SetText {\n")
    fh.write("    const IDS = [ " + ", ".join(f"Rez.JsonData.L{c}" for c in big) + " ];\n")
    # the list of each setting (identical lists shared): below 100 an entry of IDS, from 100 an entry of S
    fh.write("    const IDX = [ " + ", ".join(str(100 + small_of[a] if a in small_of else big_of[a]) for a in idx) + " ]b;\n\n")
    fh.write("    // setting i's options: an array of chunks (a computed list like \"day\" is one chunk)\n")
    fh.write("    function list(i) as Lang.Array {\n        var x = IDX[i];\n        return ((x < 100) ? WatchUi.loadResource(IDS[x]) : (WatchUi.loadResource(Rez.JsonData.S) as Lang.Array)[x - 100]) as Lang.Array;\n    }\n\n")
    fh.write("    function title(i) as Lang.String {\n        return (WatchUi.loadResource(Rez.JsonData.T) as Lang.Array)[i] as Lang.String;\n    }\n\n")
    fh.write("    function group(g) as Lang.String {\n        return (WatchUi.loadResource(Rez.JsonData.G) as Lang.Array)[g] as Lang.String;\n    }\n}\n")
chunk_texts = [c for pieces in lists for c in pieces]
print("menu texts:", len(lists), "lists in", len(chunk_texts), "chunks, largest", max(len(c) for c in chunk_texts), "characters")

# ---- phone settings (Garmin Connect app): properties with defaults, the setting list, its strings
cfg_src = open(os.path.join(PROJ, "source", "Settings.mc")).read()
keys = [f"k{i}" for i in range(len(text["t"]))]          # storage names are computed on the watch: "k" + index
defaults = list(map(int, re.findall(r"\d+", re.search(r"DEFAULTS = \[(.*?)\]b?;", cfg_src, re.S).group(1))))
group_titles = text["g"]
groups = [list(map(int, re.findall(r"\d+", grp))) for grp in re.findall(r"\[([^\[\]]*)\]", re.search(r"GROUPS = \[(.*)\];", cfg_src, re.S).group(1))]
order = [i for grp in groups for i in grp]
section = {i: group_titles[k] for k, grp in enumerate(groups) for i in grp}
assert sorted(order) == list(range(len(keys))) == list(range(len(text["t"])))
sdir = os.path.join(PROJ, "resources", "settings")
os.makedirs(sdir, exist_ok=True)
with open(os.path.join(sdir, "properties.xml"), "w", newline="\n") as fh:
    fh.write("<properties>\n")
    for k, d in zip(keys, defaults):
        fh.write(f'    <property id="{k}" type="number">{d}</property>\n')
    fh.write('</properties>\n')
strings = []
with open(os.path.join(sdir, "settings.xml"), "w", newline="\n") as fh:
    fh.write("<settings>\n")
    for i in order:
        title = section[i] + ": " + text["t"][i]
        strings.append((f"st{i}", title))
        fh.write(f'    <setting propertyKey="@Properties.{keys[i]}" title="@Strings.st{i}">\n')
        fh.write('        <settingConfig type="list">\n')
        for j in display_order(i):              # same order as the watch; value = the stored option
            strings.append((f"so{i}_{j}", text["o"][i][j]))
            fh.write(f'            <listEntry value="{j}">@Strings.so{i}_{j}</listEntry>\n')
        fh.write("        </settingConfig>\n    </setting>\n")
    fh.write("</settings>\n")
with open(os.path.join(sdir, "strings.xml"), "w", newline="\n") as fh:
    fh.write("<strings>\n")
    for sid, val in strings:
        # scope="settings": used only by the Garmin Connect app, removed from the watch's runtime memory
        fh.write(f'    <string id="{sid}" scope="settings">{escape(val)}</string>\n')
    fh.write("</strings>\n")
print("phone settings:", len(order), "settings |", len(strings), "strings")
import xml.dom.minidom
for root, _, files in os.walk(os.path.join(PROJ, "resources")):
    for f in files:
        if f.endswith(".xml"):
            xml.dom.minidom.parse(os.path.join(root, f))     # raises on any invalid XML
print("all resource XML files validated")
print("written")
