# Maps Garmin Nav

Flutter Android companion plus a Connect IQ watch app that mirrors **Google Maps** turn-by-turn guidance onto a **Forerunner 255**.

Google Maps has no public live-navigation API. The phone app reads the ongoing Maps navigation notification, maps it to a compact payload, and sends that payload to the watch over Garmin’s Connect IQ Mobile SDK.

```
Google Maps  →  NotificationListenerService  →  Connect IQ sendMessage  →  Forerunner 255
```

## Requirements

- Android 8+ phone
- [Garmin Connect](https://play.google.com/store/apps/details?id=com.garmin.android.apps.connectmobile) installed, with the watch paired
- Google Maps navigation running on the phone
- Watch app installed (sideload or Connect IQ store later)
- The watch app must be open (the phone companion tries to open it when navigation starts)

Maps notification layouts are unofficial and can change when Google updates Maps.

## Phone app (Flutter)

Requires **Java 17–21** to build. Android Studio’s bundled JBR 25 is not compatible with this Flutter/Gradle combination.

```bash
flutter pub get
flutter run
```

On first launch:

1. Allow **notification access** (so the app can read Maps guidance)
2. Allow **battery optimization exemption** (so it keeps running with the screen off)
3. Allow **notifications** and **Bluetooth**
4. Tap **Start watch bridge**

The home screen shows the last parsed instruction so you can confirm parsing even without the watch.

Application ID: `com.mapsgarmin.maps_garmin_nav`  
Connect IQ UUID (must match the watch app): `2467c647-df37-4935-94d8-4820cf22cd1d`

### Simulator (phone ↔ Connect IQ sim)

```bash
adb forward tcp:7381 tcp:7381
```

Then use a debug build and set the companion to tethered mode if you add that toggle later. Physical watches use a wireless connection through Garmin Connect.

## Watch app (Connect IQ)

Targets: `fr255`, `fr255m` (260×260).

Install the [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) and device files for Forerunner 255, then from `watch/`:

```bash
monkeyc -f monkey.jungle -d fr255 -o bin/maps-garmin-nav.prg -y /path/to/developer_key.der
```

Sideload the `.prg` onto the watch (copy to `GARMIN/APPS` or use the SDK manager / `monkeydo` with the simulator).

The watch screen shows:

- Turn arrow (or roundabout / arrive glyph)
- Remaining distance before the turn
- Next road name

## Payload

| Key | Meaning |
| --- | --- |
| `s` | `0` idle, `1` navigating, `2` rerouting, `3` ended |
| `m` | Maneuver enum (left/right/u-turn/…) |
| `d` | Distance to turn (`"200 m"`) |
| `r` | Next road name |
| `i` | Short instruction, when different from the road |

## Layout

- `lib/` Flutter UI (Riverpod + Hooks). One `Scaffold` in `lib/app.dart`.
- `android/` native listener, parser, Connect IQ bridge, foreground service
- `watch/` Monkey C application for Forerunner 255
