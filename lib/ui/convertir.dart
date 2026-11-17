import 'package:flutter/material.dart';

import '../moteur/commandes.dart';
import '../moteur/execution.dart';
import '../moteur/file_attente.dart';
import '../moteur/formats.dart';
import 'communs.dart';

class EcranConvertir extends StatefulWidget {
  const EcranConvertir({super.key, required this.lance});
  final VoidCallback lance;
  @override
  State<EcranConvertir> createState() => _EcranConvertirState();
}

class _EcranConvertirState extends State<EcranConvertir> {
  final _sources = <Source>[];
  bool _video = true;
  Format _format = Format.mp4;
  Qualite _qualite = Qualite.normale;
  Definition _definition = Definition.originale;
  bool _sansReencodage = false;

  bool get _copiePossible => _format.video && _format != Format.gif;

  Future<void> _lancer() async {
    final valides = _sources.where((s) => s.erreur == null).toList();
    var ignorees = 0;
    for (final s in valides) {
      if (_format.video && s.aDeLaVideo == false) {
        ignorees++;
        continue;
      }
      final dossier = await reglages.dossierPour(s);
      final sortie = reserverChemin(dossier, s.base, _format.extension);
      final format = _format, qualite = _qualite, definition = _definition;
      final copie = _sansReencodage && _copiePossible;
      fileAttente.ajouter(Tache(
        titre: s.nom,
        detail: '→ ${format.libelle}${copie ? ' sans réencodage' : ' · ${qualite.libelle.toLowerCase()}'}',
        etapes: [
          Etape(
            sortie: sortie,
            duree: s.duree ?? 0,
            commande: () async => commandeConversion(
              entree: await s.entree(),
              sortie: sortie,
              format: format,
              qualite: qualite,
              definition: definition,
              sansReencodage: copie,
            ),
          ),
        ],
      ));
    }
    if (!mounted) return;
    if (ignorees > 0) informer(context, '$ignorees fichier(s) audio ignoré(s) : pas d’image à mettre en vidéo.');
    setState(_sources.clear);
    widget.lance();
  }

  @override
  Widget build(BuildContext context) {
    final prets = _sources.where((s) => s.erreur == null && s.duree != null).length;
    final enLecture = _sources.any((s) => s.erreur == null && s.duree == null);
    return Ecran(enfants: [
      const Titre('Fichiers à convertir'),
      ListeFichiers(sources: _sources, onChange: () => setState(() {})),
      const Titre('Convertir en'),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: true, label: Text('Vidéo'), icon: Icon(Icons.movie_outlined)),
          ButtonSegment(value: false, label: Text('Audio'), icon: Icon(Icons.music_note_outlined)),
        ],
        selected: {_video},
        onSelectionChanged: (v) => setState(() {
          _video = v.first;
          _format = _video ? Format.mp4 : Format.mp3;
        }),
      ),
      const SizedBox(height: 12),
      Pastilles<Format>(
        options: _video ? Format.videos : Format.audios,
        valeur: _format,
        libelle: (f) => f.libelle,
        aide: (f) => f.aide,
        onChange: (f) => setState(() => _format = f),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(_format.aide, style: Theme.of(context).textTheme.bodySmall),
      ),
      if (_copiePossible)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sans réencodage'),
          subtitle: const Text('Change seulement l’enveloppe du fichier : instantané et sans perte, '
              'mais pas toujours possible.'),
          value: _sansReencodage,
          onChanged: (v) => setState(() => _sansReencodage = v),
        ),
      if (!(_copiePossible && _sansReencodage) && _format != Format.wav && _format != Format.flac) ...[
        const Titre('Qualité'),
        Pastilles<Qualite>(
          options: Qualite.values,
          valeur: _qualite,
          libelle: (q) => q.libelle,
          onChange: (q) => setState(() => _qualite = q),
        ),
      ],
      if (_copiePossible && !_sansReencodage) ...[
        const Titre('Taille de l’image (au plus)'),
        Pastilles<Definition>(
          options: Definition.values,
          valeur: _definition,
          libelle: (d) => d.libelle,
          onChange: (d) => setState(() => _definition = d),
        ),
      ],
      const Titre('Destination'),
      const DossierSortie(),
      BoutonLancer(
        libelle: enLecture
            ? 'Lecture des fichiers…'
            : prets == 0
                ? 'Convertir'
                : 'Convertir $prets fichier${prets > 1 ? 's' : ''} en ${_format.libelle}',
        icone: Icons.autorenew,
        onPressed: prets == 0 || enLecture ? null : _lancer,
      ),
    ]);
  }
}
