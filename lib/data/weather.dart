// Weather model parsed from Open-Meteo's /v1/forecast (free, no key).
import '../widgets/weather_icons.dart';

/// Yogyakarta, °C, times in WIB (Open-Meteo returns local times for timezone=Asia/Jakarta).
abstract final class WeatherPlace {
  static const name = 'Yogyakarta';
  static const latitude = -7.80;
  static const longitude = 110.36;
  static const timezone = 'Asia/Jakarta';
}

class WeatherSlot {
  const WeatherSlot({required this.label, required this.code, required this.temp, required this.isDay});

  final String label;
  final int code;
  final double temp;
  final bool isDay;

  WeatherKind get kind => kindFor(code);
}

class Weather {
  const Weather({required this.now, required this.hours, required this.hint, required this.fetchedAt});

  /// Current conditions ("Now" slot and the large readout).
  final WeatherSlot now;

  /// The next 4 whole hours after the current one.
  final List<WeatherSlot> hours;

  /// One-line outlook, e.g. "Rain likely this evening".
  final String hint;

  final DateTime fetchedAt;

  String get condition => conditionFor(now.code);

  static Weather fromOpenMeteo(Map<String, dynamic> json, {required DateTime fetchedAt}) {
    final current = json['current'] as Map<String, dynamic>;
    final hourly = json['hourly'] as Map<String, dynamic>;
    final times = (hourly['time'] as List).cast<String>();
    final temps = (hourly['temperature_2m'] as List).map((v) => (v as num).toDouble()).toList();
    final codes = (hourly['weather_code'] as List).map((v) => (v as num).toInt()).toList();
    final days = (hourly['is_day'] as List).map((v) => (v as num) == 1).toList();
    final rain = (hourly['precipitation_probability'] as List).map((v) => (v as num?)?.toInt() ?? 0).toList();

    // hourly[0] is the current hour; slots are the 4 after it.
    final hours = [
      for (var i = 1; i <= 4 && i < times.length; i++)
        WeatherSlot(label: times[i].substring(11, 16), code: codes[i], temp: temps[i], isDay: days[i]),
    ];

    return Weather(
      now: WeatherSlot(
        label: 'Now',
        code: (current['weather_code'] as num).toInt(),
        temp: (current['temperature_2m'] as num).toDouble(),
        isDay: (current['is_day'] as num) == 1,
      ),
      hours: hours,
      hint: rainHint(times, rain, codes),
      fetchedAt: fetchedAt,
    );
  }
}

/// WMO weather code → the 4 glyphs the design provides.
WeatherKind kindFor(int code) => switch (code) {
  0 => WeatherKind.clear,
  1 || 2 => WeatherKind.partlyCloudy,
  3 || 45 || 48 => WeatherKind.cloudy,
  >= 51 && <= 67 || >= 80 && <= 82 || >= 95 => WeatherKind.rain,
  _ => WeatherKind.cloudy, // snow codes: not expected in Yogyakarta
};

/// WMO weather code → short condition text.
String conditionFor(int code) => switch (code) {
  0 => 'Clear',
  1 => 'Mostly clear',
  2 => 'Partly cloudy',
  3 => 'Overcast',
  45 || 48 => 'Foggy',
  51 || 53 || 55 => 'Drizzle',
  56 || 57 => 'Freezing drizzle',
  61 => 'Light rain',
  63 => 'Rain',
  65 => 'Heavy rain',
  66 || 67 => 'Freezing rain',
  >= 71 && <= 77 => 'Snow',
  80 => 'Light showers',
  81 => 'Showers',
  82 => 'Heavy showers',
  85 || 86 => 'Snow showers',
  95 => 'Thunderstorm',
  96 || 99 => 'Thunderstorm, hail',
  _ => 'Unknown',
};

/// Outlook over the forecast window: when rain first becomes likely (≥50%).
String rainHint(List<String> times, List<int> rainChance, List<int> codes) {
  for (var i = 0; i < times.length; i++) {
    final thunder = codes[i] >= 95;
    if (rainChance[i] >= 50 || thunder) {
      final what = thunder ? 'Storms' : 'Rain';
      if (i == 0) return '$what likely now';
      final hour = int.parse(times[i].substring(11, 13));
      final sameDay = times[i].substring(0, 10) == times[0].substring(0, 10);
      return '$what likely ${_period(hour, sameDay)}';
    }
  }
  final peak = rainChance.isEmpty ? 0 : rainChance.reduce((a, b) => a > b ? a : b);
  return peak >= 20 ? 'Small chance of rain' : 'No rain expected';
}

String _period(int hour, bool sameDay) {
  if (!sameDay) return hour < 12 ? 'tomorrow morning' : 'tomorrow';
  if (hour < 5) return 'tonight';
  if (hour < 12) return 'this morning';
  if (hour < 17) return 'this afternoon';
  if (hour < 21) return 'this evening';
  return 'tonight';
}
