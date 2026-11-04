import 'dart:async';

/// Who is asking AniList for something, most important first. The shared
/// request budget serves a waiting deck refill before taste seeds, and taste
/// seeds before AI-pick name lookups.
enum RequestPriority { deck, seed, ai }

const _priorityKey = #cueRequestPriority;

/// The priority of the code currently running; calls that never set one
/// (imports, search, details) are as urgent as the deck.
RequestPriority get currentRequestPriority =>
    Zone.current[_priorityKey] as RequestPriority? ?? RequestPriority.deck;

/// Runs [body] so every provider request it makes carries [priority].
Future<T> withRequestPriority<T>(
  RequestPriority priority,
  Future<T> Function() body,
) => Zone.current.fork(zoneValues: {_priorityKey: priority}).run(body);
