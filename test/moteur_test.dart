// Teste les commandes avec le vrai FFmpeg du Mac (Homebrew) : chaque format est réellement produit puis relu.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moulinette/moteur/commandes.dart';
import 'package:moulinette/moteur/formats.dart';
import 'package:moulinette/moteur/temps.dart';
import 'package:path/path.dart' as p;

const ffmpeg = '/opt/homebrew/bin/ffmpeg';
const ffprobe = '/opt/homebrew/bin/ffprobe';
final avecFfmpeg = File(ffmpeg).existsSync();
final encodeurs = avecFfmpeg ? Process.runSync(ffmpeg, ['-hide_banner', '-encoders']).stdout as String : '';

late Directory dossier;
late String video;
late String audio;

Future<void> lancer(List<String> args) async {
  final r = await Process.run(ffmpeg, ['-loglevel', 'error', ...args]);
  expect(r.exitCode, 0, reason: 'ffmpeg ${args.join(' ')}\n${r.stderr}');
}

Future<Map<String, dynamic>> sonder(String fichier) async {
  final r = await Process.run(ffprobe, ['-v', 'error', '-print_format', 'json', '-show_format', '-show_streams', fichier]);
  expect(r.exitCode, 0, reason: r.stderr.toString());
  return jsonDecode(r.stdout as String) as Map<String, dynamic>;
}

Future<double> duree(String fichier) async => double.parse((await sonder(fichier))['format']['duration'] as String);

Future<List<String>> typesDeFlux(String fichier) async =>
    [for (final s in (await sonder(fichier))['streams'] as List) s['codec_type'] as String];

