import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:classico/weather_alert_service.dart';
import 'package:classico/app_settings.dart';

class SoilData {
  final double moisture;
  final double temperature;
  final double ph;
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final DateTime timestamp;

  SoilData({
    required this.moisture,
    required this.temperature,
    required this.ph,
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    required this.timestamp,
  });
}

class SoilScreen extends StatefulWidget {
  const SoilScreen({super.key});
  @override
  State<SoilScreen> createState() => _SoilScreenState();
}

class _SoilScreenState extends State<SoilScreen>
    with SingleTickerProviderStateMixin {
  static const Color kGreen   = Color(0xFF2ECC71);
  static const Color kWarning = Color(0xFFFFB300);
  static const Color kDanger  = Color(0xFFFF5252);
  static const Color kBlue    = Color(0xFF29B6F6);

  final AppSettings _s = AppSettings();
  late final VoidCallback _themeListener;

  int _tab = 0;
  String _npkMode = 'field'; // shared across Nutrients + Trends tabs
  String _fieldCrop = '';
  String _homeCrop  = '';
  final TextEditingController _customCropCtrl = TextEditingController();
  String _locationType = 'field';

  String get _selectedCrop => _locationType == 'field' ? _fieldCrop : _homeCrop;
  void _setSelectedCrop(String crop) => setState(() {
    if (_locationType == 'field') _fieldCrop = crop; else _homeCrop = crop;
  });
  void _clearSelectedCrop() => setState(() {
    if (_locationType == 'field') _fieldCrop = ''; else _homeCrop = '';
  });

  static const List<Map<String, String>> _fieldCrops = [
    {'name': 'Wheat', 'emoji': '🌾'}, {'name': 'Rice', 'emoji': '🌿'},
    {'name': 'Cotton', 'emoji': '🌸'}, {'name': 'Tomato', 'emoji': '🍅'},
    {'name': 'Potato', 'emoji': '🥔'}, {'name': 'Onion', 'emoji': '🧅'},
    {'name': 'Maize', 'emoji': '🌽'}, {'name': 'Sugarcane', 'emoji': '🎋'},
    {'name': 'Soybean', 'emoji': '🫘'}, {'name': 'Chili', 'emoji': '🌶️'},
    {'name': 'Groundnut', 'emoji': '🥜'}, {'name': 'Mustard', 'emoji': '🌼'},
  ];
  static const List<Map<String, String>> _homeCrops = [
    {'name': 'Rose', 'emoji': '🌹'}, {'name': 'Tulsi', 'emoji': '🌿'},
    {'name': 'Aloe Vera', 'emoji': '🪴'}, {'name': 'Mint', 'emoji': '🍃'},
    {'name': 'Sunflower', 'emoji': '🌻'}, {'name': 'Cactus', 'emoji': '🌵'},
    {'name': 'Jasmine', 'emoji': '🌸'}, {'name': 'Chili', 'emoji': '🌶️'},
    {'name': 'Tomato', 'emoji': '🍅'}, {'name': 'Money Plant', 'emoji': '🪴'},
    {'name': 'Lavender', 'emoji': '💜'}, {'name': 'Basil', 'emoji': '🌱'},
  ];
  List<Map<String, String>> get _crops =>
      _locationType == 'field' ? _fieldCrops : _homeCrops;

  late SoilData _current;
  Timer? _liveTimer;
  bool _isConnected = true;
  final List<SoilData> _history = [];
  int _trendParam = 0;

  Color get bg       => _s.bgColor;
  Color get card     => _s.cardColor;
  Color get textDark => _s.textDark;
  Color get textGrey => _s.textGrey;
  Color get divClr   => _s.dividerColor;
  Color get iconBg   => _s.isDarkGreen
      ? const Color(0xFF1B3D22) : const Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _current = _mockData();
    _generateHistory();
    _liveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() => _current = _mockData());
    });
    _themeListener = () { if (mounted) setState(() {}); };
    _s.addListener(_themeListener);
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _customCropCtrl.dispose();
    _s.removeListener(_themeListener);
    super.dispose();
  }

  SoilData _mockData() {
    final r = Random();
    return SoilData(
      moisture: 28 + r.nextDouble() * 20,
      temperature: 22 + r.nextDouble() * 12,
      ph: 5.8 + r.nextDouble() * 2.2,
      nitrogen: 180 + r.nextDouble() * 80,
      phosphorus: 35 + r.nextDouble() * 30,
      potassium: 140 + r.nextDouble() * 60,
      timestamp: DateTime.now(),
    );
  }

  void _generateHistory() {
    final r = Random();
    for (int i = 30; i >= 0; i--) {
      _history.add(SoilData(
        moisture: 25 + r.nextDouble() * 30,
        temperature: 20 + r.nextDouble() * 15,
        ph: 5.5 + r.nextDouble() * 2.5,
        nitrogen: 160 + r.nextDouble() * 100,
        phosphorus: 30 + r.nextDouble() * 40,
        potassium: 120 + r.nextDouble() * 80,
        timestamp: DateTime.now().subtract(Duration(days: i)),
      ));
    }
  }

  Map<String, dynamic> _moistureStatus(double v) {
    if (v < 20) return {'label': 'Dry — Needs Water', 'color': kDanger, 'icon': Icons.water_drop_outlined};
    if (v > 60) return {'label': 'Overwatered', 'color': kBlue, 'icon': Icons.water};
    return {'label': 'Normal', 'color': kGreen, 'icon': Icons.check_circle_outline};
  }

  Map<String, dynamic> _tempStatus(double v) {
    if (v < 15) return {'label': 'Too Cold', 'color': kBlue, 'icon': Icons.ac_unit};
    if (v > 32) return {'label': 'Too Hot', 'color': kDanger, 'icon': Icons.local_fire_department};
    return {'label': 'Optimal', 'color': kGreen, 'icon': Icons.check_circle_outline};
  }

  Map<String, dynamic> _phStatus(double v) {
    if (v < 6.0) return {'label': 'Acidic', 'color': kWarning, 'icon': Icons.science_outlined};
    if (v > 7.5) return {'label': 'Alkaline', 'color': kWarning, 'icon': Icons.science_outlined};
    return {'label': 'Ideal', 'color': kGreen, 'icon': Icons.check_circle_outline};
  }

  Map<String, dynamic> _nutrientStatus(double v, double low, double high) {
    if (v < low) return {'label': 'Low', 'color': kDanger};
    if (v > high) return {'label': 'Sufficient', 'color': kGreen};
    return {'label': 'Medium', 'color': kWarning};
  }

  List<Map<String, dynamic>> get _alerts {
    final list = <Map<String, dynamic>>[];
    if (_current.moisture < 20)
      list.add({'icon': Icons.water_drop, 'color': kDanger,
        'title': 'Critical: Soil Too Dry',
        'msg': 'Moisture at ${_current.moisture.toStringAsFixed(1)}%. Irrigate immediately.'});
    if (_current.temperature > 32)
      list.add({'icon': Icons.local_fire_department, 'color': kDanger,
        'title': 'High Soil Temperature',
        'msg': 'Temp at ${_current.temperature.toStringAsFixed(1)}°C. Risk of root damage.'});
    if (_current.ph < 6.0)
      list.add({'icon': Icons.science, 'color': kWarning,
        'title': 'Soil Too Acidic', 'msg': 'pH ${_current.ph.toStringAsFixed(1)}. Add lime.'});
    if (_current.ph > 7.5)
      list.add({'icon': Icons.science, 'color': kWarning,
        'title': 'Soil Too Alkaline', 'msg': 'pH ${_current.ph.toStringAsFixed(1)}. Add sulfur.'});
    if (_current.nitrogen < 200)
      list.add({'icon': Icons.grass, 'color': kWarning,
        'title': 'Low Nitrogen', 'msg': 'N at ${_current.nitrogen.toStringAsFixed(0)} mg/kg. Apply urea.'});
    if (list.isEmpty)
      list.add({'icon': Icons.check_circle, 'color': kGreen,
        'title': 'All Clear', 'msg': 'Soil conditions are optimal. No action needed.'});
    return list;
  }

  List<String> get _aiSuggestions {
    final s = <String>[];
    s.addAll(WeatherAlertService().weatherSuggestions);
    final ms = _moistureStatus(_current.moisture);
    final weatherMain = WeatherAlertService().weatherMain.toLowerCase();
    final isRaining = weatherMain == 'rain' || weatherMain == 'drizzle' ||
        weatherMain == 'thunderstorm';
    if (isRaining) {
      s.add('🌧️ Rain detected — skip irrigation today.');
    } else if (ms['label'] == 'Dry — Needs Water') {
      s.add('💧 Irrigate your field now. Apply 30-40mm of water evenly.');
    } else if (ms['label'] == 'Overwatered') {
      s.add('🚫 Stop irrigation. Improve drainage to prevent root rot.');
    } else {
      s.add('✅ Moisture is good. Next irrigation in 2-3 days.');
    }
    final ph = _current.ph;
    if (ph < 6.0) s.add('🧪 Add agricultural lime (2-3 bags/acre) to raise pH.');
    else if (ph > 7.5) s.add('🧪 Apply elemental sulfur to reduce alkalinity.');
    else s.add('✅ pH is ideal for most crops including wheat and cotton.');
    if (_current.nitrogen < 200) {
      if (isRaining) s.add('🌱 Low nitrogen — wait for rain to stop before applying urea.');
      else s.add('🌱 Apply urea (46-0-0) at 50kg/acre to boost nitrogen.');
    } else {
      s.add('✅ Nitrogen levels support healthy leaf growth.');
    }
    if (_current.temperature > 28)
      s.add('☀️ High soil temp — consider mulching to retain moisture.');
    else
      s.add('✅ Soil temperature is perfect for root development.');
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
        _buildHeader(),
        _buildTabBar(),
        Expanded(child: _buildTabContent()),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: card,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(
            _s.isDarkGreen ? 0.3 : 0.06),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Soil Monitor',
                    style: TextStyle(color: textDark, fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Row(children: [
                  Container(width: 8, height: 8,
                      decoration: BoxDecoration(
                          color: _isConnected ? kGreen : kDanger,
                          shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(_isConnected ? 'IoT Sensor Connected' : 'Sensor Offline',
                      style: TextStyle(
                          color: _isConnected ? kGreen : kDanger,
                          fontSize: 12)),
                ]),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kGreen.withOpacity(0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.access_time, color: textGrey, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${_current.timestamp.hour.toString().padLeft(2, '0')}:${_current.timestamp.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(color: textGrey, fontSize: 12)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = ['Overview', 'Nutrients', 'Trends'];
    final icons = [Icons.dashboard, Icons.eco, Icons.show_chart];
    return Container(
      decoration: BoxDecoration(
        color: card,
        border: Border(bottom: BorderSide(color: divClr, width: 1)),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final sel = _tab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(
                      color: sel ? kGreen : Colors.transparent, width: 2)),
                ),
                child: Column(children: [
                  Icon(icons[i],
                      color: sel ? kGreen : textGrey, size: 18),
                  const SizedBox(height: 3),
                  Text(tabs[i],
                      style: TextStyle(
                          color: sel ? kGreen : textGrey,
                          fontSize: 10,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_tab) {
      case 0: return _buildOverview();
      case 1: return _buildNutrients();
      case 2: return _buildTrends();
      default: return _buildOverview();
    }
  }

  Widget _buildOverview() {
    final ms = _moistureStatus(_current.moisture);
    final ts = _tempStatus(_current.temperature);
    final ps = _phStatus(_current.ph);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      physics: const BouncingScrollPhysics(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildLocationToggle(),
        const SizedBox(height: 12),
        _buildCropSelector(),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _mainCard(icon: Icons.water_drop, label: 'Moisture',
              value: '${_current.moisture.toStringAsFixed(1)}%', status: ms,
              progress: _current.moisture / 100, progressColor: ms['color'])),
          const SizedBox(width: 10),
          Expanded(child: _mainCard(icon: Icons.thermostat, label: 'Temperature',
              value: '${_current.temperature.toStringAsFixed(1)}°C', status: ts,
              progress: _current.temperature / 50, progressColor: ts['color'])),
        ]),
        const SizedBox(height: 10),
        _phCard(ps),
        const SizedBox(height: 20),
        _GeminiSuggestionsWidget(
            settings: _s,
            soilData: _current,
            selectedCrop: _selectedCrop,
            locationType: _locationType),
      ]),
    );
  }

  Widget _buildLocationToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _s.isDarkGreen ? const Color(0xFF0F2A18) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        _locationBtn('field', '🌾', 'Field / Farm'),
        _locationBtn('home', '🏡', 'Home / Pot'),
      ]),
    );
  }

  Widget _locationBtn(String type, String emoji, String label) {
    final sel = _locationType == type;
    final plantedCrop = type == 'field' ? _fieldCrop : _homeCrop;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _locationType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? card : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: sel ? [BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6, offset: const Offset(0, 2))] : [],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(
                  color: sel ? textDark : textGrey,
                  fontSize: 13,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
              Text(
                plantedCrop.isNotEmpty ? plantedCrop
                    : (type == 'field' ? 'Farming land' : 'Indoor plants'),
                style: TextStyle(
                    color: plantedCrop.isNotEmpty ? kGreen : textGrey,
                    fontSize: 10,
                    fontWeight: plantedCrop.isNotEmpty
                        ? FontWeight.w600 : FontWeight.normal)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildCropSelector() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          const Icon(Icons.eco, color: kGreen, size: 16),
          const SizedBox(width: 6),
          Text('My Crop', style: TextStyle(color: textDark,
              fontSize: 14, fontWeight: FontWeight.bold)),
        ]),
        if (_selectedCrop.isNotEmpty)
          GestureDetector(
            onTap: _clearSelectedCrop,
            child: const Text('Clear',
                style: TextStyle(color: kGreen, fontSize: 12)),
          ),
      ]),
      const SizedBox(height: 8),
      if (_selectedCrop.isNotEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: kGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kGreen.withOpacity(0.4)),
          ),
          child: Row(children: [
            Text(
              _crops.any((c) => c['name'] == _selectedCrop)
                  ? _crops.firstWhere((c) => c['name'] == _selectedCrop)['emoji']!
                  : '🌱',
              style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text(_selectedCrop, style: TextStyle(color: textDark,
                fontSize: 14, fontWeight: FontWeight.bold)),
            const Spacer(),
            const Icon(Icons.check_circle, color: kGreen, size: 18),
          ]),
        ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: _crops.map((crop) {
          final isSel = _selectedCrop == crop['name'];
          return GestureDetector(
            onTap: () => _setSelectedCrop(crop['name']!),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSel ? kGreen.withOpacity(0.15) : card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSel ? kGreen : divClr),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(crop['emoji']!, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 5),
                Text(crop['name']!, style: TextStyle(
                    color: isSel ? kGreen : textDark,
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
              ]),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _customCropCtrl,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(color: textDark),
            decoration: InputDecoration(
              hintText: 'Type your own crop name...',
              hintStyle: TextStyle(color: textGrey, fontSize: 13),
              prefixIcon: const Text('🌱', style: TextStyle(fontSize: 16)),
              prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              filled: true,
              fillColor: card,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: divClr)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: divClr)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kGreen)),
            ),
            onSubmitted: (val) {
              final v = val.trim();
              if (v.isNotEmpty) { _setSelectedCrop(v); _customCropCtrl.clear(); }
            },
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            final v = _customCropCtrl.text.trim();
            if (v.isNotEmpty) { _setSelectedCrop(v); _customCropCtrl.clear(); }
          },
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: kGreen,
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.add, color: Colors.white, size: 22),
          ),
        ),
      ]),
    ]);
  }

  Widget _mainCard({required IconData icon, required String label,
      required String value, required Map<String, dynamic> status,
      required double progress, required Color progressColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: divClr),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: (status['color'] as Color).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: status['color'], size: 18),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
                color: (status['color'] as Color).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20)),
            child: Text(status['label'],
                style: TextStyle(color: status['color'],
                    fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 12),
        Text(value, style: TextStyle(color: textDark, fontSize: 26,
            fontWeight: FontWeight.w300)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: textGrey, fontSize: 12)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: divClr,
            valueColor: AlwaysStoppedAnimation(progressColor),
            minHeight: 4,
          ),
        ),
      ]),
    );
  }

  Widget _phCard(Map<String, dynamic> status) {
    final ph = _current.ph;
    final pos = ph / 14.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: divClr),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: (status['color'] as Color).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.science, color: status['color'], size: 18),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Soil pH', style: TextStyle(color: textGrey, fontSize: 12)),
              Text(ph.toStringAsFixed(1), style: TextStyle(color: textDark,
                  fontSize: 24, fontWeight: FontWeight.w300)),
            ]),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: (status['color'] as Color).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20)),
            child: Text(status['label'],
                style: TextStyle(color: status['color'],
                    fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 14),
        Stack(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 12,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [
                  Color(0xFFFF5252), Color(0xFFFFB300),
                  Color(0xFF2ECC71), Color(0xFFFFB300), Color(0xFF7C4DFF),
                ]),
              ),
            ),
          ),
          Positioned(
            left: (pos * (MediaQuery.of(context).size.width - 64)).clamp(0, MediaQuery.of(context).size.width - 64),
            top: -3,
            child: Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                  color: card,
                  shape: BoxShape.circle,
                  border: Border.all(color: status['color'], width: 2),
                  boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 4)]),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('0\nAcidic', style: TextStyle(color: textGrey, fontSize: 9), textAlign: TextAlign.center),
          Text('7\nNeutral', style: TextStyle(color: textGrey, fontSize: 9), textAlign: TextAlign.center),
          Text('14\nAlkaline', style: TextStyle(color: textGrey, fontSize: 9), textAlign: TextAlign.center),
        ]),
      ]),
    );
  }

  Widget _buildNutrients() {
    final isField = _npkMode == 'field';

    final nutrients = isField ? [
      {'name': 'Nitrogen (N)', 'value': _current.nitrogen, 'unit': 'mg/kg',
        'icon': Icons.grass, 'color': const Color(0xFF66BB6A),
        'status': _nutrientStatus(_current.nitrogen, 180, 250), 'max': 300.0,
        'desc': 'Essential for leaf & stem growth',
        'tip': 'Apply urea (46-0-0) at 50 kg/acre or ammonium nitrate'},
      {'name': 'Phosphorus (P)', 'value': _current.phosphorus, 'unit': 'mg/kg',
        'icon': Icons.circle, 'color': const Color(0xFFFF7043),
        'status': _nutrientStatus(_current.phosphorus, 40, 60), 'max': 100.0,
        'desc': 'Supports root & flower development',
        'tip': 'Apply DAP (18-46-0) at 50 kg/acre or superphosphate'},
      {'name': 'Potassium (K)', 'value': _current.potassium, 'unit': 'mg/kg',
        'icon': Icons.water_drop, 'color': const Color(0xFF29B6F6),
        'status': _nutrientStatus(_current.potassium, 150, 200), 'max': 250.0,
        'desc': 'Improves water & disease resistance',
        'tip': 'Apply muriate of potash (MOP) at 25 kg/acre'},
    ] : [
      {'name': 'Nitrogen (N)', 'value': _current.nitrogen, 'unit': 'mg/kg',
        'icon': Icons.grass, 'color': const Color(0xFF66BB6A),
        'status': _nutrientStatus(_current.nitrogen, 100, 200), 'max': 250.0,
        'desc': 'Promotes lush green foliage',
        'tip': 'Use liquid NPK fertilizer (20-20-20) once a week'},
      {'name': 'Phosphorus (P)', 'value': _current.phosphorus, 'unit': 'mg/kg',
        'icon': Icons.circle, 'color': const Color(0xFFFF7043),
        'status': _nutrientStatus(_current.phosphorus, 20, 40), 'max': 60.0,
        'desc': 'Encourages root & bloom growth',
        'tip': 'Mix bone meal or slow-release phosphorus into pot soil'},
      {'name': 'Potassium (K)', 'value': _current.potassium, 'unit': 'mg/kg',
        'icon': Icons.water_drop, 'color': const Color(0xFF29B6F6),
        'status': _nutrientStatus(_current.potassium, 80, 150), 'max': 200.0,
        'desc': 'Strengthens stems & disease resistance',
        'tip': 'Add potassium-rich fertilizer or wood ash to potting mix'},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      physics: const BouncingScrollPhysics(),
      child: Column(children: [

        // ── Toggle — same style as Overview ──────────────────────────────
        _npkModeToggle(),
        const SizedBox(height: 14),

        // ── NPK summary card ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: card, borderRadius: BorderRadius.circular(18),
            border: Border.all(color: divClr),
          ),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['N', 'P', 'K'].asMap().entries.map((e) {
                  final colors = [const Color(0xFF66BB6A), const Color(0xFFFF7043), const Color(0xFF29B6F6)];
                  final vals = [_current.nitrogen, _current.phosphorus, _current.potassium];
                  return Column(children: [
                    Text(e.value, style: TextStyle(color: colors[e.key],
                        fontSize: 28, fontWeight: FontWeight.bold)),
                    Text('${vals[e.key].toStringAsFixed(0)}',
                        style: TextStyle(color: textDark,
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    Text('mg/kg', style: TextStyle(color: textGrey, fontSize: 10)),
                  ]);
                }).toList()),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: kGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.info_outline, size: 13, color: kGreen),
                const SizedBox(width: 6),
                Text(
                  isField
                      ? 'Optimal: N 180-250 · P 40-60 · K 150-200 mg/kg'
                      : 'Optimal: N 100-200 · P 20-40 · K 80-150 mg/kg',
                  style: TextStyle(color: textGrey, fontSize: 10),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        ...nutrients.map((n) => _nutrientCard(n)),
      ]),
    );
  }

  Widget _nutrientCard(Map<String, dynamic> n) {
    final value = n['value'] as double;
    final max = n['max'] as double;
    final color = n['color'] as Color;
    final status = n['status'] as Map<String, dynamic>;
    final progress = (value / max).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: divClr),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(n['icon'] as IconData, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n['name'] as String, style: TextStyle(color: textDark,
                  fontWeight: FontWeight.bold, fontSize: 14)),
              Text(n['desc'] as String,
                  style: TextStyle(color: textGrey, fontSize: 11)),
            ]),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${value.toStringAsFixed(0)} ${n['unit']}',
                style: TextStyle(color: color,
                    fontWeight: FontWeight.bold, fontSize: 15)),
            Container(
              margin: const EdgeInsets.only(top: 3),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: (status['color'] as Color).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(status['label'],
                  style: TextStyle(color: status['color'],
                      fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ]),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: divClr,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 10),
        if (status['label'] != 'Sufficient')
          Row(children: [
            const Icon(Icons.lightbulb_outline, color: kWarning, size: 14),
            const SizedBox(width: 6),
            Expanded(child: Text(n['tip'] as String,
                style: const TextStyle(color: kWarning, fontSize: 12))),
          ]),
      ]),
    );
  }

  Widget _buildTrends() {
    final params = ['Moisture', 'Temperature', 'pH'];
    final isField = _npkMode == 'field';

    final Map<String, Map<String, String>> optimalRanges = {
      'field': {
        'Moisture':    '🌊 Optimal: 30–60%',
        'Temperature': '🌡️ Optimal: 15–30°C',
        'pH':          '⚗️ Optimal: 6.0–7.5',
      },
      'pot': {
        'Moisture':    '🌊 Optimal: 40–70%',
        'Temperature': '🌡️ Optimal: 18–28°C',
        'pH':          '⚗️ Optimal: 5.5–7.0',
      },
    };

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Toggle — same style as Overview ──────────────────────────────
        _npkModeToggle(),
        const SizedBox(height: 12),

        // ── Optimal range badge ───────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: kGreen.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kGreen.withOpacity(0.2)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 14, color: kGreen),
            const SizedBox(width: 8),
            Text(
              optimalRanges[_npkMode]![params[_trendParam]] ?? '',
              style: TextStyle(color: textGrey, fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Param selector ────────────────────────────────────────────────
        Row(
          children: List.generate(params.length, (i) {
            final sel = _trendParam == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _trendParam = i),
                child: Container(
                  margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? kGreen.withOpacity(0.15) : card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: sel ? kGreen : divClr),
                  ),
                  child: Text(params[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: sel ? kGreen : textGrey,
                          fontSize: 13,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        _buildChartCard(label: 'Daily', rangeLabel: 'Last 24 Hours',
            count: 24, startLabel: '00:00', endLabel: 'Now'),
        const SizedBox(height: 14),
        _buildChartCard(label: 'Weekly', rangeLabel: 'Last 7 Days',
            count: 7, startLabel: 'Mon', endLabel: 'Today'),
        const SizedBox(height: 14),
        _buildChartCard(label: 'Monthly', rangeLabel: 'Last 30 Days',
            count: 30, startLabel: '1st', endLabel: 'Today'),
      ]),
    );
  }

  // ── Shared Field/Pot toggle — matches Overview _locationBtn style exactly ──
  Widget _npkModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _s.isDarkGreen ? const Color(0xFF0F2A18) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        _npkModeBtn('field', '🌾', 'Field / Farm', 'Farming land'),
        _npkModeBtn('pot',   '🏡', 'Home / Pot',   'Indoor plants'),
      ]),
    );
  }

  Widget _npkModeBtn(String mode, String emoji, String label, String subtitle) {
    final sel = _npkMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _npkMode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? card : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: sel ? [BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6, offset: const Offset(0, 2))] : [],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(
                  color: sel ? textDark : textGrey,
                  fontSize: 13,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
              Text(subtitle, style: TextStyle(
                  color: textGrey, fontSize: 10)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildChartCard({required String label, required String rangeLabel,
      required int count, required String startLabel, required String endLabel}) {
    final data = _history.take(count).toList().reversed.toList();
    double Function(SoilData) getValue;
    Color lineColor;
    String unit;
    switch (_trendParam) {
      case 0: getValue = (d) => d.moisture; lineColor = kBlue; unit = '%'; break;
      case 1: getValue = (d) => d.temperature; lineColor = kWarning; unit = '°C'; break;
      default: getValue = (d) => d.ph; lineColor = kGreen; unit = '';
    }
    final values = data.map(getValue).toList();
    final minV = values.reduce(min);
    final maxV = values.reduce(max);
    final range = (maxV - minV).clamp(0.1, double.infinity);
    final avg = values.reduce((a, b) => a + b) / values.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: divClr),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: textDark,
                fontWeight: FontWeight.bold, fontSize: 15)),
            Text(rangeLabel, style: TextStyle(color: textGrey, fontSize: 11)),
          ]),
          Text('Avg: ${avg.toStringAsFixed(1)}$unit',
              style: TextStyle(color: lineColor, fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 4),
        Text('Min: ${minV.toStringAsFixed(1)}$unit  •  Max: ${maxV.toStringAsFixed(1)}$unit',
            style: TextStyle(color: textGrey, fontSize: 11)),
        const SizedBox(height: 14),
        SizedBox(
          height: 140,
          child: CustomPaint(
            painter: _ChartPainter(values: values, minV: minV,
                range: range, lineColor: lineColor,
                gridColor: divClr),
            child: Container(),
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(startLabel, style: TextStyle(color: textGrey, fontSize: 10)),
          Text(endLabel, style: TextStyle(color: textGrey, fontSize: 10)),
        ]),
      ]),
    );
  }
}

