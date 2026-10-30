# Solar Frontier: Connect IQ Store listing

## App name
Solar Frontier

## Short description
An adventure watch face that shows what matters next.

## Description (paste into the store)

A personal project, built with the help of AI and shared for free.

Solar Frontier is an adventure watch face for the Instinct 3 Solar (45 and 50 mm), drawn pixel by pixel for its high-contrast screen. It is built for people who spend their time outside and want to know what the weather, the light and their own body are about to do.

CONTEXT: A QUIET BRIEFING
Most watch faces show the same numbers all day. Context shows the one weather or light message most likely to change what you do next, and stays calm when nothing does.
- Act now: strong gusts, fog, extreme air quality, freezing rain.
- Light nearly gone: the last 30 minutes before sunset.
- Change ahead: rain or snow starting or stopping within 2 hours ("RAIN ~30M", "DRY ~25M").
- Time running out: daylight left ("LIGHT 1:20").
- Worth adapting to: thunderstorm potential, strong wind, high UV, poor air.
- Nothing urgent: a calm outlook such as "DRY 12H+" or "DRY ~3H", and during steady rain how much is still to come ("RAIN +14MM").
Put Context on line 3 or in large type below the time. It reads only data the face already has, and every message disappears when its forecast is too old.

RAIN AND SNOW, HONESTLY TIMED
"RAIN ~25M" counts down to the 15-minute block in which precipitation is forecast to begin, up to 12 hours ahead, and "DRY ~3H" tells you when it should stop. The "~" is deliberate: forecasts come in 15-minute steps, so the face doesn't pretend to know the minute. Snow is named as snow when the forecast says so.

BUILT FOR THE OUTDOORS
Freezing level and the margin to your altitude, wind force on the Beaufort scale, gusts, thunderstorm potential, visibility, UV and today's maximum, new snow in the next 24 hours, air quality (all six European levels) and pollen. Sunrise and sunset, first and last light, BMNT and EENT, golden hour, day length, sun elevation, moon phase and illumination. Altitude, barometric pressure with its trend and 3-hour change, seconds in the circle on wrist raise, Zulu and a second time zone, coordinates, and a countdown to a date or to a time every day.

YOURS TO ARRANGE
Two layouts: progress rows, or three columns with a history chart (heart rate, stress, Body Battery, pressure, altitude, temperature, Pulse Ox or solar, over 1, 3 or 4 hours) or one metric in large type. Every zone is configurable: 76 metrics and 660 options in all, including steps, heart rate and zone, Body Battery, stress, breathing, intensity minutes with your own daily goal, floors, distance, calories, battery days left and notifications. Wrist raise adds exact values. Dark or light theme. Units, 12/24-hour time and the date format follow your choices.

Every setting works on the watch itself, no phone needed, and in the Garmin Connect app.

* Weather from Open-Meteo: free, no account or key. Updates every 5 to 60 minutes through the phone (shorter intervals use more battery). Thunderstorm potential is the atmosphere's storm energy (CAPE) over the next 6 hours, not a lightning detector. Weather data by Open-Meteo.com (CC BY 4.0).
** Pollen: Europe only, during the pollen season. Air quality and pollen: Copernicus Atmosphere Monitoring Service (CAMS) via Open-Meteo.

Note: the face cannot vibrate or sound an alarm. Context messages, the pressure-drop icon and thunderstorm potential are indications from the forecast and the watch's barometer, not official weather warnings. The Instinct's own storm alert remains the alarm.

PERMISSIONS
Health data and heart-rate zones, location (sun times, local weather), background and internet (Open-Meteo weather only). No data is collected.

## What's new
1.9.1: Context now focuses on weather and light, and during steady rain shows how much is still to come ("RAIN +14MM"). 1.9: Context, a field that shows what matters next; rain and snow timing ("RAIN ~25M"); a lighter on-watch settings menu that shows current values; a lighter clock redraw.

