import 'package:flutter/material.dart';
import 'package:classico/Services/auth_service.dart';
import 'package:classico/app_settings.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color kGreen     = Color(0xFF2ECC71);
  static const Color kDarkGreen = Color(0xFF1A6B35);

  bool _notificationsEnabled = true;
  bool _weatherAlerts        = true;
  bool _soilAlerts           = false;
  bool _isLoading            = true;

  String _name  = '';
  String _email = '';
  String _phone = '';

  String _farmLocation = 'Rajkot, Gujarat';
  String _cropType     = '';
  String _farmSize     = '';
  String _irrigation   = '';

  final AppSettings _s = AppSettings();
  late final VoidCallback _settingsListener;

  @override
  void initState() {
    super.initState();
    _settingsListener = () { if (mounted) setState(() {}); };
    _s.addListener(_settingsListener);
    _loadUserData();
  }

  @override
  void dispose() {
    _s.removeListener(_settingsListener);
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final result = await AuthService.getCurrentUser();
    if (!mounted) return;
    if (result['success']) {
      final data = result['data'];
      setState(() {
        _name  = data['name']  ?? '';
        _email = data['email'] ?? '';
        _phone = data['phone'] ?? '';
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  String t(String key) => _s.t(key);

  // ── Dynamic color shortcuts ───────────────────────────────────────────────
  Color get bg        => _s.bgColor;
  Color get card      => _s.cardColor;
  Color get textDark  => _s.textDark;
  Color get textGrey  => _s.textGrey;
  Color get divider   => _s.dividerColor;
  Color get iconBg    => _s.isDarkGreen
      ? const Color(0xFF1B3D22) : const Color(0xFFE8F8EF);
  Color get btnText   => _s.buttonTextColor;
  Color get btnBorder => _s.buttonBorderColor;
  Color get btnBg     => _s.buttonBgColor;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bg,
        body: const Center(child: CircularProgressIndicator(color: kGreen)),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kDarkGreen, kGreen],
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: Column(children: [
                    Row(children: [
                      Text(t('profile'),
                          style: const TextStyle(color: Colors.white,
                              fontSize: 22, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 20),
                    Row(children: [
                      Stack(children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.person,
                              color: Colors.white, size: 44),
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            width: 26, height: 26,
                            decoration: const BoxDecoration(
                                color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt,
                                color: kDarkGreen, size: 14),
                          ),
                        ),
                      ]),
                      const SizedBox(width: 16),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_name.isEmpty ? 'Farmer' : _name,
                              style: const TextStyle(color: Colors.white,
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(_email,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.grass,
                                  color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text(t('smart_farmer'),
                                  style: const TextStyle(color: Colors.white,
                                      fontSize: 11, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ],
                      )),
                    ]),
                  ]),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Personal Info ────────────────────────────────────────────
                _sectionTitle(t('personal_info')),
                const SizedBox(height: 10),
                _infoCard([
                  _infoRow(Icons.person, t('full_name'), _name),
                  _dividerW(),
                  _infoRow(Icons.email, t('email'), _email),
                  _dividerW(),
                  _infoRow(Icons.phone, t('phone'), _phone),
                ]),
                const SizedBox(height: 8),
                _actionButton(Icons.edit, t('edit_profile'),
                    () => _showEditProfile(context)),

                const SizedBox(height: 20),

                // ── Farm Details ─────────────────────────────────────────────
                _sectionTitle(t('farm_details')),
                const SizedBox(height: 10),
                _infoCard([
                  _infoRow(Icons.location_on, t('location'), _farmLocation),
                  _dividerW(),
                  _infoRow(Icons.crop, t('crop_type'),
                      _cropType.isEmpty ? t('not_set') : _cropType),
                  _dividerW(),
                  _infoRow(Icons.terrain, t('farm_size'),
                      _farmSize.isEmpty ? t('not_set') : '$_farmSize acres'),
                  _dividerW(),
                  _infoRow(Icons.water_drop, t('irrigation'),
                      _irrigation.isEmpty ? t('not_set') : _irrigation),
                ]),
                const SizedBox(height: 8),
                _actionButton(Icons.edit, t('edit_farm'),
                    () => _showEditFarm(context)),

                const SizedBox(height: 20),

                // ── Notifications ────────────────────────────────────────────
                _sectionTitle(t('notifications')),
                const SizedBox(height: 10),
                _infoCard([
                  _switchRow(Icons.notifications, t('enable_notif'),
                      _notificationsEnabled,
                      (val) => setState(() => _notificationsEnabled = val)),
                  _dividerW(),
                  _switchRow(Icons.cloud, t('weather_alerts'), _weatherAlerts,
                      (val) => setState(() => _weatherAlerts = val)),
                  _dividerW(),
                  _switchRow(Icons.grass, t('soil_alerts'), _soilAlerts,
                      (val) => setState(() => _soilAlerts = val)),
                ]),

                const SizedBox(height: 20),

                // ── App Settings ─────────────────────────────────────────────
                _sectionTitle(t('app_settings')),
                const SizedBox(height: 10),
                _infoCard([
                  _menuRow(Icons.language, t('language'),
                      AppSettings.languages[_s.languageCode] ?? 'English',
                      () => _showLanguagePicker(context)),
                  _dividerW(),
                  _menuRow(Icons.thermostat, t('temperature'),
                      AppSettings.tempUnits[_s.tempUnit] ?? 'Celsius (°C)',
                      () => _showTempPicker(context)),
                  _dividerW(),
                  _menuRow(Icons.palette, t('theme'),
                      _s.isDarkGreen ? t('dark_green') : t('light'),
                      () => _showThemePicker(context)),
                ]),

                const SizedBox(height: 20),

                // ── Legal ────────────────────────────────────────────────────
                _sectionTitle(t('legal')),
                const SizedBox(height: 10),
                _infoCard([
                  _menuRow(Icons.description, t('terms'), '',
                      () => _showLegal(context, t('terms'),
                          'Welcome to our Farmer Smart Application. By accessing or using this application, you agree to be bound by the following terms and conditions.\n\n'
                          'This application provides information related to soil conditions, weather updates, and AI-based farming suggestions. While we aim to provide accurate data, we do not guarantee completeness or reliability. Suggestions are for guidance only.\n\n'
                          'The user is responsible for ensuring IoT devices are properly installed. We do not take responsibility for crop or financial loss from use of this application.\n\n'
                          'By using this application, you acknowledge that you have read, understood, and agreed to these terms.')),
                  _dividerW(),
                  _menuRow(Icons.privacy_tip, t('privacy'), '',
                      () => _showLegal(context, t('privacy'),
                          'We respect your privacy. Personal information such as name, email, and farm data is stored securely.\n\nWe do not sell or share your personal data. You may delete your account at any time by contacting support.')),
                  _dividerW(),
                  _menuRow(Icons.info, t('about'), '',
                      () => _showLegal(context, t('about'),
                          'Smart Farmer v1.0.0\n\nA smart farming app powered by IoT sensors and AI to help farmers monitor soil moisture, temperature, and weather.\n\nBuilt with Flutter & Java Spring Boot.')),
                  _dividerW(),
                  _menuRow(Icons.star, t('rate'), '', () {}),
                ]),

                const SizedBox(height: 20),

                // ── Logout ───────────────────────────────────────────────────
                GestureDetector(
                  onTap: () => _confirmLogout(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.logout, color: Colors.red, size: 18),
                          const SizedBox(width: 6),
                          Text(t('logout'),
                              style: const TextStyle(color: Colors.red,
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                        ]),
                  ),
                ),

                const SizedBox(height: 16),
                Center(child: Text(t('version'),
                    style: TextStyle(color: textGrey, fontSize: 12))),
                const SizedBox(height: 140),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom sheet launchers ─────────────────────────────────────────────────
  void _showTempPicker(BuildContext ctx) => showModalBottomSheet(
        useRootNavigator: true, context: ctx,
        backgroundColor: Colors.transparent,
        builder: (_) => _PickerSheet(
          settings: _s, onChanged: () => setState(() {}),
          type: _PickerType.temp,
        ));

  void _showLanguagePicker(BuildContext ctx) => showModalBottomSheet(
        useRootNavigator: true, context: ctx,
        backgroundColor: Colors.transparent,
        builder: (_) => _PickerSheet(
          settings: _s, onChanged: () => setState(() {}),
          type: _PickerType.language,
        ));

  void _showThemePicker(BuildContext ctx) => showModalBottomSheet(
        useRootNavigator: true, context: ctx,
        backgroundColor: Colors.transparent,
        builder: (_) => _PickerSheet(
          settings: _s, onChanged: () => setState(() {}),
          type: _PickerType.theme,
        ));

  void _showLegal(BuildContext context, String title, String content) {
    showModalBottomSheet(
      useRootNavigator: true, context: context,
      isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
            color: card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: divider,
                  borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 18,
              fontWeight: FontWeight.bold, color: textDark)),
          const SizedBox(height: 16),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(content,
                style: TextStyle(color: textGrey, fontSize: 14, height: 1.6)),
          )),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t('logout'),
            style: TextStyle(fontWeight: FontWeight.bold, color: textDark)),
        content: Text(t('logout_confirm'), style: TextStyle(color: textGrey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('cancel'), style: TextStyle(color: textGrey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService.logout();
              if (!context.mounted) return;
              Navigator.pushReplacementNamed(context, 'Welcome_Screen');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(t('logout'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditProfile(BuildContext context) {
    final nameCtrl  = TextEditingController(text: _name);
    final emailCtrl = TextEditingController(text: _email);
    final phoneCtrl = TextEditingController(text: _phone);
    showModalBottomSheet(
      useRootNavigator: true, context: context,
      isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        settings: _s,
        nameCtrl: nameCtrl, emailCtrl: emailCtrl, phoneCtrl: phoneCtrl,
        saveLabel: t('save'), titleLabel: t('edit_profile'),
        onSave: (newName, newEmail, newPhone) async {
          // Show loading snackbar
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Row(children: [
              SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Saving profile...'),
            ]),
            backgroundColor: kGreen,
            duration: const Duration(seconds: 10),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ));

          // Call database update
          final result = await AuthService.updateProfile(
            name:  newName.isNotEmpty  ? newName  : _name,
            email: newEmail.isNotEmpty ? newEmail : _email,
            phone: newPhone.isNotEmpty ? newPhone : _phone,
          );

          if (!context.mounted) return;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();

          if (result['success'] == true) {
            setState(() {
              if (newName.isNotEmpty)  _name  = newName;
              if (newEmail.isNotEmpty) _email = newEmail;
              if (newPhone.isNotEmpty) _phone = newPhone;
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Row(children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Profile updated successfully!'),
              ]),
              backgroundColor: kGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Row(children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(
                    result['error'] ?? 'Failed to update. Try again.')),
              ]),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ));
          }
        },
      ),
    );
  }

  void _showEditFarm(BuildContext context) {
    final locationCtrl   = TextEditingController(text: _farmLocation);
    final cropCtrl       = TextEditingController(text: _cropType);
    final sizeCtrl       = TextEditingController(text: _farmSize);
    final irrigationCtrl = TextEditingController(text: _irrigation);
    showModalBottomSheet(
      useRootNavigator: true, context: context,
      isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _EditFarmSheet(
        settings: _s,
        locationCtrl: locationCtrl, cropCtrl: cropCtrl,
        sizeCtrl: sizeCtrl, irrigationCtrl: irrigationCtrl,
        saveLabel: t('save'), titleLabel: t('edit_farm'),
        onSave: (loc, crop, size, irr) {
          setState(() {
            if (loc.isNotEmpty) _farmLocation = loc;
            _cropType = crop; _farmSize = size; _irrigation = irr;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Farm details updated!'),
            backgroundColor: kGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        },
      ),
    );
  }

  // ── UI Helpers ─────────────────────────────────────────────────────────────
  Widget _sectionTitle(String title) => Text(title,
      style: TextStyle(color: _s.sectionTitleColor,
          fontSize: 15, fontWeight: FontWeight.bold));

  Widget _infoCard(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: divider),
          boxShadow: _s.isDarkGreen
              ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05),
                  blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Column(children: children),
      );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: kGreen, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: textGrey, fontSize: 11)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(color: textDark,
                fontSize: 14, fontWeight: FontWeight.w600)),
          ])),
        ]),
      );

  Widget _switchRow(IconData icon, String label, bool value,
      Function(bool) onChanged) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: kGreen, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label,
              style: TextStyle(color: textDark,
                  fontSize: 14, fontWeight: FontWeight.w600))),
          Switch(value: value, onChanged: onChanged, activeColor: kGreen),
        ]),
      );

  Widget _menuRow(IconData icon, String label, String value,
      VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: kGreen, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label,
                style: TextStyle(color: textDark,
                    fontSize: 14, fontWeight: FontWeight.w600))),
            if (value.isNotEmpty)
              Text(value, style: TextStyle(color: textGrey, fontSize: 12)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: textGrey, size: 20),
          ]),
        ),
      );

  Widget _dividerW() =>
      Divider(height: 1, indent: 64, endIndent: 16, color: divider);

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: btnBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: btnBorder),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: btnText, size: 18),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: btnText,
                fontSize: 14, fontWeight: FontWeight.bold)),
          ]),
        ),
      );
}

