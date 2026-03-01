import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents

Kirigami.FormLayout {
    id: configPage

    // ── Bound config properties ─────────────────────────────────────
    property string cfg_apiPreset
    property string cfg_apiKey
    property string cfg_latitude
    property string cfg_longitude
    property string cfg_locationDisplay
    property alias  cfg_apiEndpoint:       endpointField.text
    property alias  cfg_locationName:      locationField.text
    property alias  cfg_tempPrecision:     precisionSpin.value
    property alias  cfg_humidityPrecision: humidityPrecisionSpin.value
    property alias  cfg_updateInterval:    intervalSpin.value
    property alias  cfg_debugLayout:       debugSwitch.checked

    // ── Internal geocoding state ────────────────────────────────────
    property var    geocodeResults: []
    property bool   geocoding:      false
    property string geocodeError:   ""

    readonly property bool isOwm: presetCombo.currentIndex !== 2

    // ── 1. API Provider ─────────────────────────────────────────────
    ComboBox {
        id: presetCombo
        Kirigami.FormData.label: i18n("API provider:")
        model: [
            i18n("OpenWeatherMap One Call 3.0"),
            i18n("OpenWeatherMap One Call 2.5 (legacy)"),
            i18n("Custom URL")
        ]
        readonly property var values: ["owm30", "owm25", "custom"]
        Component.onCompleted: {
            var idx = values.indexOf(cfg_apiPreset)
            currentIndex = idx >= 0 ? idx : 2
        }
        onActivated: cfg_apiPreset = values[currentIndex]
    }

    // ── 2. API Key (OWM only) ───────────────────────────────────────
    TextField {
        id: apiKeyField
        Kirigami.FormData.label: i18n("API key:")
        placeholderText: i18n("Paste your OpenWeatherMap key here")
        text: cfg_apiKey
        onTextChanged: cfg_apiKey = text
        echoMode: TextInput.Password
        Layout.minimumWidth: Kirigami.Units.gridUnit * 22
        visible: isOwm
    }

    // ── 3. Custom URL (Custom only) ─────────────────────────────────
    TextField {
        id: endpointField
        Kirigami.FormData.label: i18n("API endpoint:")
        placeholderText: "http://host/data/3.0/onecall"
        Layout.minimumWidth: Kirigami.Units.gridUnit * 22
        visible: !isOwm
    }

    // ── 4. Location search (OWM only) ───────────────────────────────
    RowLayout {
        Kirigami.FormData.label: i18n("Location:")
        spacing: Kirigami.Units.smallSpacing
        visible: isOwm

        TextField {
            id: searchField
            placeholderText: i18n("City, region, country…")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 18
            Keys.onReturnPressed: doGeocode()
        }

        Button {
            text: geocoding ? i18n("Searching…") : i18n("Search")
            enabled: !geocoding && searchField.text.trim() !== ""
            onClicked: doGeocode()
        }
    }

    // Geocode error
    PlasmaComponents.Label {
        Kirigami.FormData.label: ""
        text: geocodeError
        visible: isOwm && geocodeError !== ""
        color: Kirigami.Theme.negativeTextColor
        font.pointSize: Kirigami.Theme.smallFont.pointSize
    }

    // Search results list
    ListView {
        id: resultsList
        Kirigami.FormData.label: i18n("Results:")
        visible: isOwm && geocodeResults.length > 0
        Layout.minimumWidth: Kirigami.Units.gridUnit * 22
        implicitHeight: Math.min(geocodeResults.length, 5) * Kirigami.Units.gridUnit * 2
        clip: true
        model: geocodeResults

        delegate: ItemDelegate {
            width: resultsList.width
            text: modelData.display_name
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            onClicked: {
                cfg_latitude        = String(modelData.lat)
                cfg_longitude       = String(modelData.lon)
                cfg_locationDisplay = modelData.display_name
                geocodeResults      = []
                searchField.text    = ""
                geocodeError        = ""
            }
        }
    }

    // Currently selected location
    PlasmaComponents.Label {
        Kirigami.FormData.label: i18n("Selected:")
        visible: isOwm
        text: cfg_locationDisplay !== ""
            ? cfg_locationDisplay
            : (cfg_latitude !== "" && cfg_longitude !== ""
                ? cfg_latitude + ", " + cfg_longitude
                : i18n("None — search above"))
        opacity: cfg_locationDisplay !== "" ? 1.0 : 0.5
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        wrapMode: Text.WordWrap
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
    }

    // Manual coordinate entry (advanced)
    Switch {
        id: coordSwitch
        Kirigami.FormData.label: i18n("Enter coordinates manually:")
        checked: false
        visible: isOwm
    }

    TextField {
        Kirigami.FormData.label: i18n("Latitude:")
        text: cfg_latitude
        onTextChanged: cfg_latitude = text
        placeholderText: "36.8253"
        Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        visible: isOwm && coordSwitch.checked
    }

    TextField {
        Kirigami.FormData.label: i18n("Longitude:")
        text: cfg_longitude
        onTextChanged: cfg_longitude = text
        placeholderText: "-121.3800"
        Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        visible: isOwm && coordSwitch.checked
    }

    // ── 5. Display name override ────────────────────────────────────
    Switch {
        id: locationOverrideSwitch
        Kirigami.FormData.label: i18n("Override display name:")
        checked: locationField.text !== ""
        onToggled: { if (!checked) locationField.text = "" }
    }

    TextField {
        id: locationField
        Kirigami.FormData.label: i18n("Display name:")
        placeholderText: i18n("e.g. Hollister, CA")
        Layout.minimumWidth: Kirigami.Units.gridUnit * 22
        visible: locationOverrideSwitch.checked
    }

    // ── 6. Fetch and display settings ───────────────────────────────
    SpinBox {
        id: intervalSpin
        Kirigami.FormData.label: i18n("Refresh interval (minutes):")
        from: 1
        to: 60
    }

    SpinBox {
        id: precisionSpin
        Kirigami.FormData.label: i18n("Temperature decimal places:")
        from: 0
        to: 2
    }

    SpinBox {
        id: humidityPrecisionSpin
        Kirigami.FormData.label: i18n("Humidity decimal places:")
        from: 0
        to: 2
    }

    Switch {
        id: debugSwitch
        Kirigami.FormData.label: i18n("Debug layout:")
    }

    // ── Geocode via Nominatim ───────────────────────────────────────
    function doGeocode() {
        var q = searchField.text.trim()
        if (q === "") return
        geocoding      = true
        geocodeError   = ""
        geocodeResults = []

        var xhr = new XMLHttpRequest()
        xhr.open("GET", "https://nominatim.openstreetmap.org/search?q="
            + encodeURIComponent(q) + "&format=json&limit=5")
        xhr.setRequestHeader("User-Agent", "KDE-Weather-Widget/1.0")
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            geocoding = false
            if (xhr.status === 200) {
                try {
                    var res = JSON.parse(xhr.responseText)
                    if (res.length === 0)
                        geocodeError = i18n("No results found.")
                    else
                        geocodeResults = res
                } catch (e) {
                    geocodeError = i18n("Could not parse response.")
                }
            } else {
                geocodeError = i18n("Request failed (HTTP %1).").arg(xhr.status)
            }
        }
        xhr.send()
    }
}
