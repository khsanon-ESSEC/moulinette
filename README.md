# Moulinette

Petite app pour convertir des fichiers audio et vidéo, en extraire le son et les découper.
Android (tablettes, Boox), iPad, Mac et Windows. FFmpeg 8 est intégré (`ffmpeg_kit_flutter_new`, version GPL complète) : rien à installer à côté.

- **Convertir** : MP4, MOV, MKV, WebM, AVI, GIF ; MP3, M4A, WAV, FLAC, OGG, Opus. Plusieurs fichiers à la fois, trois qualités, taille d'image maximale, ou « sans réencodage » (changement d'enveloppe instantané).
- **Extraire l'audio** : piste recopiée telle quelle (sans perte) ou convertie.
- **Découper** : en N parties égales, toutes les X minutes, aux moments choisis, ou garder un seul passage. Coupe rapide (sans perte, à l'image clé) ou précise (réencodée).

Les fichiers créés vont : à côté du fichier d'origine (Mac, Windows), dans Téléchargements › Moulinette (Android), dans Fichiers › Sur mon iPad › Moulinette (iPad). Le dossier se change dans l'app (sauf iPad).

Téléchargements : page [Releases](https://github.com/khsanon-ESSEC/moulinette/releases) du dépôt (APK Android et version
Windows, avec leurs empreintes SHA-256).

## Où en est l'app (au 17 novembre 2026)

Version actuelle : **1.1.0** (étiquette `v1.1.0`).

### Ce qui est fait

**Les trois fonctions (1.0.0)**
- Convertir un ou plusieurs fichiers audio ou vidéo dans les formats courants, avec trois niveaux de qualité.
- Changer seulement l'enveloppe d'un fichier, sans réencodage, ce qui est instantané et sans perte.
- Réduire la taille de l'image d'une vidéo pendant la conversion.
- Extraire le son d'une vidéo, tel quel (sans perte) ou converti.
- Découper un fichier en parts égales, toutes les X minutes, aux moments choisis, ou n'en garder qu'un passage.
- Choisir entre une coupe rapide sans perte et une coupe précise réencodée.

**L'usage au quotidien (1.0.0)**
- Les tâches passent l'une après l'autre dans une liste, avec leur progression et un bouton pour annuler.
- Les fichiers créés se partagent depuis la liste, ou s'affichent dans leur dossier sur ordinateur.
- Le dossier où vont les fichiers se change dans l'app (sauf sur iPad).
- FFmpeg est intégré à l'app : rien d'autre à installer.

**Corrections de la revue du 17 novembre (1.0.1)**
- Sur iPad, le sélecteur ouvre l'app Fichiers, avec un bouton « Depuis Photos » pour les vidéos de la photothèque.
- Un fichier dont la durée est inconnue se convertit quand même ; la découpe explique pourquoi elle est impossible.
- Le son d'une vidéo de caméra s'extrait maintenant sans erreur.
- Sur Android 10 et avant, l'app demande l'autorisation d'écrire, ou montre le vrai dossier des fichiers.
- Annuler une tâche n'arrête plus que cette tâche, même juste après son lancement.
- Avec le texte agrandi à 200 %, l'en-tête de la liste des tâches ne déborde plus.
- L'APK Android est signé avec la clé de publication de Moulinette, et non plus avec une clé de développement.
- Le FFmpeg de la version Windows est vérifié par son empreinte avant la construction.

**Licence (1.1.0)**
- L'app est publiée sous licence GPL 3.0, avec le texte de la licence dans le dépôt.
- Un écran « À propos et licences » (bouton ⓘ) affiche les notices de FFmpeg et l'adresse du code source.

**Essais et livraison**
- Les tests automatiques passent sur Mac et sur un émulateur Android.
- La version Windows est construite et testée par le robot de GitHub, à chaque nouvelle version étiquetée.
- La version 1.1.0 est publiée avec les APK Android (arm64, arm32, universel) et la version Windows.

### Ce qui reste à faire

**À décider**
- Publier ou non une version Mac et une version iPad à télécharger (aujourd'hui : Android et Windows seulement).

**À faire (comptes, clés, stores, essais sur appareil)**
- Essayer l'app sur une vraie tablette Android (Boox ou autre) : jamais essayé, seulement sur émulateur.
- Construire et essayer la version iPad : jamais construite à ce jour.
- Essayer la version Windows sur un vrai PC : seulement essayée par le robot de GitHub.
- Garder une copie de la clé de signature Android en lieu sûr : sans elle, aucune mise à jour ne pourra s'installer
  par-dessus l'app déjà en place.

**À développer**
- Retenir le dossier choisi d'un lancement à l'autre (il est oublié aujourd'hui).
- Glisser-déposer des fichiers dans la fenêtre, sur Mac et sur PC.
- Garder la liste des fichiers après un lancement, avec un bouton « Vider ».

## Construire

    flutter build macos                      # puis copier build/macos/Build/Products/Release/Moulinette.app dans /Applications
    flutter build apk --split-per-abi        # arm64 pour les tablettes récentes
    flutter build ios
    # Windows : workflow GitHub « Windows » (.github/workflows/windows.yml)

## Tests

    flutter test                             # commandes FFmpeg testées avec le ffmpeg du système + écrans
    flutter test integration_test -d macos   # FFmpeg intégré à l'app (marche aussi sur un émulateur Android)

Icône : `dart run tool/icon.dart` puis `dart run flutter_launcher_icons`.

## Licence

Moulinette est un logiciel libre, publié sous la licence publique générale GNU, version 3 ou ultérieure (voir [LICENSE](LICENSE)). © 2026 Karl-Henry Sanon.

L'app intègre FFmpeg par `ffmpeg_kit_flutter_new` (variante « Full GPL » : x264, x265, xvidcore, vid.stab), ce qui place l'app entière sous GPL. Les notices de FFmpeg sont dans `assets/licences/` et s'affichent dans l'app (bouton ⓘ, « Licences des composants »). La version Windows livre aussi `licenses/ffmpeg_kit_flutter_new/` à côté de l'exécutable.

Code source correspondant à chaque version distribuée : ce dépôt, à l'étiquette de la version (par exemple `v1.1.0`).