void main() {
  group('durées', () {
    test('lecture', () {
      expect(lireDuree('90'), 90);
      expect(lireDuree('1:30'), 90);
      expect(lireDuree('01:02:03'), 3723);
      expect(lireDuree('1:30,5'), 90.5);
      expect(lireDuree('5m'), 300);
      expect(lireDuree('2 min'), 120);
      expect(lireDuree('45s'), 45);
      expect(lireDuree('1h30'), 5400);
      expect(lireDuree('1h30s'), 3630);
      expect(lireDuree('2m30'), 150);
      expect(lireDuree('abc'), isNull);
      expect(lireDuree('1:2:3:4'), isNull);
      expect(lireDuree(''), isNull);
    });
    test('écriture', () {
      expect(ecrireDuree(90), '1:30');
      expect(ecrireDuree(3723), '1:02:03');
      expect(ecrireDuree(5.25, dixiemes: true), '0:05.2');
    });
  });

  group('plans de découpe', () {
    test('parties égales', () {
      final m = planDecoupe(dureeTotale: 100, mode: ModeDecoupe.parties, parties: 3);
      expect(m.length, 3);
      expect(m.last.fin, 100);
      expect(m[1].debut, closeTo(33.33, 0.01));
    });
    test('toutes les X secondes, petit reste rattaché', () {
      final m = planDecoupe(dureeTotale: 600.5, mode: ModeDecoupe.duree, dureeMorceau: 120);
      expect(m.length, 5);
      expect(m.last.fin, 600.5);
    });
    test('points', () {
      final m = planDecoupe(dureeTotale: 60, mode: ModeDecoupe.points, points: [40, 10, 10, 70]);
      expect(m.map((x) => [x.debut, x.fin]).toList(), [[0, 10], [10, 40], [40, 60]]);
    });
    test('passage et erreurs', () {
      expect(planDecoupe(dureeTotale: 60, mode: ModeDecoupe.passage, debut: 10, fin: 90).single.fin, 60);
      expect(() => planDecoupe(dureeTotale: 60, mode: ModeDecoupe.passage, debut: 30, fin: 20), throwsFormatException);
      expect(() => planDecoupe(dureeTotale: 60, mode: ModeDecoupe.points, points: []), throwsFormatException);
    });
  });

  test('chemin libre', () {
    final pris = {'/d/a.mp3', '/d/a (2).mp3'};
    expect(cheminLibre('/d', 'a', 'mp3', pris.contains), '/d/a (3).mp3');
  });

  group('FFmpeg réel', skip: avecFfmpeg ? false : 'ffmpeg absent', () {
    setUpAll(() async {
      dossier = await Directory.systemTemp.createTemp('moulinette');
      video = p.join(dossier.path, 'source avec espaces.mp4');
      audio = p.join(dossier.path, 'son.wav');
      await lancer(['-f', 'lavfi', '-i', 'testsrc=size=320x240:rate=25:duration=12', '-f', 'lavfi', '-i',
        'sine=frequency=440:duration=12', '-c:v', 'libx264', '-g', '25', '-c:a', 'aac', '-shortest', video]);
      await lancer(['-f', 'lavfi', '-i', 'sine=frequency=330:duration=9', audio]);
    });
    tearDownAll(() => dossier.delete(recursive: true));

    for (final f in Format.values) {
      // Le FFmpeg de Homebrew n'a pas toujours libvorbis ; celui de l'app l'a.
      final manque = f == Format.ogg && !encodeurs.contains('libvorbis');
      test('conversion vidéo → ${f.libelle}', skip: manque ? 'libvorbis absent du FFmpeg système' : false, () async {
        final sortie = p.join(dossier.path, 'conv.${f.extension}');
        await lancer(commandeConversion(entree: video, sortie: sortie, format: f, qualite: Qualite.compacte,
            definition: Definition.p480));
        final types = await typesDeFlux(sortie);
        expect(types.contains('video'), f.video);
        expect(types.contains('audio'), f != Format.gif);
        expect(await duree(sortie), closeTo(12, 0.6));
      });
    }

    test('conversion audio → vidéo impossible mais audio → mp3 possible', () async {
      final sortie = p.join(dossier.path, 'son.mp3');
      await lancer(commandeConversion(entree: audio, sortie: sortie, format: Format.mp3));
      expect(await duree(sortie), closeTo(9, 0.2));
    });

    test('conversion sans réencodage mp4 → mkv', () async {
      final sortie = p.join(dossier.path, 'copie.mkv');
      await lancer(commandeConversion(entree: video, sortie: sortie, format: Format.mkv, sansReencodage: true));
      expect(await typesDeFlux(sortie), ['video', 'audio']);
    });

    test('extraction telle quelle et en mp3', () async {
      final brut = p.join(dossier.path, 'audio.${extensionPourCodecAudio('aac')}');
      await lancer(commandeExtraction(entree: video, sortie: brut));
      expect(await typesDeFlux(brut), ['audio']);
      final mp3 = p.join(dossier.path, 'audio.mp3');
      await lancer(commandeExtraction(entree: video, sortie: mp3, format: Format.mp3));
      expect(await typesDeFlux(mp3), ['audio']);
      expect(await duree(mp3), closeTo(12, 0.2));
    });

    test('T-004 : extraction telle quelle du PCM de caméra (gros-boutiste) vers WAV', () async {
      expect(extractionTelleQuelle('pcm_s16le').arguments, ['-c:a', 'copy']);
      expect(extractionTelleQuelle('pcm_s24be').arguments, ['-c:a', 'pcm_s24le']);
      expect(extractionTelleQuelle('pcm_s8').arguments, ['-c:a', 'pcm_s24le']);
      for (final codec in ['pcm_s16be', 'pcm_s24be', 'pcm_s16le']) {
        final mov = p.join(dossier.path, 'camera $codec.mov');
        await lancer(['-f', 'lavfi', '-i', 'testsrc=duration=3:size=160x120', '-f', 'lavfi', '-i', 'sine=duration=3',
          '-c:v', 'libx264', '-c:a', codec, '-shortest', mov]);
        final sortie = p.join(dossier.path, 'camera $codec.${extensionPourCodecAudio(codec)}');
        await lancer(commandeExtraction(entree: mov, sortie: sortie, codecAudio: codec));
        expect(await typesDeFlux(sortie), ['audio']);
        expect(await duree(sortie), closeTo(3, 0.1));
      }
    });

    for (final precis in [false, true]) {
      test('découpe vidéo en 3 (${precis ? 'précise' : 'rapide'})', () async {
        final plan = planDecoupe(dureeTotale: await duree(video), mode: ModeDecoupe.parties, parties: 3);
        for (var i = 0; i < plan.length; i++) {
          final sortie = p.join(dossier.path, 'partie ${precis}_$i.mp4');
          await lancer(commandeMorceau(entree: video, sortie: sortie, morceau: plan[i], precis: precis, video: true));
          expect(await typesDeFlux(sortie), containsAll(['video', 'audio']));
          expect(await duree(sortie), closeTo(4, precis ? 0.15 : 1.1));
        }
      });
    }

    test('passage audio précis', () async {
      final sortie = p.join(dossier.path, 'passage.wav');
      await lancer(commandeMorceau(entree: audio, sortie: sortie, morceau: const Morceau(2, 5.5), precis: true, video: false));
      expect(await duree(sortie), closeTo(3.5, 0.05));
    });
  });
}
