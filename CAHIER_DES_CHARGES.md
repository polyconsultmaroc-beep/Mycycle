# Cahier des charges — MyCycle V1

## 1. Objectif
Créer une application mobile Android et iOS, simple et en français, permettant à une seule utilisatrice d'enregistrer ses menstruations et de consulter son historique et une estimation de ses prochaines règles.

## 2. Périmètre fonctionnel
### Inclus dans la V1
- Écran de verrouillage par code PIN de 4 à 6 chiffres.
- Création du PIN au premier lancement.
- Accueil indiquant le jour du cycle et la date estimée des prochaines règles.
- Enregistrement du premier jour des règles et, si connu, du dernier jour.
- Historique chronologique des périodes enregistrées.
- Modification de la date de fin lorsqu'elle n'a pas été renseignée.
- Estimation du cycle basée sur la moyenne des intervalles récents entre débuts de règles ; valeur indicative de 28 jours avant d'avoir assez d'historique.

### Exclus de la V1
- Comptes, profils multiples et partage avec un partenaire.
- Cloud, synchronisation et publicité.
- Suivi de fertilité, contraception, diagnostic ou recommandations médicales.
- Symptômes détaillés, graphiques avancés et notifications.

## 3. Plateformes et technologies
- Flutter / Dart pour Android et iOS.
- SQLite via sqflite pour l'historique local.
- flutter_secure_storage pour conserver le sel et le hash du PIN dans le stockage sécurisé du système.
- crypto pour le hash du PIN.
- Interface Material 3, palette rose poudré et blanc.

## 4. Données
Table `periods` :
- `id` : entier, clé primaire auto-incrémentée.
- `start_date` : date ISO `YYYY-MM-DD`, obligatoire.
- `end_date` : date ISO `YYYY-MM-DD`, facultative.

Les données ne sont pas envoyées à un serveur dans cette version.

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
- Aucun transfert réseau des données dans la V1.

## 7. Critères de recette
1. Au premier lancement, l'utilisatrice peut créer un PIN de 4 à 6 chiffres.
2. Un PIN incorrect ne permet pas d'accéder à l'accueil.
3. Un PIN correct ouvre l'accueil.
4. L'utilisatrice peut enregistrer le début et la fin (facultative) d'une période.
5. Les périodes restent visibles après fermeture et réouverture de l'application.
6. L'accueil affiche une estimation explicitement qualifiée d'indicative.
7. L'application fonctionne sans connexion Internet.

## 8. Réserves avant publication
Le code fourni est un prototype de départ, pas une version certifiée pour publication. Avant diffusion, il faudra notamment renforcer la protection contre les tentatives répétées de PIN, ajouter un parcours de récupération/réinitialisation, chiffrer la base SQLite, tester les migrations et les cas limites de dates, et réaliser des tests sur appareils Android et iOS. La base SQLite de ce prototype n'est pas chiffrée.
