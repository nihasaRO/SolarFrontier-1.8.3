import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.Time;

// Background process: fetches the weather from Open-Meteo (free, no key; data CC BY 4.0, open-meteo.com)
// for the remembered location and hands a small summary to the face. Air quality and pollen come from
// Open-Meteo's air-quality service (CAMS data), only while a slot shows them.
// The summary is an array of 33 values at fixed positions (an error is sent as its number alone):
//  0 ts  1 t  2 c  3 h  4 fl  5 ws  6 wb  7 g  8 cl  9 vis  10 r  11 uv  12 hi  13 lo  14 pc
//  15 n3t  16 n3c  17 n3p  18 tmh  19 tml  20 tmc  21 tmp  22 tmd  23 rs  24 uvx  25 rt  26 cp  27 fz  28 sn
//  29 aq  30 pl  31 pt  32 aqe (air quality error)  33 wet now (1/0); 34 snow (1/0); 35 amount next 12 h (cm snow / mm rain); 23 = time of the next dry/wet change
// Units: C, m/s, %, m (visibility, freezing level), mm (rain), cm (snow), J/kg (CAPE);
// conditions as Garmin Weather.CONDITION_* numbers; tmd 0 = Sunday.
(:background)
class WeatherService extends System.ServiceDelegate {
    private var mLat;
    private var mLon;
    private var mResult;

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var loc = Application.Storage.getValue("loc");
        if (!(loc instanceof Lang.Array) || loc.size() < 2) {
            Background.exit(-1);                     // an error is sent as its number alone
            return;
        }
        mLat = loc[0];
        mLon = loc[1];
        // One request for everything the face shows: times as numbers and only the needed values,
        // which keeps the reply small enough for the background memory.
        Communications.makeWebRequest(
            "https://api.open-meteo.com/v1/forecast",
            // the value lists are built from the same names the reply is read with, so each name is stored once
            { "latitude" => mLat, "longitude" => mLon, "timeformat" => "unixtime", "timezone" => "auto",
              "wind_speed_unit" => "ms", "forecast_days" => 2, "forecast_hours" => 25, "forecast_minutely_15" => 8,
              "current" => join([ "temperature_2m", "relative_humidity_2m", "apparent_temperature", "weather_code", "cloud_cover",
                                  "wind_speed_10m", "wind_direction_10m", "wind_gusts_10m", "visibility", "uv_index" ]),
              "hourly" => join([ "temperature_2m", "weather_code", "precipitation_probability", "rain", "showers", "cape",
                                 "freezing_level_height", "snowfall" ]),
              "daily" => join([ "weather_code", "temperature_2m_max", "temperature_2m_min", "precipitation_probability_max",
                                "rain_sum", "showers_sum", "uv_index_max" ]),
              "minutely_15" => "precipitation,snowfall" },
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onWeather)
        );
    }

    function onWeather(code as Lang.Number, data as Lang.Dictionary or Lang.String or PersistedContent.Iterator or Null) as Void {
        if (code != 200 || !(data instanceof Lang.Dictionary)) {
            Background.exit(code);
            return;
        }
        var d = data as Lang.Dictionary;
        mResult = new [36];                          // fixed positions, see the table above (far lighter than a dictionary)
        mResult[0] = Time.now().value();
        var c = d["current"];
        if (c instanceof Lang.Dictionary) {
            mResult[1] = c["temperature_2m"];
            mResult[3] = c["relative_humidity_2m"];
            mResult[4] = c["apparent_temperature"];
            mResult[2] = cond(c["weather_code"]);
            mResult[8] = c["cloud_cover"];
            mResult[5] = c["wind_speed_10m"];
            mResult[6] = c["wind_direction_10m"];
            mResult[7] = c["wind_gusts_10m"];
            mResult[9] = c["visibility"];
            mResult[11] = c["uv_index"];
        }
        var h = d["hourly"];
        var r12 = 0.0;                                   // rain + showers (mm) and snowfall (cm), next 12 hours
        var s12 = 0.0;
        if (h instanceof Lang.Dictionary) {
            var pop = h["precipitation_probability"];
            mResult[14] = maxOf(pop, 0, 3);                    // rain chance, next 3 hours
            mResult[10] = plus(at(h["rain"], 0), at(h["showers"], 0));   // rain + showers, last hour, mm (no snow)
            mResult[15] = at(h["temperature_2m"], 3);
            mResult[16] = cond(at(h["weather_code"], 3));
            mResult[17] = at(pop, 3);
            mResult[26] = maxOf(h["cape"], 0, 6);              // storm energy, next 6 hours, J/kg
            mResult[27] = at(h["freezing_level_height"], 0);   // m
            var sn = h["snowfall"];
            if (sn instanceof Lang.Array) {                      // new snow, next 24 hours, cm: each value is the
                var sum = 0.0;                                   // hour before its time, so hours 1-24 (not 0)
                for (var i = 1; i < sn.size() && i <= 24; i += 1) {
                    if (sn[i] != null) {
                        sum += sn[i];
                        if (i <= 12) {
                            s12 += sn[i];
                        }
                    }
                }
                mResult[28] = sum;
            }
            for (var q = 1; q <= 12; q += 1) {
                var v = plus(at(h["rain"], q), at(h["showers"], q));
                if (v != null) {
                    r12 += v;
                }
            }
        }
        var dl = d["daily"];
        if (dl instanceof Lang.Dictionary) {
            mResult[12] = at(dl["temperature_2m_max"], 0);
            mResult[13] = at(dl["temperature_2m_min"], 0);
            mResult[24] = at(dl["uv_index_max"], 0);
            mResult[25] = plus(at(dl["rain_sum"], 0), at(dl["showers_sum"], 0));   // rain + showers today, mm
            mResult[18] = at(dl["temperature_2m_max"], 1);
            mResult[19] = at(dl["temperature_2m_min"], 1);
            mResult[20] = cond(at(dl["weather_code"], 1));
            mResult[21] = at(dl["precipitation_probability_max"], 1);
            var today = (Time.now().value() + System.getClockTime().timeZoneOffset) / 86400;
            mResult[22] = (today + 1 + 4) % 7;               // 1970-01-01 was a Thursday
        }
        var m = d["minutely_15"];
        var pr = (m instanceof Lang.Dictionary) ? m["precipitation"] : null;   // any precipitation (rain or snow)
        // Wet or dry now, and the time it changes: the 15-minute data for 2 hours, then the hourly weather codes
        // (51..99: drizzle, rain, snow, showers, thunderstorms) up to 12 hours ahead. 23: change time or null.
        // A 15-minute block is wet from 0.1 mm (trace amounts ignored). 34: whether the precipitation that matters
        // (the current one, or the coming one) is snow: from the forecast's snowfall, or the hourly weather code.
        var mt = (m instanceof Lang.Dictionary) ? m["time"] : null;
        var sf = (m instanceof Lang.Dictionary) ? m["snowfall"] : null;
        var wet = null;
        var chg = null;
        var tEnd = 0;
        var at = 0;
        if (pr instanceof Lang.Array && mt instanceof Lang.Array && pr.size() > 0 && mt.size() >= pr.size()) {
            wet = pr[0] != null && pr[0] >= 0.1;
            for (var k = 1; k < pr.size(); k += 1) {
                if (pr[k] != null && (pr[k] >= 0.1) != wet) {
                    chg = mt[k];
                    at = wet ? 0 : k;                    // raining: the current block; dry: the block it starts
                    break;
                }
            }
            tEnd = mt[pr.size() - 1] + 900;
            if (sf instanceof Lang.Array && sf.size() > at && sf[at] != null && (wet || chg != null)) {
                mResult[34] = (sf[at] > 0) ? 1 : 0;
            }
        }
        var hc = (h instanceof Lang.Dictionary) ? h["weather_code"] : null;
        var ht = (h instanceof Lang.Dictionary) ? h["time"] : null;
        if (chg == null && hc instanceof Lang.Array && ht instanceof Lang.Array) {
            for (var j = 0; j < hc.size() && j < ht.size() && j <= 12; j += 1) {
                if (hc[j] != null && ht[j] >= tEnd) {        // the hours after the 15-minute data
                    var w = hc[j] >= 51;
                    var s = (hc[j] >= 71 && hc[j] <= 77) || hc[j] == 85 || hc[j] == 86;   // snow codes
                    if (wet == null) {
                        wet = w;
                        mResult[34] = w ? (s ? 1 : 0) : null;
                    } else if (w != wet) {
                        chg = ht[j];
                        if (w) {
                            mResult[34] = s ? 1 : 0;     // the coming precipitation
                        }
                        break;
                    }
                }
            }
        }
        mResult[23] = chg;
        mResult[35] = (mResult[34] == 1) ? s12 : r12;    // the amount of the kind that falls (snow: cm, rain: mm)
        mResult[33] = (wet == null) ? null : (wet ? 1 : 0);
        d = null;
        // air quality and pollen (setting index, option): line 3, columns, rows, gauges, line-2 bar
        if (!isSet([ 22, 32, 15, 38, 16, 38, 17, 38, 2, 17, 3, 17, 4, 17, 13, 16, 14, 16, 21, 14,
                     22, 38, 15, 44, 16, 44, 17, 44, 31, 32, 31, 38 ]b)) {        // + big text (setting 31)
            Background.exit(mResult);
            return;
        }
        Communications.makeWebRequest(
            "https://air-quality-api.open-meteo.com/v1/air-quality",
            { "latitude" => mLat, "longitude" => mLon, "current" => "european_aqi," + join(POLLEN) },
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onAir)
        );
    }

    function onAir(code as Lang.Number, data as Lang.Dictionary or Lang.String or PersistedContent.Iterator or Null) as Void {
        if (code != 200) {
            mResult[32] = code;                       // the face shows "AIR ERR" + code
        } else if (data instanceof Lang.Dictionary) {
            var c = (data as Lang.Dictionary)["current"];
            if (c instanceof Lang.Dictionary) {
                var e = c["european_aqi"];               // 0-20 good, 20-40 fair, 40-60 moderate, 60-80 poor, 80-100 very poor, above 100 extremely poor
                mResult[29] = (e == null) ? null : ((e < 20) ? 1 : ((e < 40) ? 2 : ((e < 60) ? 3 : ((e < 80) ? 4 : ((e <= 100) ? 5 : 6)))));
                // pollen (Europe, in season): the highest level of the six types, and which type it is
                var best = null;
                var type = 0;
                for (var i = 0; i < 6; i += 1) {
                    var v = c[POLLEN[i]];
                    if (v != null) {
                        // grains/m3: trees (alder, birch, olive) moderate <100, high <=500; grasses and weeds
                        // moderate <30 (mugwort <50), high <=100; low <10, none <1
                        var tree = i == 0 || i == 1 || i == 4;
                        var lv = (v < 1) ? 0 : ((v < 10) ? 1 : ((v < (tree ? 100 : ((i == 3) ? 50 : 30))) ? 2
                                 : ((v <= (tree ? 500 : 100)) ? 3 : 4)));
                        if (best == null || lv > best) {
                            best = lv;
                            type = i;
                        }
                    }
                }
                mResult[30] = best;                    // 0 none, 1 low, 2 moderate, 3 high, 4 very high
                mResult[31] = type;                    // 0 alder, 1 birch, 2 grass, 3 mugwort, 4 olive, 5 ragweed
            }
        }
        Background.exit(mResult);
    }

    private const POLLEN = [ "alder_pollen", "birch_pollen", "grass_pollen", "mugwort_pollen", "olive_pollen", "ragweed_pollen" ];

    // "a,b,c" from an array of names.
    private function join(a) {
        var s = a[0];
        for (var i = 1; i < a.size(); i += 1) {
            s = s + "," + a[i];
        }
        return s;
    }

    // Element i of an array, or null.
    private function at(a, i) {
        return (a instanceof Lang.Array && a.size() > i) ? a[i] : null;
    }

    // a + b, where either may be missing.
    private function plus(a, b) {
        return (a == null) ? b : ((b == null) ? a : a + b);
    }

    // Largest of elements from..to-1, or null.
    private function maxOf(a, from, to) {
        var best = null;
        for (var i = from; i < to; i += 1) {
            var v = at(a, i);
            if (v != null && (best == null || v > best)) {
                best = v;
            }
        }
        return best;
    }

    // WMO weather code -> Garmin Weather.CONDITION_* number (the face's icons).
    private function cond(w) {
        if (w == null) {
            return null;
        } else if (w <= 1) {
            return w;                                    // clear, mainly clear
        } else if (w == 2) {
            return 1;                                    // partly cloudy
        } else if (w == 3) {
            return 20;                                   // overcast
        } else if (w < 50) {
            return 8;                                    // fog
        } else if (w < 56) {
            return 31;                                   // drizzle
        } else if (w < 60 || (w >= 66 && w < 70)) {
            return 49;                                   // freezing drizzle / rain
        } else if (w == 61 || w == 80) {
            return 14;                                   // light rain / showers
        } else if (w == 65 || w == 82) {
            return 15;                                   // heavy rain / showers
        } else if (w < 70 || (w >= 80 && w < 85)) {
            return 3;                                    // rain / showers
        } else if (w < 90) {
            return 4;                                    // snow, snow showers
        }
        return 6;                                        // thunderstorm
    }

    // True when any (setting index, option) pair holds: the setting (storage name "k" + index) has that option.
    private function isSet(t) {
        for (var i = 0; i < t.size(); i += 2) {
            if (Application.Properties.getValue("k" + t[i]) == t[i + 1]) {
                return true;
            }
        }
        return false;
    }
}
