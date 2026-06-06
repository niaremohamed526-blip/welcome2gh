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

/// Lightweight i18n helper for English / French strings.
///
/// Screens read strings via [L10n.t] and rebuild when
/// [SettingsController.language] changes (wrap reactive widgets in a
/// `ValueListenableBuilder` on that notifier).
class L10n {
  static const _strings = {
    'en': {
      // Bottom navigation
      'nav_home': 'Home',
      'nav_map': 'Map',
      'nav_community': 'Community',
      'nav_saved': 'Saved',
      'nav_profile': 'Profile',
      // Settings
      'settings': 'Settings',
      'appearance': 'Appearance',
      'language': 'Language',
      'dark_mode': 'Dark Mode',
      'light_mode': 'Light Mode',
      'dark_mode_sub': 'Switch to light theme',
      'light_mode_sub': 'Switch to dark theme',
      'notifications': 'Notifications',
      'safety_alerts': 'Safety alerts',
      'community_activity': 'Community activity',
      'price_updates': 'Price updates',
      'safety': 'Safety',
      'share_location': 'Share my location with nearby travelers',
      'emergency_broadcast': 'Emergency broadcast alerts',
      'save_settings': 'Save Settings',
      'settings_saved': 'Settings saved',
      'choose_language': 'Choose language',
      'language_changed': 'Language updated',
      // Profile
      'edit_profile': 'Edit Profile',
      'add_place': 'Add a Place',
      'fair_prices': 'Fair Prices',
      'ask_ai': 'Ask the AI Guide',
      'admin': 'Admin',
      'admin_dashboard': 'Admin Dashboard',
      'account': 'Account',
      'help': 'Help & Support',
      'about': 'About Welcome2GH',
      'sign_out': 'Sign Out',
      'sign_out_q': 'Sign out?',
      'sign_out_body': 'You will need to sign in again to access your account.',
      'cancel': 'Cancel',
      'emergency_contacts': 'Emergency Contacts',
      'safety_settings': 'Safety Settings',
      'saved': 'Saved',
      'posts': 'Posts',
      'reviews': 'Reviews',
    },
    'fr': {
      // Bottom navigation
      'nav_home': 'Accueil',
      'nav_map': 'Carte',
      'nav_community': 'Communauté',
      'nav_saved': 'Enregistrés',
      'nav_profile': 'Profil',
      // Settings
      'settings': 'Paramètres',
      'appearance': 'Apparence',
      'language': 'Langue',
      'dark_mode': 'Mode sombre',
      'light_mode': 'Mode clair',
      'dark_mode_sub': 'Passer au thème clair',
      'light_mode_sub': 'Passer au thème sombre',
      'notifications': 'Notifications',
      'safety_alerts': 'Alertes de sécurité',
      'community_activity': 'Activité de la communauté',
      'price_updates': 'Mises à jour des prix',
      'safety': 'Sécurité',
      'share_location': 'Partager ma position avec les voyageurs à proximité',
      'emergency_broadcast': "Alertes d'urgence diffusées",
      'save_settings': 'Enregistrer',
      'settings_saved': 'Paramètres enregistrés',
      'choose_language': 'Choisir la langue',
      'language_changed': 'Langue mise à jour',
      // Profile
      'edit_profile': 'Modifier le profil',
      'add_place': 'Ajouter un lieu',
      'fair_prices': 'Prix justes',
      'ask_ai': "Demander au guide IA",
      'admin': 'Admin',
      'admin_dashboard': "Tableau de bord admin",
      'account': 'Compte',
      'help': 'Aide et support',
      'about': 'À propos de Welcome2GH',
      'sign_out': 'Se déconnecter',
      'sign_out_q': 'Se déconnecter ?',
      'sign_out_body': 'Vous devrez vous reconnecter pour accéder à votre compte.',
      'cancel': 'Annuler',
      'emergency_contacts': "Contacts d'urgence",
      'safety_settings': 'Paramètres de sécurité',
      'saved': 'Enregistrés',
      'posts': 'Publications',
      'reviews': 'Avis',
    },
  };

  static String t(String key) {
    final lang = SettingsController.instance.language.value;
    return _strings[lang]?[key] ?? _strings['en']![key] ?? key;
  }
}
