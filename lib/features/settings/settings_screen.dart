import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/settings_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _lang;
  late bool _notifSafety;
  late bool _notifCommunity;
  late bool _notifPrices;
  late bool _shareLocation;
  late bool _emergencyAlerts;

  @override
  void initState() {
    super.initState();
    final s = SettingsController.instance;
    _lang = s.language.value;
    _notifSafety = s.notifSafety;
    _notifCommunity = s.notifCommunity;
    _notifPrices = s.notifPrices;
    _shareLocation = s.shareLocation;
    _emergencyAlerts = s.emergencyAlerts;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = SettingsController.instance.themeMode.value == ThemeMode.dark;
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(title: Text(L10n.t('settings').toUpperCase())),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(L10n.t('appearance').toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 12),
          _Group(children: [
            _OptionTile(
              label: L10n.t('language'),
              value: _lang == 'fr' ? 'Français' : 'English',
              onTap: _pickLanguage,
              icon: Icons.language_rounded,
            ),
            Divider(height: 1, color: AppColors.cardBorder),
            // Dark / Light mode toggle
            ListTile(
              leading: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: AppColors.yellow, size: 20),
              title: Text(isDark ? L10n.t('dark_mode') : L10n.t('light_mode'), style: TextStyle(color: AppColors.white, fontSize: 14)),
              subtitle: Text(isDark ? L10n.t('dark_mode_sub') : L10n.t('light_mode_sub'), style: TextStyle(color: AppColors.grey, fontSize: 12)),
              trailing: Switch(
                value: isDark,
                thumbColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected) ? AppColors.yellow : null,
                ),
                trackColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected) ? AppColors.yellow.withValues(alpha: 0.4) : null,
                ),
                onChanged: (v) async {
                  await SettingsController.instance.setThemeDark(v);
                  if (mounted) setState(() {});
                },
              ),
            ),
          ]),
          const SizedBox(height: 24),

          Text(L10n.t('notifications').toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 12),
          _Group(children: [
            _SwitchTile(label: L10n.t('safety_alerts'), value: _notifSafety, onChanged: (v) => setState(() => _notifSafety = v)),
            _SwitchTile(label: L10n.t('community_activity'), value: _notifCommunity, onChanged: (v) => setState(() => _notifCommunity = v)),
            _SwitchTile(label: L10n.t('price_updates'), value: _notifPrices, onChanged: (v) => setState(() => _notifPrices = v)),
          ]),
          const SizedBox(height: 24),

          Text(L10n.t('safety').toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 12),
          _Group(children: [
            _SwitchTile(label: L10n.t('share_location'), value: _shareLocation, onChanged: (v) => setState(() => _shareLocation = v)),
            _SwitchTile(label: L10n.t('emergency_broadcast'), value: _emergencyAlerts, onChanged: (v) => setState(() => _emergencyAlerts = v)),
          ]),
          const SizedBox(height: 30),

          ElevatedButton(
            onPressed: () async {
              final s = SettingsController.instance;
              s.notifSafety = _notifSafety;
              s.notifCommunity = _notifCommunity;
              s.notifPrices = _notifPrices;
              s.shareLocation = _shareLocation;
              s.emergencyAlerts = _emergencyAlerts;
              await s.saveToggles();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(L10n.t('settings_saved')), backgroundColor: AppColors.green),
              );
              Navigator.pop(context);
            },
            child: Text(L10n.t('save_settings').toUpperCase()),
          ),
        ],
      ),
    );
  }

  void _pickLanguage() {
    final options = [
      {'code': 'en', 'label': 'English'},
      {'code': 'fr', 'label': 'Français'},
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navyCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 16),
          Text(L10n.t('choose_language').toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          for (final opt in options)
            ListTile(
              leading: Icon(
                opt['code'] == _lang ? Icons.radio_button_checked : Icons.radio_button_off,
                color: opt['code'] == _lang ? AppColors.yellow : AppColors.grey,
              ),
              title: Text(opt['label']!, style: TextStyle(color: AppColors.white)),
              onTap: () async {
                await SettingsController.instance.setLanguage(opt['code']!);
                if (mounted) {
                  setState(() => _lang = opt['code']!);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(L10n.t('language_changed')), backgroundColor: AppColors.green),
                  );
                }
              },
            ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
      child: Column(children: children),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final VoidCallback onTap;
  const _OptionTile({required this.label, required this.value, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.grey, size: 20),
      title: Text(label, style: TextStyle(color: AppColors.white, fontSize: 14)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: const TextStyle(color: AppColors.yellow, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        Icon(Icons.chevron_right_rounded, color: AppColors.grey, size: 18),
      ]),
      onTap: onTap,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({required this.label, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? AppColors.yellow : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? AppColors.yellow.withValues(alpha: 0.4) : null,
      ),
      title: Text(label, style: TextStyle(color: AppColors.white, fontSize: 13)),
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}
