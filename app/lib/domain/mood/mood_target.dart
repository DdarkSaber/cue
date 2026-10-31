import 'vec.dart';

/// What the deck should lean toward right now.
class MoodTarget {
  const MoodTarget(this.vec, this.confidence, {this.label, this.modeId});
  static const none = MoodTarget({}, 0);

  final Vec vec;

  /// 0 (no idea) to 1 (sure).
  final double confidence;
  final String? label;
  final String? modeId;
}
