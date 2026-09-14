import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.WatchUi;

class NavApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        Communications.registerForPhoneAppMessages(method(:onPhoneMessage));
    }

    function onStop(state as Dictionary?) as Void {
        Communications.registerForPhoneAppMessages(null);
    }

    function getInitialView() {
        return [new NavView(), new NavDelegate()];
    }

    function onPhoneMessage(msg as Communications.PhoneAppMessage) as Void {
        NavStore.apply(msg.data);
        WatchUi.requestUpdate();
    }
}

function getApp() as NavApp {
    return Application.getApp() as NavApp;
}
