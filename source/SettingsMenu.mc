import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// On-watch settings: all 32 settings and every option, in one view with three levels (groups, the settings of a
// group with their current values, the options of one setting). No stacked menus and no stored label cache:
// at most one setting's option list is loaded at a time, and only while it is shown.
// UP/DOWN move, GPS opens or saves, BACK cancels or goes up; BACK at the top lets the watch close the settings.
// Based on the compact design suggested in the ChatGPT review (Build 3).
class MenuView extends WatchUi.View {
    private var mFace;           // the watch face, told when the settings close
    private var mLevel = 0;      // 0 groups, 1 settings, 2 options
    private var mGroup = 0;
    private var mItem = 0;
    private var mOption = 0;
    private var mKey = 0;        // the setting being shown or edited
    private var mStored = 0;     // the stored value of the highlighted option
    private var mSaved = 0;      // the setting's value when it was shown or opened
    private var mHour = -1;      // countdown time: the chosen hour while picking the minutes, -1 while picking hours
    private var mOptions;        // the shown setting's option list, only while needed
    private var mHead = "SETTINGS";
    private var mEntry = "";
    private var mValue = "";     // level 1: the current value; level 2: CURRENT when it is the stored one

    function initialize(face) {
        View.initialize();
        mFace = face;
        show();
    }

    private function items() {
        return Cfg.GROUPS[mGroup] as Lang.ByteArray;
    }

    // Countdown day, year and time are generated, not read from a list.
    private function computed() {
        return mKey == Cfg.CD_DAY || mKey == Cfg.CD_YEAR || mKey == Cfg.CD_TIME;
    }

    private function count() {
        if (mLevel == 0) {
            return Cfg.GROUPS.size();
        }
        if (mLevel == 1) {
            return items().size();
        }
        if (mKey == Cfg.CD_TIME) {
            return (mHour < 0) ? 24 : 4;           // hours, then quarter hours
        }
        return Cfg.COUNTS[mKey];
    }

    function step(d) as Void {
        var n = count();
        if (mLevel == 0) {
            mGroup = (mGroup + d + n) % n;
        } else if (mLevel == 1) {
            mItem = (mItem + d + n) % n;
        } else {
            mOption = (mOption + d + n) % n;
        }
        show();
    }

    // The label of option position p (sets mStored). A packed entry is two digits of stored value, two digits of
    // label length, then the label; the lists are chunks of up to 16 entries in the phone settings' order.
    private function readOption(p) as Void {
        mStored = p;
        if (mKey == Cfg.CD_DAY) {
            mEntry = (p + 1).format("%d");
        } else if (mKey == Cfg.CD_YEAR) {
            mEntry = (p == 20) ? "DAILY" : (2026 + p).format("%d");
        } else if (mKey == Cfg.CD_TIME) {
            var h = (mHour < 0) ? p : mHour;
            var q = (mHour < 0) ? mSaved % 4 : p;
            mStored = h * 4 + q;
            mEntry = h.format("%02d") + ":" + (q * 15).format("%02d");
        } else {
            var s = mOptions[p / 16] as Lang.String;
            var at = 0;
            for (var j = 0; j < p % 16; j += 1) {
                at += 4 + s.substring(at + 2, at + 4).toNumber();
            }
            mStored = s.substring(at, at + 2).toNumber();
            mEntry = s.substring(at + 4, at + 4 + s.substring(at + 2, at + 4).toNumber());
        }
    }

    // The position of the stored value in the shown list, in one pass.
    private function savedPosition() {
        if (mKey == Cfg.CD_TIME) {
            return mSaved / 4;
        }
        if (computed()) {
            return mSaved;
        }
        var pos = 0;
        for (var c = 0; c < mOptions.size(); c += 1) {
            var s = mOptions[c] as Lang.String;
            var at = 0;
            while (at + 4 <= s.length()) {
                if (s.substring(at, at + 2).toNumber() == mSaved) {
                    return pos;
                }
                at += 4 + s.substring(at + 2, at + 4).toNumber();
                pos += 1;
            }
        }
        return 0;
    }

    // Opens the setting at the current item: its stored value and, for a list, its options.
    private function open() as Void {
        mKey = items()[mItem];
        mSaved = Cfg.get(mKey);
        mHour = -1;
        if (!computed()) {
            mOptions = SetText.list(mKey);
        }
    }

    private function show() as Void {
        mValue = "";
        if (mLevel == 0) {
            mHead = "SETTINGS";
            mEntry = SetText.group(mGroup);
        } else if (mLevel == 1) {
            mHead = SetText.group(mGroup);
            open();
            readOption(savedPosition());
            mOptions = null;                       // only the label is kept
            mValue = mEntry;
            mEntry = SetText.title(mKey);
        } else {
            readOption(mOption);
            if (mStored == mSaved) {
                mValue = "CURRENT";
            }
        }
        WatchUi.requestUpdate();
    }

    function select() as Void {
        if (mLevel == 0) {
            mLevel = 1;
            mItem = 0;
        } else if (mLevel == 1) {
            open();
            mHead = SetText.title(mKey);
            mOption = savedPosition();
            mLevel = 2;
        } else if (mKey == Cfg.CD_TIME && mHour < 0) {
            mHour = mOption;                       // hour chosen: now the minutes
            mOption = mSaved % 4;
        } else {
            Cfg.set(mKey, mStored);
            mOptions = null;
            mLevel = 1;
        }
        show();
    }

    // BACK in a picker cancels without saving; at the top, false lets the watch close the settings.
    function back() as Lang.Boolean {
        if (mLevel == 0) {
            return false;
        }
        if (mLevel == 2) {
            mOptions = null;
            mLevel = 1;
        } else {
            mLevel = 0;
        }
        show();
        return true;
    }

    function onHide() as Void {
        mOptions = null;
        mEntry = "";
        mHead = "";
        mValue = "";
        if (mFace != null) {
            mFace.behindMenu = false;              // the face draws again, after one skipped redraw
            mFace.skipOnce = true;                 // so the settings are released first
        }
    }

    // Centred text; the main line takes the largest system font that fits 150 px (measured: proportional fonts).
    private function line(dc as Graphics.Dc, y, big, text) as Void {
        var f = big ? Graphics.FONT_SMALL : Graphics.FONT_XTINY;
        if (big && dc.getTextWidthInPixels(text, f) > 150) {
            f = Graphics.FONT_TINY;
        }
        if (big && dc.getTextWidthInPixels(text, f) > 150) {
            f = Graphics.FONT_XTINY;
        }
        dc.drawText(88, y, f, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        line(dc, 62, false, mHead);      // below the round sub-screen
        dc.drawLine(26, 81, 150, 81);
        line(dc, 92, true, mEntry);
        line(dc, 122, false, mValue);
        dc.drawLine(30, 148, 146, 148);
        var pos = (mLevel == 0) ? mGroup : ((mLevel == 1) ? mItem : mOption);
        dc.drawText(88, 151, Graphics.FONT_XTINY, (pos + 1).format("%d") + "/" + count().format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class MenuDelegate extends WatchUi.BehaviorDelegate {
    private var mMenu;

    function initialize(menu) {
        BehaviorDelegate.initialize();
        mMenu = menu;
    }

    function onNextPage() {
        mMenu.step(1);
        return true;
    }

    function onPreviousPage() {
        mMenu.step(-1);
        return true;
    }

    function onSelect() {
        mMenu.select();
        return true;
    }

    function onBack() {
        return mMenu.back();
    }
}
