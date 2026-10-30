# Solar Frontier (Instinct 3 Solar)

A watch face for the Instinct 3 Solar's 176 × 176, 1-bit MIP screen, fitted to the real visible panel. Two layouts in one app, chosen with the **Layout** setting: **Rows** (three progress rows) and **Chart** (three columns and a chart). `preview.png` shows both layouts in three states (normal, wrist raise, light theme); `preview-top.png` six top-slot combinations; `store/` the store images (cover, hero, eight screenshots).

## Shared by both layouts

Circle (16 modes, default weather) · top block: moon (or phone / notifications / nothing) and the date with a larger day number, battery and the solar signal ramp, the next sunrise or sunset with the time until it · time with hours solid and minutes dithered / solid / outlined, and an optional colon.

- **Colon on the centre line.** The colon sits exactly on x 88, the face's centre, shared with the Chart layout's middle column and chart. Digits are placed by their ink (`source/TimeInk.mc`), so the gaps on both sides of the colon are equal.
- **Dotted arc.** Inside the circle, a run of dots shows a second value clockwise from the top (only filled dots are drawn): rain chance (Weather now), the current temperature between today's low and high, wind 0–50 km/h, heart rate between resting and max, the second time zone's progress through its day, daylight left, the lunar cycle, pressure 950–1050 hPa. No arc where a mode already shows the value or has its own ring.
- **Wrist raise.** For the few seconds after a wrist raise (when the watch redraws every second anyway): Rows show % of goal and the heart-rate zone; Chart shows the exact gauge values just below the time, next to each gauge.
- **Over goal and no data.** Above 100% of a goal, the last bar cell becomes an arrowhead, and a side gauge gets a small arrow on top. Missing data in the rows shows as a hairline, never as 0%.
- **Unified icons** on one 11 px grid (steps, runner, heart, bolt, stress, sunrise).

## Layout: Rows (default)

Three progress rows: icon, bar, value. Percentages use 10 cells (10% each), heart rate uses 5 cells (your training zones). Solid cells are done, dithered cells remain.

## Layout: Chart

Three columns with 15 px values (steps above 9,999 show as 15.0K) and a chart along the bottom: heart rate, stress, Body Battery, pressure, altitude, watch temperature, Pulse Ox or solar, over 1 or 4 hours. The column font and the solar history load only while Chart is selected. "Chart shows: Big text" replaces the chart with one line-3 metric in an 18 px font (chosen in "Big text shows"; the small font is used if a text is wider than 120 px).

## Side gauges (both layouts)

Two vertical gauges on the screen edges, filling from the bottom, with ticks at 25, 50 and 75% and the metric's glyph on top. **Gauge style**: Bar (a solid fill on a thin track, Enduro style) or Blocks (12 square blocks). Each side can show stress, Body Battery, watch battery, solar, steps goal, intensity goal, floors goal, move bar, daylight left, or be off. Above 100% of a goal, a small arrow tops the gauge.

## Settings

Same order on the watch (hold MENU > Watch Face > Customize > Settings) and in the Garmin Connect app. Long option lists are grouped by theme (activity, health, weather, sun and moon, tactical and time, watch); units and limits are in the option names. The default is in bold.

**Layout & theme**

| Setting | Options |
|---|---|
| Layout | **Rows**, Chart |
| Theme | **Dark**, Light |
| Wrist raise detail | **Rows+gauges+chart**, Gauges+chart, Rows+chart, Chart only, Rows+gauges, Gauges only, Rows only, Off |

**Top rows**

