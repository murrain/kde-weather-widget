import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents
import "../lib/Providers.js" as Providers

Kirigami.FormLayout {
    id: configPage

    property string cfg_apiPreset
    property string cfg_apiKey
    property string cfg_latitude
    property string cfg_longitude
    property string cfg_locationDisplay
    property alias cfg_apiEndpoint: endpointField.text
    property alias cfg_locationName: locationField.text
    property alias cfg_tempPrecision: precisionSpin.value
    property alias cfg_humidityPrecision: humidityPrecisionSpin.value
    property alias cfg_updateInterval: intervalSpin.value
    property alias cfg_debugLayout: debugSwitch.checked

    property var geocodeResults: []
    property bool geocoding: false
    property string geocodeError: ""

    readonly property var providerDefs: Providers.list()
    readonly property var providerIds: providerDefs.map(function (p) { return p.id })
    readonly property var providerLabels: providerDefs.map(function (p) { return p.label })
    readonly property var currentProvider: {
        var id = providerIds[presetCombo.currentIndex]
        return Providers.byId(id) || Providers.byId("openmeteo")
    }

    Component.onCompleted: {
        var idx = providerIds.indexOf(cfg_apiPreset)
        presetCombo.currentIndex = idx >= 0 ? idx : providerIds.indexOf("openmeteo")
        cfg_apiPreset = providerIds[presetCombo.currentIndex]
    }

    ComboBox {
        id: presetCombo
        Kirigami.FormData.label: i18n("API provider:")
        model: providerLabels
        onActivated: cfg_apiPreset = providerIds[currentIndex]
    }

    PlasmaComponents.Label {
        Kirigami.FormData.label: ""
        text: currentProvider && currentProvider.description ? currentProvider.description : ""
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        opacity: 0.75
        wrapMode: Text.WordWrap
        Layout.maximumWidth: Kirigami.Units.gridUnit * 24
    }

    TextField {
        id: apiKeyField
        Kirigami.FormData.label: i18n("API key:")
        placeholderText: i18n("Paste provider API key")
        text: cfg_apiKey
        onTextChanged: cfg_apiKey = text
        echoMode: TextInput.Password
        Layout.minimumWidth: Kirigami.Units.gridUnit * 22
        visible: currentProvider && currentProvider.requiresApiKey
    }

    TextField {
        id: endpointField
        Kirigami.FormData.label: i18n("API endpoint:")
        placeholderText: "https://api.example.com/weather"
        Layout.minimumWidth: Kirigami.Units.gridUnit * 22
        visible: currentProvider && currentProvider.requiresEndpoint
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Location:")
        spacing: Kirigami.Units.smallSpacing
        visible: currentProvider && currentProvider.supportsGeocoding

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

    PlasmaComponents.Label {
        Kirigami.FormData.label: ""
        text: geocodeError
        visible: currentProvider && currentProvider.supportsGeocoding && geocodeError !== ""
        color: Kirigami.Theme.negativeTextColor
        font.pointSize: Kirigami.Theme.smallFont.pointSize
    }

    ListView {
        id: resultsList
        Kirigami.FormData.label: i18n("Results:")
        visible: currentProvider && currentProvider.supportsGeocoding && geocodeResults.length > 0
        Layout.minimumWidth: Kirigami.Units.gridUnit * 22
        implicitHeight: Math.min(geocodeResults.length, 5) * Kirigami.Units.gridUnit * 2
        clip: true
        model: geocodeResults

        delegate: ItemDelegate {
            width: resultsList.width
            text: modelData.display_name
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            onClicked: {
                cfg_latitude = String(modelData.lat)
                cfg_longitude = String(modelData.lon)
                cfg_locationDisplay = modelData.display_name
                geocodeResults = []
                searchField.text = ""
                geocodeError = ""
            }
        }
    }

    PlasmaComponents.Label {
        Kirigami.FormData.label: i18n("Selected:")
        visible: currentProvider && currentProvider.requiresCoords
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

    Switch {
        id: coordSwitch
        Kirigami.FormData.label: i18n("Enter coordinates manually:")
        checked: false
        visible: currentProvider && currentProvider.requiresCoords
    }

    TextField {
        Kirigami.FormData.label: i18n("Latitude:")
        text: cfg_latitude
        onTextChanged: cfg_latitude = text
        placeholderText: "36.8253"
        Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        visible: currentProvider && currentProvider.requiresCoords && coordSwitch.checked
    }

    TextField {
        Kirigami.FormData.label: i18n("Longitude:")
        text: cfg_longitude
        onTextChanged: cfg_longitude = text
        placeholderText: "-121.3800"
        Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        visible: currentProvider && currentProvider.requiresCoords && coordSwitch.checked
    }

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

    function doGeocode() {
        var q = searchField.text.trim()
        if (q === "") return
        geocoding = true
        geocodeError = ""
        geocodeResults = []

        var xhr = new XMLHttpRequest()
        xhr.open("GET", "https://nominatim.openstreetmap.org/search?q="
            + encodeURIComponent(q) + "&format=json&limit=5")
        xhr.setRequestHeader("User-Agent", "KDE-Weather-Widget/1.0")
        xhr.timeout = 12000
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            geocoding = false
            if (xhr.status === 200) {
                try {
                    var res = JSON.parse(xhr.responseText)
                    if (!res || res.length === 0)
                        geocodeError = i18n("No results found.")
                    else
                        geocodeResults = res
                } catch (e) {
                    geocodeError = i18n("Could not parse location response.")
                }
            } else {
                geocodeError = i18n("Location lookup failed (HTTP %1).").arg(xhr.status)
            }
        }
        xhr.onerror = function () {
            geocoding = false
            geocodeError = i18n("Network error while searching for location.")
        }
        xhr.ontimeout = function () {
            geocoding = false
            geocodeError = i18n("Location lookup timed out.")
        }
        xhr.send()
    }
}
