import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import "lib/Providers.js" as Providers

PlasmoidItem {
    id: root

    // Shared state
    property var weatherData: null
    property string lastUpdated: ""
    property bool loading: false
    property string errorMsg: ""
    property string fetchDebugMsg: ""
    property var weatherGovCache: ({
        key: "",
        hourlyUrl: "",
        dailyUrl: "",
        city: "",
        state: ""
    })

    readonly property var selectedProvider: providerForId(Plasmoid.configuration.apiPreset || "openmeteo")

    property string kdeIcon: (weatherData && weatherData.current
            && weatherData.current.weather && weatherData.current.weather.length > 0)
        ? owmIconToKde(weatherData.current.weather[0].icon)
        : (errorMsg ? "dialog-warning" : "weather-none-available")

    property string currentTempStr: (weatherData && weatherData.current && isFiniteNumber(weatherData.current.temp))
        ? Math.round(convertTemp(weatherData.current.temp)) + tempSuffix()
        : "--"

    property string currentTemp: (weatherData && weatherData.current)
        ? formatTemp(weatherData.current.temp)
        : "--"

    property string locationName: Plasmoid.configuration.locationName
        || Plasmoid.configuration.locationDisplay
        || (weatherData && weatherData.name ? weatherData.name : "")
        || "Weather Station"

    property string conditionStr: (weatherData && weatherData.current
            && weatherData.current.weather && weatherData.current.weather.length > 0)
        ? capitalize(weatherData.current.weather[0].description)
        : (loading ? "Loading…" : (errorMsg || "No data"))

    compactRepresentation: CompactRepresentation {}
    fullRepresentation: FullRepresentation {}

    switchWidth: Kirigami.Units.gridUnit * 10
    switchHeight: Kirigami.Units.gridUnit * 10

    Plasmoid.icon: kdeIcon
    Plasmoid.title: ""
    toolTipMainText: conditionStr
    toolTipSubText: currentTemp

    Component.onCompleted: fetchWeather()

    Timer {
        id: refreshTimer
        interval: (Plasmoid.configuration.updateInterval || 5) * 60 * 1000
        running: true
        repeat: true
        onTriggered: fetchWeather()
    }

    Connections {
        target: Plasmoid.configuration
        function onApiEndpointChanged() { fetchWeather() }
        function onApiPresetChanged() { fetchWeather() }
        function onApiKeyChanged() { fetchWeather() }
        function onLatitudeChanged() { clearWeatherGovCache(); fetchWeather() }
        function onLongitudeChanged() { clearWeatherGovCache(); fetchWeather() }
        function onLocationDisplayChanged() { fetchWeather() }
        function onUpdateIntervalChanged() {
            refreshTimer.interval = (Plasmoid.configuration.updateInterval || 5) * 60 * 1000
            refreshTimer.restart()
        }
    }

    function providerForId(id) {
        return Providers.byId(id) || Providers.byId("openmeteo")
    }

    function clearWeatherGovCache() {
        weatherGovCache = {
            key: "",
            hourlyUrl: "",
            dailyUrl: "",
            city: "",
            state: ""
        }
    }

    function fetchWeather() {
        loading = true
        errorMsg = ""
        fetchDebugMsg = ""

        var provider = selectedProvider
        var validationError = validateProviderConfig(provider)
        if (validationError !== "") {
            loading = false
            weatherData = null
            errorMsg = validationError
            return
        }

        var url = buildRequestUrl(provider)
        if (!url) {
            loading = false
            weatherData = null
            errorMsg = "Could not build request URL for provider."
            return
        }

        if (provider.parser === "weathergov") {
            fetchWeatherGov(url, provider)
            return
        }

        requestJson(url, 15000, {}, function (parsed) {
            var normalized = normalizeWeatherData(parsed, provider)
            if (!normalized || !normalized.current || !normalized.current.weather) {
                loading = false
                weatherData = null
                errorMsg = "Response format is missing required weather fields."
                return
            }
            loading = false
            weatherData = normalized
            lastUpdated = Qt.formatTime(new Date(), "h:mm AP")
            errorMsg = ""
        }, function (msg) {
            loading = false
            weatherData = null
            errorMsg = msg
        })
    }

    function requestJson(url, timeoutMs, headers, onSuccess, onError) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.timeout = timeoutMs || 15000
        for (var key in headers) {
            if (headers.hasOwnProperty(key)) xhr.setRequestHeader(key, headers[key])
        }
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status !== 200) {
                onError(httpErrorMessage(xhr.status, xhr.responseText))
                return
            }
            try {
                onSuccess(JSON.parse(xhr.responseText))
            } catch (e) {
                onError("Could not parse weather response.")
            }
        }
        xhr.onerror = function () {
            onError("Network error while contacting weather provider.")
        }
        xhr.ontimeout = function () {
            onError("Weather request timed out after " + Math.round((timeoutMs || 15000) / 1000) + " seconds.")
        }
        xhr.send()
    }

    function fetchWeatherGov(pointsUrl, provider) {
        var lat = trimmed(Plasmoid.configuration.latitude)
        var lon = trimmed(Plasmoid.configuration.longitude)
        var cacheKey = lat + "," + lon

        var headers = {
            "Accept": "application/geo+json",
            "User-Agent": "kde-weather-widget/1.0 (+https://github.com/murrain/kde-weather-widget)"
        }

        if (weatherGovCache.key === cacheKey && weatherGovCache.hourlyUrl && weatherGovCache.dailyUrl) {
            fetchDebugMsg = "weather.gov: using cached forecast URLs"
            fetchWeatherGovForecasts(weatherGovCache.hourlyUrl, weatherGovCache.dailyUrl, weatherGovCache.city, weatherGovCache.state, headers)
            return
        }

        fetchDebugMsg = "weather.gov: resolving points endpoint"
        requestJson(pointsUrl, 15000, headers, function (points) {
            var props = points && points.properties ? points.properties : null
            var hourlyUrl = props && props.forecastHourly ? props.forecastHourly : ""
            var dailyUrl = props && props.forecast ? props.forecast : ""
            var city = props && props.relativeLocation && props.relativeLocation.properties
                ? props.relativeLocation.properties.city
                : ""
            var state = props && props.relativeLocation && props.relativeLocation.properties
                ? props.relativeLocation.properties.state
                : ""

            if (!hourlyUrl || !dailyUrl) {
                loading = false
                weatherData = null
                errorMsg = "weather.gov points response did not include forecast URLs."
                return
            }

            weatherGovCache = {
                key: cacheKey,
                hourlyUrl: hourlyUrl,
                dailyUrl: dailyUrl,
                city: city,
                state: state
            }
            fetchDebugMsg = "weather.gov: points resolved, fetching forecasts"
            fetchWeatherGovForecasts(hourlyUrl, dailyUrl, city, state, headers)
        }, function (msg) {
            loading = false
            weatherData = null
            if (msg.indexOf("(404)") >= 0)
                errorMsg = "weather.gov has no forecast coverage for this location."
            else
                errorMsg = "weather.gov points lookup error: " + msg
        })
    }

    function fetchWeatherGovForecasts(hourlyUrl, dailyUrl, city, state, headers) {
        requestJson(hourlyUrl, 15000, headers, function (hourly) {
            requestJson(dailyUrl, 15000, headers, function (daily) {
                var normalized = normalizeWeatherGov(hourly, daily, city, state)
                if (!normalized || !normalized.current || !normalized.daily || normalized.daily.length === 0) {
                    loading = false
                    weatherData = null
                    errorMsg = "weather.gov response format is missing required weather fields."
                    return
                }
                loading = false
                weatherData = normalized
                lastUpdated = Qt.formatTime(new Date(), "h:mm AP")
                errorMsg = ""
            }, function (msg) {
                loading = false
                weatherData = null
                errorMsg = "weather.gov daily forecast error: " + msg
            })
        }, function (msg) {
            loading = false
            weatherData = null
            errorMsg = "weather.gov hourly forecast error: " + msg
        })
    }

    function validateProviderConfig(provider) {
        if (!provider) return "No provider selected."

        if (provider.requiresCoords) {
            var latOk = isValidLatitude(Plasmoid.configuration.latitude)
            var lonOk = isValidLongitude(Plasmoid.configuration.longitude)
            if (!latOk || !lonOk)
                return "Set a valid location first (latitude -90..90, longitude -180..180)."
        }

        if (provider.requiresApiKey && !trimmed(Plasmoid.configuration.apiKey))
            return "This provider needs an API key. Open Configure → General and set API key."

        if (provider.requiresEndpoint) {
            var endpoint = trimmed(Plasmoid.configuration.apiEndpoint)
            if (!endpoint)
                return "Set API endpoint URL in Configure → General."
            if (!/^https?:\/\//.test(endpoint))
                return "API endpoint must start with http:// or https://."
        }

        return ""
    }

    function buildRequestUrl(provider) {
        var tpl = provider.requestTemplate || ""
        var endpoint = trimmed(Plasmoid.configuration.apiEndpoint)
        var lat = trimmed(Plasmoid.configuration.latitude)
        var lon = trimmed(Plasmoid.configuration.longitude)
        var key = trimmed(Plasmoid.configuration.apiKey)

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

    function normalizeWeatherData(raw, provider) {
        if (!provider || !raw) return null
        if (provider.parser === "openmeteo") return normalizeOpenMeteo(raw)
        if (provider.parser === "weathergov") return null
        if (provider.parser === "owm_onecall") return normalizeOwmOneCall(raw)
        if (provider.parser === "owm_compatible") return normalizeOwmCompatible(raw)
        return null
    }

    function normalizeOwmOneCall(raw) {
        if (!raw.current || !raw.daily || raw.daily.length === 0) return null
        return raw
    }

    function normalizeOwmCompatible(raw) {
        if (!raw.current || !raw.daily) return null
        return raw
    }

    function normalizeOpenMeteo(raw) {
        if (!raw.current || !raw.daily) return null

        var cw = openMeteoCodeToWeather(raw.current.weather_code, raw.current.is_day)
        var daily = []
        var dates = raw.daily.time || []
        var codes = raw.daily.weather_code || []
        var tMax = raw.daily.temperature_2m_max || []
        var tMin = raw.daily.temperature_2m_min || []
        var pop = raw.daily.precipitation_probability_max || []

        for (var i = 0; i < dates.length; i++) {
            var dCode = codes[i]
            var dayWeather = openMeteoCodeToWeather(dCode, 1)
            var nightWeather = openMeteoCodeToWeather(dCode, 0)
            var dt = Date.parse(dates[i] + "T12:00:00Z") / 1000
            daily.push({
                dt: isNaN(dt) ? Math.floor(Date.now() / 1000) : Math.floor(dt),
                temp: {
                    max: tMax[i],
                    min: tMin[i],
                    night: tMin[i]
                },
                weather: [dayWeather],
                pop: Number(pop[i] || 0) / 100.0,
                day_detail: {
                    weather: [dayWeather],
                    pop: Number(pop[i] || 0) / 100.0
                },
                night_detail: {
                    weather: [nightWeather],
                    pop: Number(pop[i] || 0) / 100.0
                }
            })
        }

        return {
            current: {
                temp: raw.current.temperature_2m,
                feels_like: raw.current.apparent_temperature,
                humidity: raw.current.relative_humidity_2m,
                pressure: raw.current.pressure_msl,
                wind_speed: raw.current.wind_speed_10m,
                wind_deg: raw.current.wind_direction_10m,
                dew_point: null,
                visibility: null,
                weather: [cw]
            },
            daily: daily
        }
    }

    function normalizeWeatherGov(hourlyRaw, dailyRaw, city, state) {
        var hourlyPeriods = (hourlyRaw && hourlyRaw.properties && hourlyRaw.properties.periods) ? hourlyRaw.properties.periods : []
        var dailyPeriods = (dailyRaw && dailyRaw.properties && dailyRaw.properties.periods) ? dailyRaw.properties.periods : []
        if (!hourlyPeriods.length || !dailyPeriods.length) return null

        var currentPeriod = hourlyPeriods[0]
        var currentTempC = convertTempToC(currentPeriod.temperature, currentPeriod.temperatureUnit)
        var currentWindMps = parseWindToMps(currentPeriod.windSpeed)
        var currentPop = popPercentToFraction(currentPeriod.probabilityOfPrecipitation)
        var currentWeather = weatherGovTextToWeather(currentPeriod.shortForecast, currentPeriod.isDaytime)

        var grouped = {}
        for (var i = 0; i < dailyPeriods.length; i++) {
            var p = dailyPeriods[i]
            var key = dateKeyFromIso(p.startTime)
            if (!key) continue
            if (!grouped[key]) grouped[key] = { day: null, night: null }
            if (p.isDaytime) grouped[key].day = p
            else grouped[key].night = p
        }

        var keys = Object.keys(grouped).sort()
        var daily = []
        for (var j = 0; j < keys.length && daily.length < 7; j++) {
            var dayKey = keys[j]
            var pair = grouped[dayKey]
            var d = pair.day
            var n = pair.night
            if (!d && !n) continue

            var dayTempC = d ? convertTempToC(d.temperature, d.temperatureUnit) : null
            var nightTempC = n ? convertTempToC(n.temperature, n.temperatureUnit) : dayTempC
            var maxC = (dayTempC !== null) ? dayTempC : nightTempC
            var minC = (nightTempC !== null) ? nightTempC : dayTempC
            var dayW = weatherGovTextToWeather(d ? d.shortForecast : (n ? n.shortForecast : ""), true)
            var nightW = weatherGovTextToWeather(n ? n.shortForecast : (d ? d.shortForecast : ""), false)
            var popDay = popPercentToFraction(d ? d.probabilityOfPrecipitation : null)
            var popNight = popPercentToFraction(n ? n.probabilityOfPrecipitation : null)
            var dt = Date.parse(dayKey + "T12:00:00Z") / 1000

            daily.push({
                dt: isNaN(dt) ? Math.floor(Date.now() / 1000) : Math.floor(dt),
                temp: {
                    max: maxC,
                    min: minC,
                    night: (nightTempC !== null ? nightTempC : minC)
                },
                weather: [dayW],
                pop: Math.max(popDay, popNight),
                day_detail: {
                    weather: [dayW],
                    pop: popDay
                },
                night_detail: {
                    weather: [nightW],
                    pop: popNight
                }
            })
        }

        return {
            name: city && state ? (city + ", " + state) : (city || ""),
            current: {
                temp: currentTempC,
                feels_like: currentTempC,
                humidity: null,
                pressure: null,
                wind_speed: currentWindMps,
                wind_deg: parseWindDirectionToDegrees(currentPeriod.windDirection),
                dew_point: null,
                visibility: null,
                weather: [currentWeather],
                pop: currentPop
            },
            daily: daily
        }
    }

    function dateKeyFromIso(iso) {
        if (!iso) return ""
        var parts = String(iso).split("T")
        return parts.length > 0 ? parts[0] : ""
    }

    function popPercentToFraction(popObj) {
        if (!popObj || popObj.value === undefined || popObj.value === null) return 0
        var n = Number(popObj.value)
        if (isNaN(n)) return 0
        return Math.max(0, Math.min(1, n / 100.0))
    }

    function convertTempToC(temp, unit) {
        if (temp === undefined || temp === null || isNaN(Number(temp))) return null
        var t = Number(temp)
        var u = (unit || "").toUpperCase()
        if (u === "F") return (t - 32.0) * 5.0 / 9.0
        if (u === "K") return t - 273.15
        return t
    }

    function parseWindToMps(windStr) {
        if (!windStr) return 0
        var nums = String(windStr).match(/[0-9]+(\.[0-9]+)?/g)
        if (!nums || nums.length === 0) return 0
        var total = 0
        for (var i = 0; i < nums.length; i++) total += Number(nums[i])
        var avg = total / nums.length
        var s = String(windStr).toLowerCase()
        if (s.indexOf("km/h") >= 0 || s.indexOf("kph") >= 0) return avg / 3.6
        if (s.indexOf("kt") >= 0 || s.indexOf("knot") >= 0) return avg * 0.514444
        if (s.indexOf("mph") >= 0) return avg * 0.44704
        return avg
    }

    function parseWindDirectionToDegrees(direction) {
        if (!direction) return null
        var d = String(direction).toUpperCase().replace(/[^A-Z]/g, "")
        if (!d || d === "VRB" || d === "VARIABLE") return null
        var map = {
            "N": 0,
            "NNE": 22.5,
            "NE": 45,
            "ENE": 67.5,
            "E": 90,
            "ESE": 112.5,
            "SE": 135,
            "SSE": 157.5,
            "S": 180,
            "SSW": 202.5,
            "SW": 225,
            "WSW": 247.5,
            "W": 270,
            "WNW": 292.5,
            "NW": 315,
            "NNW": 337.5
        }
        return map.hasOwnProperty(d) ? map[d] : null
    }

    function weatherGovTextToWeather(shortForecast, isDay) {
        var text = shortForecast || "Unknown"
        var s = text.toLowerCase()
        var sfx = isDay ? "d" : "n"
        if (s.indexOf("thunder") >= 0) return { description: text, icon: "11" + sfx }
        if (s.indexOf("snow") >= 0 || s.indexOf("sleet") >= 0 || s.indexOf("flurr") >= 0) return { description: text, icon: "13" + sfx }
        if (s.indexOf("rain") >= 0 || s.indexOf("shower") >= 0 || s.indexOf("drizzle") >= 0) return { description: text, icon: "10" + sfx }
        if (s.indexOf("fog") >= 0 || s.indexOf("mist") >= 0 || s.indexOf("haze") >= 0) return { description: text, icon: "50" + sfx }
        if (s.indexOf("overcast") >= 0) return { description: text, icon: "04" + sfx }
        if (s.indexOf("mostly cloudy") >= 0 || s.indexOf("cloudy") >= 0) return { description: text, icon: "03" + sfx }
        if (s.indexOf("partly cloudy") >= 0 || s.indexOf("mostly clear") >= 0) return { description: text, icon: "02" + sfx }
        if (s.indexOf("clear") >= 0 || s.indexOf("sunny") >= 0 || s.indexOf("fair") >= 0) return { description: text, icon: "01" + sfx }
        return { description: text, icon: "01" + sfx }
    }

    function openMeteoCodeToWeather(code, isDay) {
        var label = "Unknown"
        var icon = isDay ? "01d" : "01n"
        switch (Number(code)) {
        case 0: label = "Clear sky"; icon = isDay ? "01d" : "01n"; break
        case 1: label = "Mainly clear"; icon = isDay ? "02d" : "02n"; break
        case 2: label = "Partly cloudy"; icon = isDay ? "03d" : "03n"; break
        case 3: label = "Overcast"; icon = isDay ? "04d" : "04n"; break
        case 45:
        case 48: label = "Fog"; icon = isDay ? "50d" : "50n"; break
        case 51:
        case 53:
        case 55:
        case 56:
        case 57: label = "Drizzle"; icon = isDay ? "09d" : "09n"; break
        case 61:
        case 63:
        case 65:
        case 66:
        case 67:
        case 80:
        case 81:
        case 82: label = "Rain"; icon = isDay ? "10d" : "10n"; break
        case 71:
        case 73:
        case 75:
        case 77:
        case 85:
        case 86: label = "Snow"; icon = isDay ? "13d" : "13n"; break
        case 95:
        case 96:
        case 99: label = "Thunderstorm"; icon = isDay ? "11d" : "11n"; break
        default: label = "Unknown"; icon = isDay ? "01d" : "01n"; break
        }
        return {
            description: label,
            icon: icon
        }
    }

    function httpErrorMessage(status, bodyText) {
        if (status === 401) return "Authorization failed (401). Check API key."
        if (status === 403) return "Access denied (403). Check provider settings."
        if (status === 404) return "Endpoint not found (404). Check provider URL."
        if (status === 429) return "Rate limit reached (429). Try a longer refresh interval."
        if (status >= 500) return "Weather provider server error (" + status + ")."

        try {
            var body = JSON.parse(bodyText || "{}")
            if (body && body.message) return "Request failed (" + status + "): " + body.message
            if (body && body.detail) return "Request failed (" + status + "): " + body.detail
            if (body && body.title) return "Request failed (" + status + "): " + body.title
        } catch (e) {}
        return "Request failed (HTTP " + (status || "error") + ")."
    }

    function trimmed(v) {
        return String(v === undefined || v === null ? "" : v).trim()
    }

    function isFiniteNumber(v) {
        var n = Number(v)
        return !isNaN(n) && isFinite(n)
    }

    function isValidLatitude(v) {
        var n = Number(trimmed(v))
        return !isNaN(n) && n >= -90 && n <= 90
    }

    function isValidLongitude(v) {
        var n = Number(trimmed(v))
        return !isNaN(n) && n >= -180 && n <= 180
    }

    function owmIconToKde(icon) {
        if (!icon) return "weather-none-available"
        var map = {
            "01d": "weather-clear",
            "01n": "weather-clear-night",
            "02d": "weather-few-clouds",
            "02n": "weather-few-clouds-night",
            "03d": "weather-clouds",
            "03n": "weather-clouds-night",
            "04d": "weather-many-clouds",
            "04n": "weather-many-clouds",
            "09d": "weather-showers-scattered",
            "09n": "weather-showers-scattered-night",
            "10d": "weather-showers",
            "10n": "weather-showers-night",
            "11d": "weather-storm",
            "11n": "weather-storm-night",
            "13d": "weather-snow",
            "13n": "weather-snow",
            "50d": "weather-fog",
            "50n": "weather-fog"
        }
        return map[icon] || "weather-none-available"
    }

    function convertTemp(c) {
        if (c === undefined || c === null || isNaN(Number(c))) return 0
        var u = Plasmoid.configuration.tempUnit || "C"
        if (u === "F") return Number(c) * 9.0 / 5.0 + 32.0
        if (u === "K") return Number(c) + 273.15
        return Number(c)
    }

    function tempSuffix() {
        var u = Plasmoid.configuration.tempUnit || "C"
        if (u === "F") return "°F"
        if (u === "K") return " K"
        return "°C"
    }

    function formatTemp(val) {
        if (val === undefined || val === null || isNaN(Number(val))) return "--"
        var p = Plasmoid.configuration.tempPrecision
        return convertTemp(val).toFixed(p !== undefined ? p : 1) + tempSuffix()
    }

    function formatHumidity(val) {
        if (val === undefined || val === null || isNaN(Number(val))) return "--"
        var p = Plasmoid.configuration.humidityPrecision
        return Number(val).toFixed(p !== undefined ? p : 0) + "%"
    }

    function formatWind(speed) {
        if (speed === undefined || speed === null || isNaN(Number(speed))) return "--"
        var u = Plasmoid.configuration.windUnit || "m/s"
        var s = Number(speed)
        if (u === "km/h") return Math.round(s * 3.6) + " km/h"
        if (u === "mph") return Math.round(s * 2.237) + " mph"
        if (u === "knots") return Math.round(s * 1.944) + " knots"
        return Math.round(s) + " m/s"
    }

    function windDirectionArrow(degrees) {
        if (degrees === undefined || degrees === null || isNaN(Number(degrees))) return ""
        var arrows = ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"]
        var normalized = ((Number(degrees) % 360) + 360) % 360
        var idx = Math.round(normalized / 45) % 8
        return arrows[idx]
    }

    function formatWindWithDirection(speed, degrees) {
        var wind = formatWind(speed)
        var arrow = windDirectionArrow(degrees)
        return arrow ? (wind + " " + arrow) : wind
    }

    function formatPressure(hpa) {
        if (hpa === undefined || hpa === null || isNaN(Number(hpa))) return "--"
        var p = Number(hpa)
        var u = Plasmoid.configuration.pressureUnit || "hPa"
        if (u === "inHg") return (p * 0.02953).toFixed(2) + " inHg"
        if (u === "mmHg") return Math.round(p * 0.7501) + " mmHg"
        return Math.round(p) + " hPa"
    }

    function formatVisibility(vis) {
        if (vis === undefined || vis === null || isNaN(Number(vis))) return "--"
        var u = Plasmoid.configuration.visibilityUnit || "km"
        var v = Number(vis)
        if (u === "mi") {
            var miles = v / 1609.34
            return miles >= 10 ? Math.round(miles) + " mi" : miles.toFixed(1) + " mi"
        }
        var km = v / 1000.0
        return km >= 10 ? Math.round(km) + " km" : km.toFixed(1) + " km"
    }

    function formatDayShort(epoch) {
        var d = new Date(epoch * 1000)
        var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return days[d.getDay()]
    }

    function capitalize(s) {
        if (!s) return ""
        return s.charAt(0).toUpperCase() + s.slice(1)
    }
}
