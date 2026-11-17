// Éléments partagés par les trois écrans.

import 'dart:io';

import 'package:flutter/material.dart';

import '../moteur/commandes.dart';
import '../moteur/execution.dart';
import '../moteur/file_attente.dart';
import '../moteur/temps.dart';

final _reserves = <String>{};

/// Chemin de sortie libre, en tenant compte des fichiers déjà prévus par les tâches en attente.
String reserverChemin(String dossier, String nom, String extension) {
  final c = cheminLibre(dossier, nom, extension, (x) => _reserves.contains(x) || File(x).existsSync());
  _reserves.add(c);
  return c;
}

void informer(BuildContext context, String texte) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texte), behavior: SnackBarBehavior.floating));
}

/// Titre de section.
class Titre extends StatelessWidget {
  const Titre(this.texte, {super.key});
  final String texte;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(texte, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
      );
}

/// Liste des fichiers choisis, avec leur durée, et le bouton pour en ajouter.
class ListeFichiers extends StatefulWidget {
  const ListeFichiers({super.key, required this.sources, required this.onChange, this.plusieurs = true});
  final List<Source> sources;
  final VoidCallback onChange;
  final bool plusieurs;

  @override
  State<ListeFichiers> createState() => _ListeFichiersState();
}

class _ListeFichiersState extends State<ListeFichiers> {
  bool _choix = false;

  Future<void> _ajouter({bool depuisPhotos = false}) async {
    setState(() => _choix = true);
    try {
      final nouvelles = await choisirFichiers(plusieurs: widget.plusieurs, depuisPhotos: depuisPhotos);
      if (nouvelles.isEmpty) return;
      if (!widget.plusieurs) widget.sources.clear();
      widget.sources.addAll(nouvelles);
      widget.onChange();
      await Future.wait(nouvelles.map((s) => s.sonder()));
      if (mounted) widget.onChange();
    } catch (e) {
      if (mounted) informer(context, 'Impossible d’ouvrir ces fichiers : $e');
    } finally {
      if (mounted) setState(() => _choix = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in widget.sources)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: Icon(
                s.erreur != null
                    ? Icons.error_outline
                    : s.aDeLaVideo == true
                        ? Icons.movie_outlined
                        : Icons.music_note_outlined,
                color: s.erreur != null ? couleurs.error : null,
              ),
              title: Text(s.nom, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(s.erreur ??
                  (!s.sonde
                      ? 'Lecture…'
                      : '${s.duree == null ? 'durée inconnue' : ecrireDuree(s.duree!)} · '
                          '${s.aDeLaVideo == true ? 'vidéo' : 'audio'}'
                          '${s.aDeLaVideo == true && s.aDuSon == false ? ' sans son' : ''}')),
              trailing: IconButton(
                tooltip: 'Retirer',
                icon: const Icon(Icons.close),
                onPressed: () {
                  widget.sources.remove(s);
                  widget.onChange();
                },
              ),
            ),
          ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: _choix ? null : _ajouter,
          icon: const Icon(Icons.folder_open),
          label: Text(widget.sources.isEmpty
              ? (widget.plusieurs ? 'Choisir des fichiers' : 'Choisir un fichier')
              : (widget.plusieurs ? 'Ajouter des fichiers' : 'Choisir un autre fichier')),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        ),
        // Sur iPad, le bouton ci-dessus ouvre l'app Fichiers ; les vidéos de la photothèque ont leur propre bouton.
        if (aUnePhototheque)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: _choix ? null : () => _ajouter(depuisPhotos: true),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Depuis Photos'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ),
      ],
    );
  }
}

/// Ligne « Enregistrer dans … [Changer] ».
class DossierSortie extends StatelessWidget {
  const DossierSortie({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: reglages,
      builder: (context, _) => Card(
        child: ListTile(
          leading: const Icon(Icons.save_alt),
          title: const Text('Enregistrer dans'),
          subtitle: Text(reglages.description, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: !reglages.peutChanger
              ? null
              : Wrap(spacing: 4, children: [
                  if (reglages.dossierChoisi != null)
                    IconButton(
                      tooltip: 'Revenir au dossier par défaut',
                      icon: const Icon(Icons.undo),
                      onPressed: reglages.parDefaut,
                    ),
                  TextButton(
                    onPressed: () async {
                      try {
                        await reglages.changer();
                      } on FileSystemException catch (e) {
                        if (context.mounted) informer(context, e.message);
                      }
                    },
                    child: const Text('Changer'),
                  ),
                ]),
        ),
      ),
    );
  }
}

/// Bouton principal en bas d'écran.
class BoutonLancer extends StatelessWidget {
  const BoutonLancer({super.key, required this.libelle, required this.onPressed, this.icone = Icons.play_arrow});
  final String libelle;
  final VoidCallback? onPressed;
  final IconData icone;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 32),
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icone),
          label: Text(libelle),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18), textStyle: const TextStyle(fontSize: 16)),
        ),
      );
}

/// Page défilante, centrée et de largeur limitée sur grand écran.
class Ecran extends StatelessWidget {
  const Ecran({super.key, required this.enfants});
  final List<Widget> enfants;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), children: enfants),
        ),
      );
}

/// Choix parmi quelques options, en pastilles.
class Pastilles<T> extends StatelessWidget {
  const Pastilles({super.key, required this.options, required this.valeur, required this.libelle, required this.onChange, this.aide});
  final List<T> options;
  final T valeur;
  final String Function(T) libelle;
  final String? Function(T)? aide;
  final ValueChanged<T> onChange;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final o in options)
            ChoiceChip(
              label: Text(libelle(o)),
              tooltip: aide?.call(o),
              selected: o == valeur,
              onSelected: (_) => onChange(o),
            ),
        ],
      );
}
