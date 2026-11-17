// Fait tourner le FFmpeg intégré à l'app (pas celui du système) sur chaque opération.
// flutter test integration_test -d macos
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:moulinette/moteur/commandes.dart';
import 'package:moulinette/moteur/execution.dart';
import 'package:moulinette/moteur/file_attente.dart';
import 'package:moulinette/moteur/formats.dart';
import 'package:path/path.dart' as p;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory dossier;
  late Source video;

  Future<Resultat> lancer(List<String> args, double duree) =>
      lancerFfmpeg(args, dureeAttendue: duree, progression: (_) {}, surSession: (_) {});

  setUpAll(() async {
    dossier = await Directory.systemTemp.createTemp('moulinette_app');
    final chemin = p.join(dossier.path, 'clip été.mp4');
    final r = await lancer([
      '-y',
      '-f',
      'lavfi',
      '-i',
      'testsrc=size=320x240:rate=25:duration=10',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:duration=10',
      '-c:v',
      'libx264',
      '-g',
      '25',
      '-c:a',
      'aac',
      '-shortest',
      chemin,
    ], 10);
    expect(r.ok, isTrue, reason: r.message);
    video = Source(nom: p.basename(chemin), chemin: chemin);
    await video.sonder();
  });
  tearDownAll(() => dossier.delete(recursive: true));

  testWidgets('dossier de sortie par défaut', (_) async {
    final reglages = Reglages();
    final d = await reglages.dossierPour(video);
    // T-007 : sur Android 10 et avant, sans l'autorisation « stockage », repli sur le dossier de l'app, annoncé.
    // --dart-define=STOCKAGE=refuse quand le test tourne avec l'autorisation refusée.
    if (Platform.isAndroid && const String.fromEnvironment('STOCKAGE') == 'refuse') {
      expect(d, contains('/Android/data/ht.khsanon.moulinette/'));
      expect(reglages.description, startsWith('Autorisation refusée'));
    } else if (Platform.isAndroid) {
      expect(d, '/storage/emulated/0/Download/Moulinette');
      expect(reglages.description, 'Téléchargements › Moulinette');
    }
    final f = File(p.join(d, 'essai-moulinette.txt'));
    await f.writeAsString('ok');
    await f.delete();
  });

  testWidgets('sonde', (_) async {
    expect(video.duree, closeTo(10, 0.2));
    expect(video.aDeLaVideo, isTrue);
    expect(video.codecAudio, 'aac');
  });

  testWidgets('T-003 : fichier sans durée connue, prêt quand même et convertible', (_) async {
    final brut = p.join(dossier.path, 'flux brut.mkv');
    expect(
      (await lancer([
        '-y',
        '-f',
        'lavfi',
        '-i',
        'testsrc=duration=2:size=160x120',
        '-c:v',
        'libx264',
        '-f',
        'h264',
        brut,
      ], 2)).ok,
      isTrue,
    );
    final s = Source(nom: 'flux brut.mkv', chemin: brut);
    expect(s.sonde, isFalse);
    await s.sonder();
    expect(s.sonde, isTrue);
    expect(s.duree, isNull);
    expect(s.pret, isTrue);
    final r = await lancer(
      commandeConversion(entree: brut, sortie: p.join(dossier.path, 'flux.mp4'), format: Format.mp4),
      0,
    );
    expect(r.ok, isTrue, reason: r.message);
    final vide = p.join(dossier.path, 'vide.mp4');
    await File(vide).writeAsString('');
    final v = Source(nom: 'vide.mp4', chemin: vide);
    await v.sonder();
    expect(v.sonde, isTrue);
    expect(v.pret, isFalse);
  });

  testWidgets('OGG avec une piste de type inconnu : découpe rapide et précise', (_) async {
    // Comme le fichier d'enregistreur signalé sous Windows : on fabrique un OGG à deux pistes Opus, puis on rend
    // la 2e méconnaissable pour FFmpeg (son en-tête « OpusHead » devient « ZzzzHead »).
    final deux = p.join(dossier.path, 'deux.ogg');
    final r = await lancer([
      '-y',
      '-f',
      'lavfi',
      '-i',
      'sine=d=4',
      '-f',
      'lavfi',
      '-i',
      'sine=f=300:d=4',
      '-map',
      '0',
      '-map',
      '1',
      '-c:a',
      'libopus',
      deux,
    ], 4);
    expect(r.ok, isTrue, reason: r.message);
    final source = p.join(dossier.path, 'enregistrement.ogg');
    await File(source).writeAsBytes(pisteInconnue(await File(deux).readAsBytes()));
    for (final precis in [false, true]) {
      final plan = planDecoupe(dureeTotale: 4, mode: ModeDecoupe.parties, parties: 2);
      for (var i = 0; i < plan.length; i++) {
        final sortie = p.join(dossier.path, 'morceau ${precis}_$i.ogg');
        final m = await lancer(
          commandeMorceau(entree: source, sortie: sortie, morceau: plan[i], precis: precis, video: false),
          2,
        );
        expect(m.ok, isTrue, reason: 'précis=$precis : ${m.message}');
        final s = Source(nom: p.basename(sortie), chemin: sortie);
        await s.sonder();
        expect(s.duree, closeTo(2, 0.2));
      }
    }
  });

  testWidgets('tous les formats', (_) async {
    for (final f in Format.values) {
      final sortie = p.join(dossier.path, 'c.${f.extension}');
      final r = await lancer(
        commandeConversion(
          entree: video.chemin!,
          sortie: sortie,
          format: f,
          qualite: Qualite.compacte,
          definition: Definition.p480,
        ),
        10,
      );
      expect(r.ok, isTrue, reason: '${f.libelle}: ${r.message}');
      final s = Source(nom: p.basename(sortie), chemin: sortie);
      await s.sonder();
      expect(s.duree, closeTo(10, 0.6), reason: f.libelle);
    }
  });

  testWidgets('file d’attente : extraction et découpe avec progression', (_) async {
    final mp3 = p.join(dossier.path, 'son.mp3');
    final t1 = Tache(
      titre: 'x',
      detail: '',
      etapes: [
        Etape(
          sortie: mp3,
          duree: 10,
          commande: () async => commandeExtraction(entree: await video.entree(), sortie: mp3, format: Format.mp3),
        ),
      ],
    );
    final plan = planDecoupe(dureeTotale: video.duree!, mode: ModeDecoupe.parties, parties: 3);
    final t2 = Tache(
      titre: 'y',
      detail: '',
      etapes: [
        for (var i = 0; i < 3; i++)
          Etape(
            sortie: p.join(dossier.path, 'partie $i.mp4'),
            duree: plan[i].duree,
            commande: () async => commandeMorceau(
              entree: await video.entree(),
              sortie: p.join(dossier.path, 'partie $i.mp4'),
              morceau: plan[i],
              precis: true,
              video: true,
            ),
          ),
      ],
    );
    fileAttente.ajouter(t1);
    fileAttente.ajouter(t2);
    while (fileAttente.actives > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(t1.etat, EtatTache.finie, reason: t1.message);
    expect(t2.etat, EtatTache.finie, reason: t2.message);
    expect(t2.sorties.length, 3);
    for (final s in t2.sorties) {
      final src = Source(nom: p.basename(s), chemin: s);
      await src.sonder();
      expect(src.duree, closeTo(10 / 3, 0.15));
    }
  });

  testWidgets('T-008 : annuler aussitôt n’arrête que cette tâche', (_) async {
    final long = p.join(dossier.path, 'aussitot.mkv');
    final t = Tache(
      titre: 'x',
      detail: '',
      etapes: [
        Etape(
          sortie: long,
          duree: 600,
          commande: () async {
            await Future<void>.delayed(const Duration(milliseconds: 300)); // comme l'ouverture SAF sur Android
            return ['-y', '-f', 'lavfi', '-i', 'testsrc=size=1280x720:rate=30:duration=600', '-c:v', 'libx264', long];
          },
        ),
      ],
    );
    final lecture = Source(nom: video.nom, chemin: video.chemin);
    fileAttente.ajouter(t);
    final sonde = lecture.sonder();
    await fileAttente.annuler(t); // avant que la session FFmpeg ait un identifiant
    await sonde;
    while (t.active) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(t.etat, EtatTache.annulee);
    expect(lecture.erreur, isNull);
    expect(lecture.duree, closeTo(10, 0.2));
    expect(File(long).existsSync(), isFalse);
  });

  testWidgets('annulation et message d’erreur', (_) async {
    final long = p.join(dossier.path, 'long.mkv');
    final t = Tache(
      titre: 'long',
      detail: '',
      etapes: [
        Etape(
          sortie: long,
          duree: 600,
          commande: () async => [
            '-y',
            '-f',
            'lavfi',
            '-i',
            'testsrc=size=1280x720:rate=30:duration=600',
            '-c:v',
            'libx264',
            '-preset',
            'veryslow',
            long,
          ],
        ),
      ],
    );
    fileAttente.ajouter(t);
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(t.etat, EtatTache.enCours);
    await fileAttente.annuler(t);
    while (t.active) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(t.etat, EtatTache.annulee);
    expect(File(long).existsSync(), isFalse);

    final audio = p.join(dossier.path, 'son seul.wav');
    expect((await lancer(['-y', '-f', 'lavfi', '-i', 'sine=duration=2', audio], 2)).ok, isTrue);
    final r = await lancer(
      commandeConversion(entree: audio, sortie: p.join(dossier.path, 'x.mp4'), format: Format.mp4),
      2,
    );
    // Un fichier sans image converti en MP4 donne un MP4 audio seul : l'écran filtre ce cas avant.
    expect(r.ok, isTrue);
    final r2 = await lancer(
      commandeExtraction(
        entree: p.join(dossier.path, 'partie 0.mp4'),
        sortie: p.join(dossier.path, 'z.mp3'),
        format: Format.mp3,
      ),
      3,
    );
    expect(r2.ok, isTrue);
    final r3 = await lancer(
      commandeExtraction(
        entree: p.join(dossier.path, 'c.gif'),
        sortie: p.join(dossier.path, 'z2.mp3'),
        format: Format.mp3,
      ),
      3,
    );
    expect(r3.ok, isFalse);
    expect(r3.message, contains('piste'));
  });
}

