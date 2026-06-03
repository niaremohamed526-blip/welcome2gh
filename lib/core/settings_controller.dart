import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController {
  SettingsController._();
  static final instance = SettingsController._();

  static const _kLang            = 'app_lang';
  static const _kNotifSafety     = 'notif_safety';
  static const _kNotifCommunity  = 'notif_community';
  static const _kNotifPrices     = 'notif_prices';
  static const _kShareLocation   = 'share_location';
  static const _kEmergencyAlerts = 'emergency_alerts';
  static const _kThemeDark       = 'theme_dark';

  final language  = ValueNotifier<String>('en');
  final themeMode = ValueNotifier<ThemeMode>(ThemeMode.dark);

  // Notification + safety preferences (persisted locally).
  bool notifSafety = true;
  bool notifCommunity = true;
  bool notifPrices = true;
  bool shareLocation = false;
  bool emergencyAlerts = true;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    language.value = p.getString(_kLang) ?? 'en';
    notifSafety    = p.getBool(_kNotifSafety) ?? true;
    notifCommunity = p.getBool(_kNotifCommunity) ?? true;
    notifPrices    = p.getBool(_kNotifPrices) ?? true;
    shareLocation  = p.getBool(_kShareLocation) ?? false;
    emergencyAlerts = p.getBool(_kEmergencyAlerts) ?? true;
    final dark = p.getBool(_kThemeDark) ?? true;
    themeMode.value = dark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> setThemeDark(bool dark) async {
    themeMode.value = dark ? ThemeMode.dark : ThemeMode.light;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kThemeDark, dark);
  }

  Future<void> setLanguage(String lang) async {
    language.value = lang;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLang, lang);
  }

  Future<void> saveToggles() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kNotifSafety, notifSafety);
    await p.setBool(_kNotifCommunity, notifCommunity);
    await p.setBool(_kNotifPrices, notifPrices);
    await p.setBool(_kShareLocation, shareLocation);
    await p.setBool(_kEmergencyAlerts, emergencyAlerts);
  }
}

/// Tiny i18n helper for English / French strings shown across the app.
class L10n {
  static const _strings = {
    'en': {
      'language': 'Language',
      'notifications': 'Notifications',
      'safety': 'Safety',
      'about': 'About',
      'help': 'Help & Support',
      'sign_out': 'Sign Out',
      'edit_profile': 'Edit Profile',
      'saved': 'Saved',
      'language_changed': 'Language updated',
    },
    'fr': {
      'language': 'Langue',
      'notifications': 'Notifications',
      'safety': 'Sécurité',
      'about': 'À propos',
      'help': 'Aide et support',
      'sign_out': 'Se déconnecter',
      'edit_profile': 'Modifier le profil',
      'saved': 'Enregistré',
      'language_changed': 'Langue mise à jour',
    },
  };

  static String t(String key) {
    final lang = SettingsController.instance.language.value;
    return _strings[lang]?[key] ?? _strings['en']![key] ?? key;
  }
}
