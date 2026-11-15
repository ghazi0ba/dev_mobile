import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Configuration Cloudinary (Console Cloudinary > Settings > Upload > Upload presets).
///
/// Le preset doit être en mode **Unsigned** : l'app envoie les images sans
/// clé secrète. Ces deux valeurs ne sont pas secrètes, mais ne mettez JAMAIS
/// l'API Secret dans l'application.
class CloudinaryConfig {
  CloudinaryConfig._();

  // TODO(équipe) : remplacer par les valeurs du compte Cloudinary du projet.
  static const cloudName = 'VOTRE_CLOUD_NAME';
  static const uploadPreset = 'VOTRE_UPLOAD_PRESET';

  static bool get isConfigured =>
      !cloudName.startsWith('VOTRE_') && !uploadPreset.startsWith('VOTRE_');
}

class CloudinaryException implements Exception {
  const CloudinaryException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Résultat d'un envoi : URL publique + identifiant Cloudinary.
class CloudinaryImage {
  const CloudinaryImage({required this.url, required this.publicId});
  final String url;
  final String publicId;
}

/// Envoi d'images vers Cloudinary (utilisable par tous les modules :
/// photos de profil, images produits…).
class CloudinaryService {
  CloudinaryService._();
  static final instance = CloudinaryService._();

  /// Envoie une image et retourne son URL `https://res.cloudinary.com/...`.
  /// [folder] range l'image dans Cloudinary (ex. "cosmaplus/users").
  Future<CloudinaryImage> uploadImage(
    Uint8List bytes, {
    required String folder,
    String filename = 'image.jpg',
  }) async {
    if (!CloudinaryConfig.isConfigured) {
      throw const CloudinaryException(
        "Cloudinary n'est pas configuré (voir CloudinaryConfig).",
      );
    }
    final uri = Uri.https(
      'api.cloudinary.com',
      '/v1_1/${CloudinaryConfig.cloudName}/image/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..fields['folder'] = folder
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await request.send().timeout(const Duration(seconds: 60)),
      );
    } catch (_) {
      throw const CloudinaryException(
        "Impossible d'envoyer l'image. Vérifiez votre connexion.",
      );
    }

    final body = _decode(response.body);
    if (response.statusCode != 200) {
      final error = body['error'];
      final detail = error is Map ? error['message'] : null;
      throw CloudinaryException(
        "Échec de l'envoi de l'image${detail == null ? '' : ' : $detail'}.",
      );
    }
    return CloudinaryImage(
      url: body['secure_url'] as String,
      publicId: body['public_id'] as String,
    );
  }

  static Map<String, dynamic> _decode(String body) {
    try {
      final data = jsonDecode(body);
      return data is Map<String, dynamic> ? data : const {};
    } catch (_) {
      return const {};
    }
  }
}

/// URL redimensionnée par Cloudinary (carré, centré sur le visage, format
/// et qualité automatiques). Les autres URL sont retournées telles quelles.
///
/// ```dart
/// NetworkImage(cloudinaryThumbnail(user.photoUrl!, size: 200))
/// ```
String cloudinaryThumbnail(String url, {int size = 200}) {
  const marker = '/image/upload/';
  if (!url.contains('res.cloudinary.com') || !url.contains(marker)) return url;
  return url.replaceFirst(
    marker,
    '${marker}c_fill,g_face,w_$size,h_$size,q_auto,f_auto/',
  );
}
