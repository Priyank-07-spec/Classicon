import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class WeatherAnimationBackground extends StatefulWidget {
  final String weatherMain;
  final DateTime? sunrise;
  final DateTime? sunset;

  const WeatherAnimationBackground({
    super.key,
    required this.weatherMain,
    this.sunrise,
    this.sunset,
  });

  @override
  State<WeatherAnimationBackground> createState() =>
      _WeatherAnimationBackgroundState();
}

class _WeatherAnimationBackgroundState
    extends State<WeatherAnimationBackground> {
  VideoPlayerController? _controller;
  String _currentAsset = '';
  bool _isInitialized = false;

  /// Returns true if current time is between sunset and next sunrise.
  bool _isNight() {
    final now = DateTime.now();
    if (widget.sunrise != null && widget.sunset != null) {
      // Use real astronomical sunrise/sunset for the searched city
      return now.isBefore(widget.sunrise!) || now.isAfter(widget.sunset!);
    }
    // Fallback to fixed window if API data not yet available
    final t = now.hour * 60 + now.minute;
    return t >= 19 * 60 + 30 || t < 6 * 60 + 30;
  }

  String _getVideoAsset() {
    if (_isNight()) return 'assets/videos/Night_Mobile_Video.mp4';

    final w = widget.weatherMain.toLowerCase();
    if (w == 'snow') return 'assets/videos/winter_mobile_video.mp4';
    if (w == 'rain' || w == 'drizzle' || w == 'thunderstorm')
      return 'assets/videos/Rainy_Day_video.mp4';
    return 'assets/videos/Clean_Sky_video.mp4';
  }

  Future<void> _initVideo(String asset) async {
    await _controller?.dispose();
    _controller = null;
    if (mounted) setState(() => _isInitialized = false);

    final ctrl = VideoPlayerController.asset(asset);
    _controller = ctrl;
    try {
      await ctrl.initialize();
      if (!mounted) return;
      ctrl.setLooping(true);
      ctrl.setVolume(0);
      ctrl.play();
      setState(() { _currentAsset = asset; _isInitialized = true; });
    } catch (_) {
      if (mounted) setState(() => _isInitialized = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _initVideo(_getVideoAsset());
  }

  @override
  void didUpdateWidget(WeatherAnimationBackground old) {
    super.didUpdateWidget(old);
    final newAsset = _getVideoAsset();
    if (newAsset != _currentAsset) _initVideo(newAsset);
  }

  @override
  void dispose() { _controller?.dispose(); super.dispose(); }

  Widget _fallback() {
    final isNight = _isNight();
    final w = widget.weatherMain.toLowerCase();
    List<Color> c;
    if (isNight) c = [const Color(0xFF0D1B2A), const Color(0xFF1B2838)];
    else if (w == 'snow') c = [const Color(0xFF90A4AE), const Color(0xFFE0F2F1)];
    else if (w == 'rain' || w == 'drizzle' || w == 'thunderstorm')
      c = [const Color(0xFF1A237E), const Color(0xFF3949AB)];
    else c = [const Color(0xFF1565C0), const Color(0xFF90CAF9)];
    return Container(decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter,
            end: Alignment.bottomCenter, colors: c)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) return _fallback();
    return SizedBox.expand(child: FittedBox(fit: BoxFit.cover,
      child: SizedBox(width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!))));
  }
}
