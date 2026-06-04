// Basic smoke test for the app shell.
//
// The app's router wires up Supabase auth state, so the Supabase client must
// be initialized (with throwaway credentials) before the widget tree is built
// — this mirrors what main() does before runApp().

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:welcome2gh/main.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const Welcome2GhApp());
    expect(find.byType(Welcome2GhApp), findsOneWidget);
    // Let the splash screen's navigation timer fire so no timers are left
    // pending when the tree is torn down.
    await tester.pump(const Duration(seconds: 4));
  });
}
