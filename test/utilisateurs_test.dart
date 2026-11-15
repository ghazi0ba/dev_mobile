import 'package:flutter_test/flutter_test.dart';

import 'package:dev_mobile/core/services/cloudinary_service.dart';
import 'package:dev_mobile/features/utilisateurs/services/auth_errors.dart';
import 'package:dev_mobile/features/utilisateurs/services/user_filter.dart';
import 'package:dev_mobile/features/utilisateurs/widgets/form_helpers.dart';
import 'package:dev_mobile/features/utilisateurs/widgets/user_avatar.dart';
import 'package:dev_mobile/shared/models/models.dart';

AppUser _user(
  String id,
  String firstName,
  String lastName, {
  String? email,
  UserRole role = UserRole.client,
  bool disabled = false,
  String? phone,
  String? address,
  String? photoUrl,
  DateTime? createdAt,
}) => AppUser(
  id: id,
  email: email ?? '$id@test.com',
  firstName: firstName,
  lastName: lastName,
  role: role,
  disabled: disabled,
  phone: phone,
  address: address,
  photoUrl: photoUrl,
  createdAt: createdAt,
);

void main() {
  group('AppUser', () {
    test('lit prénom, nom, photo et disabled', () {
      final u = AppUser.fromMap('u', {
        'firstName': 'Nadia',
        'lastName': 'Benali',
        'photoUrl': 'https://res.cloudinary.com/x/image/upload/a.jpg',
        'role': 'admin',
      });
      expect(u.fullName, 'Nadia Benali');
      expect(u.hasPhoto, isTrue);
      expect(u.isAdmin, isTrue);
      expect(u.disabled, isFalse);
      expect(AppUser.fromMap('u', {'disabled': true}).disabled, isTrue);
    });

    test('ancien document avec seulement fullName', () {
      final u = AppUser.fromMap('u', {'fullName': 'Marie Claire Dupont'});
      expect(u.firstName, 'Marie');
      expect(u.lastName, 'Claire Dupont');
    });

    test('toMap écrit aussi fullName', () {
      final map = _user('1', 'Nadia', 'Benali').toMap();
      expect(map['firstName'], 'Nadia');
      expect(map['lastName'], 'Benali');
      expect(map['fullName'], 'Nadia Benali');
    });

    test('copyWith garde les autres champs', () {
      final u = _user('1', 'Nadia', 'Benali', phone: '0600');
      final c = u.copyWith(disabled: true, role: UserRole.admin);
      expect(c.disabled, isTrue);
      expect(c.isAdmin, isTrue);
      expect(c.phone, '0600');
      expect(c.lastName, 'Benali');
    });
  });

  test('initialsOf', () {
    expect(initialsOf('Nadia', 'Benali'), 'NB');
    expect(initialsOf(' élise ', 'de la Tour'), 'ÉD');
    expect(initialsOf('Nadia', ''), 'N');
    expect(initialsOf('', '', fallback: 'zoe@x.fr'), 'Z');
    expect(initialsOf('', ''), '?');
  });

  test('cloudinaryThumbnail', () {
    expect(
      cloudinaryThumbnail(
        'https://res.cloudinary.com/demo/image/upload/v1/cosmaplus/users/a.jpg',
        size: 120,
      ),
      'https://res.cloudinary.com/demo/image/upload/'
      'c_fill,g_face,w_120,h_120,q_auto,f_auto/v1/cosmaplus/users/a.jpg',
    );
    expect(
      cloudinaryThumbnail('https://exemple.com/a.jpg'),
      'https://exemple.com/a.jpg',
    );
  });

  group('Validators', () {
    test('email', () {
      expect(Validators.email('a@b.co'), isNull);
      expect(Validators.email('pas-un-email'), isNotNull);
      expect(Validators.email(''), isNotNull);
    });
    test('prénom / nom requis', () {
      expect(Validators.firstName(' '), isNotNull);
      expect(Validators.lastName('Benali'), isNull);
    });
    test('téléphone optionnel', () {
      expect(Validators.phone(''), isNull);
      expect(Validators.phone('+216 20 123 456'), isNull);
      expect(Validators.phone('abc'), isNotNull);
    });
  });

  test("messages d'erreur en français", () {
    expect(
      messageForErrorCode('invalid-credential'),
      'Email ou mot de passe incorrect.',
    );
    expect(
      messageForErrorCode('email-already-in-use'),
      contains('existe déjà'),
    );
    expect(errorMessage(const AuthFailure('X')), 'X');
    expect(errorMessage(const CloudinaryException('Y')), 'Y');
  });

  group('UserFilter', () {
    final users = [
      _user(
        '1',
        'Nadia',
        'Benali',
        phone: '06 12 34 56 78',
        address: 'Tunis',
        photoUrl: 'https://res.cloudinary.com/x/image/upload/a.jpg',
        createdAt: DateTime(2026, 1, 10),
      ),
      _user(
        '2',
        'Éric',
        'Martin',
        role: UserRole.admin,
        createdAt: DateTime(2026, 3, 5),
      ),
      _user(
        '3',
        'Amine',
        'Trabelsi',
        disabled: true,
        address: 'Sfax',
        createdAt: DateTime(2026, 6, 1),
      ),
      _user('4', 'Zoé', '', email: 'zoe@boutique.fr'),
    ];

    List<String> ids(UserFilter f) => f.apply(users).map((u) => u.id).toList();

    test('sans filtre : tous, triés par nom puis prénom', () {
      expect(ids(const UserFilter()), ['1', '2', '3', '4']);
      expect(const UserFilter().isActive, isFalse);
    });

    test('recherche sans accents, multi-mots, multi-champs', () {
      expect(ids(const UserFilter(query: 'eric')), ['2']);
      expect(ids(const UserFilter(query: 'martin eric')), ['2']);
      expect(ids(const UserFilter(query: 'nadia tunis')), ['1']);
      expect(ids(const UserFilter(query: 'boutique')), ['4']);
      expect(ids(const UserFilter(query: '0612')), ['1']);
      expect(ids(const UserFilter(query: 'nadia sfax')), isEmpty);
    });

    test('rôle et statut', () {
      expect(ids(const UserFilter(role: RoleFilter.admin)), ['2']);
      expect(ids(const UserFilter(status: StatusFilter.disabled)), ['3']);
      expect(
        ids(
          const UserFilter(
            role: RoleFilter.client,
            status: StatusFilter.active,
          ),
        ),
        ['1', '4'],
      );
    });

    test('profil : complet, adresse, photo', () {
      expect(ids(const UserFilter(profile: ProfileFilter.complete)), ['1']);
      expect(ids(const UserFilter(profile: ProfileFilter.missingAddress)), [
        '2',
        '4',
      ]);
      expect(ids(const UserFilter(profile: ProfileFilter.withPhoto)), ['1']);
      expect(ids(const UserFilter(profile: ProfileFilter.withoutPhoto)), [
        '2',
        '3',
        '4',
      ]);
    });

    test("période d'inscription (bornes incluses)", () {
      final f = UserFilter(
        createdFrom: DateTime(2026, 1, 10),
        createdTo: DateTime(2026, 3, 5),
      );
      expect(ids(f), ['1', '2']);
      expect(f.advancedCount, 1);
      expect(ids(f.copyWith(clearDates: true)).length, 4);
    });

    test('tris', () {
      expect(ids(const UserFilter(sort: UserSort.firstNameAsc)), [
        '3',
        '2',
        '1',
        '4',
      ]);
      expect(ids(const UserFilter(sort: UserSort.lastNameDesc)).first, '4');
      expect(ids(const UserFilter(sort: UserSort.newest)), [
        '3',
        '2',
        '1',
        '4',
      ]);
      expect(ids(const UserFilter(sort: UserSort.oldest)), [
        '1',
        '2',
        '3',
        '4',
      ]);
    });
  });
}
