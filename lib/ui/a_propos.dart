// « À propos et licences » : ce que la GPL demande de dire à chaque personne qui reçoit l'app.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

const adresseSource = 'https://github.com/khsanon-ESSEC/moulinette';

/// Ajoute aux licences affichées par Flutter celles de FFmpeg, intégré sous forme native (donc absent de la liste
/// automatique des paquets Dart). À appeler une fois au démarrage.
void enregistrerLicences() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['FFmpeg'], await rootBundle.loadString('assets/licences/ffmpeg.md'));
    final gpl = await rootBundle.loadString('assets/licences/gpl-3.0.txt');
    yield LicenseEntryWithLineBreaks(['x264', 'x265', 'xvidcore', 'vid.stab'], gpl);
    yield LicenseEntryWithLineBreaks(['Moulinette'], gpl);
  });
}

class EcranAPropos extends StatelessWidget {
  const EcranAPropos({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('À propos')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Row(children: [
              Image.asset('assets/icon/icon.png', width: 56, height: 56),
              const SizedBox(width: 16),
              Expanded(
                child: FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, info) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Moulinette', style: theme.textTheme.headlineSmall),
                    Text(info.hasData ? 'Version ${info.data!.version}' : '', style: theme.textTheme.bodyMedium),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            const Text('Convertir des fichiers audio et vidéo, en extraire le son, les découper. '
                'Tout se fait sur l’appareil : aucun fichier n’est envoyé sur Internet.'),
            const SizedBox(height: 20),
            Text('Logiciel libre', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text('© 2026 Karl-Henry Sanon. Moulinette est un logiciel libre : vous pouvez le redistribuer et le '
                'modifier selon les termes de la licence publique générale GNU (GPL), version 3 ou toute version '
                'ultérieure. Il est fourni sans aucune garantie.'),
            const SizedBox(height: 8),
            const Text('Moulinette utilise FFmpeg, avec des bibliothèques sous licence GPL (x264, x265, xvidcore, '
                'vid.stab) : c’est pourquoi l’app entière est distribuée sous GPL.'),
            const SizedBox(height: 12),
            const Text('Code source complet :'),
            SelectableText(adresseSource, style: TextStyle(color: theme.colorScheme.primary)),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(const ClipboardData(text: adresseSource));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Adresse copiée')));
                  }
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copier l’adresse'),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'Moulinette',
                applicationLegalese: '© 2026 Karl-Henry Sanon · GPL 3.0 ou ultérieure',
              ),
              icon: const Icon(Icons.description_outlined),
              label: const Text('Licences des composants'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ]),
        ),
      ),
    );
  }
}
