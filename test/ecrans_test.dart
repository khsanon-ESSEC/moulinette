// Dessine chaque écran à plusieurs tailles et vérifie qu'aucune erreur de mise en page ne survient.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moulinette/main.dart';
import 'package:moulinette/moteur/file_attente.dart';

void main() {
  for (final taille in const [Size(390, 844), Size(800, 1280), Size(1440, 900)]) {
    testWidgets('écrans à ${taille.width.toInt()}×${taille.height.toInt()}', (tester) async {
      tester.view.physicalSize = taille;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const Moulinette());
      expect(find.text('Choisir des fichiers'), findsOneWidget);
      expect(find.text('MP4'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.graphic_eq).hitTestable().first);
      await tester.pumpAndSettle();
      expect(find.text('Tel quel'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.content_cut).hitTestable().first);
      await tester.pumpAndSettle();
      expect(find.text('Choisir un fichier'), findsOneWidget);
      for (final mode in ['Toutes les X minutes', 'Aux moments choisis', 'Garder un passage']) {
        await tester.tap(find.text(mode));
        await tester.pumpAndSettle();
      }
      expect(find.text('Début'), findsOneWidget);
      if (taille.width < 1000) {
        await tester.tap(find.byIcon(Icons.list_alt).hitTestable().first);
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('apparaîtront ici'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  // T-009 : texte agrandi à 200 % (réglage d'accessibilité), sur les formats des appareils visés.
  const formats = {'téléphone': Size(360, 800), 'pliable': Size(880, 1100), 'tablette': Size(820, 1180),
    'tablette couchée': Size(1180, 820), 'Boox': Size(1200, 1600)};
  for (final e in formats.entries) {
    testWidgets('texte à 200 % sans débordement : ${e.key}', (tester) async {
      fileAttente.taches
        ..clear()
        ..add(Tache(titre: 'Vacances à Jacmel, été 2026, la grande vidéo de famille 🙂.mp4', detail: '→ MP4 · normale',
            etapes: [])..etat = EtatTache.erreur..message = 'Le fichier est abîmé ou n’est pas un fichier audio ou vidéo.');
      addTearDown(fileAttente.taches.clear);
      tester.view.physicalSize = e.value;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await tester.pumpWidget(const Moulinette());
      for (final icone in [Icons.graphic_eq, Icons.content_cut, if (e.value.width < 1000) Icons.list_alt]) {
        await tester.tap(find.byIcon(icone).hitTestable().first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$icone');
      }
      expect(find.text('Effacer les terminées'), findsOneWidget);
    });
  }
}
