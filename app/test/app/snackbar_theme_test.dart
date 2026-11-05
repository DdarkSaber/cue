import 'package:cue/app/theme.dart';
import 'package:cue/app/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Future<void> _showBar(WidgetTester t) async {
  await t.pumpWidget(
    MaterialApp(
      theme: buildCueTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Library name saved.'),
                  action: SnackBarAction(label: 'Undo', onPressed: () {}),
                ),
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('Show'));
  await t.pumpAndSettle();
}

void main() {
  test('notification bar colours read at 4.5:1 or better', () {
    final theme = buildCueTheme().snackBarTheme;
    final bg = theme.backgroundColor!;
    expect(bg.a, 1.0, reason: 'opaque, so contrast holds over any content');
    expect(
      _contrast(theme.contentTextStyle!.color!, bg),
      greaterThanOrEqualTo(4.5),
    );
    expect(_contrast(theme.actionTextColor!, bg), greaterThanOrEqualTo(4.5));
  });

  testWidgets('a notification bar uses the dark floating style', (t) async {
    await _showBar(t);
    expect(find.text('Library name saved.'), findsOneWidget);
    final material = t.widget<Material>(
      find
          .ancestor(
            of: find.text('Library name saved.'),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, CueColors.surfaceHigh);
    expect(material.shape, isA<RoundedRectangleBorder>());
    final style = t.widget<DefaultTextStyle>(
      find
          .ancestor(
            of: find.text('Library name saved.'),
            matching: find.byType(DefaultTextStyle),
          )
          .first,
    );
    expect(style.style.color, CueColors.text);
    final snack = t.widget<SnackBar>(find.byType(SnackBar));
    expect(snack.behavior, isNull, reason: 'the theme decides');
    expect(
      Theme.of(t.element(find.byType(SnackBar))).snackBarTheme.behavior,
      SnackBarBehavior.floating,
    );
  });

  testWidgets('a notification bar is announced to screen readers', (t) async {
    final semantics = t.ensureSemantics();
    await _showBar(t);
    expect(
      t.getSemantics(find.text('Library name saved.')),
      isSemantics(label: 'Library name saved.'),
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.liveRegion ?? false),
      ),
      findsWidgets,
    );
    semantics.dispose();
  });

  for (final dx in [400.0, -400.0]) {
    testWidgets('a sideways swipe (${dx > 0 ? 'right' : 'left'}) dismisses '
        'the notification bar', (t) async {
      await _showBar(t);
      expect(find.byType(SnackBar), findsOneWidget);
      await t.drag(find.text('Library name saved.'), Offset(dx, 0));
      await t.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    });
  }
}
