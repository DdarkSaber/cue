import 'package:flutter/widgets.dart';

import 'tokens.dart';

enum CueLayout { phone, tablet, desktop }

CueLayout layoutFor(double width) {
  if (width >= CueSize.desktopBreakpoint) return CueLayout.desktop;
  if (width >= CueSize.phoneBreakpoint) return CueLayout.tablet;
  return CueLayout.phone;
}

extension CueLayoutContext on BuildContext {
  CueLayout get cueLayout => layoutFor(MediaQuery.sizeOf(this).width);

  /// True when the system (or, later, the app setting) asks for less motion.
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);
}
