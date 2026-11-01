import 'package:flutter/material.dart';

import '../../domain/recommendation_context.dart';

class NotNowChoice {
  const NotNowChoice(this.delay, this.reason);
  final Duration delay;
  final NotNowReason? reason;
}

Future<NotNowChoice?> showNotNowOptions(BuildContext context) {
  NotNowReason? reason;
  return showModalBottomSheet<NotNowChoice>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDraft) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Bring back later. Optional context affects only this session, not ratings or lasting dislikes.',
                ),
              ),
              RadioGroup<NotNowReason>(
                groupValue: reason,
                onChanged: (value) => setDraft(() => reason = value),
                child: Column(
                  children: [
                    for (final item in const [
                      (NotNowReason.tooLong, 'Too long'),
                      (NotNowReason.wrongMood, 'Wrong mood'),
                      (NotNowReason.savingLater, 'Saving for later'),
                    ])
                      RadioListTile<NotNowReason>(
                        value: item.$1,
                        title: Text(item.$2),
                        toggleable: true,
                        minTileHeight: 48,
                      ),
                  ],
                ),
              ),
              for (final (label, length) in const [
                ('Tomorrow', Duration(days: 1)),
                ('For a week', Duration(days: 7)),
                ('For two weeks', Duration(days: 14)),
                ('For a month', Duration(days: 30)),
              ])
                ListTile(
                  minTileHeight: 48,
                  title: Text('Not now: $label'),
                  onTap: () =>
                      Navigator.of(ctx).pop(NotNowChoice(length, reason)),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
