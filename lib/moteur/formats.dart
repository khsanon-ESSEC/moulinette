// Formats de sortie proposés, et réglages d'encodage FFmpeg pour chacun.

enum Qualite {
  haute('Haute'),
  normale('Normale'),
  compacte('Fichier léger');

  const Qualite(this.libelle);
  final String libelle;
}

enum Definition {
  originale('Originale', null),
  p1080('1080p', 1080),
  p720('720p', 720),
  p480('480p', 480);

  const Definition(this.libelle, this.hauteur);
  final String libelle;
  final int? hauteur;
}

enum Format {
  mp4('MP4', 'mp4', video: true, aide: 'Vidéo H.264, lisible partout'),
  mov('MOV', 'mov', video: true, aide: 'Vidéo QuickTime (Apple)'),
  mkv('MKV', 'mkv', video: true, aide: 'Vidéo Matroska'),
  webm('WebM', 'webm', video: true, aide: 'Vidéo VP9 pour le web'),
  avi('AVI', 'avi', video: true, aide: 'Ancien format vidéo'),
  gif('GIF', 'gif', video: true, aide: 'Image animée, sans son'),
  mp3('MP3', 'mp3', video: false, aide: 'Audio, lisible partout'),
  m4a('M4A (AAC)', 'm4a', video: false, aide: 'Audio Apple, léger'),
  wav('WAV', 'wav', video: false, aide: 'Audio non compressé'),
  flac('FLAC', 'flac', video: false, aide: 'Audio sans perte, compressé'),
  ogg('OGG (Vorbis)', 'ogg', video: false, aide: 'Audio libre'),
  opus('Opus', 'opus', video: false, aide: 'Audio très léger, idéal pour la voix');

  const Format(this.libelle, this.extension, {required this.video, required this.aide});
  final String libelle;
  final String extension;
  final bool video;
  final String aide;

  static List<Format> get videos => values.where((f) => f.video).toList();
  static List<Format> get audios => values.where((f) => !f.video).toList();

  /// Le format qui correspond à une extension de fichier, s'il y en a un.
  static Format? depuisExtension(String ext) {
    final e = ext.toLowerCase().replaceFirst('.', '');
    if (e == 'm4v') return mp4;
    if (e == 'aac') return m4a;
    if (e == 'oga') return ogg;
    for (final f in values) {
      if (f.extension == e) return f;
    }
    return null;
  }
}

/// Arguments d'encodage (tout ce qui vient après l'entrée, sauf le fichier de sortie).
List<String> argumentsEncodage(Format f, Qualite q, {Definition definition = Definition.originale}) {
  final i = q.index; // 0 haute, 1 normale, 2 légère
  List<String> echelle() {
    final h = definition.hauteur;
    // N'agrandit jamais : la hauteur visée est un maximum. Largeur paire, proportions gardées.
    return h == null ? const [] : ['-vf', "scale=-2:'min($h,ih)'"];
  }

  const x264 = ['-c:v', 'libx264', '-preset', 'medium', '-pix_fmt', 'yuv420p'];
  final crf264 = ['18', '23', '28'][i];
  final aac = ['-c:a', 'aac', '-b:a', ['256k', '160k', '96k'][i]];
  switch (f) {
    case Format.mp4:
    case Format.mov:
      return [...echelle(), ...x264, '-crf', crf264, ...aac, '-movflags', '+faststart'];
    case Format.mkv:
      return [...echelle(), ...x264, '-crf', crf264, ...aac];
    case Format.webm:
      return [
        ...echelle(),
        '-c:v', 'libvpx-vp9', '-crf', ['24', '32', '40'][i], '-b:v', '0', '-row-mt', '1',
        '-deadline', 'good', '-cpu-used', '4',
        '-c:a', 'libopus', '-b:a', ['160k', '128k', '64k'][i],
      ];
    case Format.avi:
      return [...echelle(), '-c:v', 'mpeg4', '-q:v', ['2', '4', '7'][i], '-c:a', 'libmp3lame', '-b:a', '192k'];
    case Format.gif:
      final largeur = ['640', '480', '320'][i];
      final ips = ['15', '12', '10'][i];
      return [
        '-vf',
        "fps=$ips,scale='min($largeur,iw)':-2:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse",
        '-an', '-loop', '0',
      ];
    case Format.mp3:
      return ['-vn', '-c:a', 'libmp3lame', '-q:a', ['0', '2', '6'][i]];
    case Format.m4a:
      return ['-vn', ...aac];
    case Format.wav:
      return ['-vn', '-c:a', 'pcm_s16le'];
    case Format.flac:
      return ['-vn', '-c:a', 'flac'];
    case Format.ogg:
      return ['-vn', '-c:a', 'libvorbis', '-q:a', ['7', '5', '3'][i]];
    case Format.opus:
      return ['-vn', '-c:a', 'libopus', '-b:a', ['160k', '96k', '48k'][i]];
  }
}

/// Extension du fichier audio quand on extrait la piste telle quelle, selon son codec.
String extensionPourCodecAudio(String? codec) => extractionTelleQuelle(codec).extension;

/// PCM que le format WAV accepte tel quel (petit-boutiste).
const _pcmWav = {'pcm_u8', 'pcm_s16le', 'pcm_s24le', 'pcm_s32le', 'pcm_f32le', 'pcm_f64le', 'pcm_alaw', 'pcm_mulaw'};

/// Extraction « telle quelle » : l'extension du fichier et les arguments audio. La piste est recopiée, sauf un PCM
/// que le WAV refuse (le PCM « gros-boutiste » des .MOV de caméra) : il est réécrit en PCM standard, sans perte.
({String extension, List<String> arguments}) extractionTelleQuelle(String? codec) {
  final c = (codec ?? '').toLowerCase();
  if (c.startsWith('pcm_') && !_pcmWav.contains(c)) {
    final petit = c.endsWith('be') ? '${c.substring(0, c.length - 2)}le' : '';
    return (extension: 'wav', arguments: ['-c:a', _pcmWav.contains(petit) ? petit : 'pcm_s24le']);
  }
  return (extension: _extensionCopie(c), arguments: const ['-c:a', 'copy']);
}

String _extensionCopie(String c) {
  if (c == 'aac' || c == 'alac') return 'm4a';
  if (c == 'mp3') return 'mp3';
  if (c == 'opus') return 'opus';
  if (c == 'vorbis') return 'ogg';
  if (c == 'flac') return 'flac';
  if (c == 'ac3') return 'ac3';
  if (c == 'eac3') return 'eac3';
  if (c.startsWith('pcm_')) return 'wav';
  return 'mka';
}
