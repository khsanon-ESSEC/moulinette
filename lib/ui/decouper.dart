import 'package:flutter/material.dart';

import '../moteur/commandes.dart';
import '../moteur/execution.dart';
import '../moteur/file_attente.dart';
import '../moteur/formats.dart';
import '../moteur/temps.dart';
import 'communs.dart';

class EcranDecouper extends StatefulWidget {
  const EcranDecouper({super.key, required this.lance});
  final VoidCallback lance;
  @override
  State<EcranDecouper> createState() => _EcranDecouperState();
}

class _EcranDecouperState extends State<EcranDecouper> {
  final _sources = <Source>[];
  ModeDecoupe _mode = ModeDecoupe.parties;
  final _parties = TextEditingController(text: '2');
  final _duree = TextEditingController(text: '10:00');
  final _points = TextEditingController();
  final _debut = TextEditingController(text: '0:00');
  final _fin = TextEditingController();
  bool _precis = false;

  Source? get _source => _sources.isEmpty ? null : _sources.first;

  @override
  void dispose() {
    for (final c in [_parties, _duree, _points, _debut, _fin]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Plan de découpe calculé à partir des champs, ou message d'erreur.
  (List<Morceau>?, String?) _plan() {
    final s = _source;
    if (s == null || !s.pret) return (null, null);
    if (s.duree == null) return (null, 'La durée de ce fichier est inconnue : il ne peut pas être découpé. Convertissez-le d’abord (en MP4 ou MKV), puis découpez la copie.');
    try {
      double lire(TextEditingController c, String quoi) =>
          lireDuree(c.text) ?? (throw FormatException('$quoi : écrivez par exemple 1:30, 90 ou 5m.'));
      final plan = planDecoupe(
        dureeTotale: s.duree!,
        mode: _mode,
        parties: int.tryParse(_parties.text.trim()) ?? 0,
        dureeMorceau: _mode == ModeDecoupe.duree ? lire(_duree, 'Durée') : 0,
        points: _mode == ModeDecoupe.points
            ? [
                for (final m in _points.text.split(RegExp(r'[;\n\s]+')).where((m) => m.trim().isNotEmpty))
                  lireDuree(m) ?? (throw FormatException('« $m » n’est pas un moment lisible.')),
              ]
            : const [],
        debut: _mode == ModeDecoupe.passage ? lire(_debut, 'Début') : null,
        fin: _mode == ModeDecoupe.passage && _fin.text.trim().isNotEmpty ? lire(_fin, 'Fin') : null,
      );
      return (plan, null);
    } on FormatException catch (e) {
      return (null, e.message);
    }
  }

  Future<void> _lancer(List<Morceau> plan) async {
    final s = _source!;
    final video = s.aDeLaVideo == true;
    // En mode précis, un format que l'app ne sait pas réencoder devient MP4 (vidéo) ou M4A (audio).
    var ext = s.extension;
    if (_precis && Format.depuisExtension(ext) == null) ext = video ? 'mp4' : 'm4a';
    if (ext.isEmpty) ext = video ? 'mkv' : 'mka';
    final dossier = await reglages.dossierPour(s);
    final chiffres = plan.length.toString().length < 2 ? 2 : plan.length.toString().length;
    final precis = _precis;
    final etapes = <Etape>[
      for (var i = 0; i < plan.length; i++)
        () {
          final nom = plan.length == 1
              ? '${s.base} (${ecrireDuree(plan[i].debut).replaceAll(':', '.')} à ${ecrireDuree(plan[i].fin).replaceAll(':', '.')})'
              : '${s.base} (partie ${(i + 1).toString().padLeft(chiffres, '0')})';
          final sortie = reserverChemin(dossier, nom, ext);
          return Etape(
            sortie: sortie,
            duree: plan[i].duree,
            commande: () async => commandeMorceau(
                entree: await s.entree(), sortie: sortie, morceau: plan[i], precis: precis, video: video),
          );
        }(),
    ];
    fileAttente.ajouter(Tache(
      titre: s.nom,
      detail: plan.length == 1
          ? 'Passage ${plan.first}${precis ? ' · précis' : ''}'
          : '${plan.length} morceaux${precis ? ' · coupe précise' : ''}',
      etapes: etapes,
    ));
    setState(_sources.clear);
    widget.lance();
  }

  Widget _champ(TextEditingController c, String libelle, {String? aide, bool nombre = false, int lignes = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: nombre ? TextInputType.number : (lignes > 1 ? TextInputType.multiline : TextInputType.text),
          maxLines: lignes,
          minLines: 1,
          decoration: InputDecoration(labelText: libelle, helperText: aide, border: const OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = _source;
    final (plan, erreur) = _plan();
    final theme = Theme.of(context);
    return Ecran(enfants: [
      const Titre('Fichier à découper'),
      ListeFichiers(sources: _sources, plusieurs: false, onChange: () => setState(() {})),
      const Titre('Comment découper'),
      Pastilles<ModeDecoupe>(
        options: ModeDecoupe.values,
        valeur: _mode,
        libelle: (m) => m.libelle,
        onChange: (m) => setState(() => _mode = m),
      ),
      const SizedBox(height: 16),
      switch (_mode) {
        ModeDecoupe.parties => _champ(_parties, 'Nombre de parties', nombre: true),
        ModeDecoupe.duree => _champ(_duree, 'Durée de chaque morceau', aide: 'Par exemple 10:00, 90 (secondes) ou 5m'),
        ModeDecoupe.points => _champ(_points, 'Moments de coupe',
            aide: 'Un par ligne ou séparés par des espaces : 2:30  5:00  1:02:15', lignes: 4),
        ModeDecoupe.passage => Row(children: [
            Expanded(child: _champ(_debut, 'Début', aide: 'ex. 1:30')),
            const SizedBox(width: 12),
            Expanded(child: _champ(_fin, 'Fin', aide: s?.duree == null ? 'vide = jusqu’au bout' : 'vide = ${ecrireDuree(s!.duree!)}')),
          ]),
      },
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Coupe précise'),
        subtitle: Text(_precis
            ? 'Coupe à la seconde près, mais réencode : plus lent.'
            : 'Rapide et sans perte. Pour une vidéo, la coupe peut décaler d’une ou deux secondes.'),
        value: _precis,
        onChanged: (v) => setState(() => _precis = v),
      ),
      if (erreur != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(erreur, style: TextStyle(color: theme.colorScheme.error)),
        ),
      if (plan != null) ...[
        Titre(plan.length == 1 ? 'Passage gardé' : '${plan.length} morceaux'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (var i = 0; i < plan.length && i < 12; i++)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                  title: Text(plan[i].toString()),
                  trailing: Text(ecrireDuree(plan[i].duree)),
                ),
              if (plan.length > 12)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('… et ${plan.length - 12} autres', style: theme.textTheme.bodySmall),
                ),
            ]),
          ),
        ),
      ],
      const Titre('Destination'),
      const DossierSortie(),
      BoutonLancer(
        libelle: plan == null
            ? 'Découper'
            : plan.length == 1
                ? 'Extraire ce passage'
                : 'Découper en ${plan.length} morceaux',
        icone: Icons.content_cut,
        onPressed: plan == null ? null : () => _lancer(plan),
      ),
    ]);
  }
}
