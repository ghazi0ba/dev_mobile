import 'dart:io';

import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  CloudinaryService._();
  static const _cloudName = 'your_cloud_name';
  static const _unsignedUploadPreset = 'your_unsigned_preset';
  static final _cloudinary = CloudinaryPublic(_cloudName, _unsignedUploadPreset);

  static final ImagePicker _picker = ImagePicker();

  /// Sélectionne une image depuis la galerie
  static Future<XFile?> pickImage() async {
    return await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
  }

  /// Prend une photo avec la caméra
  static Future<XFile?> takePhoto() async {
    return await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
  }

  /// Upload une image vers Cloudinary
  static Future<String?> uploadImage(XFile imageFile) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          resourceType: CloudinaryResourceType.Image,
          folder: 'cosmaplus/reviews',
        ),
      );
      return response.secureUrl;
    } catch (e) {
      return null;
    }
  }

  /// Upload une image depuis un fichier
  static Future<String?> uploadImageFromFile(File imageFile) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          resourceType: CloudinaryResourceType.Image,
          folder: 'cosmaplus/reviews',
        ),
      );
      return response.secureUrl;
    } catch (e) {
      return null;
    }
  }

  /// Supprime une image de Cloudinary (nécessite une clé API signée)
  static Future<void> deleteImage(String publicId) async {
    // TODO: Implémenter avec une clé API signée via Cloudinary Admin API
    // Le package cloudinary_public ne supporte pas la suppression non signée
  }
}