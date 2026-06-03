import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/models.dart';
import '../../core/supabase_service.dart';
import '../../core/image_upload.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _name = TextEditingController();
  final _nationality = TextEditingController();
  bool _saving = false;
  bool _loading = true;
  UserProfile? _current;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _nationality.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await SupabaseService.instance.getMyProfile();
    if (mounted) {
      setState(() {
        _current = p;
        _name.text = p?.name ?? '';
        _nationality.text = p?.nationality ?? '';
        _photoUrl = p?.profileImage;
        _loading = false;
      });
    }
  }

  Future<void> _pickPhoto() async {
    final url = await ImageUploadHelper.pickAndUpload(context, bucket: 'avatars');
    if (url == null || !mounted) return;
    setState(() => _photoUrl = url);
    // Persist immediately so avatar updates everywhere
    await SupabaseService.instance.updateProfile(profileImage: url);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo updated!'), backgroundColor: AppColors.green),
      );
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await SupabaseService.instance.updateProfile(
        name: _name.text.trim(),
        nationality: _nationality.text.trim().isEmpty ? null : _nationality.text.trim(),
        profileImage: _photoUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!'), backgroundColor: AppColors.green));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red));
    }
  }

  Widget _avatarFallback() => Container(
        width: 90, height: 90,
        color: AppColors.navyCard,
        child: Icon(Icons.person_rounded, color: AppColors.grey, size: 48),
      );

  Future<void> _changePassword() async {
    final email = _current?.email;
    if (email == null) return;
    try {
      await SupabaseService.instance.resetPassword(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to $email'), backgroundColor: AppColors.green, duration: const Duration(seconds: 5)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(title: const Text('EDIT PROFILE')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.yellow))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: Stack(children: [
                      ClipOval(
                        child: _photoUrl != null
                            ? Image.network(_photoUrl!, width: 90, height: 90, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _avatarFallback())
                            : _avatarFallback(),
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(color: AppColors.yellow, shape: BoxShape.circle, border: Border.all(color: AppColors.navy, width: 2)),
                          child: Icon(Icons.camera_alt_rounded, color: AppColors.navy, size: 15),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 24),
                Text('NAME', style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 8),
                TextField(controller: _name, style: TextStyle(color: AppColors.white), decoration: InputDecoration(hintText: 'Your full name')),
                const SizedBox(height: 20),
                Text('EMAIL', style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
                  child: Row(children: [Icon(Icons.email_outlined, color: AppColors.grey, size: 18), SizedBox(width: 10), Text(_current?.email ?? 'â€”', style: TextStyle(color: AppColors.greyLight))]),
                ),
                const SizedBox(height: 20),
                Text('NATIONALITY', style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 8),
                TextField(controller: _nationality, style: TextStyle(color: AppColors.white), decoration: InputDecoration(hintText: 'e.g. French, American, Nigerian')),
                const SizedBox(height: 20),
                Text('SECURITY', style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _changePassword,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
                    child: Row(children: [
                      const Icon(Icons.lock_reset_rounded, color: AppColors.yellow, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Change password', style: TextStyle(color: AppColors.white, fontSize: 14))),
                      Icon(Icons.chevron_right_rounded, color: AppColors.grey, size: 18),
                    ]),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy))
                      : const Text('SAVE CHANGES'),
                )),
              ]),
            ),
    );
  }
}
