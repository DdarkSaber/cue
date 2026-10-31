import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/title.dart';

/// Image provider for a poster: disk-cached on mobile (works offline), the
/// browser cache via the Worker proxy on web.
ImageProvider? posterProvider(WidgetRef ref, String? url) {
  if (url == null) return null;
  final resolved = ref.read(catalogGatewayProvider).imageUrl(url);
  return kIsWeb ? NetworkImage(resolved) : CachedNetworkImageProvider(resolved);
}

/// Decodes the next posters ahead of time so a swipe never waits on them.
void predecodePosters(
  BuildContext context,
  WidgetRef ref,
  Iterable<Title> next,
) {
  for (final t in next) {
    final p = posterProvider(ref, t.posterUrl);
    if (p != null) precacheImage(p, context, onError: (_, _) {});
  }
}

/// Official artwork, or a readable tonal fill when there is none or it fails.
class Poster extends ConsumerWidget {
  const Poster({
    super.key,
    required this.title,
    this.alignment = const Alignment(0, -0.5),
    this.fit = BoxFit.cover,
  });

  final Title title;
  final Alignment alignment;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = posterProvider(ref, title.posterUrl);
    final fallback = _TonalFill(title: title);
    if (provider == null) return fallback;
    return Image(
      image: provider,
      fit: fit,
      alignment: alignment,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      frameBuilder: (context, child, frame, sync) {
        if (sync || frame != null) return child;
        return fallback;
      },
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class _TonalFill extends StatelessWidget {
  const _TonalFill({required this.title});
  final Title title;

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C2530), Color(0xFF0D1117)],
        ),
      ),
    );
  }
}