Version history:
- 1.9.3 The right side gauge moved 2 px inward, so it is no longer cut off by the bezel on the 45 mm Instinct 3 Solar.
- 1.9.2 Seconds in the circle after a wrist raise, with the dotted ring filling over the minute.
- 1.9.1 Context is about weather and light only (Body Battery removed); during steady rain it shows how much is still to come ("RAIN +14MM"); leaner Context code.
- 1.9 Context ordered by what to act on; approximate rain and snow timing with snow from the forecast; compact on-watch menu with current values; allocation-free clock.
- 1.8 Rain and snow start and stop times up to 12 hours ahead, Context, daily countdown.
- 1.7 Six European air-quality levels, Beaufort wind force, clearer thunderstorm-potential and pressure-drop wording, countdowns up to 2045.
- 1.6 Pressure in inHg, wind in knots, a month/day date format, rain and snow units that follow the temperature setting; watch temperature and side gauges always fill; internal optimisations.
- 1.5 Memory and stability: single-screen settings menu, wind compass, side-gauge fix.
- 1.4 Big text mode, 1/3/4-hour charts, smoother charts while resting.
- 1.3 Open-Meteo (no API key): thunderstorm potential, pollen, freezing level, snow, UV maximum, rain today.
- 1.2 Air quality, precipitation timing, Body Battery trend, sun elevation, chart minimum and maximum on wrist raise.
- 1.1 Countdown, intensity goal, new metrics.
- 1.0 Initial release.

## Store assets in this folder (regenerate with: python3 tools/store_assets.py)
- app-icon-500.png: the app icon (cover), 500 x 500 px, both layouts and both gauge styles, no text. Orange variant: app-icon-500-orange.png.
- hero-1440x720.jpg / hero-1440x720-small.png: hero image, 1440 x 720 px.
- device-icon-128.png: optional on-device store icon, 128 x 128 px, black and white.
- screenshot-01 ... 08: every one differs in all three top lines, the layout, the gauges, the circle and the data:
  01 Chart: default top lines (moon, date, battery + solar); wind, humidity, feels like; BMNT.
  02 Rows: alarm + Zulu time, Body Battery bar, countdown with time; daily intensity row; heart-rate circle.
  03 Chart: Do Not Disturb + date, resting HR + intensity bar, next new moon; resting HR, breathing, climbed.
  04 Rows: pressure-drop icon + week number, stress bar, thunderstorm potential; floors, move, daylight; wind circle.
  05 Chart on wrist raise: Bluetooth + date, battery days + battery bar, day length; UV max, rain today, freezing level.
  06 Rows on wrist raise: notifications + date, heart rate + zone bar, days to solstice; next sunset circle.
  07 Light theme: phone + date, notifications + steps bar, pollen; humidity, air quality, rain chance as bars.
  08 Minimal: no icon, gauges, circle, bar or line 3; steps to goal, watch temperature, new snow.
- hero-versatility-1440x720.png: alternative hero with the real numbers (76 metrics: 31 weather, 20 outdoors = sun & moon + tactical, 20 health & activity, 4 watch; 15 circle views, 8 charts, 2 layouts, 16 slots, 660 options). Generated by tools/store_hero_versatility.py from the versatility images.
- context-day.png (1440 x 1440): "A day with Context": the same face at five times of day, each showing the message that matters then (DRY 12H+, RAIN ~30M, GUST 72 KMH, LIGHT 0:35, RAIN +14MM), with consistent values (wind, rain chance and Body Battery change through the day).
- adventure-1 ... 4.png (1440 x 1440): four adventure scenarios, one large face each: Alpine (freezing level, Beaufort force, a climbing altitude chart), Rain (Context rain timing, next 3 hours), Sun (light theme, UV, daylight left, solar), Night (snow timing, first light, moon). Every value agrees with the circle view shown.
- anatomy-chart.png / anatomy-rows.png (1440 x 1440): each layout with numbered zones and a legend of what each zone can show; the counts are read from the real option lists.
  The seven images above: generated by tools/store_adventure.py.
- versatility-1 ... 4.png (1440 x 1440): the previous metric-variety images (Chart, Chart + big text, Rows, Light, no metric repeated within an image). Still generated by tools/store_versatility.py.
- native-*-176.png / native-*-528.png: exact screen pixels at 1:1 and 3x, if device-resolution screenshots are needed.
