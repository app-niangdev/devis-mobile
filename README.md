# Devis — application mobile du gestionnaire

Application Flutter des gestionnaires d'entreprise : clients, devis (PDF, WhatsApp, acompte),
charte graphique de l'entreprise. L'administrateur utilise l'espace web Angular (`../frontend`).

## Lancer

L'adresse de l'API est fixée à la compilation :

```bash
flutter pub get

# Émulateur Android (l'hôte est 10.0.2.2)
flutter run --dart-define=API_URL=http://10.0.2.2:8000/api

# Production
flutter build apk --release --dart-define=API_URL=https://backenddevis.niangdev.com/api
```

En HTTP non chiffré (développement local), Android et iOS bloquent les appels par défaut :
utilisez l'API en HTTPS, ou autorisez le trafic en clair pour le seul build de développement.

## Application web installable (PWA)

L'application peut aussi s'installer depuis le navigateur, sans passer par les stores.
Le site **et** l'API doivent être en HTTPS (sinon pas d'installation, et le stockage sécurisé
des jetons ne fonctionne pas).

```bash
# 1. Construire (l'adresse de l'API est fixée à la compilation)
./deploy/build_pwa.sh https://backenddevis.niangdev.com/api

# 2. Copier sur le VPS
rsync -az --delete build/web/ vps_deploy:/var/www/devis-pwa/

# 3. Première fois : site nginx (deploy/nginx-pwa.conf) + certificat
sudo certbot certonly --nginx -d app-devis.niangdev.com
```

Installation sur le téléphone, en ouvrant `https://app-devis.niangdev.com` :
- **Android (Chrome)** : menu ⋮ → « Installer l'application » (ou la bannière proposée).
- **iPhone (Safari)** : bouton Partager → « Sur l'écran d'accueil ».

Un appui long sur l'icône propose les raccourcis « Nouveau devis », « Mes devis », « Clients »
(Android). Après une mise en ligne, la nouvelle version est prise au prochain lancement.

## Connexion

- Numéro sénégalais à 9 chiffres (70, 71, 75, 76, 77, 78) + mot de passe.
- Première connexion : mot de passe provisoire donné par l'administrateur, puis code reçu
  sur WhatsApp, puis choix du mot de passe.
- Mot de passe oublié : code reçu sur WhatsApp.
- En local sans WAHA, le code est écrit dans `backend/storage/logs/laravel.log`.

## Structure

- `lib/core` : client API (jetons, renouvellement, erreurs), session, thème, formats.
- `lib/features/auth` : connexion, code OTP, mot de passe.
- `lib/features/quotes` : liste, fiche, éditeur, acompte.
- `lib/features/customers`, `lib/features/company`, `lib/features/dashboard`.
