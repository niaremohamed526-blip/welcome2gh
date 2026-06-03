import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/supabase_service.dart';
import '../../core/supabase_config.dart';
import '../../shared/widgets/app_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _adminSecret = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;
  String _role = 'tourist';

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _adminSecret.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    final name = _name.text.trim();

    if (email.isEmpty || password.length < 6) {
      setState(() => _error = 'Enter a valid email and password (min 6 chars).');
      return;
    }
    if (!_isLogin && name.isEmpty) {
      setState(() => _error = 'Please enter your name.');
      return;
    }
    if (!_isLogin && _role == 'admin' && _adminSecret.text.trim() != SupabaseConfig.adminSecret) {
      setState(() => _error = 'Invalid admin code.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isLogin) {
        await SupabaseService.instance.signIn(email: email, password: password);
      } else {
        await SupabaseService.instance.signUp(email: email, password: password, name: name, role: _role);
      }
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      setState(() => _error = _humanizeError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _humanizeError(String raw) {
    final msg = raw.replaceAll('AuthException: ', '').replaceAll('Exception: ', '');
    final lower = msg.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'Wrong email or password. Tap "Forgot password" to reset, or check your email is confirmed in Supabase.';
    }
    if (lower.contains('email not confirmed') || lower.contains('not confirmed')) {
      return 'Your email isn\'t confirmed yet. Check your inbox, or disable email confirmation in Supabase → Auth → Providers.';
    }
    if (lower.contains('already registered') || lower.contains('already exists')) {
      return 'This email is already signed up. Try signing in instead.';
    }
    if (lower.contains('password') && lower.contains('weak')) {
      return 'Password too weak. Use at least 6 characters.';
    }
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return 'Too many attempts. Wait a minute and try again.';
    }
    if (lower.contains('network') || lower.contains('socket') || lower.contains('failed host')) {
      return 'No internet connection. Check your network and try again.';
    }
    return msg;
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _googleLoading = true; _error = null; });
    try {
      await SupabaseService.instance.signInWithGoogle();
      // On web the browser redirects; on mobile the auth state stream handles navigation.
    } catch (e) {
      if (mounted) setState(() => _error = 'Google sign-in failed. Make sure Google OAuth is enabled in your Supabase dashboard.');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email above first, then tap "Forgot password" again.');
      return;
    }
    try {
      await SupabaseService.instance.resetPassword(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent to $email. Check your inbox.'),
          backgroundColor: AppColors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _humanizeError(e.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface == AppColors.navyCard ? AppColors.navy : cs.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Row(
                children: [
                  _GhanaFlagSmall(),
                  const SizedBox(width: 12),
                  Text('WELCOME2GH', style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: 1)),
                ],
              ),
              const SizedBox(height: 40),
              Text(_isLogin ? 'SIGN IN.' : 'JOIN US.', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(
                _isLogin ? 'Welcome back to Accra.' : 'Start exploring Ghana today.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 28),
              if (!_isLogin) ...[
                Text('ACCOUNT TYPE', style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 10),
                Row(children: [
                  _RoleChip(label: 'Tourist', icon: Icons.flight_takeoff, active: _role == 'tourist', onTap: () => setState(() => _role = 'tourist')),
                  _RoleChip(label: 'Student', icon: Icons.school, active: _role == 'student', onTap: () => setState(() => _role = 'student')),
                  _RoleChip(label: 'Local', icon: Icons.location_city, active: _role == 'local', onTap: () => setState(() => _role = 'local')),
                  _RoleChip(label: 'Admin', icon: Icons.shield, active: _role == 'admin', onTap: () => setState(() => _role = 'admin'), accent: AppColors.red),
                ]),
                const SizedBox(height: 18),
                if (_role == 'admin') ...[
                  TextField(
                    controller: _adminSecret,
                    obscureText: true,
                    style: TextStyle(color: AppColors.white),
                    decoration: InputDecoration(
                      hintText: 'Admin code',
                      prefixIcon: Icon(Icons.vpn_key_outlined, color: AppColors.red, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: _name,
                  style: TextStyle(color: AppColors.white),
                  decoration: InputDecoration(
                    hintText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline, color: AppColors.grey, size: 20),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  hintText: 'Email address',
                  prefixIcon: Icon(Icons.email_outlined, color: AppColors.grey, size: 20),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _password,
                obscureText: _obscure,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline, color: AppColors.grey, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: AppColors.grey, size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loading ? null : _forgotPassword,
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
                    child: const Text('Forgot password?', style: TextStyle(color: AppColors.yellow, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy))
                      : Text(_isLogin ? 'SIGN IN' : 'CREATE ACCOUNT'),
                ),
              ),
              const SizedBox(height: 16),
              // Divider
              Row(children: [
                Expanded(child: Divider(color: AppColors.cardBorder)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('OR', style: TextStyle(color: AppColors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                Expanded(child: Divider(color: AppColors.cardBorder)),
              ]),
              const SizedBox(height: 16),
              // Google Sign In button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: _googleLoading ? null : _signInWithGoogle,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.cardBorder, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    backgroundColor: AppColors.navyCard,
                  ),
                  child: _googleLoading
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.yellow))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Google G icon drawn with text (no package needed)
                            Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                              child: const Center(
                                child: Text('G', style: TextStyle(color: Color(0xFF4285F4), fontSize: 14, fontWeight: FontWeight.w700)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Continue with Google',
                              style: TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _isLogin = !_isLogin;
                    _error = null;
                  }),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(color: AppColors.grey, fontSize: 14),
                      children: [
                        TextSpan(text: _isLogin ? "Don't have an account? " : 'Already have an account? '),
                        TextSpan(
                          text: _isLogin ? 'Sign up' : 'Sign in',
                          style: const TextStyle(color: AppColors.yellow, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final Color accent;
  const _RoleChip({required this.label, required this.icon, required this.active, required this.onTap, this.accent = AppColors.yellow});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? accent : AppColors.navyCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? accent : AppColors.cardBorder),
          ),
          child: Column(
            children: [
              Icon(icon, color: active ? AppColors.navy : AppColors.grey, size: 18),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: active ? AppColors.navy : AppColors.grey, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhanaFlagSmall extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const AppLogoChip(size: 34);
  }
}
