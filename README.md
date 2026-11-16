# MyCycle V2 — prototype Flutter

Application de suivi du cycle menstruel en français. Le projet source est compilé en APK Android par GitHub Actions.

## Fonctions
- Création et vérification d'un PIN (4 à 6 chiffres), stocké sous forme de hash salé dans le stockage sécurisé du système.
- Tableau de bord du cycle.
- Calendrier mensuel des règles et des phases folliculaire, fertile, ovulatoire estimée et lutéale, avec explication des dates sélectionnées.
- Enregistrement et modification des dates de début et de fin des règles.
- Historique local SQLite.
- Réglage de la durée habituelle du cycle et des règles.
- Préférence de rappel WhatsApp activée par défaut, avec numéro, consentement explicite et aperçu du texte. Le bouton ouvre WhatsApp avec le texte prérempli; aucun message n’est envoyé automatiquement.
- Icône MyCycle approuvée, aux tons rose et prune.
- Interface française rose poudré et blanche.

## Lancer le projet
1. Installer Flutter stable et Android Studio.
2. Dans ce dossier, générer le projet Android s'il n'existe pas : `flutter create --platforms=android --project-name mycycle .`
3. Installer les dépendances : `flutter pub get`
4. Générer l'icône : `dart run flutter_launcher_icons`
5. Brancher un appareil Android ou démarrer un émulateur : `flutter run`

## Générer les applications
- Android APK : `flutter build apk --release`
- Android App Bundle : `flutter build appbundle --release`

## Confidentialité et limites du prototype
- Aucune synchronisation cloud ni compte utilisateur.
- Les données du cycle restent dans la base SQLite locale; les préférences et le numéro de téléphone sont conservés localement. Pour une version de production, prévoir le chiffrement de la base et une stratégie de sauvegarde/restauration.
- WhatsApp ne sert qu’à préparer un message après consentement. L’utilisatrice doit le relire et confirmer elle-même son envoi.
- Le PIN est protégé via le stockage sécurisé du système. La protection d'accès dans ce prototype ne remplace pas un audit de sécurité ; ajouter une temporisation après plusieurs échecs et un parcours de réinitialisation local avant publication.
- Les estimations de cycle, de fertilité et d’ovulation sont indicatives et ne conviennent pas à la contraception ni au diagnostic.

## Compilation Android dans le cloud (sans installer Flutter sur le PC)
Le dépôt inclut `.github/workflows/android-apk.yml`. Après un push sur `main`/`master`, l'action **Build MyCycle Android APK** crée le projet Android, génère les icônes puis compile l'APK. Le fichier `app-release.apk` est disponible dans les artefacts de l'exécution réussie. La compilation peut aussi être lancée manuellement depuis l'onglet Actions avec **Run workflow**.