// ── Picker Sheet (Theme / Language / Temp) ────────────────────────────────────
enum _PickerType { theme, language, temp }

class _PickerSheet extends StatefulWidget {
  final AppSettings settings;
  final VoidCallback onChanged;
  final _PickerType type;
  const _PickerSheet(
      {required this.settings, required this.onChanged, required this.type});
  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  static const kGreen = Color(0xFF2ECC71);

  AppSettings get s => widget.settings;

  Color get sheetBg   => s.cardColor;
  Color get titleColor => s.textDark;
  Color get textGrey  => s.textGrey;
  Color get divider   => s.dividerColor;
  Color get iconBg    => s.isDarkGreen
      ? const Color(0xFF1B3D22) : const Color(0xFFE8F8EF);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: divider,
                borderRadius: BorderRadius.circular(10))),
        const SizedBox(height: 16),
        Text(_title, style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.bold, color: titleColor)),
        const SizedBox(height: 12),
        ..._buildItems(),
        const SizedBox(height: 20),
      ]),
    );
  }

  String get _title {
    switch (widget.type) {
      case _PickerType.theme:    return 'Theme';
      case _PickerType.language: return 'Language';
      case _PickerType.temp:     return 'Temperature Unit';
    }
  }

  List<Widget> _buildItems() {
    switch (widget.type) {
      case _PickerType.theme:
        return [
          _item(
            icon: Icons.dark_mode,
            iconColor: Colors.white,
            iconBgColor: const Color(0xFF0A2E1A),
            label: 'Dark Green',
            selected: s.isDarkGreen,
            onTap: () {
              s.setTheme(true);
              setState(() {});
              widget.onChanged();
              Navigator.pop(context);
            },
          ),
          _item(
            icon: Icons.light_mode,
            iconColor: kGreen,
            iconBgColor: const Color(0xFFE8F8EF),
            label: 'Light',
            selected: !s.isDarkGreen,
            onTap: () {
              s.setTheme(false);
              setState(() {});
              widget.onChanged();
              Navigator.pop(context);
            },
          ),
        ];
      case _PickerType.language:
        return AppSettings.languages.entries.map((e) {
          final sel = s.languageCode == e.key;
          return _item(
            icon: Icons.language,
            iconColor: sel ? kGreen : textGrey,
            iconBgColor: sel ? kGreen.withOpacity(0.15) : iconBg,
            label: e.value,
            selected: sel,
            onTap: () {
              s.setLanguage(e.key);
              setState(() {});
              widget.onChanged();
              Navigator.pop(context);
            },
          );
        }).toList();
      case _PickerType.temp:
        return AppSettings.tempUnits.entries.map((e) {
          final sel = s.tempUnit == e.key;
          return _item(
            icon: Icons.thermostat,
            iconColor: sel ? kGreen : textGrey,
            iconBgColor: sel ? kGreen.withOpacity(0.15) : iconBg,
            label: e.value,
            selected: sel,
            onTap: () {
              s.setTempUnit(e.key);
              setState(() {});
              widget.onChanged();
            },
          );
        }).toList();
    }
  }

  Widget _item({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      ListTile(
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
              color: iconBgColor, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        title: Text(label,
            style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? kGreen : titleColor)),
        trailing: selected
            ? const Icon(Icons.check_circle, color: kGreen) : null,
        onTap: onTap,
      );
}

