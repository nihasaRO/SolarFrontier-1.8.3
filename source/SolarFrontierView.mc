import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Background;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.UserProfile;
import Toybox.WatchUi;
import Toybox.Weather;

// Solar Frontier: watch face for the Instinct 3 Solar (176 x 176 px, 1-bit MIP).
// Shared: weather circle (16 modes), top block (date, battery + solar signal ramp, sun),
// time with an optional colon, and two vertical side gauges (Enduro-style bar or blocks,
// ticks at 25/50/75 %). Lower part, chosen by the Layout setting:
//  Rows   three progress rows (icon, bar, value); 10 cells for percentages, 5 for HR zones.
//  Chart  three columns and a chart.
class SolarFrontierView extends WatchUi.WatchFace {

    private const CX = 88;
    private const GRAPH_X = 35;            // Rim chart, centred on x 88
    private const GRAPH_BOTTOM = 168;      // first row below the bars (the bottom edge is free now)
    private const GRAPH_BARS = 54;
    private const GRAPH_MAX_H = 20;
    private const SOLAR_LEN = 240;         // solar samples, one a minute (4 hours)
    private const COL_X = [ 40, 88, 136 ];         // column centres
    private const DAYS = "SUNMONTUEWEDTHUFRISAT";       // 3 letters each: one string, not 7
    private const MONTHS = "JANFEBMARAPRMAYJUNJULAUGSEPOCTNOVDEC";
    private const SYNODIC = 29.530588853;  // days
    private const NEW_MOON = 947182440;    // 2000-01-06 18:14 UTC

    // Garmin weather condition (0..53) -> icon group:
    // 0 clear, 1 partly cloudy, 2 cloudy, 3 rain, 4 snow, 5 storm, 6 fog, 7 wind
    private const WX_MAP = [ 0, 1, 2, 3, 4, 7, 5, 3, 6, 6, 4, 3, 5, 3, 3, 3, 4, 4, 3, 3,
                             2, 3, 1, 0, 3, 3, 3, 3, 5, 6, 6, 3, 7, 6, 4, 6, 7, 6, 6, 6,
                             0, 7, 7, 4, 3, 3, 4, 3, 4, 3, 3, 4, 1, 2 ]b;

    // Row layout
    private const ROW_Y = 123;       // first row top
    private const ROW_PITCH = 15;
    private const ROW_ICON_X = 28;
    private const ROW_BAR_X = 42;
    private const ROW_VALUE_R = 148; // values right-aligned here

    private var fg = Graphics.COLOR_WHITE;
    private var bg = Graphics.COLOR_BLACK;
    private var fSmall;
    private var fMid;
    private var fMed;
    private var fTime;
    private var fMinutes;          // the solid time font, or the outlined one when selected
    private var ditherMinutes = true;  // minutes drawn solid, then dithered with a checkerboard
    private var minutesStyle = -1;
    private var fIcons;            // every icon is one glyph of this font
    private var cfg;
    private var hrZones;           // zone boundaries from the user profile
    private var restHr;            // resting heart rate from the user profile
    private var wxHum;             // relative humidity %
    private var wxFeels;           // feels-like temperature, C
    private var wxGust;            // Open-Meteo only: gusts m/s, cloud cover %, visibility m, rain mm (last hour)
    private var wxCloud;
    private var wxVis;
    private var wxRainMm;
    private var wxUv;              // UV index (Open-Meteo)
    private var watchTemp;         // the watch's own temperature sensor, C
    private var wxAqi;             // European air quality 1..6 (Open-Meteo, CAMS)
    private var wxNote;           // why there is no weather data ("NO DATA", "NO GPS", "ERR..."), or null
    private var wxTs = null;      // timestamp of the applied weather data (null: none applied)
    private var ccRead = -1000;    // when Garmin's conditions were last read (seconds)
    private var sunRead = -1000;   // when the position and sun times were last worked out (seconds)
    private var l1code = -1;       // the line-3 metric shown in line 1, or -1
    private var hrNow;             // heart rate read once per redraw
    private var ami;               // the activity data, only while a redraw runs
    var behindMenu = false;        // the face's settings menu is open: skip redraws (set by the app)
    var skipOnce = false;          // just left the menu: skip one more redraw (set by the menu)
    private var wxRetry = false;
    private var wxStale = false;   // the "now" values were cleared; the forecasts are kept   // the server failed: fetch every 5 minutes until one succeeds
    private var pressRead = -1000; // when the 3 hours of pressure history were last read (for the trend)
    private var pressLast;         // the newest history value (station pressure), a fallback for the shown value
    private var histLow = false;   // a history read was skipped this minute for lack of memory
    private var cSum;              // incremental history chart: sums and counts per slot (null when not shown),
    private var cCnt;              // the newest slot's number, the newest sample read, and the chart setting
    private var cSlot = 0;
    private var cRead = 0;
    private var cKey = -1;
    private var cStale = false;
    private var cLast;             // the latest sample value read, for the newest bar while history lags
    private var chartLo;           // the chart's lowest and highest value (for the wrist-raise labels)
    private var chartHi;
    private var airErr;
    private var uvMax;             // Open-Meteo: UV max today, rain total today (mm), storm energy (CAPE, J/kg,
    private var rainDay;           // next 6 h), freezing level (m), new snow next 24 h (cm), pollen level 0-4
    private var capeV;             // and type (0 alder, 1 birch, 2 grass, 3 mugwort, 4 olive, 5 ragweed)
    private var frzLvl;
    private var snow24;
    private var polLvl;
    private var polType = 0;
    private var rainChg;           // time (s) of the next change between dry and wet, or null (none within 12 h)
    private var wxWet;             // precipitation now: 1, dry: 0, null unknown
    private var wxSnowP;           // the precipitation that matters is snow: 1, rain: 0, null unknown
    private var wxAmt;             // the amount in the next 12 hours: cm of snow or mm of rain
    private var bbDelta;           // Body Battery change over the last 2 hours
    private var sunElev;           // sun elevation now, degrees
    private var pressureDrop = 0.0;   // Pa lost over the last 3 hours (storm alert above 300)
    private var tempF = false;     // units follow the watch: Fahrenheit, miles (and mph), feet
    private var distMi = false;
    private var elevFt = false;
    private var awake = false;     // true for the few seconds after a wrist raise
    private var arcX;              // dotted-arc positions inside the subscreen
    private var arcY;
    private var fTiny;             // small digits for the gauge values on wrist raise (Chart layout only)
    private var fBig;              // Chart layout "Big text" (only loaded in that mode)
    private var bigCode = -1;      // the line-3 metric shown as big text, or -1

    // Rim layout (loaded only while it is selected)
    private var fData;             // 15 px digits for the columns
    private var spo2;
    private var chartBars;
    private var solarBuf;          // solar history recorded by the face itself
    private var solarPos = 0;
    private var solarLastMin = -1;
    private var solarSaveCount = 0;

    // Subscreen geometry; replaced by WatchUi.getSubscreen() when available
    private var subCx = 145;
    private var subCy = 31;
    private var subTop = 0;

    // Refreshed once a minute
    private var lastMinute = -1;
    private var stress;
    private var bodyBattery;
    private var hrNewest;
    private var altitude;
    private var pressure;
    private var wxCondition;
    private var wxTemp;
    private var wxHigh;
    private var wxLow;
    private var wxPrecip;
    private var wxWind;          // m/s
    private var wxBearing;       // degrees the wind comes from
    private var n3Temp;          // forecast about 3 hours ahead
    private var n3Cond;
    private var n3Precip;
    private var tmHigh;          // tomorrow
    private var tmLow;
    private var tmCond;
    private var tmPrecip;
    private var tmDow;           // 0 = Sunday
    private var pressureTrend = 0;
    private var regMinutes = -1; // weather fetch interval currently registered

    // Last known location (degrees), kept across restarts
    private var locLat;
    private var locLon;

    // Sun times
    private var sunriseText = "--:--";
    private var sunsetText = "--:--";
    private var sunriseMin = -1;
    private var polar = 0;         // 1 polar day, -1 polar night (no sunrise or sunset today), 0 otherwise
    private var sunsetMin = -1;

    function initialize() {
        WatchFace.initialize();
        cfg = Cfg.loadAll();
        applyTheme();
        // icon per row metric, in Cfg.RW_* order
        var saved = Application.Storage.getValue("loc");
        if (saved instanceof Lang.Array && saved.size() >= 2) {
            locLat = saved[0];
            locLon = saved[1];
        }
    }

    // Screen geometry only; fonts and layout resources are loaded by onShow, which always follows.
    function onLayout(dc as Dc) as Void {
        if (WatchUi has :getSubscreen) {
            var box = WatchUi.getSubscreen();
            if (box != null) {
                subCx = box.x + box.width / 2;
                subCy = box.y + box.height / 2;
                subTop = box.y;
            }
        }
        buildArc();                                      // needs the circle's position, so after it is known
    }

    function onUpdate(dc as Dc) as Void {
        if (behindMenu) {
            return;                                  // the settings menu covers the screen: no reload, no drawing
        }
        if (skipOnce) {
            skipOnce = false;                        // just left the menu: draw on the next pass, once it is freed
            WatchUi.requestUpdate();
            return;
        }
        if (fSmall == null) {
            reloadLight();                           // fonts were freed for the settings menu: the light reload only
        }
        readHrNow();                                 // once per redraw; currentHr() reuses it
        var now = Time.now();
        var clock = System.getClockTime();
        var settings = System.getDeviceSettings();

        if (clock.min != lastMinute) {
            lastMinute = clock.min;
            // onShow() and onSettingsChanged() handle configuration reloads.
            // Avoid 31 property reads and redundant resource checks every minute.
            refreshMinute(now, settings);
        }

        var info = ActivityMonitor.getInfo();
        ami = info;                                      // shared with the text functions during this redraw
        var stats = System.getSystemStats();

        dc.setColor(bg, bg);
        dc.clear();
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);

        drawCircle(dc, now, clock, settings, stats);
        var av = arcValue(cfg[Cfg.CIRCLE], now, clock, stats);
        if (av != null && av < 0) {
            av = 0;
        }
        drawArc(dc, av);
        drawTopBlock(dc, now, settings, stats, false);
        drawTime(dc, clock, settings);

