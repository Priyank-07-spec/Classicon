import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:classico/app_settings.dart';
import 'package:classico/Profile_Screen.dart';
import 'package:classico/Soil_Screen.dart';
import 'package:classico/Alerts_Screen.dart';
import 'package:classico/weather_alert_service.dart';
import 'package:classico/weather_animation.dart';

const String _apiKey = 'a022fdde8cc3c7e052cd556019e290cc';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _forecastTab  = 0;
  int _selectedHourIndex = 0; // which hourly card is tapped

  String _city        = 'Rajkot';
  String _country     = 'IN';
  double _temp        = 0;
  String _condition   = 'Loading...';
  String _weatherMain = 'Clear';
  bool   _isLoading   = true;
  final AppSettings _appSettings = AppSettings();

  // Returns true for dark weather backgrounds (rain/storm/night)
  bool get _isDarkWeather {
    final m = _weatherMain.toLowerCase();
    return m == 'rain' || m == 'drizzle' || m == 'thunderstorm' || m == 'snow';
  }

  /// The weather condition to show in the hero + drive the video background.
  /// Uses the tapped hourly slot when one is selected, otherwise live weather.
  String get _displayWeatherMain {
    final slots = (_selectedDayKey != null &&
            _dailyHourlyMap.containsKey(_selectedDayKey))
        ? _dailyHourlyMap[_selectedDayKey]!
        : _hourlyForecast;
    final usingSlot = slots.isNotEmpty &&
        (_selectedHourIndex > 0 || _selectedDayKey != null) &&
        _selectedHourIndex < slots.length;
    return usingSlot
        ? slots[_selectedHourIndex]['main'] as String
        : _weatherMain;
  }

  Color get _weatherTextColor => _isDarkWeather ? Colors.white : const Color(0xFF1A1A1A);
  Color get _weatherTextSecondary => _isDarkWeather ? Colors.white70 : Colors.black54;

  List<Map<String, dynamic>> _hourlyForecast = [];
  List<Map<String, dynamic>> _weeklyForecast = [];

  // All hourly slots grouped by day key "yyyy-M-d"
  Map<String, List<Map<String, dynamic>>> _dailyHourlyMap = {};
  // null = today; set to a day key when user taps a weekly card
  String? _selectedDayKey;

  // Real sunrise/sunset from OpenWeatherMap (local device time)
  DateTime? _sunrise;
  DateTime? _sunset;

  late AnimationController _animController;
  late Animation<double> _floatAnim;

  // Keep named reference so we can remove it cleanly
  late final VoidCallback _settingsListener;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -10, end: 10).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeInOut));
    _fetchWeather(_city);

    _settingsListener = () { if (mounted) setState(() {}); };
    _appSettings.addListener(_settingsListener);
  }

  @override
  void dispose() {
    _animController.dispose();
    _appSettings.removeListener(_settingsListener); // correctly removes the same instance
    super.dispose();
  }

  String _errorMsg = '';

  Future<void> _fetchWeather(String city) async {
    setState(() { _isLoading = true; _errorMsg = ''; });
    try {
      final currentRes = await http.get(Uri.parse(
          'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$_apiKey&units=metric'))
          .timeout(const Duration(seconds: 10));
      final forecastRes = await http.get(Uri.parse(
          'https://api.openweathermap.org/data/2.5/forecast?q=$city&appid=$_apiKey&units=metric'))
          .timeout(const Duration(seconds: 10));

      if (currentRes.statusCode == 200 && forecastRes.statusCode == 200) {
        final current = jsonDecode(currentRes.body);
        final forecast = jsonDecode(forecastRes.body);
        final List hourlyList = forecast['list'];

        final hourly = hourlyList.take(5).map((e) {
          final dt = DateTime.fromMillisecondsSinceEpoch(e['dt'] * 1000);
          return {
            'time': '${dt.hour.toString().padLeft(2, '0')}:00',
            'temp': e['main']['temp'].toDouble(),
            'main': e['weather'][0]['main'],
            'desc': e['weather'][0]['description'],
          };
        }).toList();

        final Map<String, dynamic> dailyMap = {};
        final Map<String, List<Map<String, dynamic>>> dailyHourlyMap = {};

        for (var item in hourlyList) {
          final dt = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
          final key = '${dt.year}-${dt.month}-${dt.day}';

          // Build weekly summary (first slot of each day)
          if (!dailyMap.containsKey(key)) {
            dailyMap[key] = {
              'key':  key,
              'day':  _dayName(dt.weekday),
              'date': '${_monthName(dt.month)} ${dt.day.toString().padLeft(2, '0')}',
              'temp': item['main']['temp'].round(),
              'main': item['weather'][0]['main'],
            };
          }

          // Build hourly slots per day
          dailyHourlyMap.putIfAbsent(key, () => []);
          dailyHourlyMap[key]!.add({
            'time': '${dt.hour.toString().padLeft(2, '0')}:00',
            'temp': item['main']['temp'].toDouble(),
            'main': item['weather'][0]['main'],
            'desc': item['weather'][0]['description'],
          });
        }

        if (!mounted) return;
        setState(() {
          _city = current['name'];
          _country = current['sys']['country'];
          _temp = current['main']['temp'].toDouble();
          _condition = current['weather'][0]['description'];
          _weatherMain = current['weather'][0]['main'];
          // Real sunrise/sunset for this city from OpenWeatherMap
          _sunrise = DateTime.fromMillisecondsSinceEpoch(
              current['sys']['sunrise'] * 1000);
          _sunset  = DateTime.fromMillisecondsSinceEpoch(
              current['sys']['sunset']  * 1000);
          _hourlyForecast = List<Map<String, dynamic>>.from(hourly);
          _weeklyForecast = dailyMap.values
              .take(5)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _dailyHourlyMap = dailyHourlyMap;
          _selectedDayKey = null;
          _selectedHourIndex = 0;
          _isLoading = false;
        });
        // Push weather data to shared service for Alerts + Soil AI
        WeatherAlertService().update(
          main: current['weather'][0]['main'],
          desc: current['weather'][0]['description'],
          temp: current['main']['temp'].toDouble(),
          wind: (current['wind']?['speed'] ?? 0.0).toDouble(),
        );
      } else {
        if (!mounted) return;
        setState(() {
          _errorMsg = 'City not found. Try another city.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'No internet connection.\nCheck your network and try again.';
        _isLoading = false;
      });
    }
  }

  String _dayName(int w) =>
      ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][w - 1];
  String _monthName(int m) =>
      ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];

  IconData _icon(String main) {
    switch (main.toLowerCase()) {
      case 'clear': return Icons.wb_sunny;
      case 'clouds': return Icons.cloud;
      case 'rain': return Icons.umbrella;
      case 'drizzle': return Icons.grain;
      case 'thunderstorm': return Icons.bolt;
      case 'snow': return Icons.ac_unit;
      default: return Icons.wb_cloudy;
    }
  }

  Color _iconColor(String main) {
    switch (main.toLowerCase()) {
      case 'clear': return Colors.amber;
      case 'clouds': return Colors.blueGrey;
      case 'rain':
      case 'drizzle': return Colors.lightBlueAccent;
      case 'thunderstorm': return Colors.purpleAccent;
      case 'snow': return Colors.lightBlue;
      default: return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildWeatherTab(),
          const SoilScreen(),
          const AlertsScreen(),
          const ProfileScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAIChat,
        backgroundColor: const Color(0xFF2ECC71),
        elevation: 6,
        child: const Icon(Icons.chat, color: Colors.white, size: 22),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: BottomAppBar(
            color: Colors.grey.shade200.withOpacity(0.6),
            elevation: 0,
            shape: const CircularNotchedRectangle(),
            notchMargin: 8,
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.cloud, 'Weather'),
              _navItem(1, Icons.grass, 'Soil'),
              const SizedBox(width: 48),
              _navItem(2, Icons.notifications, 'Alerts'),
              _navItem(3, Icons.person, 'Profile'),
            ],
          ),
        ),
      ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final sel = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              color: sel ? const Color(0xFF2ECC71) : Colors.black38,
              size: sel ? 24 : 20),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: sel ? const Color(0xFF2ECC71) : Colors.black38,
                  fontSize: 10,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildWeatherTab() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF2ECC71)));
    }
    if (_errorMsg.isNotEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.wifi_off, color: Colors.black26, size: 60),
          const SizedBox(height: 16),
          Text(_errorMsg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _fetchWeather(_city),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2ECC71),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ]),
      );
    }
    return Stack(
      children: [
        // ── Full-screen video background ──────────────────────────────
        Positioned.fill(
          child: WeatherAnimationBackground(
            weatherMain: _displayWeatherMain,
            sunrise: _sunrise,
            sunset:  _sunset,
          ),
        ),
        // ── UI content on top ─────────────────────────────────────────
        Column(
          children: [
        // Top weather section
        Expanded(
          flex: 10,
          child: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: _showLocationPicker,
                            child: const Icon(Icons.my_location,
                                color: Color(0xFF2ECC71), size: 20),
                          ),
                          Text('$_city, $_country',
                              style: TextStyle(
                                  color: _weatherTextColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          GestureDetector(
                            onTap: _showLocationPicker,
                            child: const Icon(Icons.search,
                                color: Color(0xFF2ECC71), size: 20),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _floatAnim,
                        builder: (context, child) => Transform.translate(
                          offset: Offset(0, _floatAnim.value),
                          child: child,
                        ),
                        child: Builder(builder: (context) {
                          // Resolve which slot is active
                          final slots = (_selectedDayKey != null &&
                                  _dailyHourlyMap.containsKey(_selectedDayKey))
                              ? _dailyHourlyMap[_selectedDayKey]!
                              : _hourlyForecast;
                          final bool usingSlot = slots.isNotEmpty &&
                              (_selectedHourIndex > 0 || _selectedDayKey != null) &&
                              _selectedHourIndex < slots.length;
                          final dMain  = usingSlot ? slots[_selectedHourIndex]['main'] as String  : _weatherMain;
                          final dTemp  = usingSlot ? (slots[_selectedHourIndex]['temp'] as num).toDouble() : _temp;
                          final dDesc  = usingSlot ? (slots[_selectedHourIndex]['desc'] as String? ?? dMain) : _condition;
                          final dTime  = usingSlot && !(_selectedDayKey == null && _selectedHourIndex == 0)
                              ? slots[_selectedHourIndex]['time'] as String : '';
                          final isDark = () { final m = dMain.toLowerCase(); return m=='rain'||m=='drizzle'||m=='thunderstorm'||m=='snow'; }();

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (dTime.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(dTime,
                                      style: const TextStyle(
                                          color: Color(0xFF2ECC71),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.5)),
                                ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 350),
                                child: Container(
                                  key: ValueKey(dMain),
                                  width: 160, height: 160,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _iconColor(dMain).withOpacity(0.08),
                                    boxShadow: [BoxShadow(
                                        color: _iconColor(dMain).withOpacity(0.25),
                                        blurRadius: 60, spreadRadius: 20)],
                                  ),
                                  child: Icon(_icon(dMain), size: 90, color: _iconColor(dMain)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 350),
                                child: Text(_appSettings.convertTemp(dTemp),
                                    key: ValueKey('$dMain$dTemp'),
                                    style: TextStyle(
                                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                        fontSize: 72,
                                        fontWeight: FontWeight.w200,
                                        letterSpacing: -3)),
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 350),
                                child: Text(dDesc.toUpperCase(),
                                    key: ValueKey(dDesc),
                                    style: TextStyle(
                                        color: isDark ? Colors.white60 : const Color(0xFF2ECC71),
                                        fontSize: 12,
                                        letterSpacing: 3)),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Bottom forecast section
        Expanded(
          flex: 7,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.4), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  child: Row(
                    children: [
                      _tabBtn(0, 'Hourly Forecast'),
                      const SizedBox(width: 24),
                      _tabBtn(1, 'Weekly Forecast'),
                    ],
                  ),
                ),
                if (_forecastTab == 0)
                  _buildHourlyRow()
                else
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      child: Column(
                        children: _weeklyForecast
                            .map((item) => _weeklyCard(item))
                            .toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
            ),
          ),
        ),
          ],  // Column children
        ),    // Column
      ],      // Stack children
    );        // Stack
  }

  Widget _tabBtn(int index, String label) {
    final sel = _forecastTab == index;
    return GestureDetector(
      onTap: () => setState(() => _forecastTab = index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: sel ? const Color(0xFF1A1A1A) : Colors.black38,
                  fontSize: 14,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
          const SizedBox(height: 3),
          if (sel)
            Container(
                height: 2,
                width: label.length * 7.5,
                decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71),
                    borderRadius: BorderRadius.circular(2))),
        ],
      ),
    );
  }

  Widget _buildHourlyRow() {
    // Decide which slots to show
    final slots = (_selectedDayKey != null &&
            _dailyHourlyMap.containsKey(_selectedDayKey))
        ? _dailyHourlyMap[_selectedDayKey]!
        : _hourlyForecast;

    // Find the weekly item for the selected day (for its label)
    final selectedWeekItem = _selectedDayKey != null
        ? _weeklyForecast.firstWhere(
            (w) => w['key'] == _selectedDayKey,
            orElse: () => {},
          )
        : null;

    final bool showingOtherDay =
        _selectedDayKey != null && selectedWeekItem != null && selectedWeekItem.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Day header row ─────────────────────────────────────────────
        if (showingOtherDay)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() {
                    _selectedDayKey = null;
                    _selectedHourIndex = 0;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2ECC71).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF2ECC71).withOpacity(0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_ios_new,
                            size: 10, color: Color(0xFF2ECC71)),
                        SizedBox(width: 4),
                        Text('Today',
                            style: TextStyle(
                                color: Color(0xFF2ECC71),
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${selectedWeekItem!['day']}  ·  ${selectedWeekItem['date']}',
                  style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ],
            ),
          ),

        // ── Scrollable hourly cards ────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: List.generate(slots.length, (index) {
              final item = slots[index];
              final isNow = !showingOtherDay && index == 0;
              final isSelected = _selectedHourIndex == index;
              return GestureDetector(
                onTap: () => setState(() => _selectedHourIndex = index),
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 62,
                        height: 90,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2ECC71).withOpacity(0.30)
                              : Colors.white.withOpacity(0.20),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF2ECC71).withOpacity(0.85)
                                  : Colors.white.withOpacity(0.45),
                              width: isSelected ? 1.8 : 1.0),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isNow ? 'Now' : item['time'],
                              style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF2ECC71)
                                      : Colors.black54,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Icon(_icon(item['main']),
                                color: isSelected
                                    ? const Color(0xFF2ECC71)
                                    : _iconColor(item['main']),
                                size: 22),
                            const SizedBox(height: 6),
                            Text(
                              _appSettings.convertTemp(
                                  (item['temp'] as num).toDouble()),
                              style: const TextStyle(
                                  color: Color(0xFF1A1A1A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _weeklyCard(Map<String, dynamic> item) {
    final isSelected = _selectedDayKey == item['key'];
    return GestureDetector(
      onTap: () => setState(() {
        _selectedDayKey = item['key'];
        _forecastTab = 0; // switch to Hourly tab to show that day
        _selectedHourIndex = 0;
      }),
      child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF2ECC71).withOpacity(0.25)
            : Colors.white.withOpacity(0.20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF2ECC71).withOpacity(0.8)
              : Colors.white.withOpacity(0.40),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item['day'],
                  style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              Text(item['date'],
                  style: const TextStyle(
                      color: Colors.black38, fontSize: 12)),
            ],
          ),
          Row(
            children: [
              Text('${item['temp']}°',
                  style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 28,
                      fontWeight: FontWeight.w300)),
              const SizedBox(width: 12),
              Icon(_icon(item['main']),
                  color: _iconColor(item['main']), size: 28),
            ],
          ),
        ],
      ),
        ),
      ),
      ), // GestureDetector
    );
  }

  Widget _buildComingSoon(String name) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.construction,
              color: Color(0xFF2ECC71), size: 60),
          const SizedBox(height: 16),
          Text('$name Coming Soon!',
              style: const TextStyle(
                  color: Color(0xFF2ECC71),
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('We are building this for you',
              style: TextStyle(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }

  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _LocationSheet(onCitySelected: (city) => _fetchWeather(city)),
    );
  }

  void _openAIChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AIChatSheet(),
    );
  }
}

