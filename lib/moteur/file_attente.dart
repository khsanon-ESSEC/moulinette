// File d'attente : les travaux s'exécutent l'un après l'autre, avec progression et annulation.

import 'dart:io';

import 'package:flutter/foundation.dart';

import 'execution.dart';

/// Une commande FFmpeg à lancer, et le fichier qu'elle produit.
class Etape {
  Etape({required this.sortie, required this.duree, required this.commande});
  final String sortie;
  final double duree;

  /// Construite au dernier moment (sur Android, l'entrée SAF ne sert qu'une fois).
  final Future<List<String>> Function() commande;
}

enum EtatTache { attente, enCours, finie, erreur, annulee }

class Tache {
  Tache({required this.titre, required this.detail, required this.etapes});
  final String titre;
  final String detail;
  final List<Etape> etapes;

  EtatTache etat = EtatTache.attente;
  int faites = 0;
  double fraction = 0;
  String? message;
  int? _session;
  bool _annulationDemandee = false;
  final List<String> sorties = [];

  double get progression => etapes.isEmpty ? 1 : ((faites + fraction) / etapes.length).clamp(0, 1).toDouble();
  bool get active => etat == EtatTache.attente || etat == EtatTache.enCours;
}

class FileAttente extends ChangeNotifier {
  final List<Tache> taches = [];
  bool _tourne = false;

  int get actives => taches.where((t) => t.active).length;

  void ajouter(Tache t) {
    taches.insert(0, t);
    notifyListeners();
    _avancer();
  }

  Future<void> annuler(Tache t) async {
    t._annulationDemandee = true;
    if (t.etat == EtatTache.attente) {
      t.etat = EtatTache.annulee;
      notifyListeners();
    } else if (t.etat == EtatTache.enCours) {
      await annulerFfmpeg(t._session);
    }
  }

  void effacerTerminees() {
    taches.removeWhere((t) => !t.active);
    notifyListeners();
  }

  Future<void> _avancer() async {
    if (_tourne) return;
    _tourne = true;
    try {
      while (true) {
        final suivantes = taches.where((t) => t.etat == EtatTache.attente).toList();
        if (suivantes.isEmpty) break;
        await _executer(suivantes.last); // la plus ancienne d'abord
      }
    } finally {
      _tourne = false;
    }
  }

  Future<void> _executer(Tache t) async {
    t.etat = EtatTache.enCours;
    notifyListeners();
    var dernierAvis = DateTime.now();
    for (final e in t.etapes) {
      if (t._annulationDemandee) break;
      t.fraction = 0;
      Resultat r;
      try {
        r = await lancerFfmpeg(
          await e.commande(),
          dureeAttendue: e.duree,
          progression: (f) {
            t.fraction = f;
            // Pas plus de quatre rafraîchissements par seconde (écrans e-ink).
            if (DateTime.now().difference(dernierAvis).inMilliseconds > 250) {
              dernierAvis = DateTime.now();
              notifyListeners();
            }
          },
          surSession: (id) => t._session = id,
        );
      } catch (err) {
        r = Resultat(ok: false, message: '$err');
      }
      if (!r.ok) {
        _effacer(e.sortie);
        t.etat = r.annule || t._annulationDemandee ? EtatTache.annulee : EtatTache.erreur;
        t.message = r.message;
        notifyListeners();
        return;
      }
      t.sorties.add(e.sortie);
      t.faites++;
      notifyListeners();
    }
    t.fraction = 0;
    t.etat = t._annulationDemandee ? EtatTache.annulee : EtatTache.finie;
    notifyListeners();
  }

  void _effacer(String chemin) {
    try {
      final f = File(chemin);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }
}

final fileAttente = FileAttente();
final reglages = Reglages();
