import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:dev_mobile/shared/models/models.dart';

/// Retourne null pour une chaîne vide (champ optionnel non renseigné).
String? cleanOptional(String? value) {
  final v = value?.trim();
  return (v == null || v.isEmpty) ? null : v;
}

/// Accès à la collection Firestore `users`.
class UserService {
  UserService._();
  static final instance = UserService._();

  CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  AppUser? _fromSnapshot(DocumentSnapshot<Map<String, dynamic>> s) {
    final data = s.data();
    return data == null ? null : AppUser.fromMap(s.id, data);
  }

  /// Suit un utilisateur en temps réel (null si le document n'existe pas).
  Stream<AppUser?> watchUser(String uid) =>
      _users.doc(uid).snapshots().map(_fromSnapshot);

  Future<AppUser?> getUser(String uid) async =>
      _fromSnapshot(await _users.doc(uid).get());

  /// Tous les utilisateurs (réservé aux admins par les règles Firestore).
  Stream<List<AppUser>> watchAllUsers() => _users.snapshots().map(
    (q) => q.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList(),
  );

  Future<void> createProfile(AppUser user) => _users.doc(user.id).set({
    ...user.toMap(),
    'createdAt': FieldValue.serverTimestamp(),
  });

  Future<void> updateInfo(
    String uid, {
    required String firstName,
    required String lastName,
    String? phone,
    String? address,
  }) => _users.doc(uid).update({
    'firstName': firstName.trim(),
    'lastName': lastName.trim(),
    'fullName': '${firstName.trim()} ${lastName.trim()}'.trim(),
    'phone': cleanOptional(phone),
    'address': cleanOptional(address),
  });

  Future<void> setPhoto(String uid, {required String url, String? publicId}) =>
      _users.doc(uid).update({'photoUrl': url, 'photoPublicId': publicId});

  /// Retire la photo : l'app affiche de nouveau les initiales.
  Future<void> removePhoto(String uid) =>
      _users.doc(uid).update({'photoUrl': null, 'photoPublicId': null});

  Future<void> updateEmail(String uid, String email) =>
      _users.doc(uid).update({'email': email});

  Future<void> setRole(String uid, UserRole role) =>
      _users.doc(uid).update({'role': role.name});

  Future<void> setDisabled(String uid, bool disabled) =>
      _users.doc(uid).update({'disabled': disabled});

  Future<void> deleteProfile(String uid) => _users.doc(uid).delete();
}