/// Renomme l'en-tête de la 2e piste d'un OGG pour que FFmpeg la voie comme « Unknown: none », et recalcule la
/// somme de contrôle de chaque page.
Uint8List pisteInconnue(Uint8List d) {
  final table = List<int>.generate(256, (i) {
    var r = i << 24;
    for (var k = 0; k < 8; k++) {
      r = (r & 0x80000000) != 0 ? ((r << 1) ^ 0x04c11db7) : r << 1;
    }
    return r & 0xffffffff;
  });
  int crc(Uint8List b) {
    var c = 0;
    for (final x in b) {
      c = ((c << 8) ^ table[((c >> 24) & 0xff) ^ x]) & 0xffffffff;
    }
    return c;
  }

  final sortie = BytesBuilder();
  final series = <int>[];
  var pos = 0;
  while (pos < d.length) {
    final n = d[pos + 26];
    final entete = 27 + n;
    var corps = 0;
    for (var i = 0; i < n; i++) {
      corps += d[pos + 27 + i];
    }
    final page = Uint8List.fromList(d.sublist(pos, pos + entete + corps));
    final serie = ByteData.sublistView(page, 14, 18).getUint32(0, Endian.little);
    if (!series.contains(serie)) series.add(serie);
    if (series.length > 1 && serie == series[1]) {
      for (var i = entete; i + 8 <= page.length; i++) {
        if (String.fromCharCodes(page.sublist(i, i + 4)) == 'Opus' &&
            ['Head', 'Tags'].contains(String.fromCharCodes(page.sublist(i + 4, i + 8)))) {
          page.setRange(i, i + 4, 'Zzzz'.codeUnits);
        }
      }
    }
    page.fillRange(22, 26, 0);
    ByteData.sublistView(page).setUint32(22, crc(page), Endian.little);
    sortie.add(page);
    pos += entete + corps;
  }
  return sortie.toBytes();
}
