import 'package:dev_mobile/shared/models/models.dart';

enum RoleFilter { all, client, admin }

enum StatusFilter { all, active, disabled }

enum ProfileFilter {
  all,
  complete,
  missingPhone,
  missingAddress,
  withPhoto,
  withoutPhoto,
  incompleteName,
}

enum UserSort { lastNameAsc, lastNameDesc, firstNameAsc, newest, oldest, email }

extension ProfileFilterLabel on ProfileFilter {
  String get label => switch (this) {
    ProfileFilter.all => 'Tous',
    ProfileFilter.complete => 'Profil complet',
    ProfileFilter.missingPhone => 'Sans téléphone',
    ProfileFilter.missingAddress => 'Sans adresse',
    ProfileFilter.withPhoto => 'Avec photo',
    ProfileFilter.withoutPhoto => 'Sans photo',
    ProfileFilter.incompleteName => 'Nom incomplet',
  };
}

extension UserSortLabel on UserSort {
  String get label => switch (this) {
    UserSort.lastNameAsc => 'Nom A → Z',
    UserSort.lastNameDesc => 'Nom Z → A',
    UserSort.firstNameAsc => 'Prénom A → Z',
    UserSort.newest => 'Plus récents',
    UserSort.oldest => 'Plus anciens',
    UserSort.email => 'Email',
  };
}

const _accents = {
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'á': 'a',
  'ã': 'a',
  'ç': 'c',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'î': 'i',
  'ï': 'i',
  'í': 'i',
  'ô': 'o',
  'ö': 'o',
  'ó': 'o',
  'õ': 'o',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ú': 'u',
  'ÿ': 'y',
  'ñ': 'n',
  'œ': 'oe',
  'æ': 'ae',
};

/// Minuscules sans accents, pour une recherche tolérante.
String normalizeForSearch(String input) {
  final buffer = StringBuffer();
  for (final char in input.toLowerCase().split('')) {
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString();
}

/// Recherche avancée + filtres + tri de la liste des utilisateurs.
/// Classe pure (sans Flutter ni Firebase) : facile à tester.
class UserFilter {
  const UserFilter({
    this.query = '',
    this.role = RoleFilter.all,
    this.status = StatusFilter.all,
    this.profile = ProfileFilter.all,
    this.createdFrom,
    this.createdTo,
    this.sort = UserSort.lastNameAsc,
  });

  /// Plusieurs mots possibles : chacun doit se retrouver dans le prénom,
  /// le nom, l'email, le téléphone ou l'adresse (accents et casse ignorés).
  final String query;
  final RoleFilter role;
  final StatusFilter status;
  final ProfileFilter profile;

  /// Période d'inscription (bornes incluses, à la journée).
  final DateTime? createdFrom;
  final DateTime? createdTo;
  final UserSort sort;

  UserFilter copyWith({
    String? query,
    RoleFilter? role,
    StatusFilter? status,
    ProfileFilter? profile,
    DateTime? createdFrom,
    DateTime? createdTo,
    bool clearDates = false,
    UserSort? sort,
  }) => UserFilter(
    query: query ?? this.query,
    role: role ?? this.role,
    status: status ?? this.status,
    profile: profile ?? this.profile,
    createdFrom: clearDates ? null : (createdFrom ?? this.createdFrom),
    createdTo: clearDates ? null : (createdTo ?? this.createdTo),
    sort: sort ?? this.sort,
  );

  bool get hasDateRange => createdFrom != null || createdTo != null;

  /// Nombre de filtres réglés dans le panneau "Filtres avancés".
  int get advancedCount =>
      (profile != ProfileFilter.all ? 1 : 0) +
      (hasDateRange ? 1 : 0) +
      (sort != UserSort.lastNameAsc ? 1 : 0);

  bool get isActive =>
      query.trim().isNotEmpty ||
      role != RoleFilter.all ||
      status != StatusFilter.all ||
      advancedCount > 0;

  bool matches(AppUser u) {
    if (role == RoleFilter.client && u.isAdmin) return false;
    if (role == RoleFilter.admin && !u.isAdmin) return false;
    if (status == StatusFilter.active && u.disabled) return false;
    if (status == StatusFilter.disabled && !u.disabled) return false;

    final hasPhone = (u.phone ?? '').trim().isNotEmpty;
    final hasAddress = (u.address ?? '').trim().isNotEmpty;
    switch (profile) {
      case ProfileFilter.all:
        break;
      case ProfileFilter.complete:
        if (!hasPhone || !hasAddress) return false;
      case ProfileFilter.missingPhone:
        if (hasPhone) return false;
      case ProfileFilter.missingAddress:
        if (hasAddress) return false;
      case ProfileFilter.withPhoto:
        if (!u.hasPhoto) return false;
      case ProfileFilter.withoutPhoto:
        if (u.hasPhoto) return false;
      case ProfileFilter.incompleteName:
        if (u.hasCompleteName) return false;
    }

    if (hasDateRange) {
      final created = u.createdAt;
      if (created == null) return false;
      final from = createdFrom;
      final to = createdTo;
      if (from != null &&
          created.isBefore(DateTime(from.year, from.month, from.day))) {
        return false;
      }
      if (to != null &&
          !created.isBefore(DateTime(to.year, to.month, to.day + 1))) {
        return false;
      }
    }

    final words = normalizeForSearch(query)
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);
    if (words.isEmpty) return true;
    final phone = u.phone ?? '';
    final haystack = normalizeForSearch(
      [
        u.firstName,
        u.lastName,
        u.email,
        phone,
        phone.replaceAll(RegExp(r'[^0-9+]'), ''),
        u.address ?? '',
      ].join(' '),
    );
    return words.every(haystack.contains);
  }

  int _compare(AppUser a, AppUser b) {
    // Tri par nom puis prénom (ou l'inverse).
    int byName(AppUser x, AppUser y, {bool firstNameFirst = false}) {
      String key(AppUser u) => normalizeForSearch(
        firstNameFirst
            ? '${u.firstName} ${u.lastName}'
            : '${u.lastName} ${u.firstName}',
      ).trim();
      return key(x).compareTo(key(y));
    }

    int byDate(AppUser x, AppUser y) {
      final dx = x.createdAt, dy = y.createdAt;
      if (dx == null && dy == null) return 0;
      if (dx == null) return 1; // sans date : toujours à la fin
      if (dy == null) return -1;
      return dx.compareTo(dy);
    }

    return switch (sort) {
      UserSort.lastNameAsc => byName(a, b),
      UserSort.lastNameDesc => byName(b, a),
      UserSort.firstNameAsc => byName(a, b, firstNameFirst: true),
      UserSort.email => a.email.toLowerCase().compareTo(b.email.toLowerCase()),
      UserSort.oldest => byDate(a, b),
      UserSort.newest =>
        a.createdAt == null || b.createdAt == null
            ? byDate(a, b)
            : byDate(b, a),
    };
  }

  /// Applique recherche, filtres et tri.
  List<AppUser> apply(Iterable<AppUser> users) =>
      users.where(matches).toList()..sort(_compare);
}
