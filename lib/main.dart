import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'shared/theme/app_theme.dart';
import 'core/router.dart';
import 'core/supabase_config.dart';
import 'core/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await SettingsController.instance.load();
  AppColors.setDark(SettingsController.instance.themeMode.value == ThemeMode.dark);

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const Welcome2GhApp());
}

class Welcome2GhApp extends StatelessWidget {
  const Welcome2GhApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: SettingsController.instance.themeMode,
      builder: (_, mode, __) {
        AppColors.setDark(mode == ThemeMode.dark);
        _applySystemUi(mode == ThemeMode.dark);
        return ValueListenableBuilder<String>(
          valueListenable: SettingsController.instance.language,
          builder: (_, __, ___) {
            return MaterialApp.router(
              title: 'Welcome2GH',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: mode,
              routerConfig: router,
            );
          },
        );
      },
    );
  }

  void _applySystemUi(bool dark) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: dark ? const Color(0xFF0D1B2A) : const Color(0xFFF0F4F8),
      systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    ));
  }
}