| Setting | Options |
|---|---|
| Line 1 icon | **Moon**, Phone, Notifications, None, Alarm, Do Not Disturb, Bluetooth, Pressure drop |
| Line 1 text | **Date**, Steps, Steps to goal, Breaths/minute, BB change last 2h, Temp high/low, Feels like temp, Dew point temp, UV index, Pressure hPa+trend, Solar noon, Sun elevation, Days to full moon, 2nd time zone, BMNT/EENT, First/last light, Altitude m/ft, Watch sensor temp, Off |
| Date format | **TUE 06**, 06 OCT, OCT 06, 06.10, Week number, Day of year, 10/06 |
| Line 2 number | Heart rate bpm, Resting HR bpm, Body Battery, Stress, **Battery %**, Battery days left, Notifications, Off |
| Line 2 bar | Steps vs goal, Intensity min/day, Intensity min/week, Heart rate zone, Body Battery, Stress, Humidity %, Rain chance %, Cloud cover %, UV index, Air quality EU, **Solar intensity**, Moon lit %, Battery %, Off |
| Line 3 | Steps, Steps to goal, Breaths/minute, BB change last 2h, Context, Temp high/low, Feels like temp, Feels + wind, Dew point temp, Humidity %, Rain chance %, Rain / dry change, Rain today mm/in, Snow 24h cm/in, Wind km/h or mph, Wind knots, Wind force (Bft), Gusts km/h or mph, Cloud cover %, UV index, UV max today, Air quality EU, Pollen (Europe), T-storm potential, Freezing lvl m/ft, Freezing margin, Pressure hPa+trend, Pressure inHg+trend, Pressure change 3h, **Next sunrise/set**, Sunrise & sunset, Day length, Solar noon, Golden hour, Sun elevation, Moon lit %, Days to full moon, Days to new moon, Solstice/equinox, 2nd time zone, Seconds, BMNT/EENT, First/last light, Lat/lon position, Altitude m/ft, Countdown, Watch sensor temp, Off |

**Circle**

| Setting | Options |
|---|---|
| Circle shows | Heart rate bpm, Body Battery, **Weather now**, Temp high/low, Next 3 hours, Tomorrow, Rain chance %, Wind km/h or mph, Pressure hPa+trend, Next sunrise/set, Moon, 2nd time zone, Altitude m/ft, Battery days left, Notifications, Off, Seconds (wrist raise) |
| 2nd time zone | UTC-12, UTC-11, UTC-10, UTC-9, ... (28 options) |

**Time**

| Setting | Options |
|---|---|
| Time format | **Watch setting**, 24 hours, 12 hours |
| Colon style | No colon, Circles, **Squares**, Diamonds |
| Minutes style | **Dithered (auto)**, Solid, Outlined, Dithered always |
| Countdown day | **1**, 2, 3, 4, ... (31 options) |
| Countdown month | **JAN**, FEB, MAR, APR, MAY, JUN, JUL, AUG, SEP, OCT, NOV, DEC |
| Countdown year | 2026, **2027**, 2028, 2029, 2030, 2031, 2032, 2033, 2034, 2035, 2036, 2037, 2038, 2039, 2040, 2041, 2042, 2043, 2044, 2045, Every day |
| Countdown time | **00:00**, 00:15, 00:30, 00:45, ... (96 options) |

**Side gauges**

| Setting | Options |
|---|---|
| Left gauge | Steps vs goal, Floors vs goal, Intensity min/day, Intensity min/week, Move alert level, Body Battery, **Stress**, Humidity %, Rain chance %, Cloud cover %, UV index, Air quality EU, Daylight left, Solar intensity, Moon lit %, Battery %, Off |
| Right gauge | Steps vs goal, Floors vs goal, Intensity min/day, Intensity min/week, Move alert level, **Body Battery**, Stress, Humidity %, Rain chance %, Cloud cover %, UV index, Air quality EU, Daylight left, Solar intensity, Moon lit %, Battery %, Off |
| Gauge look | **Bar**, Blocks |

**Rows layout**

| Setting | Options |
|---|---|
| Row 1 | **Steps vs goal**, Floors vs goal, Intensity min/day, Intensity min/week, Move alert level, Heart rate zone, Body Battery, Stress, Humidity %, Rain chance %, Cloud cover %, UV index, Air quality EU, Daylight left, Solar intensity, Moon lit %, Battery %, Off |
| Row 2 | Steps vs goal, Floors vs goal, Intensity min/day, **Intensity min/week**, Move alert level, Heart rate zone, Body Battery, Stress, Humidity %, Rain chance %, Cloud cover %, UV index, Air quality EU, Daylight left, Solar intensity, Moon lit %, Battery %, Off |
| Row 3 | Steps vs goal, Floors vs goal, Intensity min/day, Intensity min/week, Move alert level, **Heart rate zone**, Body Battery, Stress, Humidity %, Rain chance %, Cloud cover %, UV index, Air quality EU, Daylight left, Solar intensity, Moon lit %, Battery %, Off |

