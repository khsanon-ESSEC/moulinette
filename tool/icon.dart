// Dessine l'icône de Moulinette : un moulin à quatre pales (le fichier entre, il ressort transformé).
// `dart run tool/icon.dart`, puis `dart run flutter_launcher_icons`.
import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

const _size = 1024;

img.Image _draw({required bool background, required double pad, bool carre = false}) {
  final im = img.Image(width: _size, height: _size, numChannels: 4);
  final fond = img.ColorRgba8(46, 94, 78, 255);
  if (background) {
    if (carre) {
      img.fill(im, color: fond);
    } else {
      img.fillRect(im, x1: 0, y1: 0, x2: _size - 1, y2: _size - 1, color: fond, radius: 220);
    }
  }
  const c = _size / 2;
  final r = 380 * (1 - pad);
  final blanc = img.ColorRgba8(255, 255, 255, 255), creme = img.ColorRgba8(242, 201, 76, 255);
  for (var k = 0; k < 4; k++) {
    final a = k * pi / 2 - pi / 4;
    // Pale : triangle du centre vers le bord, décalé pour l'effet de rotation.
    final p1 = img.Point(c, c);
    final p2 = img.Point(c + r * cos(a), c + r * sin(a));
    final p3 = img.Point(c + r * 0.72 * cos(a + pi / 2.6), c + r * 0.72 * sin(a + pi / 2.6));
    img.fillPolygon(im, vertices: [p1, p2, p3], color: k.isEven ? blanc : creme);
  }
  img.fillCircle(im, x: c.round(), y: c.round(), radius: (52 * (1 - pad)).round(), color: fond, antialias: true);
  img.fillCircle(im, x: c.round(), y: c.round(), radius: (26 * (1 - pad)).round(), color: blanc, antialias: true);
  return im;
}

void main() {
  File('assets/icon/icon.png').writeAsBytesSync(img.encodePng(_draw(background: true, pad: 0)));
  File('assets/icon/icon_carre.png').writeAsBytesSync(img.encodePng(_draw(background: true, pad: 0.1, carre: true)));
  File('assets/icon/foreground.png').writeAsBytesSync(img.encodePng(_draw(background: false, pad: 0.30)));
}
