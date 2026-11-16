import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';

import 'package:dev_mobile/core/services/cloudinary_service.dart';

/// Erreur du module avec un message déjà prêt à afficher.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Traduit un code d'erreur Firebase (Auth ou Firestore) en message français.
String messageForErrorCode(String code) => switch (code) {
  'invalid-email' => 'Adresse email invalide.',
  'user-disabled' => 'Ce compte a été désactivé.',
  'user-not-found' ||
  'wrong-password' ||
  'invalid-credential' ||
  'INVALID_LOGIN_CREDENTIALS' => 'Email ou mot de passe incorrect.',
  'email-already-in-use' => 'Un compte existe déjà avec cet email.',
  'weak-password' => 'Mot de passe trop faible (8 caractères, majuscule, minuscule, chiffre et caractère spécial).',
  'too-many-requests' => 'Trop de tentatives. Réessayez dans quelques minutes.',
  'network-request-failed' ||
  'unavailable' => 'Pas de connexion internet. Vérifiez votre réseau.',
  'requires-recent-login' => 'Par sécurité, reconnectez-vous puis réessayez.',
  'operation-not-allowed' =>
    "Ce mode de connexion n'est pas activé dans Firebase.",
  'permission-denied' => "Vous n'avez pas les droits pour cette action.",
  'not-found' => 'Utilisateur introuvable.',
  _ => 'Une erreur est survenue ($code).',
};

/// Message à afficher pour n'importe quelle erreur levée par les services.
String errorMessage(Object error) {
  if (error is AuthFailure) return error.message;
  if (error is CloudinaryException) return error.message;
  // Caméra / galerie refusée (image_picker).
  if (error is PlatformException && error.code.contains('access_denied')) {
    return "Accès refusé. Autorisez l'appareil photo ou les photos dans "
        'les réglages du téléphone.';
  }
  if (error is FirebaseException) return messageForErrorCode(error.code);
  return 'Une erreur est survenue. Réessayez.';
}
