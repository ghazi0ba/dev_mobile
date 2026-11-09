# dev_mobile

Application mobile Flutter.

## Prérequis

| Outil | Version |
|---|---|
| Flutter (canal stable) | ** 3.47.9 ** (à remplacer par la sortie de `flutter --version`) |
| Dart | ≥ 3.13.7 (inclus avec Flutter) |
| Android Studio + Android SDK | récent, avec un émulateur ou un téléphone en mode développeur |
| JDK | 17 |
| Xcode (macOS uniquement, pour iOS) | récent |

Vérifiez votre installation :

```bash
flutter doctor
```

Tout doit être vert (au minimum Flutter et Android toolchain).

## Lancer le projet

```bash
git clone <URL_DU_DEPOT>
cd dev_mobile
flutter pub get
flutter run
```

Le fichier `android/local.properties` est créé automatiquement par Flutter au premier lancement. Il n'est **pas** versionné, car il contient des chemins propres à chaque machine.

## Commandes utiles

```bash
flutter analyze     # vérifier le code (lints)
flutter test        # lancer les tests
dart format .       # formater le code
flutter clean && flutter pub get   # si quelque chose casse après un pull
```

## Travailler en équipe

- La branche `main` doit toujours compiler. On ne pousse jamais directement dessus.
- Pour chaque tâche, créez une branche : `git checkout -b feature/nom-de-la-tache`
- Avant de pousser : `flutter analyze` et `flutter test` doivent passer.
- Ouvrez une Pull Request vers `main` et demandez une relecture.
- Après avoir ajouté une dépendance avec `flutter pub add <paquet>`, commitez `pubspec.yaml` **et** `pubspec.lock`.
- Ne commitez jamais de clés, de keystores (`*.jks`, `key.properties`) ni de fichiers `.env`.