class _GeminiSuggestionsWidget extends StatefulWidget {
  final AppSettings settings;
  final SoilData soilData;
  final String selectedCrop;
  final String locationType;
  const _GeminiSuggestionsWidget({
    required this.settings,
    required this.soilData,
    this.selectedCrop = '',
    this.locationType = 'field',
  });
  @override
  State<_GeminiSuggestionsWidget> createState() => _GeminiSuggestionsWidgetState();
}

class _GeminiSuggestionsWidgetState extends State<_GeminiSuggestionsWidget> {
  static const kGreen      = Color(0xFF2ECC71);
  static const kMistralBlue = Color(0xFFFF7000);
  static const kBlue       = Color(0xFF29B6F6);
  static const kWarning    = Color(0xFFFFB300);
  static const kDanger     = Color(0xFFFF5252);
  static const String _mistralApiKey = 'YOUR_API_KEY'; // My suggestion use mistral ai its free and more give token than gemini 

  String _response = '';
  bool _loading = false;
  String _error = '';

  AppSettings get s => widget.settings;
  Color get card     => s.cardColor;
  Color get textDark => s.textDark;
  Color get textGrey => s.textGrey;
  Color get divClr   => s.dividerColor;

  String _buildPrompt() {
    final w = WeatherAlertService();
    final isField = widget.locationType == 'field';
    final cropLine = widget.selectedCrop.isNotEmpty
        ? widget.selectedCrop
        : isField ? 'general field crops' : 'general home plants';
    final location = isField ? 'agricultural field' : 'home pot/garden';
    final moisture = widget.soilData.moisture;
    final moistureStatus = moisture < 20 ? 'critically dry, irrigate immediately'
        : moisture > 60 ? 'overwatered, stop irrigation' : 'normal range';
    final soilTemp = widget.soilData.temperature;
    final tempStatus = soilTemp > 35 ? 'dangerously high, mulch soil'
        : soilTemp < 12 ? 'too cold, cover crops' : 'optimal';
    final n = widget.soilData.nitrogen;
    final p = widget.soilData.phosphorus;
    final k = widget.soilData.potassium;
    final ph = widget.soilData.ph;
    final nStatus = n < 180 ? 'LOW - apply urea' : 'sufficient';
    final pStatus = p < 35 ? 'LOW - apply DAP' : 'sufficient';
    final kStatus = k < 140 ? 'LOW - apply MOP' : 'sufficient';
    final phStatus = ph < 6.0 ? 'acidic - add lime' : ph > 7.5 ? 'alkaline - add sulfur' : 'ideal';
    final weatherMain = w.weatherMain.toLowerCase();
    final weatherAlert = weatherMain == 'thunderstorm' ? 'DANGER: Thunderstorm - stop field work'
        : weatherMain == 'rain' ? 'Rain - stop irrigation, avoid fertilizing'
        : w.tempC > 38 ? 'Extreme heat - water crops early morning'
        : w.windSpeed > 15 ? 'High winds - avoid spraying chemicals'
        : 'Weather is clear, good time for field work';

    return '''Complete these 4 farming advice lines for my $location growing $cropLine. Write only the 4 lines.

1. 💧 Soil moisture is at ${moisture.toStringAsFixed(1)}% which is $moistureStatus.
2. 🌡️ Soil temperature is ${soilTemp.toStringAsFixed(1)}°C and weather is ${w.tempC.toStringAsFixed(1)}°C which is $tempStatus.
3. 🌱 Nutrient check: N is $nStatus, P is $pStatus, K is $kStatus, pH is ${ph.toStringAsFixed(1)} ($phStatus).
4. ⚠️ Weather alert: $weatherAlert.

Rewrite each as a complete 1-2 sentence natural advice for a farmer. Keep the number and emoji. No markdown, no bold.''';
  }

