import Toybox.Application;
import Toybox.Lang;

// Settings for Solar Frontier. Values are option indexes stored as Application.Properties,
// so both the on-watch menu and the Garmin Connect app can change them (resources/settings).
// The menu labels live in resources/jsonData (loaded only while the menu is open).
module Cfg {
    // setting indexes
    const CORNER = 0;
    const DATE = 1;
    const ROW1 = 2;            // ROW2 = 3, ROW3 = 4 (Rows layout)
    const ROW2 = 3;
    const ROW3 = 4;
    const THEME = 5;
    const MINUTES = 6;
    const CIRCLE = 7;
    const TZ = 8;
    const WX_SOURCE = 9;
    const WX_INTERVAL = 10;
    const COLON = 11;
    const LAYOUT = 12;         // 0 Rows, 1 Chart
    const GAUGE_L = 13;        // side gauges, shared by both layouts
    const GAUGE_R = 14;
    const COL1 = 15;           // Chart layout: COL2 = 16, COL3 = 17
    const COL2 = 16;
    const COL3 = 17;
    const CHART = 18;          // what and over how long: option = source * 3 + (0: 1 h, 1: 3 h, 2: 4 h); 24 off, 25 big text
    const TOP_TEXT = 19;       // 0 date, 1 second time zone, 2 off, 3.. a short metric (L1)
    const R2_VALUE = 20;       // battery %, battery days, Body Battery, stress, notifications, heart rate, resting HR, off
    const R2_RAMP = 21;        // solar, battery, Body Battery, stress, steps goal, intensity goal, HR zone, off, ...
    const R3 = 22;             // line 3: next sun, both sun times, time zone, pressure, high/low, altitude, steps, ...
    const TIMEFMT = 23;        // watch setting, 24 hours, 12 hours
    const WRIST = 24;          // wrist raise detail bits: 1 = Rows details off, 2 = side-gauge values off, 4 = chart min/max off
    const GAUGE_STYLE = 25;    // side gauges: 0 bar (Enduro style), 1 blocks
    const CD_DAY = 26;         // countdown target date and time
    const CD_MONTH = 27;
    const CD_YEAR = 28;        // option 0 = 2026
    const CD_TIME = 29;        // option n = n * 15 minutes after midnight
    const INT_GOAL = 30;       // daily intensity goal: 0 auto (weekly goal / 7), then 15, 20, 30, 45, 60, 90 min
    const BIG = 31;            // Chart layout "Big text" (Chart shows option 25): which line-3 metric, same list
    const COUNT = 32;

    // row metrics (Rows layout)
    const RW_STEPS = 0;
    const RW_INTENSITY = 1;
    const RW_HR = 2;
    const RW_BB = 3;
    const RW_STRESS = 4;
    const RW_FLOORS = 5;
    const RW_BATTERY = 6;
    const RW_SOLAR = 7;
    const RW_MOVE = 8;
    const RW_DAYLIGHT = 9;

    // gauge options (Rim layout)
    const GA_STRESS = 0;
    const GA_BB = 1;
    const GA_BATTERY = 2;
    const GA_SOLAR = 3;
    const GA_STEPS = 4;
    const GA_INTENSITY = 5;
    const GA_FLOORS = 6;
    const GA_MOVE = 7;
    const GA_DAYLIGHT = 8;
    const GA_OFF = 9;

    // "Off" options and other indexes used by the view
    const CORNER_STORM = 7;
    const TOPTEXT_OFF = 2;
    const R2V_RESTHR = 6;
    const R2V_OFF = 7;
    const R2R_OFF = 7;
    const R3_OFF = 24;
    const RW_OFF = 10;
    const CO_OFF = 29;
    const CM_OFF = 15;
    const TZ_ZULU = 27;

    // column options (Rim layout; 0..11 are data fields)
    const FI_STEPS = 0;
    const FI_INT_DAY = 1;
    const FI_INT_WEEK = 2;
    const FI_CALORIES = 3;
    const FI_DISTANCE = 4;
    const FI_FLOORS = 5;
    const FI_ALTITUDE = 6;
    const FI_PRESSURE = 7;
    const FI_NOTIF = 8;
    const FI_BATT_DAYS = 9;
    const FI_BB = 10;
    const FI_STRESS = 11;
    const CO_HR = 12;
    const CO_SPO2 = 13;

    // chart options / sensor kinds
    const CH_HR = 0;
    const CH_STRESS = 1;
    const CH_BB = 2;
    const CH_PRESSURE = 3;
    const CH_ALTITUDE = 4;
    const CH_TEMP = 5;
    const CH_SPO2 = 6;
    const CH_SOLAR = 7;

    // circle (subscreen) modes
    const CM_WEATHER = 0;
    const CM_HILO = 1;
    const CM_NEXT3H = 2;
    const CM_TOMORROW = 3;
    const CM_RAIN = 4;
    const CM_WIND = 5;
    const CM_HR = 6;
    const CM_BB = 7;
    const CM_DUAL = 8;
    const CM_SUN = 9;
    const CM_MOON = 10;
    const CM_ALTITUDE = 11;
    const CM_PRESSURE = 12;
    const CM_NOTIF = 13;
    const CM_BATTERY = 14;
    const CM_SEC = 16;             // seconds after a wrist raise (after Off, so stored values keep their meaning)

    // weather update intervals in minutes, matching the WX_INTERVAL options
    const WX_MINUTES = [ 15, 20, 30, 45, 60, 5, 10 ];        // options 5 and 6 appended; shown in order of minutes
    const L1 = [ 3, 4, 5, 6, 10, 11, 13, 15, 16, 18, 21, 25, 26, 27, 33, 34 ]b;    // line 1 text options 3.. -> line-3 metric

    const DEFAULTS = [ 0, 0, 0, 1, 2, 0, 0, 0, 12, 0, 4, 2, 0, 0, 1, 1, 0, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 4 ]b;
    const COUNTS = [ 8, 7, 18, 18, 18, 2, 4, 17, 28, 2, 7, 4, 2, 17, 17, 49, 49, 49, 26, 19, 8, 15, 48, 3, 8, 2, 31, 12, 21, 96, 7, 48 ]b;


    // Settings grouped by theme, in screen order. The watch menu lists the group titles (from the
    // menu texts, loaded only while it is open); the Garmin Connect app shows the same order with the
    // group name in front of each title (tools/make_project.py).
    const GROUPS = [ [ 12, 5, 24 ]b, [ 0, 19, 1, 20, 21, 22 ]b, [ 7, 8 ]b, [ 23, 11, 6, 26, 27, 28, 29 ]b,
                     [ 13, 14, 25 ]b, [ 2, 3, 4 ]b, [ 15, 16, 17, 18, 31 ]b, [ 9, 10 ]b, [ 30 ]b ];
    const GROUP_ROWS = 5;      // shown only with the Rows layout
    const GROUP_CHART = 6;     // shown only with the Chart layout

    function get(i) {
        var v = Application.Properties.getValue("k" + i);         // storage names: k0 ... k31
        if (v instanceof Lang.Number && v >= 0 && v < COUNTS[i]) {
            return v;
        }
        return DEFAULTS[i];
    }

    function set(i, v) {
        Application.Properties.setValue("k" + i, v);
    }


    function loadAll() {
        var a = new [COUNT]b;                                       // every value fits in a byte
        for (var i = 0; i < COUNT; i += 1) {
            a[i] = get(i);
        }
        return a;
    }
}
