import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../moteur/execution.dart';
import '../moteur/file_attente.dart';

class EcranTaches extends StatelessWidget {
  const EcranTaches({super.key, this.compact = false});

  /// Colonne latérale sur grand écran.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: fileAttente,
      builder: (context, _) {
        final taches = fileAttente.taches;
        final theme = Theme.of(context);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            // Le bouton peut passer sur deux lignes quand le texte est agrandi (réglage d'accessibilité).
            child: Row(children: [
              if (compact) Text('Tâches', style: theme.textTheme.titleMedium),
              const Spacer(),
              if (taches.any((t) => !t.active))
                Flexible(
                  flex: 4,
                  child: TextButton(
                    onPressed: fileAttente.effacerTerminees,
                    child: const Text('Effacer les terminées', textAlign: TextAlign.end),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: taches.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Les conversions et découpes lancées apparaîtront ici.',
                          textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    itemCount: taches.length,
                    itemBuilder: (context, i) => _CarteTache(taches[i]),
                  ),
          ),
        ]);
      },
    );
  }
}

class _CarteTache extends StatelessWidget {
  const _CarteTache(this.t);
  final Tache t;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final (icone, couleur, etat) = switch (t.etat) {
      EtatTache.attente => (Icons.schedule, c.outline, 'En attente'),
      EtatTache.enCours => (
          Icons.autorenew,
          c.primary,
          t.etapes.length > 1
              ? 'Morceau ${t.faites + 1} sur ${t.etapes.length} · ${(t.progression * 100).round()} %'
              : '${(t.progression * 100).round()} %'
        ),
      EtatTache.finie => (
          Icons.check_circle,
          Colors.green.shade700,
          t.sorties.length > 1 ? '${t.sorties.length} fichiers créés' : 'Terminé'
        ),
      EtatTache.erreur => (Icons.error, c.error, 'Échec'),
      EtatTache.annulee => (Icons.cancel_outlined, c.outline, 'Annulé'),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icone, color: couleur, size: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.titre, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                Text(t.detail, style: theme.textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(etat, style: theme.textTheme.bodySmall?.copyWith(color: couleur, fontWeight: FontWeight.w600)),
              ]),
            ),
            if (t.active)
              IconButton(tooltip: 'Annuler', icon: const Icon(Icons.close), onPressed: () => fileAttente.annuler(t)),
          ]),
          if (t.etat == EtatTache.enCours)
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: LinearProgressIndicator(value: t.progression == 0 ? null : t.progression),
            ),
          if (t.message != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: SelectableText(t.message!, style: theme.textTheme.bodySmall?.copyWith(color: c.error)),
            ),
          if (t.sorties.isNotEmpty && !t.active)
            Wrap(spacing: 4, children: [
              if (t.sorties.length == 1)
                TextButton.icon(
                  onPressed: () => montrer(t.sorties.first),
                  icon: Icon(surBureau ? Icons.folder_open : Icons.ios_share, size: 18),
                  label: Text(_libelle(p.basename(t.sorties.first))),
                )
              else ...[
                TextButton.icon(
                  onPressed: () => montrer(t.sorties.first),
                  icon: Icon(surBureau ? Icons.folder_open : Icons.ios_share, size: 18),
                  label: Text(surBureau ? 'Afficher dans le dossier' : 'Partager le premier'),
                ),
                if (!surBureau)
                  TextButton.icon(
                    onPressed: () => partager(t.sorties),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Tout partager'),
                  ),
              ],
            ]),
        ]),
      ),
    );
  }

  String _libelle(String nom) =>
      surBureau ? (Platform.isMacOS ? 'Afficher dans le Finder' : 'Afficher dans le dossier') : 'Partager $nom';
}