// ── Location Sheet ──────────────────────────────────────────────────────────
class _LocationSheet extends StatefulWidget {
  final Function(String) onCitySelected;
  const _LocationSheet({required this.onCitySelected});
  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  final _ctrl = TextEditingController();
  final List<String> _cities = [
    'Rajkot', 'Ahmedabad', 'Surat', 'Mumbai',
    'Delhi', 'Pune', 'Jaipur', 'Bangalore'
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 16),
          const Text('Pick Location',
              style: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Find your city for weather info',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _ctrl,
              style: const TextStyle(color: Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                hintText: 'Search city...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                prefixIcon:
                    const Icon(Icons.search, color: Color(0xFF2ECC71)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: (val) {
                if (val.isNotEmpty) {
                  widget.onCitySelected(val);
                  Navigator.pop(context);
                }
              },
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.2),
              itemCount: _cities.length,
              itemBuilder: (context, index) => GestureDetector(
                onTap: () {
                  widget.onCitySelected(_cities[index]);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_city,
                          color: Color(0xFF2ECC71), size: 18),
                      const SizedBox(height: 4),
                      Text(_cities[index],
                          style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      Text('India',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── AI Chat Sheet ────────────────────────────────────────────────────────────
class _AIChatSheet extends StatefulWidget {
  const _AIChatSheet();
  @override
  State<_AIChatSheet> createState() => _AIChatSheetState();
}

class _AIChatSheetState extends State<_AIChatSheet> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isTyping = false;

  // Mistral AI API key — replace with your own from https://console.mistral.ai
  static const String _mistralApiKey = 'Owd7H8WSF2nApRBGy4ZiDUDqESI3NrWz';
  static const String _mistralModel   = 'mistral-large-latest';

  final List<Map<String, String>> _messages = [
    {
      'role': 'ai',
      'text': 'Hello Farmer! 🌱 I am your Smart Farming AI powered by Mistral. Ask me anything about your crops, soil, weather, or farming!'
    }
  ];

  // Build conversation history for Mistral (OpenAI-compatible format)
  List<Map<String, dynamic>> _buildHistory() {
    final w = WeatherAlertService();
    final systemPrompt =
        'You are a smart farming AI assistant. '
        'Current weather: ${w.weatherMain}, ${w.weatherDesc}, '
        'temp ${w.tempC.toStringAsFixed(1)}°C, wind ${w.windSpeed.toStringAsFixed(1)} m/s. '
        'Give short, practical farming advice. No markdown, no bold text, no special characters.';

    final history = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    // Add conversation history (skip first AI greeting)
    for (final msg in _messages.skip(1)) {
      history.add({
        'role': msg['role'] == 'user' ? 'user' : 'assistant',
        'content': msg['text'],
      });
    }
    return history;
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isTyping) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _msgCtrl.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final history = _buildHistory();
      // Append the latest user message
      history.add({'role': 'user', 'content': text});

      final response = await http.post(
        Uri.parse('https://api.mistral.ai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_mistralApiKey',
        },
        body: jsonEncode({
          'model': _mistralModel,
          'messages': history,
          'max_tokens': 300,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      String reply;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        reply = data['choices'][0]['message']['content'] ?? 'Sorry, I could not understand that.';
        reply = reply
            .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1')
            .replaceAll('**', '')
            .replaceAll('*', '')
            .replaceAll('#', '')
            .trim();
      } else if (response.statusCode == 429) {
        // Rate limit — wait and retry once
        if (mounted) setState(() {
          _messages.add({'role': 'ai', 'text': '⏳ Rate limit reached. Retrying in 10 seconds...'});
        });
        _scrollToBottom();
        await Future.delayed(const Duration(seconds: 10));
        if (!mounted) return;
        final retry = await http.post(
          Uri.parse('https://api.mistral.ai/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_mistralApiKey',
          },
          body: jsonEncode({
            'model': _mistralModel,
            'messages': history,
            'max_tokens': 300,
            'temperature': 0.7,
          }),
        ).timeout(const Duration(seconds: 20));
        if (retry.statusCode == 200) {
          final data = jsonDecode(retry.body);
          reply = data['choices'][0]['message']['content'] ?? '';
          reply = reply
              .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1')
              .replaceAll('**', '')
              .replaceAll('*', '')
              .replaceAll('#', '')
              .trim();
        } else {
          reply = '⚠️ Too many requests. Please wait a minute and try again.';
        }
      } else if (response.statusCode == 401) {
        reply = '⚠️ Invalid Mistral API key. Please check your configuration.';
      } else {
        reply = '⚠️ Could not connect to AI. Check your internet connection.';
      }

      setState(() {
        _messages.add({'role': 'ai', 'text': reply});
        _isTyping = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'ai', 'text': '⚠️ Network error. Please check your connection.'});
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.78,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
                color: const Color(0xFF2ECC71).withOpacity(0.4)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: const Color(0xFF2ECC71).withOpacity(0.2),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.auto_awesome,
                          color: Color(0xFF2ECC71), size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Smart Farming AI',
                            style: TextStyle(
                                color: Color(0xFF2ECC71),
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        Text('Powered by Mistral ✨',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(
                  color: const Color(0xFF2ECC71).withOpacity(0.2),
                  height: 16),
              Expanded(
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, i) {
                    // Typing indicator
                    if (_isTyping && i == _messages.length) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.15)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Text('Mistral is thinking',
                                style: TextStyle(color: Colors.white54, fontSize: 12)),
                            const SizedBox(width: 6),
                            SizedBox(width: 20, height: 12,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(3, (j) => Container(
                                  width: 4, height: 4,
                                  decoration: const BoxDecoration(
                                      color: Color(0xFF2ECC71),
                                      shape: BoxShape.circle),
                                )),
                              ),
                            ),
                          ]),
                        ),
                      );
                    }
                    final msg = _messages[i];
                    final isAI = msg['role'] == 'ai';
                    return Align(
                      alignment: isAI
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isAI
                              ? Colors.white.withOpacity(0.1)
                              : const Color(0xFF2ECC71).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isAI
                                  ? Colors.white.withOpacity(0.15)
                                  : Colors.transparent),
                        ),
                        child: Text(msg['text']!,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom:
                        MediaQuery.of(context).viewInsets.bottom + 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Ask about crops, soil, weather...',
                          hintStyle:
                              const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide(
                                  color: const Color(0xFF2ECC71)
                                      .withOpacity(0.3))),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide(
                                  color: const Color(0xFF2ECC71)
                                      .withOpacity(0.3))),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: const BorderSide(
                                  color: Color(0xFF2ECC71))),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: _isTyping
                          ? Colors.grey
                          : const Color(0xFF2ECC71),
                      child: IconButton(
                        icon: _isTyping
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send, color: Colors.white, size: 18),
                        onPressed: _isTyping ? null : _send,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
