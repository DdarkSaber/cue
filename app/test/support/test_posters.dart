import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// A poster that decodes at once from an in-memory test image, so widget
/// tests show real [Image]s without touching the network. Equal by [url],
/// which tests read back to see which poster is on screen. With [fails]
/// it reports a load error instead.
class TestPosterImage extends ImageProvider<TestPosterImage> {
  const TestPosterImage(this.url, this.image, {this.fails = false});

  final String url;
  final ui.Image image;
  final bool fails;

  @override
  Future<TestPosterImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    TestPosterImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    fails
        ? Future<ImageInfo>.error(StateError('poster $url failed'))
        : SynchronousFuture(ImageInfo(image: image.clone())),
  );

  @override
  bool operator ==(Object other) =>
      other is TestPosterImage && other.url == url && other.fails == fails;

  @override
  int get hashCode => Object.hash(url, fails);
}
