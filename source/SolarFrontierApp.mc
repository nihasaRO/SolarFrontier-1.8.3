import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Annotated for the background process too, which runs the Open-Meteo weather fetch.
(:background)
class SolarFrontierApp extends Application.AppBase {
    private var mView;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        mView = new SolarFrontierView();
        return [ mView ];
    }

    // Settings changed in the Garmin Connect app (faces installed from the Connect IQ Store).
    function onSettingsChanged() {
        if (mView != null) {
            mView.settingsChanged();
        }
        WatchUi.requestUpdate();
    }

    // On-watch settings menu (works for sideloaded and store installs alike)
    function getSettingsView() {
        if (mView != null) {
            mView.onHide();                          // free the face's memory before the menu is built
            mView.behindMenu = true;                 // and don't draw it while the menu covers the screen
        }
        var menu = new MenuView(mView);
        return [ menu, new MenuDelegate(menu) ];
    }

    function getServiceDelegate() {
        return [ new WeatherService() ];
    }

    // Result of a background weather fetch: keep it for the face (for restarts), hand it over, then redraw.
    function onBackgroundData(data) {
        if (data instanceof Lang.Array) {                // the weather summary (fixed positions)
            Application.Storage.setValue("wx", data);
            Application.Storage.deleteValue("wxErr");    // a success clears an old error
        } else if (data instanceof Lang.Number) {        // an error number
            Application.Storage.setValue("wxErr", data);
        }
        if (mView != null && data != null) {
            mView.weatherArrived(data);                  // applied now, outside a redraw, without a storage read
        }
        WatchUi.requestUpdate();
    }
}