**Chart layout**

| Setting | Options |
|---|---|
| Column 1 | Steps, Steps to goal, Distance km/mi, Calories kcal, Floors up, Floors down, Climbed m/ft today, Descended m/ft today, **Intensity min/day**, Intensity min/week, Heart rate bpm, Resting HR bpm, Breaths/minute, Pulse Ox %, Body Battery, BB change last 2h, Stress, Temp high/low, Feels like temp, Dew point temp, Humidity %, Rain chance %, Rain / dry change, Rain last 1h mm/in, Rain today mm/in, Snow 24h cm/in, Wind km/h or mph, Wind force (Bft), Gusts km/h or mph, Cloud cover %, Visibility km/mi, UV index, UV max today, Air quality EU, Pollen (Europe), T-storm potential, Freezing lvl m/ft, Pressure hPa, Pressure change 3h, Sun elevation, Moon lit %, Days to new moon, Solstice/equinox, Altitude m/ft, Countdown, Battery days left, Watch sensor temp, Notifications, Off |
| Column 2 | **Steps**, Steps to goal, Distance km/mi, Calories kcal, Floors up, Floors down, Climbed m/ft today, Descended m/ft today, Intensity min/day, Intensity min/week, Heart rate bpm, Resting HR bpm, Breaths/minute, Pulse Ox %, Body Battery, BB change last 2h, Stress, Temp high/low, Feels like temp, Dew point temp, Humidity %, Rain chance %, Rain / dry change, Rain last 1h mm/in, Rain today mm/in, Snow 24h cm/in, Wind km/h or mph, Wind force (Bft), Gusts km/h or mph, Cloud cover %, Visibility km/mi, UV index, UV max today, Air quality EU, Pollen (Europe), T-storm potential, Freezing lvl m/ft, Pressure hPa, Pressure change 3h, Sun elevation, Moon lit %, Days to new moon, Solstice/equinox, Altitude m/ft, Countdown, Battery days left, Watch sensor temp, Notifications, Off |
| Column 3 | Steps, Steps to goal, Distance km/mi, Calories kcal, Floors up, Floors down, Climbed m/ft today, Descended m/ft today, Intensity min/day, Intensity min/week, **Heart rate bpm**, Resting HR bpm, Breaths/minute, Pulse Ox %, Body Battery, BB change last 2h, Stress, Temp high/low, Feels like temp, Dew point temp, Humidity %, Rain chance %, Rain / dry change, Rain last 1h mm/in, Rain today mm/in, Snow 24h cm/in, Wind km/h or mph, Wind force (Bft), Gusts km/h or mph, Cloud cover %, Visibility km/mi, UV index, UV max today, Air quality EU, Pollen (Europe), T-storm potential, Freezing lvl m/ft, Pressure hPa, Pressure change 3h, Sun elevation, Moon lit %, Days to new moon, Solstice/equinox, Altitude m/ft, Countdown, Battery days left, Watch sensor temp, Notifications, Off |
| Chart shows | **Heart rate, 1 h**, Heart rate, 3 h, Heart rate, 4 h, Stress, 1 h, Stress, 3 h, Stress, 4 h, Body Battery, 1 h, Body Battery, 3 h, Body Battery, 4 h, Pressure, 1 h, Pressure, 3 h, Pressure, 4 h, Altitude, 1 h, Altitude, 3 h, Altitude, 4 h, Watch temp, 1 h, Watch temp, 3 h, Watch temp, 4 h, Pulse Ox, 1 h, Pulse Ox, 3 h, Pulse Ox, 4 h, Solar (live), 1 h, Solar (live), 3 h, Solar (live), 4 h, Off, Big text |
| Big text shows | Steps, Steps to goal, Breaths/minute, BB change last 2h, Context, **Temp high/low**, Feels like temp, Feels + wind, Dew point temp, Humidity %, Rain chance %, Rain / dry change, Rain today mm/in, Snow 24h cm/in, Wind km/h or mph, Wind knots, Wind force (Bft), Gusts km/h or mph, Cloud cover %, UV index, UV max today, Air quality EU, Pollen (Europe), T-storm potential, Freezing lvl m/ft, Freezing margin, Pressure hPa+trend, Pressure inHg+trend, Pressure change 3h, Next sunrise/set, Sunrise & sunset, Day length, Solar noon, Golden hour, Sun elevation, Moon lit %, Days to full moon, Days to new moon, Solstice/equinox, 2nd time zone, Seconds, BMNT/EENT, First/last light, Lat/lon position, Altitude m/ft, Countdown, Watch sensor temp, Off |

