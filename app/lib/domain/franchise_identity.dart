import 'models/title.dart';

bool isReliableFranchiseScope(String scope) =>
    RegExp(r'^tmdb:c[1-9][0-9]*$').hasMatch(scope);

/// TMDB's movie mapper copies belongs_to_collection.id into this namespace.
/// AniList relation minima and Title.franchiseKey's name fallback are not
/// verified collections and must never become persistent exclusions.
String? reliableFranchiseId(Title title) {
  final scope = title.franchiseId;
  if (title.kind != MediaKind.movie ||
      !RegExp(r'^tmdb:movie:[1-9][0-9]*$').hasMatch(title.id) ||
      scope == null ||
      !isReliableFranchiseScope(scope)) {
    return null;
  }
  return scope;
}
