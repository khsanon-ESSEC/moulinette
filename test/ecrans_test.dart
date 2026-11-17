// Dessine chaque écran à plusieurs tailles et vérifie qu'aucune erreur de mise en page ne survient.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moulinette/main.dart';

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
}
