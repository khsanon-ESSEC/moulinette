// Ce qui touche à l'appareil : choisir des fichiers, les sonder, lancer FFmpeg, ranger les résultats.

import 'dart:async';
import 'dart:io';

import 'package:android_file_picker/android_file_picker.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

bool get surBureau => Platform.isMacOS || Platform.isWindows || Platform.isLinux;

/// Un fichier choisi par l'utilisateur. Sur Android, il est lu directement (sans copie) par son adresse SAF.
class Source {
  Source({required this.nom, this.chemin, this.uri});
  final String nom;
  final String? chemin;
  final String? uri;

  /// Vrai quand la lecture du fichier est finie, réussie ou non. La durée peut rester inconnue (flux brut,
  /// enregistrement interrompu) : le fichier se convertit quand même, sans pourcentage.
  bool sonde = false;
  double? duree;
  bool? aDeLaVideo;
  bool? aDuSon;
  String? codecAudio;
  String? erreur;

  String get base => p.basenameWithoutExtension(nom);
  String get extension => p.extension(nom).replaceFirst('.', '').toLowerCase();
  String? get dossier => chemin == null ? null : p.dirname(chemin!);

  /// Entrée à passer à FFmpeg. Une adresse SAF ne sert qu'une fois : on en demande une neuve à chaque commande.
  Future<String> entree() async {
    if (chemin != null) return chemin!;
    final saf = await FFmpegKitConfig.getSafParameterForRead(uri!);
    if (saf == null) throw StateError('Impossible d’ouvrir $nom');
    return saf;
  }

  /// Lit la durée et les pistes du fichier.
  Future<void> sonder() async {
    try {
      final session = await FFprobeKit.getMediaInformation(await entree());
      final info = session.getMediaInformation();
      if (info == null) {
        erreur = 'Fichier illisible';
        return;
      }
      duree = double.tryParse(info.getDuration() ?? '');
      final flux = info.getStreams();
      // Une pochette d'album (image fixe) ne compte pas comme vidéo.
      aDeLaVideo = flux.any((s) =>
          s.getType() == 'video' && !['mjpeg', 'png', 'bmp', 'gif'].contains(s.getCodec()?.toLowerCase()));
      final audio = flux.where((s) => s.getType() == 'audio');
      aDuSon = audio.isNotEmpty;
      codecAudio = audio.isEmpty ? null : audio.first.getCodec();
      if (aDeLaVideo == false && aDuSon == false) erreur = 'Ni son ni vidéo';
    } catch (e) {
      erreur = 'Fichier illisible';
    } finally {
      sonde = true;
    }
  }

  /// Lu, sans erreur : prêt à être traité.
  bool get pret => sonde && erreur == null;
}

const _extensionsMedia = [
  'mp4', 'm4v', 'mov', 'mkv', 'webm', 'avi', 'wmv', 'flv', 'mpg', 'mpeg', 'ts', 'mts', 'm2ts', '3gp', 'ogv',
  'gif', 'mp3', 'm4a', 'aac', 'wav', 'flac', 'ogg', 'oga', 'opus', 'wma', 'aiff', 'aif', 'amr', 'ac3', 'mka',
  'caf',
];

/// La photothèque n'existe comme source à part que sur iPad et iPhone.
bool get aUnePhototheque => Platform.isIOS;

/// Ouvre le sélecteur de fichiers (audio et vidéo). Partout c'est le sélecteur de documents, filtré par extension
/// (sur iPad : l'app Fichiers, Drive, clé USB…) ; avec [depuisPhotos], la photothèque de l'iPad (vidéos).
Future<List<Source>> choisirFichiers({bool plusieurs = true, bool depuisPhotos = false}) async {
  final List<PlatformFile> fichiers;
  // Android : pas de copie dans le cache (les vidéos peuvent peser des gigaoctets).
  const android = FilePickerAndroidOptions(safOptions: AndroidSAFOptions(copyToCache: false));
  final type = depuisPhotos ? FileType.video : FileType.custom;
  final extensions = depuisPhotos ? null : _extensionsMedia;
  if (plusieurs) {
    fichiers = await FilePicker.pickFiles(type: type, allowedExtensions: extensions, androidOptions: android);
  } else {
    final f = await FilePicker.pickFile(type: type, allowedExtensions: extensions, androidOptions: android);
    fichiers = f == null ? [] : [f];
  }
  return [
    for (final f in fichiers)
      Source(nom: f.name, chemin: f.path, uri: f.path == null ? f.uri.toString() : null),
  ];
}

/// Le dossier où ranger les résultats.
class Reglages extends ChangeNotifier {
  /// Dossier choisi par l'utilisateur ; `null` = réglage par défaut de l'appareil.
  String? dossierChoisi;

  String get description {
    if (dossierChoisi != null) return dossierChoisi!;
    if (surBureau) return 'Le dossier du fichier d’origine';
    if (Platform.isAndroid) return 'Téléchargements › Moulinette';
    return 'Fichiers › Sur mon iPad › Moulinette';
  }

  bool get peutChanger => !Platform.isIOS;