        drawSideGauges(dc, info, stats);
        if (cfg[Cfg.LAYOUT] == 1) {
            drawChartLower(dc, info, stats, settings);
        } else {
            // Tray rail under the time: 45-degree ends echo the top rail and the panel corners
            dc.drawLine(16, 122, 20, 118);
            dc.drawLine(20, 118, 156, 118);
            dc.drawLine(156, 118, 160, 122);
            for (var k = 0; k < 3; k += 1) {
                drawRow(dc, cfg[Cfg.ROW1 + k], ROW_Y + k * ROW_PITCH, info, stats);
            }
        }
        ami = null;                                      // the activity data is not kept between redraws
    }

    // ------------------------------------------------------------ once a minute

    private function refreshMinute(now, settings) as Void {
        var nowSec = now.value();
        l1code = (cfg[Cfg.TOP_TEXT] >= 3) ? Cfg.L1[cfg[Cfg.TOP_TEXT] - 3] : -1;
        bigCode = (cfg[Cfg.LAYOUT] == 1 && cfg[Cfg.CHART] == 25) ? cfg[Cfg.BIG] : -1;
        histLow = false;
        tempF = (settings has :temperatureUnits) && settings.temperatureUnits == System.UNIT_STATUTE;
        distMi = (settings has :distanceUnits) && settings.distanceUnits == System.UNIT_STATUTE;
        elevFt = (settings has :elevationUnits) && settings.elevationUnits == System.UNIT_STATUTE;
        // a skipped read (little memory) or an empty one keeps the last value, so gauges never go blank
        var nv = newest(Cfg.CH_STRESS);
        stress = (nv != null) ? nv : stress;
        nv = newest(Cfg.CH_BB);
        bodyBattery = (nv != null) ? nv : bodyBattery;
        var act = Activity.getActivityInfo();
        if (act == null || act.currentHeartRate == null) {   // the history only stands in for a missing live value
            nv = newest(Cfg.CH_HR);
            hrNewest = (nv != null) ? nv : hrNewest;
        }
        var circle = cfg[Cfg.CIRCLE];
        var rim = cfg[Cfg.LAYOUT] == 1;
        altitude = null;
        if (circle == Cfg.CM_ALTITUDE || (rim && colWants(Cfg.FI_ALTITUDE)) || lineShows(5) || lineShows(41)) {
            altitude = newest(Cfg.CH_ALTITUDE);
            if (altitude == null) {
                var ai = Activity.getActivityInfo();
                if (ai != null && (ai has :altitude)) {
                    altitude = ai.altitude;
                }
            }
            if (altitude != null && elevFt) {
                altitude = altitude * 3.28084;
            }
        }
        if (circle == Cfg.CM_PRESSURE || (rim && (colWants(Cfg.FI_PRESSURE) || colWants(34))) || lineShows(3)
                || lineShows(28) || lineShows(44) || cfg[Cfg.CORNER] == Cfg.CORNER_STORM) {
            readPressure(nowSec);                        // keeps the last value if no new sample came in
        } else {
            pressure = null;                             // not shown: nothing to keep
            pressRead = -1000;
        }
        if (rim) {
            spo2 = colWants(Cfg.CO_SPO2) ? newest(Cfg.CH_SPO2) : null;
            if (colWants(33)) {
                readWatchTemp();
            }
            recordSolar(nowSec);
        }
        if (lineShows(27)) {
            readWatchTemp();
        }
        if (lineShows(33) || (rim && colWants(39))) {
            bbChange();
        }
        if (lineShows(34) || (rim && colWants(40))) {
            sunElev = sunElevation(nowSec);
        }
        readWeatherAndSun(now, settings);
        if (nowSec - sunRead > 21600) {
            updateSun();                                 // safety net: no wake-up for 6 hours
        }
        checkWeatherAge(nowSec);
        manageBackground();
        if (hrZones == null || nowSec % 3600 < 60) {      // zones and resting HR: on show, then once an hour
            readHrZones();
            if ((Toybox has :UserProfile) && (UserProfile has :getProfile)) {
                var prof = UserProfile.getProfile();
                restHr = (prof != null && (prof has :restingHeartRate)) ? prof.restingHeartRate : null;
            }
        }
        if (rim) {
            if (cfg[Cfg.CHART] / 3 == Cfg.CH_SOLAR) {
                chartBars = computeChart(Cfg.CH_SOLAR, chartSpan(), nowSec);
            } else {
                updateChart(nowSec);                         // a few minutes of history, not the whole window
            }
        }
    }

    private function readHrZones() as Void {
        if ((Toybox has :UserProfile) && (UserProfile has :getHeartRateZones)) {
            hrZones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
        }
    }

    // 0 below zone 1, else 1..5 from the profile's zone boundaries.
    private function hrZone(hr) {
        var z = hrZones;
        if (hr == null || z == null || z.size() < 6) {
            return 0;
        }
        if (hr < z[0]) {
            return 0;
        }
        var zone = 1;
        for (var k = 1; k < 5; k += 1) {
            if (hr > z[k]) {
                zone = k + 1;
            }
        }
        return zone;
    }

    // ------------------------------------------------------------ top block

    // Top block: three slots chosen in settings (row 1 icon + text, row 2 value + bar, row 3).
    // Defaults: moon + date, battery + solar ramp, next sun event.
    private function drawTopBlock(dc as Dc, now, settings, stats, night) as Void {
        var icon = cfg[Cfg.CORNER];
        var cw = (icon == 3) ? 0 : 17;
        var x;
        if (cfg[Cfg.TOP_TEXT] >= 3) {
            // a short metric (as in line 3); the icon only when both fit line 1's ~73 px
            var lt = line3Text(Cfg.L1[cfg[Cfg.TOP_TEXT] - 3], now, settings);
            var lw = dc.getTextWidthInPixels(lt, fSmall);
            var iw = (cw > 0 && cw + lw <= 73) ? cw : 0;
            x = 64 - (iw + lw) / 2;
            if (x < 29) {
                x = 29;
            }
            if (iw > 0) {
                drawCornerItem(dc, icon, x, settings, now);
            }
            dc.drawText(x + iw, 13, fSmall, lt, Graphics.TEXT_JUSTIFY_LEFT);
        } else if (cfg[Cfg.TOP_TEXT] == Cfg.TOPTEXT_OFF) {
            drawCornerItem(dc, icon, 58, settings, now);   // icon alone, centred
        } else if (cfg[Cfg.TOP_TEXT] == 1) {
            var tz = tzText(now, settings, true);
            if (cw + dc.getTextWidthInPixels(tz, fSmall) > 75) {
                tz = tzText(now, settings, false);                 // "+3 13:23" when space is short
            }
            x = 64 - (cw + dc.getTextWidthInPixels(tz, fSmall)) / 2;
            if (x < 29) {
                x = 29;
            }
            drawCornerItem(dc, icon, x, settings, now);
            dc.drawText(x + cw, 13, fSmall, tz, Graphics.TEXT_JUSTIFY_LEFT);
        } else {
            var g = Gregorian.info(now, Time.FORMAT_SHORT);
            var fmt = cfg[Cfg.DATE];
            if (fmt == 0) {
                var wd = DAYS.substring(3 * (g.day_of_week - 1), 3 * (g.day_of_week - 1) + 3);
                var dd = g.day.format("%02d");
                var wW = dc.getTextWidthInPixels(wd, fSmall);
                x = 64 - (cw + wW + 4 + dc.getTextWidthInPixels(dd, fMed)) / 2;
                if (x < 29) {
                    x = 29;
                }
                drawCornerItem(dc, icon, x, settings, now);
                dc.drawText(x + cw, 13, fSmall, wd, Graphics.TEXT_JUSTIFY_LEFT);
                dc.drawText(x + cw + wW + 4, 11, fMed, dd, Graphics.TEXT_JUSTIFY_LEFT);
            } else {
                var dt = dateText(g, fmt);
                x = 64 - (cw + dc.getTextWidthInPixels(dt, fSmall)) / 2;
                if (x < 29) {
                    x = 29;
                }
                drawCornerItem(dc, icon, x, settings, now);
                dc.drawText(x + cw, 13, fSmall, dt, Graphics.TEXT_JUSTIFY_LEFT);
            }
        }

        drawRow2(dc, stats, settings);

        // Enduro rail angling up into the circle
        dc.drawLine(14, 47, 101, 47);
        dc.drawLine(101, 47, 107, 41);

        if (!night) {
            drawRow3(dc, now, settings);
        }
    }

    // Row 2: a short value (battery draws its own icon) and a 10-bar signal ramp; any ramp
    // other than solar gets a glyph. Shifts left when wide, so it never reaches the ring.
    private function drawRow2(dc as Dc, stats, settings) as Void {
        var vk = cfg[Cfg.R2_VALUE];
        var vIcon = null;
        var text;
        if (vk == 1) {
            vIcon = Ic.F_BATT;
            text = ((stats has :batteryInDays) && stats.batteryInDays != null) ? num(stats.batteryInDays) + "D" : "--";
        } else if (vk == 2) {
            vIcon = Ic.I_BOLT;
            text = num(bodyBattery);
        } else if (vk == 3) {
            vIcon = Ic.F_ZIG;
            text = num(stress);
        } else if (vk == 4) {
            vIcon = Ic.F_MAIL;
            text = num(settings.notificationCount);
        } else if (vk == 5) {
            vIcon = Ic.I_HEART;
            text = num(currentHr());
        } else if (vk == Cfg.R2V_RESTHR) {
            vIcon = Ic.N_HEART_O;
            text = num(restHr);
        } else {
            text = num(stats.battery);
        }
        var valueOn = vk != Cfg.R2V_OFF;
        var rk = cfg[Cfg.R2_RAMP];
        var rampOn = rk != Cfg.R2R_OFF;
        if (!valueOn && !rampOn) {
            return;
        }
        var lit = rampOn ? rampLit(rk, stats) : 0;
        var glyph = rampOn ? Ic.RAMP[rk] : 255;
        var tw = valueOn ? dc.getTextWidthInPixels(text, fSmall) : 0;
        var vw = valueOn ? ((vIcon == null) ? 19 : 15) : 0;
        var gw = (glyph == 255) ? 0 : 11;
        var w = vw + tw + (valueOn && rampOn ? 6 : 0) + gw + (rampOn ? 29 : 0);
        var x = 60 - w / 2;
        if (x + w > 100) {
            x = 100 - w;
        }
        if (x < 11) {
            x = 11;
        }
        if (!valueOn) {
            // bar alone
        } else if (vIcon == null) {                 // battery icon, filled with charge
            dc.drawRectangle(x, 31, 13, 10);
            dc.fillRectangle(x + 13, 34, 2, 4);
            var fill = (stats.battery * 9.0 / 100.0 + 0.5).toNumber();
            if (fill > 9) {
                fill = 9;
            }
            if (fill > 0) {
                dc.fillRectangle(x + 2, 33, fill, 6);
            }
        } else {
            drawIconBox(dc, vIcon, x, 30, 11, 11);
        }
        if (valueOn) {
            dc.drawText(x + vw, 30, fSmall, text, Graphics.TEXT_JUSTIFY_LEFT);
        }
        if (!rampOn) {
            return;
        }
        var rx = x + vw + tw + (valueOn ? 6 : 0);
        if (glyph != 255) {
            drawIconBox(dc, glyph, rx, 32, 9, 9);
            rx += gw;
        }
        for (var i = 0; i < 10; i += 1) {
            if (i < lit) {
                dc.fillRectangle(rx + 3 * i, 39 - i, 2, 2 + i);
            } else {
                dc.fillRectangle(rx + 3 * i, 40, 2, 1);
            }
        }
    }

    // Lit bars (0..10) for the row-2 ramp.
    private function rampLit(rk, stats) {
        var v = null;
        if (rk == 0) {
            if (stats has :solarIntensity) {
                var si = stats.solarIntensity;
                if (si != null && si > 0) {
                    var l = (si.toNumber() + 9) / 10;
                    return (l > 10) ? 10 : l;
                }
            }
            return 0;
        }
        var info = actInfo();
        if (rk > Cfg.R2R_OFF) {
            v = pctMetric(rk - Cfg.R2R_OFF - 1);
        } else if (rk <= 5) {
            // battery, Body Battery, stress, steps, intensity: the same values as the gauges
            // (bar options 1..5 -> gauge kinds 2, 1, 0, 4, 5); above 100 % the bar is full either way
            v = gaugeValue((rk <= 3) ? 3 - rk : rk, info, stats);
        } else {
            return hrZone(currentHr()) * 2;
        }
        if (v == null) {
            return 0;
        }
        var lit = (v * 10 / 100.0 + 0.5).toNumber();
        if (lit > 10) {
            lit = 10;
        }
        return (lit < 0) ? 0 : lit;
    }

    // Line 3: plain text in the small font; pictograms (sun, triangles, mountain, steps, the dot)
    // are characters of that font, so every option is drawn by the same few lines.
    // The original options (0-6) stay centred on x 62, the newer ones on x 60, as before.
    private function drawRow3(dc as Dc, now, settings) as Void {
        var r3 = cfg[Cfg.R3];
        if (r3 == Cfg.R3_OFF) {
            return;
        }
        var x;
        if (r3 == 7) {                                       // wind: direction arrow + speed
            var wt = speedText(wxWind);
            x = 60 - (12 + dc.getTextWidthInPixels(wt, fSmall)) / 2;
            drawArrowSmall(dc, x + 4, 59, wxBearing);
            dc.drawText(x + 12, 53, fSmall, wt, Graphics.TEXT_JUSTIFY_LEFT);
            return;
        }
        var lt = line3Text(r3, now, settings);
        var lw = dc.getTextWidthInPixels(lt, fSmall);
        x = ((r3 <= 6) ? 62 : 60) - lw / 2;
        if (x + lw > 106) {                                  // keep clear of the circle's ring
            x = 106 - lw;
        }
        dc.drawText((x < 8) ? 8 : x, 53, fSmall, lt, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // Second time zone as "UTC+3 13:23"; the short form drops "UTC" when there is an offset.
    private function tzText(now, settings, longForm) {
        var off = tzOffset();
        if (cfg[Cfg.TZ] == Cfg.TZ_ZULU) {
            return tzTime(now, off, settings, true) + "Z";       // military Zulu time
        }
        return tzLabel(off, longForm) + " " + tzTime(now, off, settings, true);
    }

    // The zone's label: "UTC", or the offset ("+3", long form "UTC+3").
    private function tzLabel(off, longForm) {
        if (off == 0) {
            return "UTC";
        }
        var l = ((off > 0) ? "+" : "") + off.format("%d");
        return longForm ? "UTC" + l : l;
    }

    // The time in the zone. Zulu is always 24 h (line 3 "07:00", the circle "7:00" as before); otherwise the
    // face's Time format, and in line 3 with A / P in 12 h (the circle's big digits have no letters).
    private function tzTime(now, off, settings, line) {
        var u = Gregorian.utcInfo(new Time.Moment(now.value() + off * 3600), Time.FORMAT_SHORT);
        if (cfg[Cfg.TZ] == Cfg.TZ_ZULU) {
            return u.hour.format(line ? "%02d" : "%d") + ":" + u.min.format("%02d");
        }
        return clockText(u.hour, u.min, settings) + ((line && !use24(settings)) ? ((u.hour < 12) ? "A" : "P") : "");
    }

    // Row-1 icon slot: 0 moon, 1 phone, 2 notifications, 3 none, 4 alarm, 5 Do Not Disturb, 6 Bluetooth.
    // Status icons only appear while their state is on.
    private function drawCornerItem(dc as Dc, corner, x, settings, now) as Void {
        if (corner == 0) {
            drawMoon(dc, x + 6, 17, 6, now.value());
        } else if (corner == 1) {
            drawIconBox(dc, settings.phoneConnected ? Ic.C_PHONE : Ic.C_PHONE_X, x, 11, 13, 13);
        } else if (corner == 2) {
            if (settings.notificationCount > 0) {
                drawIconBox(dc, Ic.F_MAIL, x, 11, 13, 13);
            }
        } else if (corner == 4) {
            if ((settings has :alarmCount) && settings.alarmCount > 0) {
                drawIconBox(dc, Ic.S_ALARM, x, 11, 13, 13);
            }
        } else if (corner == 5) {
            if ((settings has :doNotDisturb) && settings.doNotDisturb) {
                drawIconBox(dc, Ic.S_DND, x, 11, 13, 13);
            }
        } else if (corner == 6) {
            if (settings.phoneConnected) {
                drawIconBox(dc, Ic.S_BT, x, 11, 13, 13);
            }
        } else if (corner == Cfg.CORNER_STORM) {
            if (pressureDrop > 300.0) {                     // more than 3 hPa lost in 3 hours
                drawIconBox(dc, Ic.S_STORM, x, 11, 13, 13);
            }
        }
    }

    private function dateText(g, fmt) {
        var dd = g.day.format("%02d");
        if (fmt == 1) {
            return dd + " " + MONTHS.substring(3 * (g.month - 1), 3 * (g.month - 1) + 3);
        }
        if (fmt == 2) {
            return MONTHS.substring(3 * (g.month - 1), 3 * (g.month - 1) + 3) + " " + dd;
        }
        if (fmt == 3) {
            return dd + "." + g.month.format("%02d");
        }
        if (fmt == 4) {
            return "W" + isoWeek(g.year, g.month, g.day, g.day_of_week).format("%d");
        }
        if (fmt == 5) {
            return "DAY " + dayOfYear(g.year, g.month, g.day).format("%d");
        }
        if (fmt == 6) {
            return g.month.format("%02d") + "/" + dd;             // US: month / day
        }
        return DAYS.substring(3 * (g.day_of_week - 1), 3 * (g.day_of_week - 1) + 3) + " " + dd;
    }

    // ------------------------------------------------------------ progress rows

    // One row: icon, bar (10 cells for a percentage, 5 for heart-rate zones), value.
    // The gauge for each row kind (rows and gauges show the same levels); the heart-rate row has none.
    private const ROW_GA = [ 4, 5, 0, 1, 0, 6, 2, 3, 7, 8 ]b;

    private function drawRow(dc as Dc, kind, y, info, stats) as Void {
        if (kind == Cfg.RW_OFF) {
            return;
        }
        drawIconBox(dc, Ic.ROW[kind], ROW_ICON_X, y, 11, 11);
        var zone = -1;       // 0..5 for the heart-rate row
        // the level (0..100) is the side gauge's; the extra rows follow the gauge list one place earlier
        var level = (kind == Cfg.RW_HR) ? null : gaugeValue((kind > Cfg.RW_OFF) ? kind - 1 : ROW_GA[kind], info, stats);
        var text;
        if (kind > Cfg.RW_OFF) {
            text = (kind == Cfg.RW_OFF + 5) ? num(wxUv) : ((kind == Cfg.RW_OFF + 6) ? num(minutesToday())
                   : ((kind == Cfg.RW_OFF + 7) ? num(wxAqi) : pctText(level)));
        } else if (kind == Cfg.RW_STEPS) {
            text = compact(info.steps);
        } else if (kind == Cfg.RW_INTENSITY) {
            var wk = (info has :activeMinutesWeek) ? info.activeMinutesWeek : null;
            text = (wk == null) ? "--" : num(wk.total);
        } else if (kind == Cfg.RW_HR) {
            var hr = currentHr();
            text = num(hr);
            zone = hrZone(hr);
        } else if (kind == Cfg.RW_FLOORS) {
            text = (info has :floorsClimbed) ? num(info.floorsClimbed) : "--";
        } else if (kind == Cfg.RW_MOVE) {
            text = num((level == null) ? null : level / 20);
        } else if (kind == Cfg.RW_DAYLIGHT) {
            text = daylightText();
        } else {
            text = (kind == Cfg.RW_BATTERY || kind == Cfg.RW_SOLAR) ? pctText(level) : num(level);   // BB, stress
        }

        // Wrist raise: goal rows show their percentage, the heart-rate row its zone
        var goalRow = kind == Cfg.RW_STEPS || kind == Cfg.RW_INTENSITY || kind == Cfg.RW_FLOORS || kind == Cfg.RW_OFF + 6;
        if (detailsRows() && goalRow && level != null) {
            text = num(level) + "%";
        } else if (detailsRows() && kind == Cfg.RW_HR && zone > 0) {
            text = "Z" + zone.format("%d");
        }

        if (kind == Cfg.RW_HR && (hrZones == null || currentHr() == null)) {
            dc.fillRectangle(ROW_BAR_X, y + 5, 69, 1);          // no data: a hairline, not 0 %
        } else if (zone >= 0) {
            drawMeter(dc, ROW_BAR_X, y + 2, 5, 13, zone, Ic.M_D13);
        } else if (level == null) {
            dc.fillRectangle(ROW_BAR_X, y + 5, 69, 1);          // no data: a hairline, not 0 %
        } else {
            var cells = 0;
            if (level != null) {
                cells = (level * 10 / 100.0 + 0.5).toNumber();
                if (cells > 10) {
                    cells = 10;
                }
                if (cells < 0) {
                    cells = 0;
                }
            }
            drawMeter(dc, ROW_BAR_X, y + 2, 10, 6, cells, Ic.M_D6);
            if (level > 100) {
                drawOverGoal(dc, ROW_BAR_X + 9 * 7, y + 2);
            }
        }
        dc.drawText(ROW_VALUE_R - dc.getTextWidthInPixels(text, fSmall), y, fSmall, text, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // Over goal: the last cell becomes an arrowhead pointing past the end of the bar.
    private function drawOverGoal(dc as Dc, x, y) as Void {
        dc.setColor(bg, bg);
        dc.fillRectangle(x, y, 6, 7);
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, 3, 7);
        dc.fillRectangle(x + 3, y + 1, 1, 5);
        dc.fillRectangle(x + 4, y + 2, 1, 3);
        dc.fillRectangle(x + 5, y + 3, 1, 1);
    }

    private function ratioRaw(a, b) {
        if (a == null || b == null || b <= 0) {
            return null;
        }
        return a * 100.0 / b;
    }

    // Solid cells for what is done, dithered cells (an icon glyph) for what remains.
    private function drawMeter(dc as Dc, x, y, cells, cellW, lit, ditherIcon) as Void {
        for (var i = 0; i < cells; i += 1) {
            var cx = x + i * (cellW + 1);
            if (i < lit) {
                dc.fillRectangle(cx, y, cellW, 7);
            } else {
                drawIcon(dc, ditherIcon, cx, y);
            }
        }
    }

    // 15000 -> "15.0K" so the value column never overflows.
    private function compact(v) {
        if (v == null) {
            return "--";
        }
        if (v > 9999) {
            return (v / 1000.0).format("%.1f") + "K";
        }
        return num(v);
    }

    // Share of today's daylight still to come, 0..100.
    private function daylightLeft() {
        if (sunriseMin < 0 || sunsetMin <= sunriseMin) {
            return null;
        }
        var t = System.getClockTime();
        var m = t.hour * 60 + t.min;
        if (m <= sunriseMin) {
            return 100;
        }
        if (m >= sunsetMin) {
            return 0;
        }
        return (sunsetMin - m) * 100.0 / (sunsetMin - sunriseMin);
    }

    // Daylight still to come as h:mm.
    private function daylightText() {
        if (sunriseMin < 0 || sunsetMin <= sunriseMin) {
            return "--";
        }
        var t = System.getClockTime();
        var m = t.hour * 60 + t.min;
        var left = sunsetMin - ((m > sunriseMin) ? m : sunriseMin);
        if (left < 0) {
            left = 0;
        }
        return hm(left);
    }

    // ------------------------------------------------------------ Rim layout

    // Loads the Rim-only resources when Rim is selected and frees them otherwise.
    private function loadLayoutResources() as Void {
        if (cfg[Cfg.LAYOUT] == 1) {
            if (fData == null) {
                fData = WatchUi.loadResource(Rez.Fonts.Data);
            }
            if (fTiny == null) {
                fTiny = WatchUi.loadResource(Rez.Fonts.Tiny);
            }
            if (cfg[Cfg.CHART] == 25) {
                if (fBig == null) {
                    fBig = WatchUi.loadResource(Rez.Fonts.Big);
                }
            } else {
                fBig = null;
            }

            if (cfg[Cfg.CHART] / 3 == Cfg.CH_SOLAR) {
                if (solarBuf == null) {
                    initSolar();                         // 240 readings: only for the solar chart
                }
            } else if (solarBuf != null) {
                Application.Storage.setValue("solarBuf", solarBuf);
                Application.Storage.setValue("solarPos", solarPos);
                Application.Storage.setValue("solarT", solarLastMin);
                solarBuf = null;
            }
        } else {
            fData = null;
            fTiny = null;
            fBig = null;
            chartBars = null;
            solarBuf = null;
        }
    }

    private function initSolar() as Void {
        var buf = Application.Storage.getValue("solarBuf");
        if (buf instanceof Lang.ByteArray && buf.size() == SOLAR_LEN) {
            solarBuf = buf;
            var pos = Application.Storage.getValue("solarPos");
            var last = Application.Storage.getValue("solarT");
            if (pos instanceof Lang.Number && last instanceof Lang.Number) {
                solarPos = pos % SOLAR_LEN;
                solarLastMin = last;
            }
        } else {
            solarBuf = new [SOLAR_LEN]b;                 // 0..100 %, 255 = no reading
            for (var i = 0; i < SOLAR_LEN; i += 1) {
                solarBuf[i] = 255;
            }
            solarPos = 0;
            solarLastMin = -1;
        }
    }

    // ---------------- metrics added in Solar Frontier 1.0 ----------------

    // 0..100 metrics usable in every bar and gauge: humidity, rain chance, cloud cover,
    // moon illumination, UV index (11+ = full).
    private function pctMetric(i) {
        if (i == 0) {
            return wxHum;
        } else if (i == 1) {
            return wxPrecip;
        } else if (i == 2) {
            return wxCloud;
        } else if (i == 3) {
            return moonLit(Time.now().value());
        } else if (i == 5) {
            return ratioRaw(minutesToday(), dailyGoal());
        } else if (i == 6) {
            return (wxAqi == null) ? null : (wxAqi - 1) * 20;  // six European levels
        }
        if (wxUv == null) {
            return null;
        }
        var u = wxUv * 100.0 / 11.0;
        return (u > 100.0) ? 100.0 : u;
    }

    // Shared by line 3 (with a label) and the columns (value only):
    // 0 UV, 1 steps left to goal, 2 watch temperature, 3 pressure change over 3 h, 4 days to new moon,
    // 5 days to the next solstice or equinox.
    private function lateText(i, labelled) {
        var v;
        if (i == 0) {
            v = num(wxUv);
            return labelled ? "UV " + v : v;
        } else if (i == 1) {
            var info = actInfo();
            var left = (info.stepGoal == null || info.steps == null) ? null : info.stepGoal - info.steps;
            v = (left == null) ? "--" : ((left > 0) ? "-" + compact(left) : "+" + compact(-left));
            return labelled ? "\u00aa" + v : v;
        } else if (i == 2) {
            v = degText(watchTemp);
            return labelled ? "WATCH " + v : v;
        } else if (i == 3) {
            v = (pressure == null) ? "--" : ((pressureDrop > 0) ? "-" : "+") + (pressureDrop.abs() / 100.0).format("%.1f");
            return labelled ? "3H " + v + " HPA" : v;
        } else if (i == 4) {
            v = (SYNODIC - moonAge(Time.now().value())).toNumber().format("%d") + "D";
            return labelled ? "NEW MOON " + v : v;
        }
        if (i == 6) {                                        // when it turns wet or dry
            return wetText(labelled, minsLeft());
        } else if (i == 7) {                                 // air quality 1..5
            if (wxAqi == null && airErr != null) {
                return (labelled ? "AIR ERR" : "E") + airErr;       // the air quality request failed: show why
            }
            v = num(wxAqi);
            return (labelled && wxAqi != null && wxAqi >= 1 && wxAqi <= 6)
                   ? "AIR " + [ "GOOD", "FAIR", "MODERATE", "POOR", "V.POOR", "EXTREME" ][wxAqi - 1] : (labelled ? "AIR " + v : v);
        } else if (i == 8) {                                 // Body Battery and its change over 2 hours
            v = (bbDelta == null) ? "--" : ((bbDelta >= 0) ? "+" : "") + num(bbDelta);
            return labelled ? "BB " + num(bodyBattery) + " " + v : v;
        } else if (i == 9) {                                // sun elevation now
            v = (sunElev == null) ? "--" : num(sunElev) + "\u00b0";
            return labelled ? "SUN " + v : v;
        }
        if (i == 10) {                                       // UV max today
            v = num(uvMax);
            return labelled ? "UV MAX " + v : v;
        } else if (i == 11) {                                // rain total today (mm or in)
            v = (rainDay == null) ? "--" : (tempF ? (rainDay / 25.4).format("%.2f") : ((rainDay < 10) ? rainDay.format("%.1f") : num(rainDay)));
            return labelled ? "RAIN " + v + (tempF ? " IN" : " MM") : v;
        } else if (i == 12) {                                // storm energy (CAPE, J/kg) as a risk level
            // thunderstorm potential from CAPE, not an official warning
            v = (capeV == null) ? "--" : ((capeV < 300) ? "LOW" : ((capeV < 1000) ? "MOD" : ((capeV < 2500) ? "HIGH" : "V.HIGH")));
            return labelled ? "TSTORM " + v : num(capeV);
        } else if (i == 13) {                                // pollen (Europe, in season): type and level, or level 0-4
            if (!labelled || polLvl == null) {
                return labelled ? "POLLEN --" : num(polLvl);
            }
            return (polLvl == 0) ? "NO POLLEN"
                : [ "ALDER", "BIRCH", "GRASS", "MUGWORT", "OLIVE", "RAGWEED" ][polType] + " " + [ "", "LOW", "MOD", "HIGH", "V.HI" ][polLvl];
        } else if (i == 14) {                                // freezing level (m or ft)
            v = (frzLvl == null) ? "--" : num(ft(frzLvl));
            return labelled ? "0\u00b0 AT " + v + eUnit() : v;
        } else if (i == 15) {                                // new snow, next 24 hours (cm or in)
            v = (snow24 == null) ? "--" : (tempF ? snow24 / 2.54 : snow24);
            v = (v instanceof Lang.String) ? v : ((v < 10) ? v.format("%.1f") : num(v));
            return labelled ? "SNOW " + v + (tempF ? " IN" : " CM") : v;
        } else if (i == 16) {                                // freezing level relative to the watch's altitude
            if (frzLvl == null || altitude == null) {
                return "0\u00b0 --";
            }
            var d = ft(frzLvl) - altitude;              // altitude is already in the user's units
            var a = (d < 0) ? -d : d;
            // up triangle: the freezing level is above you; down: you are already above it
            return "0\u00b0 " + ((d < 0) ? "\u00a4" : "\u00a3") + num(a) + eUnit();
        } else if (i == 17) {                                // cold exposure: feels-like and wind together
            return degText(wxFeels) + "\u00a8" + speedText(wxWind);
        } else if (i == 18) {                                // seconds: after a wrist raise the face redraws every
            return awake ? "SEC " + System.getClockTime().sec.format("%02d") : "SEC --";   // second; asleep: --
        } else if (i == 19) {                                // pressure in inches of mercury, with the trend
            return trendGlyph() + ((pressure == null) ? "--" : (pressure / 3386.39).format("%.2f") + " INHG");
        } else if (i == 20) {                                // wind in knots
            return "WIND " + ((wxWind == null) ? "--" : num(wxWind * 1.94384)) + " KN";
        } else if (i == 21) {                                // wind force on the Beaufort scale
            return "FORCE " + bft(wxWind);
        } else if (i == 22) {                                // context: the most important message right now
            return contextText();
        }
        // next of Mar 20, Jun 21, Sep 22, Dec 21 (this year or next)
        var g = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var today = dayNumber(g.year, g.month, g.day);
        var best = 999;
        var sol = false;
        for (var k = 0; k < 8; k += 1) {
            var mo = 3 * (k % 4) + 3;
            var dd = dayNumber(g.year + k / 4, mo, (mo == 3) ? 20 : ((mo == 9) ? 22 : 21)) - today;
            if (dd >= 0 && dd < best) {
                best = dd;
                sol = mo == 6 || mo == 12;
            }
        }
        v = best.format("%d") + "D";
        return labelled ? (sol ? "SOLSTICE " : "EQUINOX ") + v : v;
    }

    // Body Battery now, and its change over the last 2 hours (oldest sample to newest).
    private function bbChange() as Void {
        var iter = history(Cfg.CH_BB, 7200, false);
        if (iter == null) {
            if (!histLow) {
                bbDelta = null;
            }
            return;                                      // skipped for memory: keep the previous value
        }
        bbDelta = null;
        var first = null;
        var smp = iter.next();
        while (smp != null) {
            if (smp.data != null) {
                if (first == null) {
                    first = smp.data;
                }
                bodyBattery = smp.data;
            }
            smp = iter.next();
        }
        if (first != null) {
            bbDelta = bodyBattery - first;
        }
    }

    // Sun elevation now (degrees; negative at night): hour angle from solar noon (halfway between today's
    // sunrise and sunset), declination from the day of the year; within about a degree.
    private function sunElevation(nowSec) {
        if (locLat == null || sunriseMin < 0 || sunsetMin <= sunriseMin) {
            return null;
        }
        var t = System.getClockTime();
        var g = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var d2r = Math.PI / 180.0;
        var dec = 23.44 * d2r * Math.sin(2 * Math.PI * (284 + dayOfYear(g.year, g.month, g.day)) / 365.0);
        var ha = (t.hour * 60 + t.min - (sunriseMin + sunsetMin) / 2.0) * 0.25 * d2r;
        var lat = locLat * d2r;
        return Math.asin(Math.sin(lat) * Math.sin(dec) + Math.cos(lat) * Math.cos(dec) * Math.cos(ha)) / d2r;
    }

    // True when line 3 or line 1 shows line-3 metric c (so its value has to be read).
    private function lineShows(c) {
        return cfg[Cfg.R3] == c || l1code == c || bigCode == c;     // line 3, line 1 or the big text
    }

    // Daily intensity goal: the setting, or the Garmin weekly goal / 7 on Auto.
    private function minutesToday() {
        var info = actInfo();
        return ((info has :activeMinutesDay) && info.activeMinutesDay != null) ? info.activeMinutesDay.total : null;
    }

    private function dailyGoal() {
        var gi = cfg[Cfg.INT_GOAL];
        if (gi > 0) {
            return [ 15, 20, 30, 45, 60, 90 ][gi - 1];
        }
        var info = actInfo();
        var wg = (info has :activeMinutesWeekGoal) ? info.activeMinutesWeekGoal : null;
        return (wg == null || wg <= 0) ? 30 : (wg + 6) / 7;
    }

    private function tzOffset() {
        return (cfg[Cfg.TZ] == Cfg.TZ_ZULU) ? 0 : cfg[Cfg.TZ] - 12;
    }

    // Wind force on the Beaufort scale (0..12) from a speed in m/s, by the official upper limits (in 0.1 m/s);
    // forces 11 and 12 start at 28.5 and 32.7 m/s.
    private const BFT = [ 5, 16, 34, 55, 80, 108, 139, 172, 208, 245 ]b;

    private function bft(ms) {
        if (ms == null) {
            return "--";
        }
        var v = ms * 10;
        var b = (v >= 327) ? 12 : ((v >= 285) ? 11 : 10);
        for (var i = 9; i >= 0; i -= 1) {
            if (v < BFT[i]) {
                b = i;
            }
        }
        return b.format("%d");
    }

    // Minutes until the next change between dry and wet, or null (none within 12 h).
    private function minsLeft() {
        return (rainChg == null) ? null : (rainChg - Time.now().value()) / 60;
    }

    // The next change between dry and wet, approximate on purpose: the forecast comes in 15-minute blocks (often
    // interpolated from hourly data outside Central Europe and North America). Line 3: "RAIN ~25M", "SNOW ~4H",
    // "DRY 12H+", "DRY ~25M", "RAIN +14MM" (raining with no end in 12 h: the amount still to come in those 12 h;
    // "RAIN 12H+" when it is under 0.5), and "RAIN DUE" / "DRY DUE"
    // once the forecast moment has passed; minutes rounded to 5 below 100 minutes, then whole hours.
    // Columns: "~25M", "~4H", "DRY", "DUE", and "NOW" while it falls.
    private function wetText(labelled, left) {
        if (wxWet == null) {
            return labelled ? "PRECIP --" : "--";
        }
        var t = null;
        if (left != null && left > 0) {
            var r = (left + 2) / 5 * 5;
            t = "~" + ((left < 100) ? ((r < 5) ? 5 : r).format("%d") + "M" : ((left + 30) / 60).format("%d") + "H");
        }
        var wet = wxWet == 1;
        if (!labelled) {
            return wet ? "NOW" : ((left == null) ? "DRY" : ((t == null) ? "DUE" : t));
        }
        var snow = (wxSnowP != null) ? wxSnowP == 1 : (wxTemp != null && wxTemp <= 1);
        var word = snow ? "SNOW" : "RAIN";
        if (left == null) {
            if (!wet) {
                return "DRY 12H+";
            }
            if (wxAmt == null || wxAmt < 0.5) {
                return word + " 12H+";
            }
            return word + " +" + (tempF ? (wxAmt / ((wxSnowP == 1) ? 2.54 : 25.4)).format("%.1f") + "IN"
                                        : num(wxAmt) + ((wxSnowP == 1) ? "CM" : "MM"));   // more to come in 12 h
        }
        return (wet ? "DRY" : word) + ((t == null) ? " DUE" : " " + t);
    }

    // Context: the weather or light message most likely to change what you do next. 1 act now: gusts of force 8+,
    // fog under 1 km, EXTREME air, freezing precipitation; 2 under 30 min of light left; 3 rain or snow starting or
    // stopping within 2 h; 4 light running out (2 h); 5 worth adapting to: thunderstorm potential HIGH+, force 7
    // gusts, UV 8+, POOR air or worse; 6 quiet: the dry/wet outlook ("DRY ~3H", or "RAIN +14MM" when it rains on),
    // or without weather the next sun event. Weather values expire with the forecast (clearNow).
    private function contextText() {
        var left = minsLeft();
        var ct = System.getClockTime();
        var nowMin = ct.hour * 60 + ct.min;
        var light = (sunsetMin >= 0 && nowMin >= sunriseMin && nowMin < sunsetMin) ? sunsetMin - nowMin : 999;
        var g = (wxGust == null) ? 0 : wxGust;
        var a = (wxAqi == null) ? 0 : wxAqi;
        var k = 6;                                       // 1 gust, 2 fog, 3 air, 4 freeze, 5 light, 6 dry/wet, 7 storm, 8 UV
        if (g >= 17.2) {
            k = 1;
        } else if (wxVis != null && wxVis < 1000) {
            k = 2;
        } else if (a >= 6) {
            k = 3;
        } else if (wxWet == 1 && wxTemp != null && wxTemp <= 1 && wxTemp >= -3) {
            k = 4;
        } else if (light <= 30) {
            k = 5;
        } else if (wxWet != null && left != null && left <= 120) {
            k = 6;
        } else if (light <= 120) {
            k = 5;
        } else if (capeV != null && capeV >= 1000) {
            k = 7;
        } else if (g >= 13.9) {
            k = 1;
        } else if (wxUv != null && wxUv >= 8) {
            k = 8;
        } else if (a >= 4) {
            k = 3;
        }
        if (k == 1) {
            return "GUST " + speedText(wxGust);
        } else if (k == 2) {
            return "FOG " + extraText(13, null) + (distMi ? " MI" : " KM");
        } else if (k == 3) {
            return lateText(7, true);
        } else if (k == 4) {
            return "FREEZE RISK";
        } else if (k == 5) {
            return "LIGHT " + hm(light);
        } else if (k == 7) {
            return lateText(12, true);
        } else if (k == 8) {
            return "UV " + num(wxUv) + " HIGH";
        }
        if (wxWet != null) {
            return wetText(true, left);
        }
        var ns = nextSun(nowMin);
        return (ns == null) ? "--" : "\u00a1" + ns[0] + "\u00a8" + hm(ns[1]);
    }

    // A speed in m/s as a number in km/h or mph ("--" if missing).
    private function speedNum(ms) {
        return (ms == null) ? "--" : num(ms * (distMi ? 2.23694 : 3.6));
    }

    private function speedText(ms) {
        return (ms == null) ? "--" : speedNum(ms) + (distMi ? " MPH" : " KMH");
    }

    // A height in metres in the user's elevation units, and the unit text.
    private function ft(m) {
        return elevFt ? m * 3.28084 : m;
    }

    private function eUnit() {
        return elevFt ? " FT" : " M";
    }

    // A duration in minutes as h:mm.
    private function hm(m) {
        return (m / 60).format("%d") + ":" + (m % 60).format("%02d");
    }

    // The share of the moon that is lit, 0..100.
    private function moonLit(nowS) {
        return (1.0 - Math.cos(2.0 * Math.PI * moonAge(nowS) / SYNODIC)) * 50.0;
    }

    // The pressure trend as a glyph: up, down or level.
    private function trendGlyph() {
        return (pressureTrend > 0) ? "\u00a5" : ((pressureTrend < 0) ? "\u00a6" : "\u00a7");
    }

    // The next sunrise or sunset: [its time text, minutes until it], or null without sun times.
    private function nextSun(nowMin) {
        if (sunriseMin < 0 || sunsetMin < 0) {
            return null;
        }
        if (nowMin < sunriseMin) {
            return [ sunriseText, sunriseMin - nowMin ];
        }
        if (nowMin < sunsetMin) {
            return [ sunsetText, sunsetMin - nowMin ];
        }
        return [ sunriseText, sunriseMin + 1440 - nowMin ];
    }

    // The activity data: the redraw's own copy while it runs, otherwise fetched.
    private function actInfo() {
        return (ami != null) ? ami : ActivityMonitor.getInfo();
    }

    private function degText(c) {
        return (c == null) ? "--" : num(userTemp(c)) + "\u00b0";
    }

    private function pctText(v) {
        return (v == null) ? "--" : num(v) + "%";
    }

    // Dew point from temperature and humidity (Magnus formula), C.
    private function dewPoint() {
        if (wxTemp == null || wxHum == null || wxHum <= 0) {
            return null;
        }
        var t = wxTemp.toFloat();
        var g = Math.ln(wxHum / 100.0) + 17.62 * t / (243.12 + t);
        return 243.12 * g / (17.62 - g);
    }

    // Today's local time (minutes) when the sun crosses a zenith angle; -1 if unknown.
    private function sunAt(zen, rising, dayShift) {
        if (locLat == null || locLon == null) {
            return -1;
        }
        var d = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var m = sunEvent(dayOfYear(d.year, d.month, d.day) + dayShift, locLat, locLon,
                         System.getClockTime().timeZoneOffset / 3600.0, rising, zen);
        return (m == null) ? -1 : m;
    }

    // "LABEL time" for the next of a morning / evening pair, e.g. BMNT 5:41 or EENT 19:52.
    private function pairText(zen, morningLabel, eveningLabel, settings) {
        var a = sunAt(zen, true, 0);
        var b = sunAt(zen, false, 0);
        if (a < 0 || b < 0) {
            return morningLabel + " --";
        }
        var ct = System.getClockTime();
        var nowMin = ct.hour * 60 + ct.min;
        var m = (nowMin < a || nowMin >= b) ? a : b;
        return ((m == a) ? morningLabel : eveningLabel) + " " + clockText(m / 60, m % 60, settings);
    }

    // Days from 1970-01-01 to a civil date (no time zone involved).
    private function dayNumber(y, m, d) {
        if (m <= 2) {
            y -= 1;
        }
        var era = y / 400;
        var yoe = y - era * 400;
        var mp = (m + 9) % 12;
        var doy = (153 * mp + 2) / 5 + d - 1;
        return era * 146097 + yoe * 365 + yoe / 4 - yoe / 100 + doy - 719468;
    }

    // Countdown to the date and time set in Time: "D-12 T-21:44" (line 3) or "D-12" (columns);
    // on the last day "T-05:42"; after the moment the signs flip to "+".
    private function countdownText(full) {
        var g = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var diff = cfg[Cfg.CD_TIME] * 900 - g.hour * 3600 - g.min * 60;
        if (cfg[Cfg.CD_YEAR] != 20) {                    // 20: every day (only the time counts; after it, T+)
            diff += (dayNumber(2026 + cfg[Cfg.CD_YEAR], cfg[Cfg.CD_MONTH] + 1, cfg[Cfg.CD_DAY] + 1)
                     - dayNumber(g.year, g.month, g.day)) * 86400;
        }
        var sign = (diff >= 0) ? "-" : "+";
        diff = diff.abs();
        var t = "T" + sign + (diff % 86400 / 3600).format("%02d") + ":" + (diff % 3600 / 60).format("%02d");
        if (diff < 86400) {
            return t;
        }
        var d = "D" + sign + (diff / 86400).format("%d");
        return full ? d + " " + t : d;
    }

    private function respiration(info) {
        return ((info has :respirationRate) && info.respirationRate != null) ? info.respirationRate : null;
    }

    // Line 3 texts for the options from Rain chance on (index 8 and up).
    private function line3Text(k, now, settings) {
        if (k > Cfg.R3_OFF) {
            return lateText(k - Cfg.R3_OFF - 1, true);
        }
        if ((k == 0 || k == 1) && polar != 0) {
            return (polar > 0) ? "POLAR DAY" : "POLAR NIGHT";
        }
        if (k == 0) {                                        // next sunrise/set, dot, time left
            var ct = System.getClockTime();
            var ns = nextSun(ct.hour * 60 + ct.min);
            return (ns == null) ? "\u00a1--:--" : "\u00a1" + ns[0] + "\u00a8" + hm(ns[1]);
        } else if (k == 1) {
            return sunriseText + "\u00a2" + sunsetText;
        } else if (k == 2) {
            return tzText(now, settings, true);
        } else if (k == 3) {
            return trendGlyph() + ((pressure == null) ? "--" : num(pressure / 100.0) + " HPA");
        } else if (k == 4) {
            return "\u00a3" + num(userTemp(wxHigh)) + "\u00a4" + num(userTemp(wxLow));
        } else if (k == 5) {
            return "\u00a9" + ((altitude == null) ? "--" : num(altitude) + eUnit());
        } else if (k == 6) {
            return "\u00aa" + compact(actInfo().steps);
        }
        if (k == 8) {
            return ((cfg[Cfg.WX_SOURCE] == 1) ? "RAIN 3H " : "RAIN ") + pctText(wxPrecip);   // Open-Meteo: next 3 hours
        } else if (k == 9) {
            return "HUMID " + pctText(wxHum);
        } else if (k == 10) {
            return "FEELS " + degText(wxFeels);
        } else if (k == 11) {
            return "DEW " + degText(dewPoint());
        } else if (k == 12) {
            if (sunriseMin < 0 || sunsetMin < 0) {
                return (polar == 0) ? "DAY --" : ((polar > 0) ? "DAY 24H" : "DAY 0H");
            }
            var len = sunsetMin - sunriseMin;
            var t = "DAY " + hm(len);
            var y0 = sunAt(90.833, true, -1);
            var y1 = sunAt(90.833, false, -1);
            if (y0 >= 0 && y1 >= 0) {
                var dl = len - (y1 - y0);
                t += " " + ((dl >= 0) ? "+" : "") + dl.format("%d") + "M";
            }
            return t;
        } else if (k == 13) {
            if (sunriseMin < 0 || sunsetMin < 0) {
                return "NOON --";
            }
            var nm = (sunriseMin + sunsetMin) / 2;
            return "NOON " + clockText(nm / 60, nm % 60, settings);
        } else if (k == 14) {
            return pairText(84.0, "GOLD TIL", "GOLD", settings);
        } else if (k == 15) {
            return pairText(96.0, "FIRST", "LAST", settings);
        } else if (k == 16) {
            return pairText(102.0, "BMNT", "EENT", settings);
        } else if (k == 17) {
            return "MOON " + num(moonLit(now.value())) + "%";
        } else if (k == 18) {
            var dd = 14.765 - moonAge(now.value());
            if (dd < 0) {
                dd += SYNODIC;
            }
            return (dd < 1.0) ? "FULL MOON" : "FULL " + dd.toNumber().format("%d") + "D";
        } else if (k == 19) {
            if (locLat == null || locLon == null) {
                return "--";
            }
            return locLat.abs().format("%.2f") + ((locLat >= 0) ? "N " : "S ")
                   + locLon.abs().format("%.2f") + ((locLon >= 0) ? "E" : "W");
        } else if (k == 20) {
            return countdownText(true);
        } else if (k == 21) {
            return "BREATH " + num(respiration(actInfo()));
        } else if (k == 22) {
            return "GUST " + speedText(wxGust);
        }
        return "CLOUD " + pctText(wxCloud);
    }

    // Column texts for the options from Wind on (k = kind - 14).
    private function extraText(k, info) {
        if (k == 34) {                                   // wind force (Beaufort), column
            return bft(wxWind);
        }
        if (k == 33) {                                   // metres descended today (column), in elevation units
            var md = (info has :metersDescended) ? info.metersDescended : null;
            return (md == null) ? "--" : num(ft(md));
        }
        if (k >= 18) {
            return lateText(k - 17, false);
        }
        if (k == 16) {
            return num(wxUv);
        } else if (k == 17) {
            return pctText(pctMetric(3));
        }
        if (k == 0) {
            return speedNum(wxWind);
        } else if (k == 1) {
            return pctText(wxPrecip);
        } else if (k == 2) {
            return pctText(wxHum);
        } else if (k == 3) {
            return degText(wxFeels);
        } else if (k == 4) {
            return degText(dewPoint());
        } else if (k == 5) {
            return num(userTemp(wxHigh)) + "/" + num(userTemp(wxLow));
        } else if (k == 6) {
            return num(restHr);
        } else if (k == 7) {
            return num(respiration(info));
        } else if (k == 8) {
            var mc = (info has :metersClimbed) ? info.metersClimbed : null;
            return (mc == null) ? "--" : num(ft(mc));
        } else if (k == 9) {
            return (info has :floorsDescended) ? num(info.floorsDescended) : "--";
        } else if (k == 10) {
            return countdownText(false);
        } else if (k == 11) {
            return speedNum(wxGust);
        } else if (k == 12) {
            return pctText(wxCloud);
        } else if (k == 13) {
            return (wxVis == null) ? "--" : (wxVis / (distMi ? 1609.34 : 1000.0)).format("%.1f");
        }
        return (wxRainMm == null) ? "--" : (tempF ? (wxRainMm / 25.4).format("%.2f") : wxRainMm.format("%.1f"));
    }

    // Small direction arrow (wind blowing toward the arrow), 9 px.
    private function drawArrowSmall(dc as Dc, cx, cy, bearing) as Void {
        if (bearing == null) {
            dc.fillRectangle(cx - 2, cy, 5, 1);
            return;
        }
        var a = (bearing + 180) * Math.PI / 180.0;
        var dx = Math.sin(a);
        var dy = -Math.cos(a);
        var tx = cx + 4 * dx;
        var ty = cy + 4 * dy;
        dc.drawLine(cx - 4 * dx, cy - 4 * dy, tx, ty);
        dc.fillPolygon([ [ tx + 1 * dx, ty + 1 * dy ], [ tx - 3 * dx + 3 * dy, ty - 3 * dy - 3 * dx ],
                         [ tx - 3 * dx - 3 * dy, ty - 3 * dy + 3 * dx ] ]);
    }

    // Chart layout: three columns, dotted dividers and the chart. On wrist raise the exact
    // gauge values appear just below the time, by each side gauge.
    private function drawChartLower(dc as Dc, info, stats, settings) as Void {
        if (fData == null) {
            loadLayoutResources();
        }
        if (detailsGauges() && fTiny != null) {
            var lv = gaugeValue(cfg[Cfg.GAUGE_L], info, stats);
            var rv = gaugeValue(cfg[Cfg.GAUGE_R], info, stats);
            var uvKind = Cfg.GA_OFF + 5;
            if (lv != null && cfg[Cfg.GAUGE_L] != Cfg.GA_OFF) {
                dc.drawText(12, 116, fTiny, num((cfg[Cfg.GAUGE_L] == uvKind) ? wxUv : lv), Graphics.TEXT_JUSTIFY_LEFT);
            }
            if (rv != null && cfg[Cfg.GAUGE_R] != Cfg.GA_OFF) {
                dc.drawText(161, 116, fTiny, num((cfg[Cfg.GAUGE_R] == uvKind) ? wxUv : rv), Graphics.TEXT_JUSTIFY_RIGHT);
            }
        }
        for (var c = 0; c < 3; c += 1) {
            drawColumn(dc, cfg[Cfg.COL1 + c], COL_X[c], info, stats, settings);
        }
        for (var y = 118; y <= 143; y += 2) {
            dc.drawPoint(64, y);
            dc.drawPoint(112, y);
        }
        if (cfg[Cfg.CHART] == 25) {
            // Big text instead of the chart: a line-3 metric in the 18 px font (the small font if too wide)
            var bc = cfg[Cfg.BIG];
            if (bc != Cfg.R3_OFF && fBig != null) {
                var bt = (bc == 7) ? "WIND " + speedText(wxWind) : line3Text(bc, Time.now(), settings);
                var bf = (dc.getTextWidthInPixels(bt, fBig) <= 120) ? fBig : fSmall;   // panel: x 26..150 at row 161
                dc.drawText(88, (bf == fBig) ? 149 : 152, bf, bt, Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
        drawChart(dc);
        if (detailsChart() && chartBars != null && fTiny != null) {
            // wrist raise: lowest value at the left edge, highest at the right edge, in the space beside the
            // chart (rows 146-153); they only overlap the outermost bars, on cleared patches
            var loT = chartText(chartLo);
            var hiT = chartText(chartHi);
            var lw = dc.getTextWidthInPixels(loT, fTiny);
            var hw = dc.getTextWidthInPixels(hiT, fTiny);
            dc.setColor(bg, bg);
            dc.fillRectangle(16, 145, lw + 9, 10);
            dc.fillRectangle(150 - hw, 145, hw + 9, 10);
            dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(17, 148, 5, 1);                 // down triangle, then the lowest value
            dc.fillRectangle(18, 149, 3, 1);
            dc.fillRectangle(19, 150, 1, 1);
            dc.drawText(23, 146, fTiny, loT, Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(151, 146, fTiny, hiT, Graphics.TEXT_JUSTIFY_RIGHT);
            dc.fillRectangle(155, 148, 1, 1);                // the highest value, then an up triangle
            dc.fillRectangle(154, 149, 3, 1);
            dc.fillRectangle(153, 150, 5, 1);
        }
    }

    // A chart value in its unit: pressure in hPa, altitude in m or ft, temperature in C or F.
    private function chartText(v) {
        var k = cfg[Cfg.CHART] / 3;
        if (k == Cfg.CH_PRESSURE) {
            v = v / 100.0;
        } else if (k == Cfg.CH_ALTITUDE && elevFt) {
            v = v * 3.28084;
        } else if (k == Cfg.CH_TEMP) {
            v = userTemp(v);
        }
        return num(v);
    }

    // Vertical side gauges on both edges (rows 85..132, the same span for both styles):
    //  style 0 Bar    thick fill from the bottom on a 1 px track (Enduro style)
    //  style 1 Blocks 12 square blocks (3 px, 1 px gaps); empty blocks show as a centre line
    // Ticks point inward at 25 / 50 / 75 % (the 50 % tick is longer); the glyph sits on top.
    // The right gauge sits 2 px further in than the left one mirrored: on the Instinct 3 Solar 45 mm the bezel
    // covers the screen's outermost columns on the right (user report), which cut the gauge off.
    private function drawSideGauges(dc as Dc, info, stats) as Void {
        for (var side = 0; side < 2; side += 1) {
            var kind = cfg[(side == 0) ? Cfg.GAUGE_L : Cfg.GAUGE_R];
            if (kind == Cfg.GA_OFF) {
                continue;
            }
            var left = side == 0;
            var value = gaugeValue(kind, info, stats);
            var blocks = cfg[Cfg.GAUGE_STYLE] == 1;
            if (blocks) {
                var bx = left ? 1 : 167;
                var lit = (value == null) ? 0 : (value * 12 / 100.0 + 0.5).toNumber();
                for (var i = 0; i < 12; i += 1) {
                    var y0 = 130 - 4 * i;
                    if (i < lit) {
                        dc.fillRectangle(bx, y0, 6, 3);
                    } else {
                        dc.fillRectangle(left ? 4 : 170, y0, 1, 3);
                    }
                }
            } else {
                dc.fillRectangle(left ? 2 : 171, 85, 1, 48);
                if (value != null) {
                    var h = (48 * ((value > 100) ? 100 : value) / 100.0 + 0.5).toNumber();
                    if (h > 0) {
                        dc.fillRectangle(left ? 1 : 169, 133 - h, 4, h);
                    }
                }
            }
            var tx = left ? (blocks ? 8 : 6) : (blocks ? 162 : 164);
            for (var q = 0; q < 3; q += 1) {
                var ty = 121 - 12 * q;                       // 25 %, 50 %, 75 %
                var len = (q == 1) ? 3 : 2;
                dc.fillRectangle(left ? tx : tx + 3 - len, ty, len, 1);
            }
            if (value != null && value > 100) {              // over goal: a small arrow on top
                var ax = left ? 2 : 168;
                dc.fillRectangle(ax + 1, 82, 2, 1);
                dc.fillRectangle(ax, 83, 4, 1);
            }
            drawIconBox(dc, Ic.GAUGE[kind], left ? 0 : 163, 73, 11, 9);
        }
    }

    // 0..100 for an edge gauge, or null when there is no data.
    private function gaugeValue(kind, info, stats) {
        if (kind > Cfg.GA_OFF) {
            return pctMetric(kind - Cfg.GA_OFF - 1);
        }
        if (kind == Cfg.GA_STRESS) {
            return stress;
        }
        if (kind == Cfg.GA_BB) {
            return bodyBattery;
        }
        if (kind == Cfg.GA_BATTERY) {
            return stats.battery;
        }
        if (kind == Cfg.GA_SOLAR) {
            return (stats has :solarIntensity) ? stats.solarIntensity : null;
        }
        if (kind == Cfg.GA_STEPS) {
            return ratioRaw(info.steps, info.stepGoal);
        }
        if (kind == Cfg.GA_INTENSITY) {
            if ((info has :activeMinutesWeek) && (info has :activeMinutesWeekGoal)) {
                var wk = info.activeMinutesWeek;
                if (wk != null) {
                    return ratioRaw(wk.total, info.activeMinutesWeekGoal);
                }
            }
            return null;
        }
        if (kind == Cfg.GA_FLOORS) {
            if ((info has :floorsClimbed) && (info has :floorsClimbedGoal)) {
                return ratioRaw(info.floorsClimbed, info.floorsClimbedGoal);
            }
            return null;
        }
        if (kind == Cfg.GA_MOVE) {
            if ((info has :moveBarLevel) && info.moveBarLevel != null) {
                return info.moveBarLevel * 20;   // levels 0..5
            }
            return null;
        }
        return daylightLeft();                           // share of today's daylight still to come
    }

    private function fieldText(kind, info, stats, settings) {
        if (kind == Cfg.FI_STEPS) {
            return compact(info.steps);
        }
        if (kind == Cfg.FI_INT_DAY || kind == Cfg.FI_INT_WEEK) {
            var am = null;
            if (kind == Cfg.FI_INT_DAY && (info has :activeMinutesDay)) {
                am = info.activeMinutesDay;
            }
            if (kind == Cfg.FI_INT_WEEK && (info has :activeMinutesWeek)) {
                am = info.activeMinutesWeek;
            }
            return (am == null) ? "--" : num(am.total);
        }
        if (kind == Cfg.FI_CALORIES) {
            return num(info.calories);
        }
        if (kind == Cfg.FI_DISTANCE) {
            var cm = info.distance;
            if (cm == null) {
                return "--";
            }
            var km = cm / (distMi ? 160934.4 : 100000.0);      // miles or km, per the watch
            return (km < 100.0) ? km.format("%.1f") : num(km);
        }
        if (kind == Cfg.FI_FLOORS) {
            return (info has :floorsClimbed) ? num(info.floorsClimbed) : "--";
        }
        if (kind == Cfg.FI_ALTITUDE) {
            return num(altitude);
        }
        if (kind == Cfg.FI_PRESSURE) {
            return (pressure == null) ? "--" : num(pressure / 100.0);
        }
        if (kind == Cfg.FI_NOTIF) {
            return num(settings.notificationCount);
        }
        if (kind == Cfg.FI_BATT_DAYS) {
            return (stats has :batteryInDays) ? num(stats.batteryInDays) : "--";
        }
        if (kind == Cfg.FI_BB) {
            return num(bodyBattery);
        }
        return num(stress);
    }

    // ------------------------------------------------------------ drawing

    // One column: icon on top, value in the 15 px data font below, centred.
    private function drawColumn(dc as Dc, kind, cx, info, stats, settings) as Void {
        if (kind == Cfg.CO_OFF) {
            return;
        }
        var icon;
        var text;
        if (kind >= 14) {
            text = extraText(kind - 14, info);
            icon = Ic.COL[kind - 14];
            if (kind == 14) {                                // wind: the icon is the direction arrow
                drawArrowSmall(dc, cx, 122, wxBearing);
                icon = 255;
            }
        } else if (kind == Cfg.CO_HR) {
            icon = Ic.I_HEART;
            text = num(currentHr());
        } else if (kind == Cfg.CO_SPO2) {
            icon = Ic.F_DROP;
            text = (spo2 == null) ? "--" : num(spo2) + "%";
        } else {
            icon = Ic.FIELD[kind];
            text = fieldText(kind, info, stats, settings);
        }
        if (icon != 255) {
            drawIconBox(dc, icon, cx - 5, 117, 11, 11);
        }
        var f = (dc.getTextWidthInPixels(text, fData) > 46) ? fSmall : fData;
        dc.drawText(cx, (f == fData) ? 129 : 131, f, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function colWants(kind) {
        return cfg[Cfg.COL1] == kind || cfg[Cfg.COL2] == kind || cfg[Cfg.COL3] == kind;
    }

    // Average per slot over the span; null if there is no data at all.
    // Solar chart: from its own recorder (one reading a minute), sorted into the slots.
    private function computeChart(kind, span, nowSec) {
        var n = GRAPH_BARS;
        var sums = new [n];
        var counts = new [n]b;
        for (var i = 0; i < n; i += 1) {
            sums[i] = 0.0;
        }
        var start = nowSec - span;
        for (var k = 0; k < span / 60 && k < SOLAR_LEN; k += 1) {
            var sv = solarBuf[(solarPos - 1 - k + 2 * SOLAR_LEN) % SOLAR_LEN];
            if (sv != 255) {
                var slotS = (((solarLastMin - k) * 60 - start) * n) / span;
                if (slotS >= 0 && slotS < n) {
                    sums[slotS] += sv;
                    counts[slotS] += 1;
                }
            }
        }
        return barsOf(sums, counts);
    }

    // Slot averages -> bar heights 1..GRAPH_MAX_H (0 = no data), as bytes; also keeps the chart's range.
    private function barsOf(sums, counts) {
        var lo = null;
        var hi = null;
        var i;
        for (i = 0; i < GRAPH_BARS; i += 1) {
            if (counts[i] > 0) {
                var a = sums[i] / counts[i];
                lo = (lo == null || a < lo) ? a : lo;
                hi = (hi == null || a > hi) ? a : hi;
            }
        }
        if (lo == null) {
            return null;
        }
        chartLo = lo;
        chartHi = hi;
        var bars = new [GRAPH_BARS]b;
        for (i = 0; i < GRAPH_BARS; i += 1) {
            if (counts[i] > 0) {
                bars[i] = (hi > lo) ? 1 + ((sums[i] / counts[i] - lo) * (GRAPH_MAX_H - 1) / (hi - lo)).toNumber() : 6;
            }
        }
        return bars;
    }

    // History charts (heart rate, stress, Body Battery, pressure, altitude, temperature, Pulse Ox) are kept
    // incrementally on a fixed time grid: the whole window is read only outside redraws (rebuildChart, from
    // onShow or onEnterSleep); each minute only the samples since the last read are added (updateChart).
    private function slotOf(sec, span) {
        return (sec.toLong() * GRAPH_BARS / span).toNumber();
    }

    private function chartSpan() {
        var n = cfg[Cfg.CHART] % 3;
        return (n == 0) ? 3600 : ((n == 1) ? 10800 : 14400); // 1 h, 3 h, 4 h
    }

    private function rebuildChart() as Void {
        var kind = cfg[Cfg.CHART] / 3;
        cKey = cfg[Cfg.CHART];
        cStale = false;
        if (cfg[Cfg.LAYOUT] != 1 || kind >= Cfg.CH_SOLAR) {   // Rows layout, solar (own recorder) or off
            cSum = null;
            cCnt = null;
            chartBars = null;
            return;
        }
        var span = chartSpan();
        var now = Time.now().value();
        cSum = new [GRAPH_BARS];
        cCnt = new [GRAPH_BARS]b;
        for (var i = 0; i < GRAPH_BARS; i += 1) {
            cSum[i] = 0.0;
        }
        cSlot = slotOf(now, span);
        cRead = now - span - 60;
        if (!addHistory(kind, span, span + 60)) {
            cSum = null;                                     // no room even here: try again later
            return;
        }
        chartBars = barsOf(cSum, cCnt);
    }

    // Each minute (inside the redraw): move the window to now and add the samples since the last read.
    private function updateChart(nowSec) as Void {
        if (cSum == null || cKey != cfg[Cfg.CHART]) {
            return;                                          // rebuilt outside redraws
        }
        var span = chartSpan();
        var shift = slotOf(nowSec, span) - cSlot;
        if (shift > 9) {
            cStale = true;                                   // a long gap: read the whole window again at the
        }                                                    // next wrist raise (onEnterSleep), outside a redraw
        if (shift > 0) {
            for (var i = 0; i < GRAPH_BARS; i += 1) {
                var src = i + shift;
                cSum[i] = (src < GRAPH_BARS) ? cSum[src] : 0.0;
                cCnt[i] = (src < GRAPH_BARS) ? cCnt[src] : 0;
            }
            cSlot += shift;
        }
        // the watch writes its history in batches, often minutes late while asleep: read everything since the
        // newest sample already added, up to 30 minutes, so a late batch is never lost
        var since = nowSec - cRead + 60;
        var kind = cfg[Cfg.CHART] / 3;
        addHistory(kind, span, (since < 1800) ? since : 1800);
        // until the batch arrives, the newest bar shows the live value (heart rate) or the latest one read,
        // once, so the chart never trails behind; the real samples join the same bar later
        if (cCnt[GRAPH_BARS - 1] == 0) {
            var lv = (kind == Cfg.CH_HR && hrNow != null) ? hrNow.toFloat() : cLast;
            if (lv != null && validSample(kind, lv)) {
                cSum[GRAPH_BARS - 1] = lv;
                cCnt[GRAPH_BARS - 1] = 1;
            }
        }
        chartBars = barsOf(cSum, cCnt);
    }

    // Adds the samples newer than cRead (from the last `seconds`) to their slots; false if skipped for memory.
    private function addHistory(kind, span, seconds) {
        var iter = history(kind, seconds, false);
        if (iter == null) {
            return false;
        }
        var newest = cRead;
        var smp = iter.next();
        while (smp != null) {
            var d = smp.data;
            var w = smp.when;
            if (d != null && w != null && w.value() > cRead) {
                var v = d.toFloat();
                var k = GRAPH_BARS - 1 - (cSlot - slotOf(w.value(), span));
                if (validSample(kind, v) && k >= 0 && k < GRAPH_BARS && cCnt[k] < 255) {
                    cSum[k] += v;
                    cCnt[k] += 1;
                    cLast = v;                               // the latest value read (samples come oldest first)
                }
                newest = (w.value() > newest) ? w.value() : newest;
            }
            smp = iter.next();
        }
        cRead = newest;
        return true;
    }

    // One solar sample a minute into a ring buffer; saved every 10 minutes.
    private function recordSolar(nowSec) as Void {
        if (solarBuf == null) {
            return;                                      // history only kept for the solar chart
        }
        var stats = System.getSystemStats();
        var v = 255;
        if (stats has :solarIntensity) {
            var si = stats.solarIntensity;
            if (si != null && si >= 0) {
                v = (si > 100) ? 100 : si.toNumber();
            }
        }
        var m = nowSec / 60;
        if (solarLastMin >= 0) {
            var gap = m - solarLastMin;
            if (gap <= 0) {
                return;
            }
            if (gap > SOLAR_LEN) {
                gap = SOLAR_LEN;
            }
            for (var i = 1; i < gap; i += 1) {
                solarBuf[solarPos] = 255;
                solarPos = (solarPos + 1) % SOLAR_LEN;
            }
        }
        solarBuf[solarPos] = v;
        solarPos = (solarPos + 1) % SOLAR_LEN;
        solarLastMin = m;
        solarSaveCount += 1;
        if (solarSaveCount >= 10) {
            solarSaveCount = 0;
            Application.Storage.setValue("solarBuf", solarBuf);
            Application.Storage.setValue("solarPos", solarPos);
            Application.Storage.setValue("solarT", solarLastMin);
        }
    }

    private function drawChart(dc as Dc) as Void {
        var bars = chartBars;
        if (bars == null) {
            return;
        }
        for (var i = 0; i < GRAPH_BARS; i += 1) {
            var hgt = bars[i];
            if (hgt > 0) {
                dc.fillRectangle(GRAPH_X + 2 * i, GRAPH_BOTTOM - hgt, 1, hgt);
            }
        }
    }

    // ------------------------------------------------------------ kept from build 2

    // Wrist raise: the watch redraws every second for a few seconds; show exact values meanwhile.
    function onExitSleep() as Void {
        awake = true;
        if (fSmall != null) {
            readOutside();                               // fresh gauge values the moment the wrist is raised
        }
        WatchUi.requestUpdate();
    }

    function onEnterSleep() as Void {
        awake = false;
        behindMenu = false;                              // safety net: the watch went idle, so no menu is in use
        if (fSmall != null && (cSum == null || cKey != cfg[Cfg.CHART] || cStale)) {
            rebuildChart();                              // never recreate chart buffers while settings are open
        }
        if (fSmall != null && Time.now().value() - sunRead >= 900) {
            updateSun();                                 // position and sun times, outside a redraw
        }
        if (fSmall != null) {
            readOutside();                               // stress, Body Battery, watch temperature, outside a redraw
        }
        WatchUi.requestUpdate();
    }

    // Wrist-raise details, switched on or off per layout in the settings.
    private function detailsRows() {
        return awake && (cfg[Cfg.WRIST] & 1) == 0;       // Rows layout: percent of goal, heart-rate zone
    }

    // Chart layout on wrist raise: side-gauge values (bit 2) and the chart's min / max (bit 4), each on its own.
    private function detailsGauges() {
        return awake && (cfg[Cfg.WRIST] & 2) == 0;
    }

    private function detailsChart() {
        return awake && (cfg[Cfg.WRIST] & 4) == 0;
    }

    // While the face is hidden (for example its settings menu is open), drop everything that
    // can be reloaded, so the menu has room. onShow loads it again.
    function onHide() as Void {
        if (solarBuf != null) {
            Application.Storage.setValue("solarBuf", solarBuf);
            Application.Storage.setValue("solarPos", solarPos);
            Application.Storage.setValue("solarT", solarLastMin);
        }
        fData = null;
        fTiny = null;
        chartBars = null;
        solarBuf = null;
        fBig = null;
        cSum = null;                                   // chart history is rebuilt by onShow()
        cCnt = null;
        hrZones = null;                                // profile zones are reread on the next minute
        fMinutes = null;
        minutesStyle = -1;
        fMid = null;
        fMed = null;
        fSmall = null;                               // all fonts go: the menu gets the room
        fTime = null;
        fIcons = null;
    }

    // Called by the app when settings change in the Garmin Connect app.
    function settingsChanged() as Void {
        onShow();
    }

    // Back in front (start, or after the settings menu): the light reload, plus the saved weather and the
    // chart's full history, which may only be read here and outside redraws.
    function onShow() as Void {
        behindMenu = false;
        reloadLight();
        wxTs = null;                                    // settings may have changed: apply the saved weather again
        ccRead = -1000;
        loadWeather(Application.Storage.getValue("wx"), Time.now().value());
        rebuildChart();                                  // the chart's full history read, outside a redraw
        updateSun();                                     // position and sun times (settings may have changed)
        readOutside();
    }

    // Fonts, settings, theme and layout resources only. Used by onShow and by a redraw that finds the fonts
    // released (the watch can redraw the face while its settings menu opens): a redraw never reads the saved
    // weather or the chart's history; the chart is rebuilt at the next onShow or wrist raise instead.
    private function reloadLight() as Void {
        if (fSmall == null) {                            // first show, or after the settings menu freed them
            fSmall = WatchUi.loadResource(Rez.Fonts.Small);
            fMid = WatchUi.loadResource(Rez.Fonts.Mid);
            fMed = WatchUi.loadResource(Rez.Fonts.Med);
            fTime = WatchUi.loadResource(Rez.Fonts.Time);
            fIcons = WatchUi.loadResource(Rez.Fonts.Icons);
        }
        cfg = Cfg.loadAll();
        applyTheme();
        loadMinutesFont();
        loadLayoutResources();
        lastMinute = -1;
    }

    // Minutes style: 0 dithered (solid in the light theme), 1 solid, 2 outlined, 3 dithered always.
    // Dithered minutes use the solid time font plus a checkerboard drawn over them in the
    // background colour (see drawTime), so no second 41 px font has to be in memory.
    private function loadMinutesFont() as Void {
        if (fTime == null) {
            return;
        }
        var style = cfg[Cfg.MINUTES];
        if (style == 0 && cfg[Cfg.THEME] == 1) {
            style = 1;
        } else if (style == 3) {
            style = 0;
        }
        ditherMinutes = style == 0;
        if (style == minutesStyle && fMinutes != null) {
            return;
        }
        fMinutes = null;
        fMinutes = (style == 2) ? WatchUi.loadResource(Rez.Fonts.TimeOutline) : fTime;
        minutesStyle = style;
    }
    private function applyTheme() as Void {
        var light = cfg[Cfg.THEME] == 1;
        fg = light ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;
        bg = light ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
    }

    private function history(kind, seconds, newestFirst) {
        if (!(Toybox has :SensorHistory)) {
            return null;
        }
        // Safety net: the watch prepares the history in memory. With little room left (heavy setups,
        // inside a redraw) skip it this minute; the callers keep their previous values.
        if (System.getSystemStats().freeMemory < 2500) {
            histLow = true;
            return null;
        }
        var opts = {
            :period => new Time.Duration(seconds),
            :order => newestFirst ? SensorHistory.ORDER_NEWEST_FIRST : SensorHistory.ORDER_OLDEST_FIRST
        };
        if (kind == Cfg.CH_HR && (SensorHistory has :getHeartRateHistory)) {
            return SensorHistory.getHeartRateHistory(opts);
        }
        if (kind == Cfg.CH_STRESS && (SensorHistory has :getStressHistory)) {
            return SensorHistory.getStressHistory(opts);
        }
        if (kind == Cfg.CH_BB && (SensorHistory has :getBodyBatteryHistory)) {
            return SensorHistory.getBodyBatteryHistory(opts);
        }
        if (kind == Cfg.CH_PRESSURE && (SensorHistory has :getPressureHistory)) {
            return SensorHistory.getPressureHistory(opts);
        }
        if (kind == Cfg.CH_ALTITUDE && (SensorHistory has :getElevationHistory)) {
            return SensorHistory.getElevationHistory(opts);
        }
        if (kind == Cfg.CH_TEMP && (SensorHistory has :getTemperatureHistory)) {
            return SensorHistory.getTemperatureHistory(opts);
        }
        if (kind == Cfg.CH_SPO2 && (SensorHistory has :getOxygenSaturationHistory)) {
            return SensorHistory.getOxygenSaturationHistory(opts);
        }
        return null;
    }

    private function validSample(kind, v) {
        if (kind == Cfg.CH_HR) {
            return v > 0 && v < 255;
        }
        if (kind == Cfg.CH_STRESS || kind == Cfg.CH_BB || kind == Cfg.CH_SPO2) {
            return v >= 0 && v <= 100;
        }
        if (kind == Cfg.CH_PRESSURE) {
            return v > 10000;   // Pa
        }
        return true;
    }

    // The latest valid sample of the last hour (enough for the watch's delayed history writing while asleep,
    // and half the memory of two hours), or null.
    // The watch's temperature: a skipped or empty read keeps the last value (the watch records temperature
    // less often than heart rate, so it looks back 2 hours).
    private function readWatchTemp() as Void {
        var v = newest(Cfg.CH_TEMP);
        watchTemp = (v != null) ? v : watchTemp;
    }

    // Outside redraws (onShow, wrist raise, back to sleep): the history reads for stress, Body Battery and the
    // watch temperature get the room the minute's redraw may lack (with heavy setups it skips them every
    // minute). A skipped or empty read keeps the last value.
    private function readOutside() as Void {
        var v = newest(Cfg.CH_STRESS);
        stress = (v != null) ? v : stress;
        v = newest(Cfg.CH_BB);
        bodyBattery = (v != null) ? v : bodyBattery;
        if (lineShows(27) || (cfg[Cfg.LAYOUT] == 1 && colWants(33))) {
            readWatchTemp();
        }
    }

    private function newest(kind) {
        var iter = history(kind, (kind == Cfg.CH_TEMP) ? 7200 : 3600, true);
        if (iter == null) {
            return null;
        }
        var sample = iter.next();
        while (sample != null) {
            var d = sample.data;
            if (d != null) {
                var v = d.toFloat();
                if (validSample(kind, v)) {
                    return v;
                }
            }
            sample = iter.next();
        }
        return null;
    }

    private function readWeatherAndSun(now, settings) as Void {
        // Garmin weather: read every minute. With Open-Meteo selected, Garmin's conditions only give the
        // position, which hardly changes: read them every 15 minutes, and keep the Open-Meteo values.
        var wxMode = cfg[Cfg.WX_SOURCE] == 1;
        var cc = null;
        if ((Toybox has :Weather) && (!wxMode || now.value() - ccRead >= 900)) {
            cc = Weather.getCurrentConditions();
            ccRead = now.value();
        }
        if (!wxMode) {
            clearWeather();
        }
        // With Open-Meteo selected, Garmin's conditions only give the position for the fetch:
        // every weather value comes from Open-Meteo, or shows "--" (with the reason) while it has none.
        if (cc != null && cfg[Cfg.WX_SOURCE] != 1) {
            wxCondition = cc.condition;
            wxTemp = cc.temperature;
            wxHigh = cc.highTemperature;
            wxLow = cc.lowTemperature;
            wxPrecip = cc.precipitationChance;
            wxWind = cc.windSpeed;
            wxBearing = cc.windBearing;
            wxHum = (cc has :relativeHumidity) ? cc.relativeHumidity : null;
            wxFeels = (cc has :feelsLikeTemperature) ? cc.feelsLikeTemperature : null;
        }
    }

    // Position and sun times, worked out outside redraws (onShow, and onEnterSleep at most every 15 minutes; in
    // a redraw only after 6 hours without), with the face's own sun formula (within about 2 minutes of NOAA).
    private function updateSun() as Void {
        var now = Time.now();
        sunRead = now.value();
        var loc = null;
        if (Toybox has :Position) {                      // the watch's own fix, if under 2 hours old
            var pi = Position.getInfo();
            if (pi != null && pi.position != null && pi.when != null && now.value() - pi.when.value() < 7200
                    && pi.accuracy != Position.QUALITY_NOT_AVAILABLE) {
                loc = pi.position;
            }
        }
        if (loc == null && (Toybox has :Weather)) {
            var cc = Weather.getCurrentConditions();
            if (cc != null) {
                loc = cc.observationLocationPosition;    // where Garmin's weather comes from (may be a station)
            }
        }
        if (loc == null) {
            var ai = Activity.getActivityInfo();
            if (ai != null && (ai has :currentLocation)) {
                loc = ai.currentLocation;
            }
        }
        if (loc != null) {
            rememberLocation(loc.toDegrees());
        }
        if (locLat == null || locLon == null) {
            return;
        }
        var day = Gregorian.info(now, Time.FORMAT_SHORT);
        var n = dayOfYear(day.year, day.month, day.day);
        var tz = System.getClockTime().timeZoneOffset / 3600.0;
        var r = sunEvent(n, locLat, locLon, tz, true, 90.833);
        var f = sunEvent(n, locLat, locLon, tz, false, 90.833);
        if (r != null && f != null) {
            var settings = System.getDeviceSettings();
            polar = 0;
            sunriseMin = r;
            sunsetMin = f;
            sunriseText = clockText(r / 60, r % 60, settings);
            sunsetText = clockText(f / 60, f % 60, settings);
        } else {
            // no sunrise or sunset today: polar day if the sun is above the horizon at noon, else polar night
            var dec = 23.44 * Math.sin(2 * Math.PI * (284 + n) / 365.0);
            polar = (90.0 - (locLat - dec).abs() > 0) ? 1 : -1;
            sunriseMin = -1;
            sunsetMin = -1;
            sunriseText = "--:--";
            sunsetText = "--:--";
        }
    }

    // Pressure now, its 3-hour change and trend. The whole 3 hours (for the change, trend and storm alert)
    // are read every 15 minutes; in between only the last 10 minutes, for the current value.
    // Pressure shown: the live sea-level pressure (station pressure if the watch has no sea-level value, then
    // the last history value), read each minute without a history read. The 3-hour change, trend and storm
    // alert compare history values only (station pressure, like with like), read every 15 minutes.
    private function readPressure(nowSec) as Void {
        if (nowSec - pressRead >= 900) {
            var iter = history(Cfg.CH_PRESSURE, 10800, false);
            if (iter != null) {                          // skipped for memory: keep the previous values
                pressRead = nowSec;
                var first = null;
                var last = null;
                var sample = iter.next();
                while (sample != null) {
                    var d = sample.data;
                    if (d != null) {
                        var v = d.toFloat();
                        if (validSample(Cfg.CH_PRESSURE, v)) {
                            if (first == null) {
                                first = v;
                            }
                            last = v;
                        }
                    }
                    sample = iter.next();
                }
                iter = null;
                pressLast = last;
                pressureTrend = 0;
                pressureDrop = (first != null && last != null) ? first - last : 0.0;
                if (first != null && last != null) {
                    if (last - first > 100.0) {
                        pressureTrend = 1;
                    } else if (first - last > 100.0) {
                        pressureTrend = -1;
                    }
                }
            }
        }
        var ai = Activity.getActivityInfo();
        var live = null;
        if (ai != null) {
            if ((ai has :meanSeaLevelPressure) && ai.meanSeaLevelPressure != null) {
                live = ai.meanSeaLevelPressure;
            } else if ((ai has :ambientPressure) && ai.ambientPressure != null) {
                live = ai.ambientPressure;
            }
        }
        if (live != null && validSample(Cfg.CH_PRESSURE, live.toFloat())) {
            pressure = live.toFloat();
        } else if (pressLast != null) {
            pressure = pressLast;
        }
    }

    // Weather (Open-Meteo) values. The saved data is never read during a redraw (it is the largest single
    // read): it is applied when a fetch arrives (weatherArrived, with the data already in memory) and when the
    // face is shown (onShow). Each minute only its age is checked.
    private function checkWeatherAge(nowSec) as Void {
        if (cfg[Cfg.WX_SOURCE] != 1) {
            wxNote = null;
            return;
        }
        if (wxTs == null) {
            return;
        }
        var age = nowSec - wxTs;
        if (age > 43200 || dayOf(wxTs) != dayOf(nowSec)) {
            wxTs = null;                                // forecasts too old (or from another day): clear all
            clearWeather();
            wxNote = errNote(Application.Storage.getValue("wxErr"));
        } else if (age > wxMaxAge() && !wxStale) {
            wxStale = true;                             // only the "now" values: forecasts stay, off-grid too
            clearNow();
            wxNote = errNote(Application.Storage.getValue("wxErr"));
        }
    }

    private function wxMaxAge() {
        return Cfg.WX_MINUTES[cfg[Cfg.WX_INTERVAL]] * 120 + 600;    // 2 intervals + 10 min
    }

    private function errNote(err) {
        return (err instanceof Lang.Number) ? ((err == -1) ? "NO GPS" : "ERR" + err) : "NO DATA";
    }

    // Applies a weather summary (from a fetch or from storage), or shows why there is none.
    private function loadWeather(o, nowSec) as Void {
        if (cfg == null || cfg[Cfg.WX_SOURCE] != 1) {
            return;
        }
        var ts = (o instanceof Lang.Array && o.size() == 36) ? o[0] : null;   // a summary, or an error number
        if (ts == null || nowSec - ts > 43200 || dayOf(ts) != dayOf(nowSec)) {   // forecasts: up to 12 h, same day
            if (wxTs == null) {                         // keep fresh values when only an error arrived
                clearWeather();
                wxNote = errNote((o instanceof Lang.Number) ? o : Application.Storage.getValue("wxErr"));
            }
            return;
        }
        if (!(o instanceof Lang.Array)) {                // tells the compiler: from here on, o is an array
            return;
        }
        wxNote = null;
        wxStale = false;
        clearWeather();
        wxTs = ts;
        wxTemp = o[1];
        wxCondition = o[2];
        wxHigh = o[12];
        wxLow = o[13];
        wxPrecip = o[14];
        wxWind = o[5];
        wxBearing = o[6];
        wxHum = o[3];
        wxFeels = o[4];
        wxGust = o[7];
        wxCloud = o[8];
        wxVis = o[9];
        wxRainMm = o[10];
        wxUv = o[11];
        wxAqi = o[29];
        rainChg = o[23];
        wxWet = o[33];
        wxSnowP = o[34];
        wxAmt = o[35];
        airErr = o[32];
        n3Temp = o[15];
        n3Cond = o[16];
        n3Precip = o[17];
        tmHigh = o[18];
        tmLow = o[19];
        tmCond = o[20];
        tmPrecip = o[21];
        tmDow = o[22];
        uvMax = o[24];
        rainDay = o[25];
        capeV = o[26];
        frzLvl = o[27];
        snow24 = o[28];
        polLvl = o[30];
        polType = o[31];
        checkWeatherAge(nowSec);                         // older than the "now" limit: keep only the forecasts
    }

    // Called by the app when a background fetch (or its error) arrived, outside a redraw.
    function weatherArrived(data) as Void {
        // a server error (5xx): fetch again in 5 minutes, until a success; without phone (-104) or position (-1)
        // stay at the normal interval, so a phone left behind does not wake the watch every 5 minutes
        wxRetry = (data instanceof Lang.Number) && data >= 500;
        loadWeather(data, Time.now().value());
        lastMinute = -1;
    }

    // Day of the month of a time in seconds (forecasts are only kept on the day they were fetched).
    private function dayOf(sec) {
        return Gregorian.info(new Time.Moment(sec), Time.FORMAT_SHORT).day;
    }

    // All weather values.
    private function clearWeather() as Void {
        clearNow();
        tmHigh = null;
        tmLow = null;
        tmCond = null;
        tmPrecip = null;
        tmDow = null;
        uvMax = null;
        rainDay = null;
        frzLvl = null;
        snow24 = null;
        polLvl = null;
        polType = 0;
        wxHigh = null;
        wxLow = null;
    }

    // The "now" values (current conditions and the next hours), which go stale first.
    private function clearNow() as Void {
        n3Temp = null;                                   // Next 3 hours / Tomorrow come only from Open-Meteo
        n3Cond = null;
        n3Precip = null;
        capeV = null;
        wxCondition = null;
        wxTemp = null;
        wxPrecip = null;
        wxWind = null;
        wxBearing = null;
        wxHum = null;
        wxFeels = null;
        wxGust = null;
        wxCloud = null;
        wxVis = null;
        wxRainMm = null;
        wxUv = null;
        wxAqi = null;
        rainChg = null;
        wxWet = null;
        wxSnowP = null;
        wxAmt = null;
        airErr = null;
    }

    private function manageBackground() as Void {
        if (!(Toybox has :Background)) {
            return;
        }
        var want = (cfg[Cfg.WX_SOURCE] == 1) ? (wxRetry ? 5 : Cfg.WX_MINUTES[cfg[Cfg.WX_INTERVAL]]) : 0;   // after an error: every 5 min
        if (regMinutes < 0) {
            var r = Application.Storage.getValue("wxReg");
            regMinutes = (r instanceof Lang.Number) ? r : 0;
        }
        var registered = Background.getTemporalEventRegisteredTime();
        if (want == 0) {
            if (registered != null) {
                Background.deleteTemporalEvent();
            }
        } else if (registered == null || regMinutes != want) {
            Background.registerForTemporalEvent(new Time.Duration(want * 60));
        }
        if (regMinutes != want) {
            regMinutes = want;
            Application.Storage.setValue("wxReg", want);
        }
    }

    private function rememberLocation(deg) as Void {
        if (deg == null || deg.size() < 2) {
            return;
        }
        var la = deg[0].toFloat();
        var lo = deg[1].toFloat();
        if (la < -90.0 || la > 90.0 || lo < -180.0 || lo > 180.0 || (la == 0.0 && lo == 0.0)) {
            return;
        }
        var moved = true;
        if (locLat != null && locLon != null) {
            var dLa = la - locLat;
            var dLo = lo - locLon;
            if (dLa < 0) {
                dLa = -dLa;
            }
            if (dLo < 0) {
                dLo = -dLo;
            }
            moved = dLa > 0.05 || dLo > 0.05;
        }
        locLat = la;
        locLon = lo;
        if (moved) {
            Application.Storage.setValue("loc", [ la, lo ]);
        }
    }

    // ------------------------------------------------------------ values

    private function num(v) {
        if (v == null) {
            return "--";
        }
        var f = v.toFloat();
        return (f + (f < 0 ? -0.5 : 0.5)).toNumber().format("%d");
    }

    private function drawWeather(dc as Dc) as Void {
        var night = polar < 0;                           // polar night: the night icons all day
        if (sunriseMin >= 0 && sunsetMin >= 0) {
            var t = System.getClockTime();
            var nowMin = t.hour * 60 + t.min;
            night = (nowMin < sunriseMin) || (nowMin >= sunsetMin);
        }
        var icon = weatherIcon(wxCondition, night);
        drawIcon(dc, icon, subCx - Ic.W[icon] / 2, subCy - 25 + (23 - Ic.H[icon]) / 2);

        // Celsius, centred on its digits; the degree sign hangs to the right
        var numText = "--";
        if (wxTemp != null) {
            var deg = userTemp(wxTemp).toFloat();
            numText = (deg + (deg < 0 ? -0.5 : 0.5)).toNumber().format("%d");
        }
        if (wxNote != null) {                           // Open-Meteo selected but no data: say why
            dc.drawText(subCx, subCy + 4, fSmall, wxNote, Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        var tx = subCx - dc.getTextWidthInPixels(numText, fMid) / 2;
        dc.drawText(tx, subCy + 2, fMid, numText + "°", Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function isoWeek(year, month, day, dow) {
        var n = dayOfYear(year, month, day);
        var wd = ((dow + 5) % 7) + 1;          // Monday = 1 .. Sunday = 7
        var w = (n - wd + 10) / 7;
        if (w < 1) {
            return weeksInYear(year - 1);
        }
        if (w > weeksInYear(year)) {
            return 1;
        }
        return w;
    }

    private function weeksInYear(y) {
        var p = (y + y / 4 - y / 100 + y / 400) % 7;
        var y1 = y - 1;
        var q = (y1 + y1 / 4 - y1 / 100 + y1 / 400) % 7;
        return (p == 4 || q == 3) ? 53 : 52;
    }

    private function drawMoon(dc as Dc, cx, cy, r, nowSec) as Void {
        var age = moonAge(nowSec);
        var k = Math.cos(2.0 * Math.PI * age / SYNODIC);
        var waxing = age < SYNODIC / 2.0;
        if (locLat != null && locLat < 0) {
            waxing = !waxing;              // southern hemisphere sees it mirrored
        }
        var r2 = (r + 0.5) * (r + 0.5);
        for (var dy = -r; dy <= r; dy += 1) {
            var ady = dy < 0 ? -dy : dy;
            var w = halfWidth(r2, dy);
            var wn = halfWidth(r2, ady + 1);
            if (wn < 0) {
                wn = 0;
            }
            var edge = w - wn;
            if (edge < 1) {
                edge = 1;
            }
            if (ady == r) {
                dc.fillRectangle(cx - w, cy + dy, 2 * w + 1, 1);
            } else {
                dc.fillRectangle(cx - w, cy + dy, edge, 1);
                dc.fillRectangle(cx + w - edge + 1, cy + dy, edge, 1);
            }
            var t = ceilNum(k * w);
            var a;
            var b;
            if (waxing) {
                a = cx + t;
                b = cx + w;
            } else {
                a = cx - w;
                b = cx - t;
            }
            if (b >= a) {
                dc.fillRectangle(a, cy + dy, b - a + 1, 1);
            }
        }
    }

    private function moonAge(nowSec) {
        var age = (nowSec - NEW_MOON) / 86400.0;
        return age - (age / SYNODIC).toNumber() * SYNODIC;
    }

    private function halfWidth(r2, dy) {
        var q = r2 - dy * dy;
        if (q < 0) {
            return -1;
        }
        return Math.sqrt(q).toNumber();
    }

    private function ceilNum(x) {
        var t = x.toNumber();
        if (x > t) {
            t += 1;
        }
        return t;
    }

    // Time anchored on the colon at x 88: hours end and minutes start 3 px from the colon,
    // measured on the digits' ink (TimeInk), so both gaps are equal. Without a colon the
    // digits get 2 px extra spacing and the gap between hours and minutes is centred.
    // Hours end 4 px left of the colon's edge and minutes start 4 px right of it, by the digits' ink. Positions
    // come from the font's own metrics (TimeInk: ink offset X, ink width W, advance A per digit, generated with
    // the fonts), so the clock is drawn without temporary texts or measurements (idea from the ChatGPT review).
    private function drawTime(dc as Dc, clock, settings) as Void {
        var h = clock.hour;
        var two = use24(settings);                       // 24 h: always two hour digits
        if (!two) {
            h = h % 12;
            if (h == 0) {
                h = 12;
            }
            two = h >= 10;
        }
        var m = clock.min;
        var mFont = (fMinutes != null) ? fMinutes : fTime;
        var style = cfg[Cfg.COLON];
        var extra = (style == 0) ? 2 : 0;                // no colon: 2 px more between digits
        var half = (style == 0) ? 0 : ((style == 3) ? 3 : 2);
        var hu = h % 10;
        var mt = m / 10;
        var mu = m % 10;
        var hx = CX - half - 4 - ((two ? TimeInk.A[h / 10] + extra : 0) + TimeInk.X[hu] + TimeInk.W[hu] - 1);
        var mx = CX + half + 4 - TimeInk.X[mt];
        if (extra == 0) {
            dc.drawText(hx, 74, fTime, h.format(two ? "%02d" : "%d"), Graphics.TEXT_JUSTIFY_LEFT);
            drawColon(dc, CX, style);
            dc.drawText(mx, 74, mFont, m.format("%02d"), Graphics.TEXT_JUSTIFY_LEFT);
        } else {
            if (two) {
                dc.drawText(hx, 74, fTime, (h / 10).format("%d"), Graphics.TEXT_JUSTIFY_LEFT);
                hx += TimeInk.A[h / 10] + extra;
            }
            dc.drawText(hx, 74, fTime, hu.format("%d"), Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(mx, 74, mFont, mt.format("%d"), Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(mx + TimeInk.A[mt] + extra, 74, mFont, mu.format("%d"), Graphics.TEXT_JUSTIFY_LEFT);
        }
        if (ditherMinutes && mFont == fTime) {
            // Knock out every other pixel of the solid minutes in the background colour.
            // Clipped to the minutes, so nothing else is touched; even x keeps the pattern aligned.
            var x0 = mx + TimeInk.X[mt];
            var x1 = mx + TimeInk.A[mt] + extra + TimeInk.X[mu] + TimeInk.W[mu] - 1;
            dc.setClip(x0, 74, x1 - x0 + 1, 42);         // rows 74..115: the device draws the digits 1 px lower
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            for (var tx = x0 - (x0 % 2); tx <= x1; tx += 16) {
                drawIcon(dc, Ic.M_CHK, tx, 74);
            }
            dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
            dc.clearClip();
        }
    }

    // [first, last] inked column of a digit string, relative to the pen position.


    // Colon marks at one third and two thirds of the digit height: 1 circles, 2 squares, 3 diamonds.
    private function drawColon(dc as Dc, cx, style) as Void {
        for (var k = 0; k < 2; k += 1) {
            var cy = (k == 0) ? 88 : 102;
            if (style == 1) {
                dc.fillRectangle(cx - 1, cy - 2, 3, 1);
                dc.fillRectangle(cx - 2, cy - 1, 5, 3);
                dc.fillRectangle(cx - 1, cy + 2, 3, 1);
            } else if (style == 2) {
                dc.fillRectangle(cx - 2, cy - 2, 5, 5);
            } else {
                for (var dy = -3; dy <= 3; dy += 1) {
                    var w = 3 - ((dy < 0) ? -dy : dy);
                    dc.fillRectangle(cx - w, cy + dy, 2 * w + 1, 1);
                }
            }
        }
    }

    // Heart rate now: read once per redraw (readHrNow), then reused. Each Activity.getActivityInfo() call
    // builds a full activity record, and the face needs the heart rate in up to eight places.
    private function currentHr() {
        return hrNow;
    }

    private function readHrNow() as Void {
        var act = Activity.getActivityInfo();
        hrNow = (act != null && act.currentHeartRate != null) ? act.currentHeartRate : hrNewest;
    }

    // ------------------------------------------------------------ circle (subscreen)

    private function drawCircle(dc as Dc, now, clock, settings, stats) as Void {
        var mode = cfg[Cfg.CIRCLE];
        if (mode == Cfg.CM_OFF) {
            return;
        }
        if (mode == Cfg.CM_SEC) {
            // Seconds only after a wrist raise (the face redraws every second then); at rest the circle stays
            // empty, so there is no redraw every second while the watch rests. The dotted arc fills over the minute.
            if (awake) {
                drawCentered(dc, fMid, clock.sec.format("%02d"), subCy - 10);
            }
            return;
        }
        var cx = subCx;
        var cy = subCy;
        if (mode == Cfg.CM_HILO) {
            drawTri(dc, cx - 13, 11, true);
            dc.drawText(cx - 2, 8, fSmall, num(userTemp(wxHigh)), Graphics.TEXT_JUSTIFY_LEFT);
            drawTemp(dc, fMid, wxTemp, cy - 9);
            drawTri(dc, cx - 13, 47, false);
            dc.drawText(cx - 2, 44, fSmall, num(userTemp(wxLow)), Graphics.TEXT_JUSTIFY_LEFT);
        } else if ((mode == Cfg.CM_NEXT3H || (mode == Cfg.CM_TOMORROW && tmHigh == null)) && wxNote != null) {
            // no forecast: the title, then why (NO DATA, NO GPS or the error number)
            drawCentered(dc, fSmall, (mode == Cfg.CM_NEXT3H) ? "+3H" : "TMRW", 6);
            dc.drawText(cx, cy + 4, fSmall, wxNote, Graphics.TEXT_JUSTIFY_CENTER);
        } else if (mode == Cfg.CM_NEXT3H) {
            drawCentered(dc, fSmall, "+3H", 6);
            drawIconBox(dc, weatherIcon(n3Cond, false), cx - 27, cy - 13, 28, 23);
            var t3 = tempNum(n3Temp) + "°";
            var w3 = dc.getTextWidthInPixels(t3, fMed);
            var x3 = cx + 3;
            if (x3 + w3 > cx + 29) {
                x3 = cx + 29 - w3;
            }
            dc.drawText(x3, cy - 7, fMed, t3, Graphics.TEXT_JUSTIFY_LEFT);
            drawIcon(dc, Ic.C_DROPS, cx - 19, 44);
            dc.drawText(cx - 6, 45, fSmall, pctText(n3Precip), Graphics.TEXT_JUSTIFY_LEFT);
        } else if (mode == Cfg.CM_TOMORROW) {
            drawCentered(dc, fSmall, (tmDow == null) ? "TMRW" : DAYS.substring(3 * (tmDow), 3 * (tmDow) + 3), 6);
            drawIconBox(dc, weatherIcon(tmCond, false), cx - 27, cy - 13, 27, 23);
            drawHiLoLine(dc, num(userTemp(tmHigh)), cy - 12, true);
            drawHiLoLine(dc, num(userTemp(tmLow)), cy + 2, false);
            drawIcon(dc, Ic.C_DROPS, cx - 19, 44);
            dc.drawText(cx - 6, 45, fSmall, pctText(tmPrecip), Graphics.TEXT_JUSTIFY_LEFT);
        } else if (mode == Cfg.CM_RAIN) {
            drawIcon(dc, Ic.C_DROP, cx - 5, 5);
            bigValue(dc, pctText(wxPrecip), 21, "RAIN", 45);
        } else if (mode == Cfg.CM_WIND) {
            if (wxBearing != null) {
                dc.drawText(cx, 6, fSmall, compass(wxBearing), Graphics.TEXT_JUSTIFY_CENTER);
            }
            bigValue(dc, speedNum(wxWind), 22, distMi ? "MPH" : "KMH", 45);
        } else if (mode == Cfg.CM_HR) {
            drawIcon(dc, Ic.I_HEART, cx - 5, 8);
            bigValue(dc, num(currentHr()), 21, "BPM", 45);
        } else if (mode == Cfg.CM_BB) {
            drawIcon(dc, Ic.I_BOLT, cx - 5, 9);
            bigValue(dc, num(bodyBattery), 18, "BB", 40);
        } else if (mode == Cfg.CM_DUAL) {
            var off = tzOffset();
            drawCentered(dc, fSmall, (cfg[Cfg.TZ] == Cfg.TZ_ZULU && off == 0) ? "ZULU" : tzLabel(off, true), 9);
            drawCentered(dc, fMed, tzTime(now, off, settings, false), cy - 6);   // the big digits have no A / P
            var diff = off - clock.timeZoneOffset / 3600.0;
            var dText = (diff == diff.toNumber()) ? diff.toNumber().format("%d") : diff.format("%.1f");
            drawCentered(dc, fSmall, ((diff > 0) ? "+" : "") + dText + "H", 44);
        } else if (mode == Cfg.CM_SUN) {
            var ns = nextSun(clock.hour * 60 + clock.min);
            drawIcon(dc, Ic.I_SUNHZ, cx - 6, 10);
            if (polar != 0) {                            // the sun neither rises nor sets today
                drawCentered(dc, fSmall, "POLAR", cy - 7);
                drawCentered(dc, fSmall, (polar > 0) ? "DAY" : "NIGHT", 44);
            } else {
                drawCentered(dc, fMed, (ns == null) ? "--:--" : ns[0], cy - 7);
                drawCentered(dc, fSmall, (ns == null) ? "--" : "IN " + hm(ns[1]), 44);
            }
        } else if (mode == Cfg.CM_MOON) {
            var nowS = now.value();
            drawMoon(dc, cx, cy - 5, 12, nowS);
            var lText = num(moonLit(nowS));
            dc.drawText(cx - dc.getTextWidthInPixels(lText, fSmall) / 2, 45, fSmall, lText + "%", Graphics.TEXT_JUSTIFY_LEFT);
        } else if (mode == Cfg.CM_ALTITUDE) {
            drawIcon(dc, Ic.C_MOUNT, cx - 8, 8);
            bigValue(dc, num(altitude), 21, elevFt ? "FT" : "M", 45);
        } else if (mode == Cfg.CM_PRESSURE) {
            if (pressureTrend > 0) {
                drawTri(dc, cx - 4, 10, true);
            } else if (pressureTrend < 0) {
                drawTri(dc, cx - 4, 10, false);
            } else {
                dc.fillRectangle(cx - 4, 11, 9, 2);
            }
            drawCentered(dc, fMed, (pressure == null) ? "--" : num(pressure / 100.0), 23);
            drawCentered(dc, fSmall, "HPA", 44);
        } else if (mode == Cfg.CM_NOTIF) {
            drawIcon(dc, Ic.C_MAIL, cx - 8, 7);
            bigValue(dc, num(settings.notificationCount), 21, "NEW", 45);
        } else if (mode == Cfg.CM_BATTERY) {
            dc.drawRectangle(cx - 8, 9, 14, 8);
            dc.fillRectangle(cx + 6, 11, 2, 4);
            var bf = (stats.battery * 10.0 / 100.0 + 0.5).toNumber();
            if (bf > 10) {
                bf = 10;
            }
            if (bf > 0) {
                dc.fillRectangle(cx - 6, 11, bf, 4);
            }
            bigValue(dc, (stats has :batteryInDays) ? num(stats.batteryInDays) : "--", 18, "DAYS", 40);
        } else {
            drawWeather(dc);
        }
    }

    // Dotted progress arc inside the circle: only the filled dots, clockwise from the top.
    private function buildArc() as Void {
        arcX = new [30]b;                                // positions fit in a byte
        arcY = new [30]b;
        for (var i = 0; i < 30; i += 1) {
            var a = (i * 12 - 90) * Math.PI / 180.0;
            var x = (subCx + 28 * Math.cos(a) + 0.5).toNumber();
            var y = (subCy + 28 * Math.sin(a) + 0.5).toNumber();
            arcX[i] = (x > subCx) ? x - 1 : x;
            arcY[i] = (y > subCy) ? y - 1 : y;
        }
    }

    private function drawArc(dc as Dc, pct) as Void {
        if (pct == null || arcX == null) {
            return;
        }
        var lit = (pct * 30 / 100.0 + 0.5).toNumber();
        if (lit > 30) {
            lit = 30;
        }
        for (var i = 0; i < lit; i += 1) {
            dc.fillRectangle(arcX[i], arcY[i], 2, 2);
        }
    }

    // What the arc shows in each circle mode (null: no arc).
    private function arcValue(mode, now, clock, stats) {
        if (mode == Cfg.CM_SEC) {
            return awake ? clock.sec * 100 / 59 : null;  // the arc fills over the minute
        }
        if (mode == Cfg.CM_BB) {
            return bodyBattery;                          // the dotted arc shows the level (no ring)
        }
        if (mode == Cfg.CM_BATTERY) {
            return stats.battery;
        }
        if (mode == Cfg.CM_WEATHER) {
            return wxPrecip;
        }
        if (mode == Cfg.CM_HILO) {
            if (wxTemp != null && wxLow != null && wxHigh != null && wxHigh > wxLow) {
                return (wxTemp - wxLow) * 100.0 / (wxHigh - wxLow);
            }
            return null;
        }
        if (mode == Cfg.CM_WIND) {
            return (wxWind == null) ? null : wxWind * 3.6 * 2.0;          // 0-50 km/h
        }
        if (mode == Cfg.CM_HR) {
            var hr = currentHr();
            if (hr != null && restHr != null && hrZones != null && hrZones.size() >= 6 && hrZones[5] > restHr) {
                return (hr - restHr) * 100.0 / (hrZones[5] - restHr);
            }
            return null;
        }
        if (mode == Cfg.CM_DUAL) {
            var off = tzOffset();
            var u = Gregorian.utcInfo(new Time.Moment(now.value() + off * 3600), Time.FORMAT_SHORT);
            return (u.hour * 60 + u.min) * 100.0 / 1440;
        }
        if (mode == Cfg.CM_SUN) {
            return daylightLeft();
        }
        if (mode == Cfg.CM_MOON) {
            return moonAge(now.value()) * 100.0 / SYNODIC;
        }
        if (mode == Cfg.CM_PRESSURE) {
            return (pressure == null) ? null : (pressure / 100.0 - 950.0);  // 950-1050 hPa
        }
        return null;
    }

    // Circle views: a big value and a small label under it, both centred.
    private function bigValue(dc as Dc, value, vy, label, ly) as Void {
        dc.drawText(subCx, vy, fMid, value, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(subCx, ly, fSmall, label, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawCentered(dc as Dc, font, text, y) as Void {
        dc.drawText(subCx, y, font, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Celsius from the weather sources -> the watch's temperature unit.
    private function userTemp(v) {
        if (v == null || !tempF) {
            return v;
        }
        return v * 9.0 / 5.0 + 32.0;
    }

    private function tempNum(v) {
        if (v == null) {
            return "--";
        }
        var f = userTemp(v).toFloat();
        return (f + (f < 0 ? -0.5 : 0.5)).toNumber().format("%d");
    }

    private function drawTemp(dc as Dc, font, v, y) as Void {
        var t = tempNum(v);
        dc.drawText(subCx - dc.getTextWidthInPixels(t, font) / 2, y, font, t + "°", Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function drawHiLoLine(dc as Dc, text, y, up) as Void {
        var w = dc.getTextWidthInPixels(text, fSmall);
        var tx = subCx + 11;
        if (tx + w > subCx + 29) {
            tx = subCx + 29 - w;
        }
        drawTri(dc, tx - 10, y + 3, up);
        dc.drawText(tx, y, fSmall, text, Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function drawTri(dc as Dc, x, y, up) as Void {
        if (up) {
            dc.fillPolygon([ [ x, y + 4 ], [ x + 4, y ], [ x + 8, y + 4 ] ]);
        } else {
            dc.fillPolygon([ [ x, y ], [ x + 8, y ], [ x + 4, y + 4 ] ]);
        }
    }


    // Wind direction as compass letters (where the wind comes from, as weather reports state it):
    // N NE E SE S SW W NW, cut from one text: start i + i / 2, length 1 or 2.
    private function compass(bearing) as String {
        var i = (((bearing.toFloat() + 382.5) / 45.0).toNumber()) % 8;
        return "NNEESESSWWNW".substring(i + i / 2, i + i / 2 + 1 + i % 2);
    }

    private function weatherIcon(cond, night) {
        var group = 2;
        if (cond != null && cond >= 0 && cond < 54) {
            group = WX_MAP[cond];
        }
        if (group == 0) {
            return night ? Ic.W_MOON : Ic.W_SUN;
        }
        if (group == 1) {
            return night ? Ic.W_CLOUD : Ic.W_PARTLY;
        }
        if (group == 3) {
            return Ic.W_RAIN;
        }
        if (group == 4) {
            return Ic.W_SNOW;
        }
        if (group == 5) {
            return Ic.W_STORM;
        }
        if (group == 6) {
            return Ic.W_FOG;
        }
        if (group == 7) {
            return Ic.W_WIND;
        }
        return Ic.W_CLOUD;
    }

    // The face's Time format setting (watch setting / 24 h / 12 h).
    private function use24(settings) {
        var f = cfg[Cfg.TIMEFMT];
        return (f == 1) ? true : ((f == 2) ? false : settings.is24Hour);
    }

    private function clockText(hour, minute, settings) {
        var h = hour;
        if (!use24(settings)) {
            h = h % 12;
            if (h == 0) {
                h = 12;
            }
        }
        return h.format("%d") + ":" + minute.format("%02d");
    }

    private function dayOfYear(year, month, day) {
        var cum = [ 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 ];
        var n = cum[month - 1] + day;
        var leap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
        if (leap && month > 2) {
            n += 1;
        }
        return n;
    }

    // zen: 90.833 sunrise/sunset, 84 golden hour, 96 civil (first/last light), 102 nautical (BMNT/EENT)
    private function sunEvent(n, lat, lon, tz, rising, zen) {
        var d2r = Math.PI / 180.0;
        var lngHour = lon / 15.0;
        var t = n + ((rising ? 6.0 : 18.0) - lngHour) / 24.0;
        var m = 0.9856 * t - 3.289;
        var l = wrap(m + 1.916 * Math.sin(m * d2r) + 0.020 * Math.sin(2.0 * m * d2r) + 282.634, 360.0);
        var ra = wrap(Math.atan2(0.91764 * Math.sin(l * d2r), Math.cos(l * d2r)) / d2r, 360.0) / 15.0;
        var sinDec = 0.39782 * Math.sin(l * d2r);
        var cosDec = Math.cos(Math.asin(sinDec));
        var cosH = (Math.cos(zen * d2r) - sinDec * Math.sin(lat * d2r)) / (cosDec * Math.cos(lat * d2r));
        if (cosH > 1.0 || cosH < -1.0) {
            return null;
        }
        var h = Math.acos(cosH) / d2r;
        if (rising) {
            h = 360.0 - h;
        }
        var local = wrap(h / 15.0 + ra - 0.06571 * t - 6.622 - lngHour + tz, 24.0);
        return (local * 60.0 + 0.5).toNumber() % 1440;
    }

    private function wrap(v, range) {
        while (v < 0) {
            v += range;
        }
        while (v >= range) {
            v -= range;
        }
        return v;
    }

    // ------------------------------------------------------------ pixel helpers

    private function drawIcon(dc as Dc, idx, x, y) as Void {
        dc.drawText(x, y, fIcons, (65 + idx).toChar().toString(), Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function drawIconBox(dc as Dc, idx, x, y, bw, bh) as Void {
        drawIcon(dc, idx, x + (bw - Ic.W[idx]) / 2, y + (bh - Ic.H[idx]) / 2);
    }
}
