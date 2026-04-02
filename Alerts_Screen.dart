import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:classico/Soil_Screen.dart';
import 'package:classico/weather_alert_service.dart';
import 'package:classico/app_settings.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  static const Color kGreen   = Color(0xFF2ECC71);
  static const Color kWarning = Color(0xFFFFB300);
  static const Color kDanger  = Color(0xFFFF5252);
  static const Color kBlue    = Color(0xFF29B6F6);

  final AppSettings _s = AppSettings();
  late final VoidCallback _themeListener;

  late SoilData _soil;
  Timer? _timer;
  int _filterIndex = 0;
  final List<Map<String, dynamic>> _alertLog = [];

  Color get bg       => _s.bgColor;
  Color get card     => _s.cardColor;
  Color get textDark => _s.textDark;
  Color get textGrey => _s.textGrey;
  Color get divClr   => _s.dividerColor;

  @override
  void initState() {
    super.initState();
    _soil = _mockSoil();
    _rebuildLog();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() { _soil = _mockSoil(); _rebuildLog(); });
    });
    _themeListener = () { if (mounted) setState(() {}); };
    _s.addListener(_themeListener);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _s.removeListener(_themeListener);
    super.dispose();
  }

  SoilData _mockSoil() {
    final r = Random();
    return SoilData(
      moisture: 18 + r.nextDouble() * 30,
      temperature: 20 + r.nextDouble() * 16,
      ph: 5.6 + r.nextDouble() * 2.4,
      nitrogen: 160 + r.nextDouble() * 100,
      phosphorus: 30 + r.nextDouble() * 40,
      potassium: 120 + r.nextDouble() * 80,
      timestamp: DateTime.now(),
    );
  }

  void _rebuildLog() {
    _alertLog.clear();
    final wAlerts = WeatherAlertService().weatherAlerts;
    for (final wa in wAlerts) {
      final colorStr = wa['color'] as String;
      final color = colorStr == 'danger' ? kDanger
          : colorStr == 'warning' ? kWarning
          : colorStr == 'blue' ? kBlue : kGreen;
      _alertLog.add({
        'type': wa['type'],
        'icon': IconData(wa['icon'] as int, fontFamily: 'MaterialIcons'),
        'color': color,
        'title': wa['title'],
        'msg': wa['msg'],
        'time': DateTime.now(),
        'category': 'weather',
      });
    }
    if (_soil.moisture < 20)
      _alertLog.add(_alert('critical', Icons.water_drop, kDanger,
          'Critical: Soil Too Dry',
          'Moisture at ${_soil.moisture.toStringAsFixed(1)}%. Irrigate immediately.'));
    else if (_soil.moisture > 60)
      _alertLog.add(_alert('warning', Icons.water, kBlue,
          'Soil Overwatered',
          'Moisture at ${_soil.moisture.toStringAsFixed(1)}%. Improve drainage.'));
    if (_soil.temperature > 32)
      _alertLog.add(_alert('critical', Icons.local_fire_department, kDanger,
          'High Soil Temperature',
          'Temp at ${_soil.temperature.toStringAsFixed(1)}°C. Risk of root damage.'));
    else if (_soil.temperature < 12)
      _alertLog.add(_alert('warning', Icons.ac_unit, kBlue,
          'Low Soil Temperature',
          'Temp at ${_soil.temperature.toStringAsFixed(1)}°C. Crop growth may slow.'));
    if (_soil.ph < 6.0)
      _alertLog.add(_alert('warning', Icons.science, kWarning,
          'Soil Too Acidic', 'pH ${_soil.ph.toStringAsFixed(1)}. Apply agricultural lime.'));
    else if (_soil.ph > 7.5)
      _alertLog.add(_alert('warning', Icons.science, kWarning,
          'Soil Too Alkaline', 'pH ${_soil.ph.toStringAsFixed(1)}. Apply sulfur.'));
    if (_soil.nitrogen < 180)
      _alertLog.add(_alert('warning', Icons.grass, kWarning,
          'Low Nitrogen (N)', 'N at ${_soil.nitrogen.toStringAsFixed(0)} mg/kg. Apply urea.'));
    if (_soil.phosphorus < 35)
      _alertLog.add(_alert('warning', Icons.circle, kWarning,
          'Low Phosphorus (P)', 'P at ${_soil.phosphorus.toStringAsFixed(0)} mg/kg. Apply DAP.'));
    if (_soil.potassium < 140)
      _alertLog.add(_alert('warning', Icons.water_drop_outlined, kWarning,
          'Low Potassium (K)', 'K at ${_soil.potassium.toStringAsFixed(0)} mg/kg. Apply MOP.'));
    if (_soil.moisture > 55 && _soil.temperature > 28)
      _alertLog.add(_alert('critical', Icons.bug_report, kDanger,
          'Disease Risk: Fungal Infection',
          'High moisture + high temperature. Apply fungicide.'));
    _alertLog.add(_alert('info', Icons.info_outline, kGreen,
        'IoT Sensor Active', 'Sensor transmitting normally. Last sync: just now.'));
    if (_alertLog.where((a) => a['type'] != 'info').isEmpty)
      _alertLog.insert(0, _alert('info', Icons.check_circle, kGreen,
          'All Soil Conditions Normal', 'All values in optimal range.'));
  }

  Map<String, dynamic> _alert(String type, IconData icon, Color color,
      String title, String msg) => {
    'type': type, 'icon': icon, 'color': color,
    'title': title, 'msg': msg, 'time': DateTime.now(),
  };

  List<Map<String, dynamic>> get _filtered {
    if (_filterIndex == 0) return _alertLog;
    final types = ['', 'critical', 'warning', 'info'];
    return _alertLog.where((a) => a['type'] == types[_filterIndex]).toList();
  }

  int get _criticalCount => _alertLog.where((a) => a['type'] == 'critical').length;
  int get _warningCount  => _alertLog.where((a) => a['type'] == 'warning').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
        _buildHeader(),
        const SizedBox(height: 8),
        _buildSummaryRow(),
        _buildFilterBar(),
        Expanded(child: _buildAlertList()),
      ]),
    );
  }

  Widget _buildHeader() {
    final hasAlerts = _criticalCount > 0;
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
                Text('Alerts', style: TextStyle(color: textDark,
                    fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  hasAlerts
                      ? '$_criticalCount critical · $_warningCount warnings'
                      : 'All conditions normal',
                  style: TextStyle(
                      color: hasAlerts ? kDanger : kGreen, fontSize: 12)),
              ]),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: hasAlerts
                      ? kDanger.withOpacity(0.15) : kGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: hasAlerts
                      ? kDanger.withOpacity(0.3) : kGreen.withOpacity(0.3)),
                ),
                child: Icon(
                  hasAlerts ? Icons.warning_amber_rounded : Icons.check_circle,
                  color: hasAlerts ? kDanger : kGreen, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(children: [
        _summaryCard('Critical', _criticalCount, kDanger, Icons.error_outline),
        const SizedBox(width: 10),
        _summaryCard('Warnings', _warningCount, kWarning, Icons.warning_amber),
        const SizedBox(width: 10),
        _summaryCard('Total', _alertLog.length, textGrey, Icons.notifications),
      ]),
    );
  }

  Widget _summaryCard(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: divClr),
          boxShadow: _s.isDarkGreen ? [] : [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text('$count', style: TextStyle(color: color,
              fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: textGrey, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = ['All', 'Critical', 'Warning', 'Info'];
    final colors = [textDark, kDanger, kWarning, kGreen];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: List.generate(filters.length, (i) {
          final sel = _filterIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _filterIndex = i),
              child: Container(
                margin: EdgeInsets.only(right: i < filters.length - 1 ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? colors[i].withOpacity(0.15) : card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: sel ? colors[i] : divClr),
                ),
                child: Text(filters[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: sel ? colors[i] : textGrey,
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAlertList() {
    final items = _filtered;
    if (items.isEmpty) {
      return Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.notifications_off_outlined,
            color: textGrey.withOpacity(0.4), size: 48),
        const SizedBox(height: 12),
        Text('No alerts in this category',
            style: TextStyle(color: textGrey, fontSize: 14)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (_, i) => _alertCard(items[i]),
    );
  }

  Widget _alertCard(Map<String, dynamic> a) {
    final color = a['color'] as Color;
    final type = a['type'] as String;
    final isWeather = a['category'] == 'weather';
    final typeLabel = type == 'critical' ? 'CRITICAL'
        : type == 'warning' ? 'WARNING' : 'INFO';
    final dt = a['time'] as DateTime;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(a['icon'] as IconData, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(typeLabel, style: TextStyle(color: color,
                    fontSize: 9, fontWeight: FontWeight.bold)),
              ),
              if (isWeather) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: kBlue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('WEATHER',
                      style: TextStyle(color: kBlue, fontSize: 9,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ]),
            Text(
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
              style: TextStyle(color: textGrey, fontSize: 10)),
          ]),
          const SizedBox(height: 6),
          Text(a['title'] as String, style: TextStyle(color: color,
              fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(a['msg'] as String,
              style: TextStyle(color: textGrey, fontSize: 12, height: 1.4)),
        ])),
      ]),
    );
  }
}
