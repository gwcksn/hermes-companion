/// Trimmed Open-Meteo /v1/forecast response (shape captured from the live API, 2026-10-16).
Map<String, dynamic> openMeteoFixture({
  int currentCode = 2,
  double currentTemp = 29.3,
  int isDay = 1,
  List<int> rain = const [10, 10, 20, 60, 80, 40],
  List<int> codes = const [2, 3, 3, 61, 63, 3],
}) => {
  'timezone': 'Asia/Jakarta',
  'current': {'time': '2026-10-16T17:15', 'temperature_2m': currentTemp, 'weather_code': currentCode, 'is_day': isDay},
  'hourly': {
    'time': [
      '2026-10-16T17:00', '2026-10-16T18:00', '2026-10-16T19:00', //
      '2026-10-16T20:00', '2026-10-16T21:00', '2026-10-16T22:00',
    ],
    'temperature_2m': [29.0, 27.4, 26.2, 25.5, 24.6, 24.1],
    'weather_code': codes,
    'precipitation_probability': rain,
    'is_day': [1, 1, 0, 0, 0, 0],
  },
};
