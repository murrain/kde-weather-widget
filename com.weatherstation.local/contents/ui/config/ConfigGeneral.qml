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
    property bool providerTestRunning: false
    property string providerTestMessage: ""
    property bool providerTestSuccess: false

    readonly property var providerDefs: Providers.list()
    readonly property var providerIds: providerDefs.map(function (p) { return p.id })
    readonly property var providerLabels: providerDefs.map(function (p) { return p.label })
    readonly property var currentProvider: {
        var id = providerIds[presetCombo.currentIndex]
        return Providers.byId(id) || Providers.byId("openmeteo")
    }
    readonly property string coordValidationError: {
        if (!currentProvider || !currentProvider.requiresCoords) return ""
        var lat = String(cfg_latitude || "").trim()
        var lon = String(cfg_longitude || "").trim()
        if (!lat || !lon)
            return i18n("%1 requires a location. Search above or enter coordinates manually.").arg(currentProvider.label || i18n("Selected provider"))
        var latN = Number(lat)
        var lonN = Number(lon)
        if (isNaN(latN) || latN < -90 || latN > 90)
            return i18n("Latitude must be between -90 and 90.")
        if (isNaN(lonN) || lonN < -180 || lonN > 180)
            return i18n("Longitude must be between -180 and 180.")
        return ""
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
        Kirigami.FormData.label: i18n("Connection test:")
        spacing: Kirigami.Units.smallSpacing
        visible: currentProvider !== null

        Button {
            text: providerTestRunning ? i18n("Testing…") : i18n("Test Provider")
            enabled: !providerTestRunning
            onClicked: doProviderTest()
        }

        PlasmaComponents.Label {
            text: providerTestMessage
            visible: providerTestMessage !== ""
            color: providerTestSuccess ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
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

    PlasmaComponents.Label {
        Kirigami.FormData.label: ""
        visible: currentProvider && currentProvider.requiresCoords && coordValidationError !== ""
        text: coordValidationError
        color: Kirigami.Theme.negativeTextColor
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

    function trimmed(v) {
        return String(v === undefined || v === null ? "" : v).trim()
    }

    function shortUrl(url) {
        var s = trimmed(url)
        if (!s) return i18n("provider URL")
        var noQuery = s.split("?")[0]
        if (noQuery.length <= 72) return noQuery
        return noQuery.slice(0, 69) + "..."
    }

    function responsePreview(body) {
        return String(body || "").replace(/\s+/g, " ").trim().slice(0, 120)
    }

    function providerLabel(provider) {
        return provider && provider.label ? provider.label : i18n("Selected provider")
    }

    function providerConfigError(provider) {
        if (!provider) return i18n("No provider selected.")

        if (provider.requiresCoords && coordValidationError !== "") return coordValidationError
        if (provider.requiresApiKey && trimmed(cfg_apiKey) === "")
            return i18n("%1 requires an API key.").arg(providerLabel(provider))
        if (provider.requiresEndpoint) {
            var endpoint = trimmed(cfg_apiEndpoint)
            if (!endpoint) return i18n("Set API endpoint URL first.")
            if (!/^https?:\/\//.test(endpoint)) return i18n("API endpoint must start with http:// or https://.")
        }
        return ""
    }

    function buildRequestUrl(provider) {
        if (!provider) return ""
        var tpl = provider.requestTemplate || ""
        var endpoint = trimmed(cfg_apiEndpoint)
        var lat = trimmed(cfg_latitude)
        var lon = trimmed(cfg_longitude)
        var key = trimmed(cfg_apiKey)

        var url = tpl
            .replace("{lat}", encodeURIComponent(lat))
            .replace("{lon}", encodeURIComponent(lon))
            .replace("{apiKey}", encodeURIComponent(key))
            .replace("{endpoint}", endpoint)

        if (provider.parser === "owm_compatible") {
            var sep = url.indexOf("?") >= 0 ? "&" : "?"
            if (url.indexOf("units=") < 0) url += sep + "units=metric"
        }
        return url
    }

    function validateProviderPayload(provider, parsed) {
        var missing = []
        if (!parsed || typeof parsed !== "object") missing.push("root object")
        if (!provider) return i18n("No provider selected.")

        if (provider.parser === "openmeteo") {
            if (!parsed.current) missing.push("current")
            if (!parsed.daily) missing.push("daily")
            if (!parsed.current || parsed.current.temperature_2m === undefined) missing.push("current.temperature_2m")
            if (!parsed.current || parsed.current.wind_speed_10m === undefined) missing.push("current.wind_speed_10m")
            if (!parsed.current || parsed.current.wind_direction_10m === undefined) missing.push("current.wind_direction_10m")
            if (!parsed.daily || !parsed.daily.time || parsed.daily.time.length === 0) missing.push("daily.time[0]")
        } else if (provider.parser === "owm_onecall" || provider.parser === "owm_compatible") {
            if (!parsed.current) missing.push("current")
            if (!parsed.daily || parsed.daily.length === 0) missing.push("daily[0]")
            if (!parsed.current || parsed.current.wind_speed === undefined) missing.push("current.wind_speed")
            if (!parsed.current || !parsed.current.weather || parsed.current.weather.length === 0) missing.push("current.weather[0]")
        }

        if (missing.length === 0) return ""
        return i18n("Response schema is missing required fields: %1").arg(missing.join(", "))
    }

    function requestJson(url, timeoutMs, headers, onSuccess, onError) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.timeout = timeoutMs || 12000
        for (var key in headers) {
            if (headers.hasOwnProperty(key)) xhr.setRequestHeader(key, headers[key])
        }
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status !== 200) {
                var preview = responsePreview(xhr.responseText)
                var statusMsg = i18n("HTTP %1 from %2").arg(xhr.status).arg(shortUrl(url))
                if (preview) statusMsg += i18n(" — Response starts with: %1").arg(preview)
                onError(statusMsg)
                return
            }
            try {
                onSuccess(JSON.parse(xhr.responseText))
            } catch (e) {
                var parsePreview = responsePreview(xhr.responseText)
                var parseMsg = i18n("Could not parse JSON from %1.").arg(shortUrl(url))
                if (parsePreview) parseMsg += i18n(" Response starts with: %1").arg(parsePreview)
                onError(parseMsg)
            }
        }
        xhr.onerror = function () { onError(i18n("Network error while requesting %1.").arg(shortUrl(url))) }
        xhr.ontimeout = function () { onError(i18n("Request timed out for %1.").arg(shortUrl(url))) }
        xhr.send()
    }

    function setProviderTestResult(ok, message) {
        providerTestRunning = false
        providerTestSuccess = ok
        providerTestMessage = message
    }

    function doProviderTest() {
        var provider = currentProvider
        providerTestRunning = true
        providerTestSuccess = false
        providerTestMessage = ""

        var cfgError = providerConfigError(provider)
        if (cfgError !== "") {
            setProviderTestResult(false, cfgError)
            return
        }

        var url = buildRequestUrl(provider)
        if (!url) {
            setProviderTestResult(false, i18n("Could not build request URL."))
            return
        }

        var headers = {}
        if (provider && provider.parser === "weathergov") {
            headers = {
                "Accept": "application/geo+json",
                "User-Agent": "kde-weather-widget/1.0 (+https://github.com/murrain/kde-weather-widget)"
            }
        }

        requestJson(url, 12000, headers, function (parsed) {
            if (provider && provider.parser === "weathergov") {
                var props = parsed && parsed.properties ? parsed.properties : null
                var hourly = props && props.forecastHourly ? props.forecastHourly : ""
                var daily = props && props.forecast ? props.forecast : ""
                if (!hourly || !daily) {
                    setProviderTestResult(false, i18n("weather.gov points response is missing forecast URLs. Check that coordinates are in the United States."))
                    return
                }
                setProviderTestResult(true, i18n("Success: weather.gov points resolved to forecast endpoints."))
                return
            }

            var payloadError = validateProviderPayload(provider, parsed)
            if (payloadError !== "") {
                setProviderTestResult(false, payloadError)
                return
            }

            setProviderTestResult(true, i18n("Success: %1 returned valid JSON and expected fields.").arg(providerLabel(provider)))
        }, function (msg) {
            setProviderTestResult(false, i18n("%1 test failed: %2").arg(providerLabel(provider)).arg(msg))
        })
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
                    var parsePreview = responsePreview(xhr.responseText)
                    geocodeError = i18n("Could not parse location response from %1.").arg(shortUrl(xhr.responseURL || "nominatim"))
                    if (parsePreview) geocodeError += i18n(" Response starts with: %1").arg(parsePreview)
                }
            } else {
                var httpPreview = responsePreview(xhr.responseText)
                geocodeError = i18n("Location lookup failed (HTTP %1).").arg(xhr.status)
                if (httpPreview) geocodeError += i18n(" Response starts with: %1").arg(httpPreview)
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