**Weather**

| Setting | Options |
|---|---|
| Weather source | **Garmin**, Open-Meteo |
| Update every | 5 min, 10 min, 15 min, 20 min, 30 min, 45 min, **60 min** |

**Goals**

| Setting | Options |
|---|---|
| Intensity goal/day | **Auto (week / 7)**, 15 min, 20 min, 30 min, 45 min, 60 min, 90 min |

Solar chart: "Solar (live)" records only while it is shown (Chart layout with the solar chart selected), so it starts empty and fills in over 1 or 4 hours; the readings are kept as bytes and saved to the watch's storage, not held in memory when the chart is off. Countdown: line 3 shows days and time (D-12 T-21:44), columns the days (D-12); on the last day both show the time left (T-05:42), and after the moment the signs flip to +. The time is set in 15-minute steps. The face stores 32 settings (the limit: new choices must go into existing lists): the watch's settings table grows sharply above 32 entries, so related choices are combined (chart source and length (1, 3 or 4 hours), countdown hour and minute, both wrist-raise switches in one setting). Gusts, cloud cover, visibility, UV, rain amounts (rain and showers, without snow), precipitation in the next hour (rain or snow), snow, freezing level, storm risk, air quality and pollen need Open-Meteo as the weather source. With Open-Meteo, "Rain chance" is the highest chance over the next 3 hours and reads RAIN 3H on line 3; Both are only requested while a slot shows them. Body Battery change and sun elevation are read once a minute, only while shown.
Line 1 can show the date, a second time zone or one of 16 short metrics (only those that fit its ~73 px); the icon is left out when both don't fit. Wrist raise detail switches three things independently: the Rows layout's percent of goal and heart-rate zone ("Rows"), the Chart layout's side-gauge values ("gauges") and its chart range ("chart"). With "chart" on, the chart shows its lowest value (left edge) and highest value (right edge) in its unit, in the space beside it. Open-Meteo can update every 5 to 60 minutes; shorter intervals use more battery.

## Mountain metrics