  Future<void> _fetchGemini() async {
    setState(() { _loading = true; _error = ''; _response = ''; });
    try {
      final response = await http.post(
        Uri.parse('https://api.mistral.ai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_mistralApiKey',
        },
        body: jsonEncode({
          'model': 'mistral-small-latest',
          'messages': [
            {
              'role': 'user',
              'content': _buildPrompt(),
            }
          ],
          'max_tokens': 800,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['choices'][0]['message']['content'] ?? '';
        setState(() { _response = text; _loading = false; });
      } else {
        setState(() { _error = 'Mistral API error (${response.statusCode}).'; _loading = false; });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Connection failed. Check your internet.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: kMistralBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
            child: const _ThreeStarIcon(size: 16, color: kMistralBlue),
          ),
          const SizedBox(width: 8),
          Text('AI Suggestions', style: TextStyle(color: textDark,
              fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: kMistralBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20)),
            child: const Text('Mistral',
                style: TextStyle(color: kMistralBlue,
                    fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ]),
        if (!_loading)
          GestureDetector(
            onTap: () { setState(() => _response = ''); _fetchGemini(); },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: s.cardAltColor, borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.refresh, color: textGrey, size: 16),
            ),
          ),
      ]),
      const SizedBox(height: 12),
      if (_loading)
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: card, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: divClr),
          ),
          child: Column(children: [
            const CircularProgressIndicator(color: kMistralBlue, strokeWidth: 2),
            const SizedBox(height: 12),
            Text('Mistral AI is analyzing your soil & weather...',
                textAlign: TextAlign.center,
                style: TextStyle(color: textGrey, fontSize: 13)),
          ]),
        )
      else if (_response.isEmpty && _error.isEmpty)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: card, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: divClr),
          ),
          child: Column(children: [
            const _ThreeStarIcon(size: 36, color: kMistralBlue),
            const SizedBox(height: 10),
            Text('Get AI-powered farming suggestions\nbased on your soil and weather data.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textGrey, fontSize: 13, height: 1.5)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _fetchGemini,
                style: ElevatedButton.styleFrom(
                    backgroundColor: kMistralBlue,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                icon: const _ThreeStarIcon(size: 18, color: Colors.white),
                label: const Text('Ask Mistral AI',
                    style: TextStyle(color: Colors.white,
                        fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        )
      else if (_error.isNotEmpty)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: card, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade700.withOpacity(0.4)),
          ),
          child: Column(children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 32),
            const SizedBox(height: 8),
            Text(_error, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () { setState(() { _response = ''; _error = ''; }); _fetchGemini(); },
              style: ElevatedButton.styleFrom(
                  backgroundColor: kMistralBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
              label: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ]),
        )
      else
        Column(children: () {
          final rawLines = _response
              .split(RegExp(r'\n|(?<=\.)\s+(?=\d+[\.\)])'))
              .where((l) => l.trim().isNotEmpty)
              .map((l) => l.trim()
                  .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1')
                  .replaceAll('**', '').replaceAll('*', '').replaceAll('#', '').trim())
              .where((l) => l.isNotEmpty).toList();
          final titles = ['Moisture & Irrigation', 'Temperature', 'Nutrients & Fertilizer', 'Urgent Action'];
          final icons = [Icons.water_drop, Icons.thermostat, Icons.grass, Icons.warning_amber_rounded];
          final colors = [kBlue, kWarning, kGreen, kDanger];
          return List.generate(rawLines.length, (i) {
            String text = rawLines[i].replaceAll(RegExp(r'^\d+[\.\)]\s*'), '').trim();
            if (text.isEmpty) return const SizedBox.shrink();
            final color = i < colors.length ? colors[i] : kMistralBlue;
            final icon = i < icons.length ? icons[i] : Icons.auto_awesome;
            final title = i < titles.length ? titles[i] : 'Suggestion ${i + 1}';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.25)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title, style: TextStyle(color: color,
                      fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(text, softWrap: true, overflow: TextOverflow.visible,
                      style: TextStyle(color: textDark, fontSize: 13, height: 1.5)),
                ])),
              ]),
            );
          });
        }()),
    ]);
  }
}