// ── Edit Profile Sheet ────────────────────────────────────────────────────────
class _EditProfileSheet extends StatefulWidget {
  final AppSettings settings;
  final TextEditingController nameCtrl, emailCtrl, phoneCtrl;
  final String saveLabel, titleLabel;
  final Function(String name, String email, String phone) onSave;
  const _EditProfileSheet({
    required this.settings,
    required this.nameCtrl, required this.emailCtrl, required this.phoneCtrl,
    required this.saveLabel, required this.titleLabel, required this.onSave,
  });
  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  static const kGreen = Color(0xFF2ECC71);
  String? _phoneError;

  AppSettings get s => widget.settings;
  Color get bg      => s.cardColor;
  Color get textD   => s.textDark;
  Color get textG   => s.textGrey;
  Color get iconBg  => s.isDarkGreen
      ? const Color(0xFF1B3D22) : const Color(0xFFE8F8EF);
  Color get fillBg  => s.inputFillColor;

  void _validate() {
    final phone = widget.phoneCtrl.text.trim();
    if (phone.isEmpty) { setState(() => _phoneError = null); return; }
    if (!RegExp(r'^[0-9]+$').hasMatch(phone)) {
      setState(() => _phoneError = 'Phone must contain digits only');
    } else if (phone.length < 10) {
      setState(() => _phoneError = 'Enter a valid 10 digit number');
    } else {
      setState(() => _phoneError = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: s.dividerColor,
                borderRadius: BorderRadius.circular(10))),
        const SizedBox(height: 16),
        Text(widget.titleLabel,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                color: textD)),
        const SizedBox(height: 20),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _fieldLabel('Full Name'),
            _textField(widget.nameCtrl, 'Enter your name',
                Icons.person, TextInputType.name),
            const SizedBox(height: 14),
            _fieldLabel('Email'),
            _textField(widget.emailCtrl, 'Email',
                Icons.email, TextInputType.emailAddress),
            const SizedBox(height: 14),
            _fieldLabel('Phone'),
            TextField(
              controller: widget.phoneCtrl,
              keyboardType: TextInputType.number,
              maxLength: 15,
              onChanged: (_) => _validate(),
              style: TextStyle(color: s.inputTextColor),
              decoration: InputDecoration(
                hintText: 'Enter 10 digit number',
                hintStyle: TextStyle(color: textG),
                prefixIcon: const Icon(Icons.phone, color: kGreen, size: 20),
                filled: true,
                fillColor: _phoneError != null ? Colors.red.shade900.withOpacity(0.2) : fillBg,
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: _phoneError != null ? Colors.red : kGreen)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: _phoneError != null ? Colors.red.shade300 : Colors.transparent)),
              ),
            ),
            if (_phoneError != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 14),
                const SizedBox(width: 4),
                Text(_phoneError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ]),
            ],
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () {
                _validate();
                if (_phoneError != null) return;
                Navigator.pop(context);
                widget.onSave(widget.nameCtrl.text.trim(),
                    widget.emailCtrl.text.trim(),
                    widget.phoneCtrl.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(widget.saveLabel,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 15, fontWeight: FontWeight.bold)),
            )),
            const SizedBox(height: 10),
          ]),
        )),
      ]),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w600, color: textD)),
      );

  Widget _textField(TextEditingController ctrl, String hint, IconData icon,
      TextInputType type, {bool readOnly = false}) =>
      TextField(
        controller: ctrl,
        readOnly: readOnly,
        keyboardType: type,
        style: TextStyle(color: s.inputTextColor),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: textG),
          prefixIcon: Icon(icon, color: kGreen, size: 20),
          filled: true,
          fillColor: readOnly
              ? s.dividerColor.withOpacity(0.5) : fillBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kGreen)),
        ),
      );
}

