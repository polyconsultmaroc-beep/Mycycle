# Cahier des charges — MyCycle V2

## 1. Objectif
Faire évoluer le prototype mobile Flutter en application Android française de suivi du cycle, avec calendrier des phases, historique modifiable, rappel WhatsApp préparé manuellement et une icône dédiée.

## 2. Périmètre fonctionnel
### Inclus dans la V2
- Écran de verrouillage par code PIN de 4 à 6 chiffres.
- Création du PIN au premier lancement.
- Tableau de bord indiquant le jour du cycle et les prochaines dates estimées.
- Calendrier mensuel avec menstruations, phases folliculaire et lutéale, fenêtre fertile estimée et ovulation estimée.
- Sélection d'une date avec explication de la phase correspondante.
- Enregistrement et modification des dates de début et de fin des règles.
- Historique chronologique des périodes enregistrées.
- Modification des dates de début et de fin, avec possibilité d'effacer la date de fin.
- Estimation du cycle basée sur la moyenne des intervalles récents entre débuts de règles ; durée par défaut modifiable avant d'avoir assez d'historique.
- Préférence de rappel WhatsApp activée par défaut, avec numéro, consentement explicite et aperçu. Le bouton ouvre WhatsApp avec un texte prérempli; aucun envoi automatique.
- Icône fleur et symbole féminin/cycle approuvée par l'utilisatrice.

### Exclus de la V2
- Comptes, profils multiples et partage avec un partenaire.
- Cloud, synchronisation et publicité.
- Contraception, diagnostic ou recommandations médicales.
- Symptômes détaillés, graphiques avancés et notifications.

## 3. Plateformes et technologies
- Flutter / Dart pour Android.
- SQLite via sqflite pour l'historique local.
- flutter_secure_storage pour conserver le sel et le hash du PIN dans le stockage sécurisé du système.
- crypto pour le hash du PIN.
- Interface Material 3, palette rose poudré et blanc.

## 4. Données
Table `periods` :
- `id` : entier, clé primaire auto-incrémentée.
- `start_date` : date ISO `YYYY-MM-DD`, obligatoire.
- `end_date` : date ISO `YYYY-MM-DD`, facultative.

Les données du cycle restent locales. Le numéro et le texte ne sont transmis à WhatsApp que lorsque l'utilisatrice a donné son consentement et appuie sur le bouton d'ouverture; l'envoi reste une confirmation manuelle dans WhatsApp.

## 5. Règles métier
- La durée d'un cycle correspond à l'écart en jours entre deux dates de début consécutives.
- Les intervalles aberrants (moins de 15 ou plus de 60 jours) sont ignorés dans la moyenne simple.
- L'estimation suivante est calculée à partir du dernier début enregistré et de la moyenne disponible.
- Les prévisions doivent toujours être présentées comme approximatives ; elles ne constituent ni une contraception ni un diagnostic.

## 6. Exigences non fonctionnelles
- Utilisation hors ligne.
- Interface lisible, avec peu d'écrans et d'actions.
- Aucun compte obligatoire.
- Verrouillage PIN à l'ouverture.
- Aucun transfert réseau automatique des données dans la V2.

## 7. Critères de recette
1. Au premier lancement, l'utilisatrice peut créer un PIN de 4 à 6 chiffres.
2. Un PIN incorrect ne permet pas d'accéder à l'accueil.
3. Un PIN correct ouvre l'accueil.
4. L'utilisatrice peut enregistrer le début et la fin (facultative) d'une période.
5. Les périodes restent visibles après fermeture et réouverture de l'application.
6. L'accueil affiche une estimation explicitement qualifiée d'indicative.
7. L'application fonctionne hors ligne, sauf l'ouverture volontaire de WhatsApp.
8. Le calendrier colore les cinq phases et affiche une explication pour la date sélectionnée.
9. L'historique permet de corriger les dates de début et de fin.
10. Le rappel WhatsApp exige un consentement explicite et n'envoie rien automatiquement.

## 8. Réserves avant publication
Le code fourni est un prototype de départ, pas une version certifiée pour publication. Avant diffusion, il faudra notamment renforcer la protection contre les tentatives répétées de PIN, ajouter un parcours de récupération/réinitialisation, chiffrer la base SQLite, tester les migrations et les cas limites de dates, et réaliser des tests sur appareils Android. La base SQLite de ce prototype n'est pas chiffrée.
