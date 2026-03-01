# kde-weather-widget

A KDE Plasma 6 applet that displays live weather conditions from an OpenWeatherMap-compatible API endpoint. Shows current temperature, conditions, wind, humidity, pressure, and visibility in the system tray and popup.

---

## What it does

- Sits in the system tray and shows the current temperature and a weather icon
- Expands to a popup with full conditions: temperature, weather description, wind, humidity, pressure, and visibility
- Supports OpenWeatherMap One Call 3.0, One Call 2.5 (legacy), or any compatible custom endpoint
- Location search built in — type a city name and pick from results, no coordinates needed
- Refreshes on a configurable interval (default 5 minutes)
- Converts all units display-side — data is always requested in metric

---

## Requirements

- KDE Plasma 6
- An OpenWeatherMap API key, **or** any OWM One Call compatible endpoint

---

## Install

**1. Clone the repo**

```sh
git clone https://github.com/murrain/kde-weather-widget.git
cd kde-weather-widget
```

**2. Install the widget package**

```sh
kpackagetool6 --install com.weatherstation.local
```

**3. Sync files to the Plasma plasmoids directory**

```sh
rsync -a com.weatherstation.local/ ~/.local/share/plasma/plasmoids/com.weatherstation.local/
kbuildsycoca6
```

**4. Restart Plasma**

```sh
plasmashell --replace &disown
```

**5. Add the widget to your panel**

Right-click your panel → **Add Widgets** → search for **Weather Station** → drag it onto the panel.

---

## Configuration

Right-click the widget → **Configure**.

**General tab**

| Setting | Notes |
|---|---|
| API provider | Choose OpenWeatherMap One Call 3.0, 2.5 (legacy), or Custom URL |
| API key | Required for OWM presets — get one at [openweathermap.org](https://openweathermap.org/api) |
| Location search | Type a city or region and hit Search — click a result to save it |
| Enter coordinates manually | Toggle on to type lat/lon directly instead of searching |
| Override display name | Optional — replaces the location name shown in the popup header |
| Refresh interval | 1–60 minutes (default 5) |
| Temperature / humidity decimal places | 0–2 |

**Units tab**

| Measurement | Options |
|---|---|
| Temperature | °C, °F, K |
| Wind speed | m/s, km/h, mph, knots |
| Pressure | hPa, inHg, mmHg |
| Visibility | km, mi |

---

## Updating

After pulling new changes:

```sh
kpackagetool6 --upgrade com.weatherstation.local
rsync -a com.weatherstation.local/ ~/.local/share/plasma/plasmoids/com.weatherstation.local/
kbuildsycoca6
plasmashell --replace &disown
```

---

## Files

```
com.weatherstation.local/
├── metadata.json
└── contents/
    ├── config/
    │   ├── main.xml               Config schema (KConfig XT)
    │   └── config.qml             Config dialog tab definitions
    └── ui/
        ├── main.qml               Root plasmoid: data fetching, unit conversion
        ├── CompactRepresentation.qml   System tray icon + temperature
        ├── FullRepresentation.qml      Popup with full conditions
        └── config/
            ├── ConfigGeneral.qml  API provider, location search, precision, interval
            └── ConfigUnits.qml    Per-measurement unit selectors
```