// ── Edit Farm Sheet ───────────────────────────────────────────────────────────
class _EditFarmSheet extends StatelessWidget {
  final AppSettings settings;
  final TextEditingController locationCtrl, cropCtrl, sizeCtrl, irrigationCtrl;
  final String saveLabel, titleLabel;
  final Function(String loc, String crop, String size, String irr) onSave;

  const _EditFarmSheet({
    required this.settings,
    required this.locationCtrl, required this.cropCtrl,
    required this.sizeCtrl, required this.irrigationCtrl,
    required this.saveLabel, required this.titleLabel, required this.onSave,
  });

  static const kGreen = Color(0xFF2ECC71);

  @override
  Widget build(BuildContext context) {
    final s = settings;
    final textD  = s.textDark;
    final textG  = s.textGrey;
    final fillBg = s.inputFillColor;
    final divClr = s.dividerColor;

    Widget field(String label, String hint, IconData icon,
        TextEditingController ctrl,
        {TextInputType type = TextInputType.text}) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.w600, color: textD)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl, keyboardType: type,
            style: TextStyle(color: s.inputTextColor),
            decoration: InputDecoration(
              hintText: hint, hintStyle: TextStyle(color: textG),
              prefixIcon: Icon(icon, color: kGreen, size: 20),
              filled: true, fillColor: fillBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kGreen)),
            ),
          ),
        ]);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(color: s.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: divClr,
                borderRadius: BorderRadius.circular(10))),
        const SizedBox(height: 16),
        Text(titleLabel, style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.bold, color: textD)),
        const SizedBox(height: 20),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            field(s.t('location'), 'Rajkot, Gujarat',
                Icons.location_on, locationCtrl),
            const SizedBox(height: 14),
            field(s.t('crop_type'), 'e.g. Wheat, Cotton',
                Icons.crop, cropCtrl),
            const SizedBox(height: 14),
            field('${s.t('farm_size')} (acres)', 'e.g. 5',
                Icons.terrain, sizeCtrl, type: TextInputType.number),
            const SizedBox(height: 14),
            field(s.t('irrigation'), 'e.g. Drip',
                Icons.water_drop, irrigationCtrl),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onSave(locationCtrl.text.trim(), cropCtrl.text.trim(),
                    sizeCtrl.text.trim(), irrigationCtrl.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(saveLabel, style: const TextStyle(color: Colors.white,
                  fontSize: 15, fontWeight: FontWeight.bold)),
            )),
            const SizedBox(height: 10),
          ]),
        )),
      ]),
    );
  }
}