**Freezing margin** (0° with an up triangle: the freezing level is that far above you; down triangle: you are already above it; from the forecast freezing level and the watch's altitude) and **Feels + wind** (feels-like temperature and wind speed together). Available in line 3 and as big text.

**Seconds** (line 3 or big text): SEC 42 while the watch is awake after a wrist raise (the face redraws every second then), SEC -- while it rests.

**Position**: the watch's own GPS fix when it is under 2 hours old (checked every 15 minutes), otherwise Garmin's weather position (which may be a weather station), otherwise the last activity's position. **Off-grid weather**: Open-Meteo forecasts (today's high/low, UV max, rain today, freezing level, snow 24 h, pollen, Tomorrow) are kept up to 12 hours on the day they were fetched; current conditions and the next hours expire after two update intervals plus 10 minutes. After a server error the face retries every 5 minutes; without the phone or a position it keeps the normal interval. **Pressure** shows the live sea-level pressure (the station pressure if the watch has no sea-level value), read each minute without a history read; the 3-hour change, trend arrow and storm alert compare the pressure history (station pressure, like with like), read every 15 minutes. **Sun times** are worked out with the face's own formula (within about 2 minutes of NOAA's) when the face is shown and when the watch goes back to sleep, at most every 15 minutes, not in the minute's redraw; where the sun does not rise or set, **POLAR DAY** or **POLAR NIGHT** is shown. The Body Battery and Battery days circle views show their level with the dotted arc. **Descended m/ft today** is a column option, **Day of year** a date format. **Units** follow the watch: temperature (°C/°F), distance (km/mi, also wind km/h or mph and visibility), elevation (m/ft); rain and snow follow the temperature setting (inches with °F, mm and cm with °C), so the UK gets millimetres. Pressure in inHg and wind in knots are separate line-3 / big-text options; "10/06" is a month/day date format. **Thunderstorm potential** (TSTORM LOW / MOD / HIGH / V.HIGH) is estimated from the forecast's CAPE and is not an official warning; the **Pressure drop** icon marks a falling barometer. **Air quality EU** uses all six European levels (GOOD, FAIR, MODERATE, POOR, V.POOR, EXTREME). **Wind force (Bft)** follows the official Beaufort limits. The countdown can be set up to 2045. **Rain / dry change** (line 3, columns, big text) tells when it turns wet or dry, approximately on purpose: "RAIN ~25M" counts down (in 5-minute steps) to the start of the 15-minute block in which precipitation of at least 0.1 mm is forecast to begin (Open-Meteo, 2 hours ahead; outside Central Europe and North America these blocks are often interpolated from hourly data), then hourly up to 12 hours ("RAIN ~4H", "DRY 12H+"); while it rains, "DRY ~25M", or "RAIN +14MM" when no end is forecast within 12 hours (the rain or snow still to come in those hours; "RAIN 12H+" if under 0.5 mm). Once the forecast moment passes without a new forecast it says "RAIN DUE". SNOW comes from the forecast's snowfall (or the hourly weather code), otherwise from the temperature (1 °C or below). **Context** (line 3, big text) shows the weather or light message most likely to change what you do next: first anything to act on now (gusts of force 8+, fog under 1 km, EXTREME air quality, freezing precipitation), then under 30 minutes of light left, rain or snow starting or stopping within 2 hours, light running out ("LIGHT 1:20"), conditions worth adapting to (thunderstorm potential HIGH or above, force 7 gusts, UV 8+, POOR air or worse), and when nothing needs attention a calm default: the dry/wet outlook ("DRY 12H+", "DRY ~3H", or "RAIN +14MM" when it rains with no end in 12 hours: the amount still to come in those 12 hours), or the next sun event without weather data. Weather messages disappear when the forecast is too old; none of them is an official warning. The countdown can repeat **every day** (choose DAILY as the year): it counts to that time each day, then T+ until midnight. The circle can show **Seconds (wrist raise)**: large seconds for the few seconds after a wrist raise, with the dotted ring filling over the minute; at rest the circle stays empty, so nothing is redrawn every second (always-on seconds would need about 0.45 kB more). The right side gauge sits 2 px further in than a mirror of the left one: on the Instinct 3 Solar 45 mm the bezel covers the outermost columns on the right. **Times** follow the face's Time format; Zulu is always 24-hour, and the 2nd time zone adds A/P in 12-hour mode.

## Weather source

After a failed fetch (for example ERR503, a busy server), the face retries every 5 minutes until a fetch succeeds, then returns to the chosen interval.

Garmin (default) or Open-Meteo (free, no account or key): a background task makes one weather request (current conditions, the next 24 hours, today and tomorrow, and the next hour in 15-minute steps) and, only while air quality or pollen is shown, one air-quality request, at the chosen interval (5 to 60 minutes) while the phone is connected. Every weather value then comes from Open-Meteo; the watch only supplies the position. Weather data by Open-Meteo.com (CC BY 4.0); air quality and pollen from the Copernicus Atmosphere Monitoring Service (CAMS) via Open-Meteo.

## Settings on the phone, units, and publishing

On the watch, the settings show one entry per screen: the group, then each setting with its current value, then its options (the stored one marked CURRENT). UP and DOWN move, GPS opens a group or a setting or saves the option shown, BACK cancels or goes up a level; BACK at the top hands back to the watch, which closes the settings. The countdown time is set in two steps, hour then minutes; choosing DAILY as the countdown year makes it repeat every day. The menu keeps no label cache: it loads only the option list of the setting on screen, so it uses little memory (compact design suggested in the ChatGPT review, adapted).