  Future<void> changer() async {
    // FFmpeg a besoin d'un chemin ; l'écriture y est vérifiée juste après.
    // ignore: deprecated_member_use
    final d = await FilePicker.getDirectoryPath(dialogTitle: 'Où enregistrer les fichiers ?');
    if (d == null) return;
    // Sur Android, certains dossiers ne sont pas accessibles en écriture directe : on vérifie.
    try {
      final essai = File(p.join(d, '.moulinette-essai'));
      await essai.writeAsString('ok');
      await essai.delete();
    } catch (_) {
      throw const FileSystemException('Ce dossier n’accepte pas l’écriture. Choisissez-en un autre (Téléchargements, Musique, Films…).');
    }
    dossierChoisi = d;
    notifyListeners();
  }

  void parDefaut() {
    dossierChoisi = null;
    notifyListeners();
  }

  /// Dossier de sortie pour une source donnée (créé au besoin).
  Future<String> dossierPour(Source s) async {
    if (dossierChoisi != null) return dossierChoisi!;
    if (surBureau && s.dossier != null) return s.dossier!;
    Directory d;
    if (Platform.isAndroid) {
      d = Directory('/storage/emulated/0/Download/Moulinette');
      try {
        await d.create(recursive: true);
        final essai = File(p.join(d.path, '.essai'));
        await essai.writeAsString('ok');
        await essai.delete();
      } catch (_) {
        d = Directory(p.join((await getExternalStorageDirectory())!.path, 'Moulinette'));
      }
    } else if (Platform.isIOS) {
      d = await getApplicationDocumentsDirectory();
    } else {
      d = Directory(p.join((await getDownloadsDirectory())!.path, 'Moulinette'));
    }
    await d.create(recursive: true);
    return d.path;
  }
}

/// Résultat d'une commande FFmpeg.
class Resultat {
  const Resultat({required this.ok, this.annule = false, this.message});
  final bool ok;
  final bool annule;
  final String? message;
}

/// Lance FFmpeg. [progression] reçoit une fraction de 0 à 1, calculée sur [dureeAttendue] (secondes).
/// [surSession] reçoit l'identifiant de session, pour pouvoir annuler.
Future<Resultat> lancerFfmpeg(
  List<String> args, {
  required double dureeAttendue,
  required void Function(double) progression,
  required void Function(int?) surSession,
}) async {
  final fin = Completer<Resultat>();
  final session = await FFmpegKit.executeWithArgumentsAsync(
    args,
    (s) async {
      final code = await s.getReturnCode();
      if (ReturnCode.isSuccess(code)) {
        fin.complete(const Resultat(ok: true));
      } else if (ReturnCode.isCancel(code)) {
        fin.complete(const Resultat(ok: false, annule: true));
      } else {
        final journal = (await s.getAllLogsAsString()) ?? '';
        fin.complete(Resultat(ok: false, message: messageErreur(journal)));
      }
    },
    null,
    (stats) {
      if (dureeAttendue > 0) progression((stats.getTime() / 1000 / dureeAttendue).clamp(0, 1).toDouble());
    },
  );
  surSession(session.getSessionId());
  return fin.future;
}

Future<void> annulerFfmpeg(int? sessionId) => FFmpegKit.cancel(sessionId);

/// Traduit les erreurs FFmpeg les plus courantes ; sinon garde les dernières lignes du journal.
String messageErreur(String journal) {
  final j = journal.toLowerCase();
  if (j.contains('matches no streams') || j.contains('does not contain any stream')) {
    return 'Le fichier n’a pas la piste demandée (pas de son, ou pas d’image).';
  }
  if (j.contains('could not find tag for codec') || j.contains('codec not currently supported in container')) {
    return 'Ce format ne peut pas contenir les pistes d’origine sans réencodage. Décochez « Sans réencodage ».';
  }
  if (j.contains('no space left')) return 'L’appareil n’a plus assez de place.';
  if (j.contains('permission denied')) return 'Écriture refusée dans le dossier de destination.';
  if (j.contains('invalid data found')) return 'Le fichier est abîmé ou n’est pas un fichier audio ou vidéo.';
  final lignes = journal.trim().split('\n').where((l) => l.trim().isNotEmpty).toList();
  return lignes.length <= 4 ? lignes.join('\n') : lignes.sublist(lignes.length - 4).join('\n');
}

/// Montre le fichier : dans le Finder ou l'Explorateur sur ordinateur, par la feuille de partage sur tablette.
Future<void> montrer(String chemin) async {
  if (Platform.isMacOS) {
    await Process.run('open', ['-R', chemin]);
  } else if (Platform.isWindows) {
    await Process.run('explorer', ['/select,', chemin]);
  } else if (Platform.isLinux) {
    await Process.run('xdg-open', [p.dirname(chemin)]);
  } else {
    await SharePlus.instance.share(ShareParams(files: [XFile(chemin)]));
  }
}

Future<void> partager(List<String> chemins) =>
    SharePlus.instance.share(ShareParams(files: [for (final c in chemins) XFile(c)]));
