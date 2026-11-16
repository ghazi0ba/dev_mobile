import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Cloudinary configuration for image upload
class CloudinaryConfig {

  static const String cloudName = 'x8z7s871';

  // Preset non signé de l'équipe
  static const String uploadPreset = 'project_mobile_esprit';

  // Cloudinary upload API URL
  static String get uploadUrl =>
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
}

/// Service for uploading images to Cloudinary
class CloudinaryService {
  /// Upload an image file to Cloudinary and return the secure URL
  Future<String> uploadImage(File file) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(CloudinaryConfig.uploadUrl),
      );

      // Add upload preset
      request.fields['upload_preset'] = CloudinaryConfig.uploadPreset;

      // Add image file
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final secureUrl = data['secure_url'] as String?;

        if (secureUrl != null) {
          return secureUrl;
        } else {
          throw Exception('URL sécurisée non trouvée dans la réponse');
        }
      } else {
        throw Exception(
          'Échec du téléchargement: ${response.statusCode} ${response.reasonPhrase}',
        );
      }
    } on SocketException {
      throw Exception(
        'Erreur réseau. Vérifiez votre connexion Internet.',
      );
    } on http.ClientException {
      throw Exception(
        'Erreur de connexion au service de téléchargement.',
      );
    } catch (e) {
      throw Exception(
        'Impossible de télécharger l\'image: ${e.toString()}',
      );
    }
  }
}
