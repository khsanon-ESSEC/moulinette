// Lecture et écriture des durées : « 90 », « 1:30 », « 01:02:03.5 », « 1h30 », « 5m », « 45s ».

/// Lit une durée saisie par l'utilisateur et la rend en secondes, ou `null` si elle est illisible.
double? lireDuree(String texte) {
  var t = texte.trim().toLowerCase().replaceAll(',', '.').replaceAll(' ', '');
  if (t.isEmpty) return null;
  // Forme « 1h30m15s », « 1h30 », « 5m », « 45s », « 2min ».
  final unites = RegExp(r'^(?:(\d+(?:\.\d+)?)h)?(?:(\d+(?:\.\d+)?)(?:min|m))?(?:(\d+(?:\.\d+)?)s?)?$');
  if (RegExp(r'[hms]').hasMatch(t)) {
    t = t.replaceAll('min', 'm');
    final m = unites.firstMatch(t);
    if (m == null) return null;
    final h = double.tryParse(m.group(1) ?? '') ?? 0;
    final mi = double.tryParse(m.group(2) ?? '') ?? 0;
    // Après des heures, un nombre seul compte en minutes (« 1h30 ») ; sinon en secondes.
    var s = double.tryParse(m.group(3) ?? '') ?? 0;
    if (m.group(1) != null && m.group(2) == null && m.group(3) != null && !t.endsWith('s')) {
      return h * 3600 + s * 60;
    }
    return h * 3600 + mi * 60 + s;
  }
  // Forme « hh:mm:ss.ms », « mm:ss » ou secondes seules.
  final morceaux = t.split(':');
  if (morceaux.length > 3) return null;
  var total = 0.0;
  for (final m in morceaux) {
    final v = double.tryParse(m);
    if (v == null || v < 0) return null;
    total = total * 60 + v;
  }
  return total;
}

/// Écrit une durée en « h:mm:ss » (ou « m:ss »), avec les dixièmes s'il y en a.
String ecrireDuree(double secondes, {bool dixiemes = false}) {
  if (secondes.isNaN || secondes < 0) secondes = 0;
  final entier = secondes.floor();
  final h = entier ~/ 3600, m = (entier % 3600) ~/ 60, s = entier % 60;
  final d = ((secondes - entier) * 10).floor();
  final base = h > 0
      ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
      : '$m:${s.toString().padLeft(2, '0')}';
  return dixiemes && d > 0 ? '$base.$d' : base;
}

/// Valeur passée à FFmpeg pour -ss et -t : secondes avec trois décimales.
String pourFfmpeg(double secondes) => secondes.toStringAsFixed(3);
