import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:dev_mobile/core/services/cloudinary_service.dart';
import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/shared/models/models.dart';

import '../services/auth_errors.dart';
import '../services/user_service.dart';
import 'form_helpers.dart';
import 'user_avatar.dart';

/// Avatar cliquable : prendre une photo, choisir dans la galerie ou
/// supprimer la photo. L'image est envoyée sur Cloudinary, puis son URL
/// est enregistrée dans `users/{uid}`. Sans photo : initiales.
class EditableAvatar extends StatefulWidget {
  const EditableAvatar({super.key, required this.user, this.radius = 40});

  final AppUser user;
  final double radius;

  @override
  State<EditableAvatar> createState() => _EditableAvatarState();
}

class _EditableAvatarState extends State<EditableAvatar> {
  bool _busy = false;

  Future<void> _showOptions() async {
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Photo de profil',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, _PhotoAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(context, _PhotoAction.gallery),
            ),
            if (widget.user.hasPhoto)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Supprimer la photo',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () => Navigator.pop(context, _PhotoAction.remove),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    switch (action) {
      case _PhotoAction.camera:
        await _pickAndUpload(ImageSource.camera);
      case _PhotoAction.gallery:
        await _pickAndUpload(ImageSource.gallery);
      case _PhotoAction.remove:
        await _remove();
      case null:
        break;
    }
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      // Image réduite avant l'envoi : plus rapide et moins de données.
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );
      if (file == null) return; // annulé
      setState(() => _busy = true);
      final image = await CloudinaryService.instance.uploadImage(
        await file.readAsBytes(),
        folder: 'cosmaplus/users',
        filename: file.name,
      );
      await UserService.instance.setPhoto(
        widget.user.id,
        url: image.url,
        publicId: image.publicId,
      );
      if (mounted) showMessage(context, 'Photo de profil mise à jour');
    } catch (e) {
      if (mounted) showMessage(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer la photo ?',
      message: 'Les initiales seront affichées à la place.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await UserService.instance.removePhoto(widget.user.id);
      if (mounted) showMessage(context, 'Photo supprimée');
    } catch (e) {
      if (mounted) showMessage(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.radius;
    return Semantics(
      button: true,
      label: 'Modifier la photo de profil',
      child: GestureDetector(
        onTap: _busy ? null : _showOptions,
        child: SizedBox(
          width: r * 2,
          height: r * 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              UserAvatar(user: widget.user, radius: r),
              if (_busy)
                Positioned.fill(
                  child: CircleAvatar(
                    backgroundColor: AppColors.textPrimary.withValues(
                      alpha: 0.45,
                    ),
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                  child: Icon(
                    Icons.photo_camera,
                    size: r * 0.32,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _PhotoAction { camera, gallery, remove }
