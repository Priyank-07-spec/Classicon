import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

const int _nightStartHour   = 19;
const int _nightStartMinute = 30;
const int _dayStartHour     = 6;

bool isNightTime({DateTime? sunrise, DateTime? sunset}) {
  final now = DateTime.now();
  if (sunrise != null && sunset != null) {
    return now.isBefore(sunrise) || now.isAfter(sunset);
  }
  final h = now.hour;
  final m = now.minute;
  if (h > _nightStartHour)                            return true;
  if (h == _nightStartHour && m >= _nightStartMinute) return true;
  if (h < _dayStartHour)                              return true;
  return false;
}

class _VCfg {
  final String asset;
  final Color  overlay;
  final double opacity;
  final Color  textColor;
  const _VCfg(this.asset, this.overlay, this.opacity, this.textColor);
}

const _VCfg _night = _VCfg(
  'assets/videos/night.mp4',
  Color(0xFF0A0A2E), 0.40,
  Colors.white,
);

const Map<String, _VCfg> _day = {
  'clear': _VCfg(
    'assets/videos/clear.mp4',
    Color(0xFF1A6B35), 0.10,
    Color(0xFF1A1A1A),
  ),
  'clouds': _VCfg(
    'assets/videos/clouds.mp4',
    Color(0xFF37474F), 0.22,
    Colors.white,
  ),
  'rain': _VCfg(
    'assets/videos/rain.mp4',
    Color(0xFF0D47A1), 0.32,
    Colors.white,
  ),
  'drizzle': _VCfg(
    'assets/videos/drizzle.mp4',
    Color(0xFF1565C0), 0.26,
    Colors.white,
  ),
  'fog': _VCfg(
    'assets/videos/fog.mp4',
    Color(0xFF546E7A), 0.28,
    Colors.white,
  ),
  'mist': _VCfg(
    'assets/videos/fog.mp4',
    Color(0xFF546E7A), 0.26,
    Colors.white,
  ),
  'snow': _VCfg(
    'assets/videos/snow.mp4',
    Color(0xFF90CAF9), 0.16,
    Color(0xFF1A1A1A),
  ),
};

_VCfg _resolve(String weatherMain, [DateTime? sunrise, DateTime? sunset]) {
  if (isNightTime(sunrise: sunrise, sunset: sunset)) return _night;
  return _day[weatherMain.toLowerCase()] ?? _day['clear']!;
}

Color getWeatherTextColor(String weatherMain, [DateTime? sunrise, DateTime? sunset]) =>
    _resolve(weatherMain, sunrise, sunset).textColor;

class WeatherVideoBackground extends StatefulWidget {
  final String weatherMain;
  final Widget child;
  final DateTime? sunrise;
  final DateTime? sunset;

  const WeatherVideoBackground({
    super.key,
    required this.weatherMain,
    required this.child,
    this.sunrise,
    this.sunset,
  });

  @override
  State<WeatherVideoBackground> createState() => _WVBState();
}

class _WVBState extends State<WeatherVideoBackground> {
  VideoPlayerController? _ctrl;
  bool   _ready     = false;
  String _loadedKey = '';

  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _loadVideo();
    _clockTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted) return;
      if (_buildKey() != _loadedKey) _loadVideo();
    });
  }

  @override
  void didUpdateWidget(WeatherVideoBackground old) {
    super.didUpdateWidget(old);
    if (_buildKey() != _loadedKey) _loadVideo();
  }

  String _buildKey() =>
      isNightTime(sunrise: widget.sunrise, sunset: widget.sunset)
          ? 'night'
          : widget.weatherMain.toLowerCase();

  Future<void> _loadVideo() async {
    final key    = _buildKey();
    if (key == _loadedKey && _ready) return;

    final cfg    = _resolve(widget.weatherMain, widget.sunrise, widget.sunset);
    final oldCtrl = _ctrl;
    final newCtrl = VideoPlayerController.asset(cfg.asset);

    try {
      await newCtrl.initialize();
      if (!mounted) { newCtrl.dispose(); return; }

      newCtrl.setLooping(true);
      newCtrl.setVolume(0.0);
      newCtrl.play();

      setState(() {
        _ctrl      = newCtrl;
        _loadedKey = key;
        _ready     = true;
      });

      await Future.delayed(const Duration(milliseconds: 900));
      await oldCtrl?.dispose();

    } catch (_) {
      newCtrl.dispose();
      if (mounted) setState(() => _ready = false);
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _resolve(widget.weatherMain, widget.sunrise, widget.sunset);

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 900),
          child: _ready && _ctrl != null
              ? _VideoFill(key: ValueKey(_loadedKey), ctrl: _ctrl!)
              : _FallbackGrad(
                  key: ValueKey('fb_${_loadedKey}'),
                  weatherMain: widget.weatherMain,
                  sunrise: widget.sunrise,
                  sunset:  widget.sunset,
                ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 900),
          color: cfg.overlay.withOpacity(cfg.opacity),
        ),
        if (isNightTime(sunrise: widget.sunrise, sunset: widget.sunset))
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 14,
            child: _NightBadge(),
          ),
        widget.child,
      ],
    );
  }
}

class _VideoFill extends StatelessWidget {
  final VideoPlayerController ctrl;
  const _VideoFill({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) => SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width:  ctrl.value.size.width,
            height: ctrl.value.size.height,
            child:  VideoPlayer(ctrl),
          ),
        ),
      );
}

class _FallbackGrad extends StatelessWidget {
  final String weatherMain;
  final DateTime? sunrise;
  final DateTime? sunset;
  const _FallbackGrad({super.key, required this.weatherMain, this.sunrise, this.sunset});

  @override
  Widget build(BuildContext context) =>
      Container(decoration: BoxDecoration(gradient: _pick()));

  LinearGradient _pick() {
    if (isNightTime(sunrise: sunrise, sunset: sunset)) {
      return const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF0A0A2E), Color(0xFF1A1A4E), Color(0xFF0D1B2A)],
      );
    }
    switch (weatherMain.toLowerCase()) {
      case 'rain': case 'drizzle':
        return const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF3F51B5)],
        );
      case 'snow':
        return const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB), Color(0xFFE8EAF6)],
        );
      case 'clouds':
        return const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF78909C), Color(0xFFB0BEC5), Color(0xFFECEFF1)],
        );
      case 'fog': case 'mist':
        return const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF90A4AE), Color(0xFFB0BEC5), Color(0xFFCFD8DC)],
        );
      default:
        return const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF87CEEB), Color(0xFFFFF9C4), Color(0xFFE8F5E9)],
        );
    }
  }
}

class _NightBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Text('🌙', style: TextStyle(fontSize: 12)),
          SizedBox(width: 4),
          Text('Night',
              style: TextStyle(
                  color: Colors.white, fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ]),
      );
}