- **Phone settings.** All settings are stored as properties, so faces installed from the Connect IQ Store can be configured in the Garmin Connect app as well as on the watch (`resources/settings/`, generated by `tools/make_project.py`).
- **Limits.** Pollen covers Europe only, during the pollen season (otherwise "POLLEN --"). Thunderstorm risk is the atmosphere's storm energy (CAPE, J/kg) over the next 6 hours: LOW below 300, MOD below 1000, HIGH below 2500, SEVERE above; it is not lightning detection. The free Open-Meteo service is for non-commercial use (under 10,000 calls a day; the face makes at most 576).
- **Weather check.** With Weather source set to Open-Meteo, while there is no fresh data the weather values show "--", and the circle (Weather now, Next 3 hours, Tomorrow) shows why: NO DATA (nothing arrived yet; normal for the first interval), NO GPS (no position yet) or ERR followed by the error number (for example ERR-104: phone not connected). A successful fetch clears it.
- **Units.** Temperature, distance (and wind), and altitude follow the watch's unit settings.
- **Store package.** `.\build.ps1 -Export` (or `./build.sh --export`) writes `bin/SolarFrontier.iq`, signed with your developer key; keep that key, every update must use it.
- **Store listing.** `store/STORE.md` has the name, description and permission notes; `store/` also holds the store icon and screenshots.

## Build and install

1. SDK Manager with the **Instinct 3 Solar 45mm / 50mm** device and Java 17+.
2. From this folder: `powershell -ExecutionPolicy Bypass -File .\build.ps1` (Windows) or `./build.sh`. Add `-Sim` / `--sim` for the simulator (**File > View Memory** shows memory use).
3. In `GARMIN/APPS`, delete any older `SolarVanguard.prg` or test faces, copy in `bin/SolarFrontier.prg`, unplug, and pick **Solar Frontier**. It has its own app ID, so its settings start at the defaults.

## Notes

- Permissions: SensorHistory, UserProfile (heart-rate zones), Positioning (sunrise/sunset), Background and Communications (Open-Meteo weather).
- Regenerate fonts, icons and menu text with `python3 tools/make_project.py` (Saira Semi Condensed TTFs in `tools/fonts/`, Python 3 with Pillow); `python3 tools/preview.py` redraws the previews and `python3 tools/store_assets.py` the store images.
- Fonts: Saira Semi Condensed by Omnibus-Type, SIL Open Font License (`OFL-SairaSemiCondensed.txt`).

- `tools/store_adventure.py`: the store images for 1.9 (four adventure scenarios, a day with Context, an anatomy image per layout).

## Devices

Built for the **Instinct 3 Solar, 45 mm and 50 mm** (Connect IQ ID `instinct3solar45mm`, which Garmin uses for both sizes); `manifest.xml` lists only this device.

The Instinct 2 and 2X (`instinct2`, `instinct2x`) have the same 176 x 176 screen and could be added later: nothing in the face needs API 4 (everything newer is checked with `has`), so it would mean adding the two products and setting `minApiLevel` to 3.3.0, then testing memory, settings and weather in the simulator (`.\build.ps1 -Device instinct2 -Sim`). The Instinct 2S (156 x 156) would need its own layout.

## Licences and credits

**Code:** Solar Frontier is free software under the **GNU General Public License v3.0 or later** (see `LICENSE`). You may use, study, change and share it; if you distribute a modified version (on GitHub, in the Connect IQ store or anywhere else), you must publish its complete source under the same licence.

**Fonts:** the bitmap fonts in `resources/fonts/` ("Solar Frontier Pixel") are a Modified Version of **Saira Semi Condensed** by Omnibus-Type, under the **SIL Open Font License 1.1** (see `OFL-SairaSemiCondensed.txt`). They are renamed because the licence reserves the name "Saira" for the original font. To regenerate them, download Saira Semi Condensed from Google Fonts and set `SAIRA_FONT_DIR` (see Build).

**Weather data:** Open-Meteo.com (CC BY 4.0); air quality and pollen: Copernicus Atmosphere Monitoring Service via Open-Meteo. Free for non-commercial use.

**Trademarks:** Garmin, Instinct and Connect IQ are trademarks of Garmin Ltd. This project is not affiliated with or endorsed by Garmin.

**If you publish your own version:** generate a new app ID (a new UUID in `manifest.xml`) so it doesn't clash with Solar Frontier in the Connect IQ store, use your own developer key, and keep the licence notices.

Written with the help of AI assistants (Anthropic's Claude, OpenAI's ChatGPT).
