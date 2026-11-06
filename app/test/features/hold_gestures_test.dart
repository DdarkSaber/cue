import 'package:cue/app/sheets.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/features/deck/story_card.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Title;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('long-pressing a details title copies it', (t) async {
    String? copied;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CueSheet(
            kicker: 'Manhua',
            title: 'Invented Mountain Chief',
            body: SizedBox(height: 40),
            copyableTitle: true,
          ),
        ),
      ),
    );
    await t.longPress(find.text('Invented Mountain Chief'));
    await t.pump();
    expect(copied, 'Invented Mountain Chief');
    expect(find.text('Title copied'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    expect(find.text('Manhua'), findsOneWidget);
  });

  testWidgets('holding a card hides its copy until released', (t) async {
    t.view.physicalSize = const Size(390, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: StoryCard(
              title: Title(
                id: 'peek',
                kind: MediaKind.anime,
                titleEn: 'Invented peek show',
              ),
              reason: 'Because of a test',
            ),
          ),
        ),
      ),
    );
    double opacity() => t
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.text('Invented peek show'),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;
    expect(opacity(), 1);
    final gesture = await t.startGesture(t.getCenter(find.byType(StoryCard)));
    await t.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(opacity(), 0);
    await gesture.up();
    await t.pump();
    expect(opacity(), 1);
  });
}
