# MyCycle — prototype Flutter V1

Application simple de suivi menstruel en français, Android et iOS.

## Fonctions présentes
- Création et vérification d'un PIN (4 à 6 chiffres), stocké sous forme de hash salé dans le stockage sécurisé du système.
- Enregistrement des dates de début et de fin des règles.
- Historique local SQLite.
- Estimation simple des prochaines règles à partir des intervalles entre débuts de cycles (28 jours par défaut tant que deux débuts ne sont pas enregistrés).
- Interface rose poudré.

## Lancer le projet
1. Installer Flutter stable et Android Studio (Android) ou Xcode sur macOS (iOS).
2. Dans ce dossier : `flutter pub get`
3. Brancher un appareil ou démarrer un émulateur : `flutter run`
4. Vérifier les dépendances natives iOS avec `cd ios && pod install` si nécessaire.

## Générer les applications
- Android APK : `flutter build apk --release`
- Android App Bundle : `flutter build appbundle --release`
- iOS : `flutter build ios --release` (sur macOS avec Xcode configuré)

## Confidentialité et limites du prototype
- Aucune synchronisation cloud ni compte utilisateur.
- Les données de cycle restent dans la base SQLite locale. Pour une version de production, prévoir le chiffrement de la base et une stratégie de sauvegarde/restauration.
- Le PIN est protégé via le stockage sécurisé du système. La protection d'accès dans ce prototype ne remplace pas un audit de sécurité ; ajouter une temporisation après plusieurs échecs et un parcours de réinitialisation local avant publication.
- Les estimations de cycle sont indicatives et ne conviennent pas à la contraception ni au diagnostic.

## Compilation Android dans le cloud (sans installer Flutter sur le PC)
Le dépôt inclut `.github/workflows/android-apk.yml`. Après avoir placé le projet dans un dépôt GitHub, l'action **Build MyCycle Android APK** compile automatiquement l'APK à chaque push sur `main`/`master`, ou manuellement depuis l'onglet Actions avec **Run workflow**. Le fichier `app-release.apk` est disponible dans les artefacts de l'exécution réussie.
