// Shared provider registry for runtime fetch logic and config UI.
// Add a new provider by appending an object in `list()`.
//
// Supported template tokens:
// - {lat}
// - {lon}
// - {apiKey}
// - {endpoint}
//
// `parser` decides how response JSON is normalized:
// - "openmeteo"      -> Open-Meteo API response
// - "weathergov"     -> weather.gov points + forecast APIs
// - "owm_onecall"    -> OpenWeatherMap One Call (2.5 / 3.0)
// - "owm_compatible" -> custom endpoint that already matches OWM-like shape

function list() {
  return [
    {
      id: "openmeteo",
      label: "Open-Meteo (No API key)",
      parser: "openmeteo",
      description: "Works out of the box. Free, no account required.",
      requiresApiKey: false,
      requiresEndpoint: false,
      requiresCoords: true,
      supportsGeocoding: true,
      requestTemplate:
        "https://api.open-meteo.com/v1/forecast" +
        "?latitude={lat}&longitude={lon}" +
        "&current=temperature_2m,relative_humidity_2m,apparent_temperature,pressure_msl,wind_speed_10m,weather_code,is_day" +
        "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max" +
        "&timezone=auto&forecast_days=7&wind_speed_unit=ms",
    },
    {
      id: "weathergov",
      label: "weather.gov (US National Weather Service)",
      parser: "weathergov",
      description: "US locations only. Free, no API key required.",
      requiresApiKey: false,
      requiresEndpoint: false,
      requiresCoords: true,
      supportsGeocoding: true,
      requestTemplate: "https://api.weather.gov/points/{lat},{lon}",
    },
    {
      id: "owm30",
      label: "OpenWeatherMap One Call 3.0",
      parser: "owm_onecall",
      description: "Requires OpenWeatherMap API key.",
      requiresApiKey: true,
      requiresEndpoint: false,
      requiresCoords: true,
      supportsGeocoding: true,
      requestTemplate:
        "https://api.openweathermap.org/data/3.0/onecall" +
        "?lat={lat}&lon={lon}&appid={apiKey}&units=metric",
    },
    {
      id: "owm25",
      label: "OpenWeatherMap One Call 2.5 (legacy)",
      parser: "owm_onecall",
      description: "Legacy endpoint. Requires OpenWeatherMap API key.",
      requiresApiKey: true,
      requiresEndpoint: false,
      requiresCoords: true,
      supportsGeocoding: true,
      requestTemplate:
        "https://api.openweathermap.org/data/2.5/onecall" +
        "?lat={lat}&lon={lon}&appid={apiKey}&units=metric",
    },
    {
      id: "custom",
      label: "Custom URL (OWM-compatible JSON)",
      parser: "owm_compatible",
      description: "Use a full endpoint URL that returns OWM-like fields.",
      requiresApiKey: false,
      requiresEndpoint: true,
      requiresCoords: false,
      supportsGeocoding: false,
      requestTemplate: "{endpoint}",
    },
  ];
}

function byId(id) {
  var all = list();
  for (var i = 0; i < all.length; i++) {
    if (all[i].id === id) return all[i];
  }
  return null;
}
