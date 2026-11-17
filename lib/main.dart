// Moulinette : convertir des fichiers audio et vidéo, en extraire le son, les découper.
import 'package:flutter/material.dart';

import 'moteur/file_attente.dart';
import 'ui/convertir.dart';
import 'ui/decouper.dart';
import 'ui/extraire.dart';
import 'ui/taches.dart';

void main() => runApp(const Moulinette());

const couleurMoulinette = Color(0xFF2E5E4E);

class Moulinette extends StatelessWidget {
  const Moulinette({super.key});

  ThemeData _theme(Brightness b) => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: couleurMoulinette, brightness: b),
        useMaterial3: true,
      );

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Moulinette',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: const Accueil(),
      );
}

class Accueil extends StatefulWidget {
  const Accueil({super.key});
  @override
  State<Accueil> createState() => _AccueilState();
}

class _AccueilState extends State<Accueil> {
  int _onglet = 0;
  static const _titres = ['Convertir', 'Extraire l’audio', 'Découper', 'Tâches'];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, contraintes) {
      final large = contraintes.maxWidth >= 1000;
      // Sur grand écran, les tâches restent visibles à droite ; sinon elles ont leur onglet.
      void lance() {
        if (!large) setState(() => _onglet = 3);
      }

      final ecrans = [
        EcranConvertir(lance: lance),
        EcranExtraire(lance: lance),
        EcranDecouper(lance: lance),
        const EcranTaches(),
      ];
      final onglet = large && _onglet == 3 ? 0 : _onglet;
      final contenu = IndexedStack(index: onglet, children: ecrans);
      final destinations = [
        (Icons.autorenew, 'Convertir'),
        (Icons.graphic_eq, 'Audio'),
        (Icons.content_cut, 'Découper'),
        if (!large) (Icons.list_alt, 'Tâches'),
      ];
      final badge = ListenableBuilder(
        listenable: fileAttente,
        builder: (context, _) => Badge(
          isLabelVisible: fileAttente.actives > 0,
          label: Text('${fileAttente.actives}'),
          child: const Icon(Icons.list_alt),
        ),
      );

      if (contraintes.maxWidth >= 700) {
        return Scaffold(
          body: SafeArea(
            child: Row(children: [
              NavigationRail(
                selectedIndex: onglet,
                labelType: NavigationRailLabelType.all,
                onDestinationSelected: (i) => setState(() => _onglet = i),
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Image.asset('assets/icon/icon.png', width: 40, height: 40),
                ),
                destinations: [
                  for (final (i, d) in destinations.indexed)
                    NavigationRailDestination(icon: i == 3 ? badge : Icon(d.$1), label: Text(d.$2)),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Text(_titres[onglet], style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  Expanded(child: contenu),
                ]),
              ),
              if (large) ...[
                const VerticalDivider(width: 1),
                const SizedBox(width: 380, child: EcranTaches(compact: true)),
              ],
            ]),
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(title: Text(_titres[onglet])),
        body: contenu,
        bottomNavigationBar: NavigationBar(
          selectedIndex: onglet,
          onDestinationSelected: (i) => setState(() => _onglet = i),
          destinations: [
            for (final (i, d) in destinations.indexed)
              NavigationDestination(icon: i == 3 ? badge : Icon(d.$1), label: d.$2),
          ],
        ),
      );
    });
  }
}
