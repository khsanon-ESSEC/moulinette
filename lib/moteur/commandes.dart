// Construit les commandes FFmpeg (listes d'arguments) des trois opérations de l'app.
// Rien ici ne dépend de Flutter : les tests les exécutent avec le FFmpeg du système.

import 'package:path/path.dart' as p;

import 'formats.dart';
import 'temps.dart';

/// Un passage d'un fichier, en secondes.
class Morceau {
  const Morceau(this.debut, this.fin);
  final double debut;
  final double fin;
  double get duree => fin - debut;

  @override
  String toString() => '${ecrireDuree(debut, dixiemes: true)} → ${ecrireDuree(fin, dixiemes: true)}';
}

enum ModeDecoupe {
  parties('En parties égales'),
  duree('Toutes les X minutes'),
  points('Aux moments choisis'),
  passage('Garder un passage');

  const ModeDecoupe(this.libelle);
  final String libelle;
}

/// Découpe une durée totale en morceaux. Lève [FormatException] avec un message lisible si c'est impossible.
List<Morceau> planDecoupe({
  required double dureeTotale,
  required ModeDecoupe mode,
  int parties = 2,
  double dureeMorceau = 600,
  List<double> points = const [],
  double? debut,
  double? fin,
}) {
  if (dureeTotale <= 0) throw const FormatException('La durée du fichier est inconnue.');
  final morceaux = <Morceau>[];
  switch (mode) {
    case ModeDecoupe.parties:
      if (parties < 2) throw const FormatException('Il faut au moins 2 parties.');
      if (parties > 500) throw const FormatException('500 parties au plus.');
      final pas = dureeTotale / parties;
      for (var i = 0; i < parties; i++) {
        morceaux.add(Morceau(i * pas, i == parties - 1 ? dureeTotale : (i + 1) * pas));
      }
    case ModeDecoupe.duree:
      if (dureeMorceau < 1) throw const FormatException('Chaque morceau doit durer au moins 1 seconde.');
      if (dureeTotale / dureeMorceau > 500) throw const FormatException('Cela ferait plus de 500 morceaux.');
      for (var t = 0.0; t < dureeTotale - 0.05; t += dureeMorceau) {
        morceaux.add(Morceau(t, (t + dureeMorceau).clamp(0, dureeTotale).toDouble()));
      }
      // Un dernier bout de moins d'une seconde est rattaché au morceau précédent.
      if (morceaux.length > 1 && morceaux.last.duree < 1) {
        final dernier = morceaux.removeLast();
        morceaux[morceaux.length - 1] = Morceau(morceaux.last.debut, dernier.fin);
      }
    case ModeDecoupe.points:
      final tries = points.where((t) => t > 0.05 && t < dureeTotale - 0.05).toSet().toList()..sort();
      if (tries.isEmpty) {
        throw FormatException('Indiquez au moins un moment entre 0:00 et ${ecrireDuree(dureeTotale)}.');
      }
      var precedent = 0.0;
      for (final t in [...tries, dureeTotale]) {
        morceaux.add(Morceau(precedent, t));
        precedent = t;
      }
    case ModeDecoupe.passage:
      final d = debut ?? 0, f = fin ?? dureeTotale;
      if (d < 0 || d >= dureeTotale) throw const FormatException('Le début est après la fin du fichier.');
      if (f <= d) throw const FormatException('La fin doit venir après le début.');
      morceaux.add(Morceau(d, f > dureeTotale ? dureeTotale : f));
  }
  return morceaux;
}

/// Commande de conversion d'un fichier vers [format].
/// Avec [sansReencodage], les flux sont recopiés tels quels (rapide, sans perte, mais pas toujours possible).
List<String> commandeConversion({
  required String entree,
  required String sortie,
  required Format format,
  Qualite qualite = Qualite.normale,
  Definition definition = Definition.originale,
  bool sansReencodage = false,
}) {
  return [
    '-hide_banner', '-y', '-i', entree,
    if (sansReencodage) ...['-map', '0:v?', '-map', '0:a?', '-c', 'copy'] else ...[
      // Première piste vidéo et première piste audio, si elles existent.
      if (format.video && format != Format.gif) ...['-map', '0:v:0?', '-map', '0:a:0?'],
      if (!format.video) ...['-map', '0:a:0'],
      ...argumentsEncodage(format, qualite, definition: definition),
    ],
    if (sansReencodage && (format == Format.mp4 || format == Format.mov)) ...['-movflags', '+faststart'],
    sortie,
  ];
}

/// Commande d'extraction de la piste audio. Sans [format], la piste est recopiée telle quelle.
List<String> commandeExtraction({
  required String entree,
  required String sortie,
  Format? format,
  Qualite qualite = Qualite.normale,
}) {
  return [
    '-hide_banner', '-y', '-i', entree, '-map', '0:a:0', '-vn', '-sn', '-dn',
    if (format == null) ...['-c:a', 'copy'] else ...argumentsEncodage(format, qualite),
    sortie,
  ];
}

/// Commande qui produit un morceau. En mode rapide, les flux sont recopiés (la coupe tombe sur l'image clé
/// la plus proche) ; en mode précis, le morceau est réencodé dans le format du fichier d'origine.
List<String> commandeMorceau({
  required String entree,
  required String sortie,
  required Morceau morceau,
  required bool precis,
  required bool video,
}) {
  final ext = p.extension(sortie);
  final format = Format.depuisExtension(ext) ?? (video ? Format.mp4 : Format.m4a);
  return [
    '-hide_banner', '-y',
    if (morceau.debut > 0) ...['-ss', pourFfmpeg(morceau.debut)],
    '-i', entree,
    '-t', pourFfmpeg(morceau.duree),
    if (precis) ...[
      if (video) ...['-map', '0:v:0?', '-map', '0:a:0?'] else ...['-map', '0:a:0'],
      ...argumentsEncodage(format, Qualite.haute),
    ] else ...['-map', '0', '-c', 'copy', '-avoid_negative_ts', 'make_zero'],
    sortie,
  ];
}

/// Nom de sortie libre dans [dossier] : « nom.ext », sinon « nom (2).ext », « nom (3).ext »…
String cheminLibre(String dossier, String nom, String extension, bool Function(String) existe) {
  var chemin = p.join(dossier, '$nom.$extension');
  for (var i = 2; existe(chemin); i++) {
    chemin = p.join(dossier, '$nom ($i).$extension');
  }
  return chemin;
}
