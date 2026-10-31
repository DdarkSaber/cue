import 'package:cue/app/icons.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every prototype icon parses and stays inside the 24px grid', () {
    for (final icon in CueIcons.values) {
      // getBounds includes curve control points, so sample the outline instead.
      var bounds = Rect.zero;
      var first = true;
      for (final m in svgPath(icon.data).computeMetrics()) {
        for (var d = 0.0; d <= m.length; d += 0.25) {
          final p = m.getTangentForOffset(d)!.position;
          final r = Rect.fromPoints(p, p);
          bounds = first ? r : bounds.expandToInclude(r);
          first = false;
        }
      }
      expect(bounds.isEmpty, isFalse, reason: icon.name);
      expect(
        const Rect.fromLTWH(-1, -1, 26, 26).contains(bounds.topLeft) &&
            const Rect.fromLTWH(-1, -1, 26, 26).contains(bounds.bottomRight),
        isTrue,
        reason: '${icon.name} bounds $bounds',
      );
    }
  });

  test('relative and implicit line commands resolve to absolute points', () {
    // "M4 7h7m5 0h4": first segment 4..11, second 16..20 on y=7.
    final b = svgPath('M4 7h7m5 0h4').getBounds();
    expect(b.left, 4);
    expect(b.right, 20);
    expect(b.top, 7);
  });

  test('unsupported commands fail loudly', () {
    expect(() => svgPath('M0 0Q1 1 2 2'), throwsFormatException);
  });
}
