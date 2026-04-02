class WeatherAlertService {
  static final WeatherAlertService _instance = WeatherAlertService._internal();
  factory WeatherAlertService() => _instance;
  WeatherAlertService._internal();

  String weatherMain = 'Clear';
  String weatherDesc = '';
  double tempC       = 25.0;
  double windSpeed   = 0.0;

  void update({
    required String main,
    required String desc,
    required double temp,
    double wind = 0.0,
  }) {
    weatherMain = main;
    weatherDesc = desc;
    tempC = temp;
    windSpeed = wind;
  }

  List<Map<String, dynamic>> get weatherAlerts {
    final alerts = <Map<String, dynamic>>[];
    final main = weatherMain.toLowerCase();
    final desc = weatherDesc.toLowerCase();

    if (main == 'thunderstorm' || desc.contains('thunderstorm')) {
      alerts.add({
        'type': 'critical',
        'icon': 0xe1f8,
        'color': 'danger',
        'title': 'Thunderstorm Warning',
        'msg': 'Thunderstorm detected. Move equipment indoors, avoid open fields, and disconnect IoT sensors from power.',
      });
    }

    if (desc.contains('tornado')) {
      alerts.add({
        'type': 'critical',
        'icon': 0xe5d5,
        'color': 'danger',
        'title': 'Tornado Alert',
        'msg': 'Tornado conditions detected. Seek shelter immediately. Do not go to the fields.',
      });
    }

    if (desc.contains('heavy rain') || desc.contains('extreme rain')) {
      alerts.add({
        'type': 'critical',
        'icon': 0xe56e,
        'color': 'danger',
        'title': 'Heavy Rain Warning',
        'msg': 'Heavy rainfall expected. Stop irrigation immediately. Check drainage channels to prevent flooding.',
      });
    } else if (main == 'rain' || main == 'drizzle') {
      alerts.add({
        'type': 'warning',
        'icon': 0xe56e,
        'color': 'warning',
        'title': 'Rain Expected',
        'msg': 'Rain detected. Pause irrigation and avoid fertilizer application as nutrients may wash away.',
      });
    }

    if (main == 'snow') {
      alerts.add({
        'type': 'warning',
        'icon': 0xe034,
        'color': 'blue',
        'title': 'Snow / Frost Warning',
        'msg': 'Freezing conditions detected. Cover sensitive crops and protect irrigation pipes from frost damage.',
      });
    }

    if (tempC > 38) {
      alerts.add({
        'type': 'critical',
        'icon': 0xef6c,
        'color': 'danger',
        'title': 'Extreme Heat Warning',
        'msg': 'Temperature at ${tempC.toStringAsFixed(1)}°C. High risk of crop heat stress. Increase irrigation frequency.',
      });
    } else if (tempC > 33) {
      alerts.add({
        'type': 'warning',
        'icon': 0xeb3b,
        'color': 'warning',
        'title': 'High Temperature Alert',
        'msg': 'Temperature at ${tempC.toStringAsFixed(1)}°C. Monitor crops for wilting. Consider early morning irrigation.',
      });
    }

    if (windSpeed > 15) {
      alerts.add({
        'type': 'warning',
        'icon': 0xe1a3,
        'color': 'warning',
        'title': 'High Wind Speed',
        'msg': 'Wind at ${windSpeed.toStringAsFixed(1)} m/s. Avoid spraying pesticides or fertilizers. Secure greenhouse covers.',
      });
    }

    if (desc.contains('fog') || desc.contains('mist')) {
      alerts.add({
        'type': 'info',
        'icon': 0xe218,
        'color': 'info',
        'title': 'Fog / Low Visibility',
        'msg': 'Foggy conditions. High humidity may increase fungal disease risk. Monitor crops closely.',
      });
    }

    return alerts;
  }

  List<String> get weatherSuggestions {
    final suggestions = <String>[];
    final main = weatherMain.toLowerCase();
    final desc = weatherDesc.toLowerCase();

    if (main == 'thunderstorm' || desc.contains('storm')) {
      suggestions.add('⛈️ Storm alert — stop all field operations immediately. Secure equipment and avoid open areas.');
      suggestions.add('🌱 After the storm, inspect crops for damage and check soil drainage to avoid waterlogging.');
    }

    if (desc.contains('heavy rain') || desc.contains('extreme rain')) {
      suggestions.add('🌧️ Heavy rain expected — stop irrigation now to avoid overwatering and root rot.');
      suggestions.add('💊 Do not apply fertilizers or pesticides before heavy rain as they will wash away.');
    } else if (main == 'rain') {
      suggestions.add('🌦️ Rain detected — pause irrigation for 1-2 days and check soil moisture levels after rain stops.');
    }

    if (tempC > 38) {
      suggestions.add('🌡️ Extreme heat — water crops in early morning and evening only. Mulch soil to retain moisture.');
      suggestions.add('🌿 Consider temporary shade covers for sensitive crops to prevent scorching.');
    } else if (tempC > 33) {
      suggestions.add('☀️ High temperature — increase irrigation frequency and monitor for wilting signs.');
    }

    if (main == 'snow') {
      suggestions.add('❄️ Frost risk — cover crops with protective sheets and drain water from pipes overnight.');
    }

    if (windSpeed > 15) {
      suggestions.add('💨 High winds — avoid spraying chemicals. Wind will carry pesticides away from target areas.');
    }

    if (main == 'clear' && tempC >= 20 && tempC <= 30) {
      suggestions.add('✅ Ideal weather for field work. Good time for fertilizer application and crop inspection.');
    }

    return suggestions;
  }
}