class _ThreeStarIcon extends StatelessWidget {
  final double size;
  final Color color;
  const _ThreeStarIcon({required this.size, required this.color});
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size,
      child: CustomPaint(painter: _ThreeStarPainter(color: color)));
}

class _ThreeStarPainter extends CustomPainter {
  final Color color;
  const _ThreeStarPainter({required this.color});
  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    const points = 4; const innerRatio = 0.4;
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : radius * innerRatio;
      final angle = (i * 3.14159265 / points) - 3.14159265 / 2;
      final x = center.dx + r * cos(angle); final y = center.dy + r * sin(angle);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    path.close(); canvas.drawPath(path, paint);
  }
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    _drawStar(canvas, Offset(size.width * 0.72, size.height * 0.22), size.width * 0.28, paint);
    _drawStar(canvas, Offset(size.width * 0.25, size.height * 0.70), size.width * 0.19, paint);
    _drawStar(canvas, Offset(size.width * 0.18, size.height * 0.22), size.width * 0.11, paint);
  }
  @override
  bool shouldRepaint(_ThreeStarPainter old) => old.color != color;
}

class _ChartPainter extends CustomPainter {
  final List<double> values;
  final double minV, range;
  final Color lineColor, gridColor;
  _ChartPainter({required this.values, required this.minV,
      required this.range, required this.lineColor,
      this.gridColor = const Color(0xFFEEEEEE)});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final linePaint = Paint()..color = lineColor..strokeWidth = 2.5
        ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final gridPaint = Paint()..color = gridColor..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final path = Path(); final fillPath = Path();
    for (int i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final normalized = (values[i] - minV) / range;
      final y = size.height * (1 - normalized.clamp(0.0, 1.0));
      if (i == 0) {
        path.moveTo(x, y); fillPath.moveTo(x, size.height); fillPath.lineTo(x, y);
      } else {
        final prevX = size.width * (i - 1) / (values.length - 1);
        final prevNorm = (values[i - 1] - minV) / range;
        final prevY = size.height * (1 - prevNorm.clamp(0.0, 1.0));
        final cpX = (prevX + x) / 2;
        path.cubicTo(cpX, prevY, cpX, y, x, y);
        fillPath.cubicTo(cpX, prevY, cpX, y, x, y);
      }
    }
    fillPath.lineTo(size.width, size.height); fillPath.close();
    fillPaint.shader = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [lineColor.withOpacity(0.3), lineColor.withOpacity(0.0)],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint); canvas.drawPath(path, linePaint);
    final lastX = size.width;
    final lastNorm = (values.last - minV) / range;
    final lastY = size.height * (1 - lastNorm.clamp(0.0, 1.0));
    canvas.drawCircle(Offset(lastX, lastY), 5, Paint()..color = lineColor);
    canvas.drawCircle(Offset(lastX, lastY), 5,
        Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
  }
  @override
  bool shouldRepaint(_ChartPainter old) => old.values != values;
}
