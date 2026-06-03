import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'supabase_service.dart';
import '../shared/theme/app_theme.dart';

/// Reusable image upload helper.
/// Shows a camera/gallery sheet, uploads to Supabase Storage, returns the URL.
class ImageUploadHelper {
  static final _picker = ImagePicker();

  /// Opens a source picker, then uploads. Returns the public URL or null if cancelled.
  static Future<String?> pickAndUpload(
    BuildContext context, {
    required String bucket,
    String? folder,
  }) async {
    final source = await _chooseSource(context);
    if (source == null) return null;

    final XFile? file = await _picker.pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 80,
    );
    if (file == null) return null;

    if (!context.mounted) return null;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _UploadingDialog(),
    );

    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
      final url = await SupabaseService.instance.uploadImageBytes(
        bucket: bucket,
        bytes: bytes,
        extension: ext,
        folder: folder,
      );
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      return url;
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.red),
        );
      }
      return null;
    }
  }

  static Future<ImageSource?> _chooseSource(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.navyCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 16),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded, color: AppColors.yellow),
            title: Text('Take a photo', style: TextStyle(color: AppColors.white)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: AppColors.yellow),
            title: Text('Choose from gallery', style: TextStyle(color: AppColors.white)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }
}

class _UploadingDialog extends StatelessWidget {
  const _UploadingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.navyCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.yellow)),
          const SizedBox(width: 18),
          Text('Uploading photo…', style: TextStyle(color: AppColors.white, fontSize: 14)),
        ]),
      ),
    );
  }
}
