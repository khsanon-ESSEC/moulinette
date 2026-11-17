# Moulinette

Petite app pour convertir des fichiers audio et vidéo, en extraire le son et les découper.
Android (tablettes, Boox), iPad, Mac et Windows. FFmpeg 8 est intégré (`ffmpeg_kit_flutter_new`, version GPL complète) : rien à installer à côté.

- **Convertir** : MP4, MOV, MKV, WebM, AVI, GIF ; MP3, M4A, WAV, FLAC, OGG, Opus. Plusieurs fichiers à la fois, trois qualités, taille d'image maximale, ou « sans réencodage » (changement d'enveloppe instantané).
- **Extraire l'audio** : piste recopiée telle quelle (sans perte) ou convertie.
- **Découper** : en N parties égales, toutes les X minutes, aux moments choisis, ou garder un seul passage. Coupe rapide (sans perte, à l'image clé) ou précise (réencodée).

Les fichiers créés vont : à côté du fichier d'origine (Mac, Windows), dans Téléchargements › Moulinette (Android), dans Fichiers › Sur mon iPad › Moulinette (iPad). Le dossier se change dans l'app (sauf iPad).

## Construire

    flutter build macos                      # puis copier build/macos/Build/Products/Release/Moulinette.app dans /Applications
    flutter build apk --split-per-abi        # arm64 pour les tablettes récentes
    flutter build ios                        # équipe UGCR242B6L
    # Windows : workflow GitHub « Windows » (.github/workflows/windows.yml)

## Tests

    flutter test                             # commandes FFmpeg testées avec le ffmpeg du système + écrans
    flutter test integration_test -d macos   # FFmpeg intégré à l'app (marche aussi sur un émulateur Android)

Icône : `dart run tool/icon.dart` puis `dart run flutter_launcher_icons`.

## Licence

Moulinette est un logiciel libre, publié sous la licence publique générale GNU, version 3 ou ultérieure (voir [LICENSE](LICENSE)). © 2026 Karl-Henry Sanon.

L'app intègre FFmpeg par `ffmpeg_kit_flutter_new` (variante « Full GPL » : x264, x265, xvidcore, vid.stab), ce qui place l'app entière sous GPL. Les notices de FFmpeg sont dans `assets/licences/` et s'affichent dans l'app (bouton ⓘ, « Licences des composants »). La version Windows livre aussi `licenses/ffmpeg_kit_flutter_new/` à côté de l'exécutable.

Code source correspondant à chaque version distribuée : ce dépôt, à l'étiquette de la version (par exemple `v1.1.0`).
