import 'decision.dart';
import 'title.dart';

/// Saved preferences for the active library. Contextual filters live in the
/// deck; these are the defaults.
class AppSettings {
  const AppSettings({
    this.reduceMotion = false,
    this.haptics = true,
    this.swipeMap = SwipeMap.standard,
    this.showAdult = false,
    this.region = 'IN',
    this.defaultKinds = const {...MediaKind.discoverable},
    this.includeRewatches = false,
    this.inviteDismissed = false,
    this.smartMoodText = false,
    this.displayName,
  });

  /// App-level reduce motion; the system setting always wins as well.
  final bool reduceMotion;
  final bool haptics;
  final SwipeMap swipeMap;
  final bool showAdult;
  final String region;
  final Set<MediaKind> defaultKinds;
  final bool includeRewatches;
  final bool inviteDismissed;

  /// Opt-in: send the typed mood sentence to an AI service for hints.
  final bool smartMoodText;
  final String? displayName;

  AppSettings copyWith({
    bool? reduceMotion,
    bool? haptics,
    SwipeMap? swipeMap,
    bool? showAdult,
    String? region,
    Set<MediaKind>? defaultKinds,
    bool? includeRewatches,
    bool? inviteDismissed,
    bool? smartMoodText,
    String? displayName,
  }) => AppSettings(
    reduceMotion: reduceMotion ?? this.reduceMotion,
    haptics: haptics ?? this.haptics,
    swipeMap: swipeMap ?? this.swipeMap,
    showAdult: showAdult ?? this.showAdult,
    region: region ?? this.region,
    defaultKinds: defaultKinds ?? this.defaultKinds,
    includeRewatches: includeRewatches ?? this.includeRewatches,
    inviteDismissed: inviteDismissed ?? this.inviteDismissed,
    smartMoodText: smartMoodText ?? this.smartMoodText,
    displayName: displayName ?? this.displayName,
  );

  /// Key/value form stored in profile_settings (showAdult, region and name
  /// live on the profile row).
  Map<String, String> toEntries() => {
    'reduceMotion': '$reduceMotion',
    'haptics': '$haptics',
    'swipeMap': swipeMap.encode(),
    'defaultKinds': defaultKinds.map((k) => k.name).join(','),
    'includeRewatches': '$includeRewatches',
    'inviteDismissed': '$inviteDismissed',
    'smartMoodText': '$smartMoodText',
  };

  static AppSettings fromEntries(
    Map<String, String> e, {
    bool showAdult = false,
    String region = 'IN',
    String? displayName,
  }) {
    bool b(String k, bool d) => e[k] == null ? d : e[k] == 'true';
    final kinds = e['defaultKinds'];
    return AppSettings(
      reduceMotion: b('reduceMotion', false),
      haptics: b('haptics', true),
      swipeMap: SwipeMap.decode(e['swipeMap']),
      showAdult: showAdult,
      region: region,
      defaultKinds: kinds == null || kinds.isEmpty
          ? {...MediaKind.discoverable}
          : {
              for (final k in kinds.split(','))
                if (MediaKind.parse(k) != MediaKind.unknown) MediaKind.parse(k),
            },
      includeRewatches: b('includeRewatches', false),
      inviteDismissed: b('inviteDismissed', false),
      smartMoodText: b('smartMoodText', false),
      displayName: displayName,
    );
  }
}
