# kde-weather-widget

A KDE Plasma 6 applet that displays live weather conditions from an OpenWeatherMap-compatible API endpoint. Shows current temperature, conditions, wind, humidity, pressure, and visibility in the system tray and popup.

---

## What it does

- Sits in the system tray and shows the current temperature and a weather icon
- Expands to a popup with full conditions: temperature, weather description, wind, humidity, pressure, and visibility
- Fetches from any OpenWeatherMap One Call API 3.0 compatible endpoint (local proxy or direct OWM)
- Refreshes on a configurable interval (default 5 minutes)
- Converts all units display-side — data is always requested in metric

---

## Requirements

- KDE Plasma 6
- An OpenWeatherMap One Call API 3.0 compatible endpoint

---

## Install

```sh
kpackagetool6 --install com.weatherstation.local
```

To update after editing:

```sh
kpackagetool6 --upgrade com.weatherstation.local
cp -r com.weatherstation.local ~/.local/share/plasma/plasmoids/com.weatherstation.local
kbuildsycoca6
```

Then restart the shell to pick up changes:

```sh
plasmashell --replace &disown
```

---

## Configuration

Right-click the widget → Configure.

**General tab**

| Setting | Default | Notes |
|---|---|---|
| API Endpoint | `http://192.168.8.30:8002/data/3.0/onecall` | Any OWM One Call 3.0 compatible URL |
| Location name | (from API response) | Optional override displayed in the popup header |
| Temperature decimal places | 1 | 0–2 |
| Humidity decimal places | 0 | 0–2 |
| Refresh interval | 5 min | 1–60 minutes |

**Units tab**

| Measurement | Options |
|---|---|
| Temperature | °C, °F, K |
| Wind speed | m/s, km/h, mph, knots |
| Pressure | hPa, inHg, mmHg |
| Visibility | km, mi |

---

## Files

```
com.weatherstation.local/
├── metadata.json
└── contents/
    ├── config/
    │   ├── main.xml          Config schema (KConfig XT)
    │   └── config.qml        Config dialog tab definitions
    └── ui/
        ├── main.qml              Root plasmoid: data fetching, unit conversion
        ├── CompactRepresentation.qml   System tray icon + temperature
        ├── FullRepresentation.qml      Popup with full conditions
        └── config/
            ├── ConfigGeneral.qml   Endpoint, location, precision, interval
            └── ConfigUnits.qml     Per-measurement unit selectors
```
