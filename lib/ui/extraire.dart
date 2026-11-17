import 'package:flutter/material.dart';

import '../moteur/commandes.dart';
import '../moteur/execution.dart';
import '../moteur/file_attente.dart';
import '../moteur/formats.dart';
import 'communs.dart';

class EcranExtraire extends StatefulWidget {
  const EcranExtraire({super.key, required this.lance});
  final VoidCallback lance;
  @override
  State<EcranExtraire> createState() => _EcranExtraireState();
}

class _EcranExtraireState extends State<EcranExtraire> {
  final _sources = <Source>[];

  /// `null` : la piste est recopiée telle quelle.
  Format? _format = Format.mp3;
  Qualite _qualite = Qualite.normale;

  Future<void> _lancer() async {
    var sansSon = 0;
    for (final s in _sources.where((s) => s.pret)) {
      if (s.aDuSon == false) {
        sansSon++;
        continue;
      }
      final format = _format, qualite = _qualite;
      final ext = format?.extension ?? extensionPourCodecAudio(s.codecAudio);
      final sortie = reserverChemin(await reglages.dossierPour(s), s.base, ext);
      fileAttente.ajouter(Tache(
        titre: s.nom,
        detail: 'Audio → ${format?.libelle ?? 'piste d’origine (.$ext)'}',
        etapes: [
          Etape(
            sortie: sortie,
            duree: s.duree ?? 0,
            commande: () async =>
                commandeExtraction(
                entree: await s.entree(), sortie: sortie, format: format, qualite: qualite, codecAudio: s.codecAudio),
          ),
        ],
      ));
    }
    if (!mounted) return;
    if (sansSon > 0) informer(context, '$sansSon fichier(s) ignoré(s) : aucune piste audio.');
    setState(_sources.clear);
    widget.lance();
  }

  @override
  Widget build(BuildContext context) {
    final prets = _sources.where((s) => s.pret).length;
    final enLecture = _sources.any((s) => !s.sonde);
    return Ecran(enfants: [
      const Titre('Vidéos dont garder le son'),
      ListeFichiers(sources: _sources, onChange: () => setState(() {})),
      const Titre('Format du son'),
      Pastilles<Format?>(
        options: [null, ...Format.audios],
        valeur: _format,
        libelle: (f) => f?.libelle ?? 'Tel quel',
        onChange: (f) => setState(() => _format = f),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          _format?.aide ?? 'Recopie la piste audio sans la transformer : instantané et sans aucune perte.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      if (_format != null && _format != Format.wav && _format != Format.flac) ...[
        const Titre('Qualité'),
        Pastilles<Qualite>(
          options: Qualite.values,
          valeur: _qualite,
          libelle: (q) => q.libelle,
          onChange: (q) => setState(() => _qualite = q),
        ),
      ],
      const Titre('Destination'),
      const DossierSortie(),
      BoutonLancer(
        libelle: enLecture
            ? 'Lecture des fichiers…'
            : prets == 0
                ? 'Extraire le son'
                : 'Extraire le son de $prets fichier${prets > 1 ? 's' : ''}',
        icone: Icons.graphic_eq,
        onPressed: prets == 0 || enLecture ? null : _lancer,
      ),
    ]);
  }
}
