/// Maps Flutter widget property values to Tailwind CSS utility classes.
///
/// This is a pure function module — all methods are static.
/// It handles the translation from Flutter's "logical pixel" values
/// to Tailwind's 4px-per-unit spacing scale.
///
/// ## Spacing Scale
/// Flutter logical pixels → Tailwind units (1 unit = 4px):
/// - 4px → `*-1`
/// - 8px → `*-2`
/// - 12px → `*-3`
/// - 16px → `*-4`
/// - 20px → `*-5`
/// - 24px → `*-6`
/// - 32px → `*-8`
/// - 40px → `*-10`
/// - 48px → `*-12`
/// - 64px → `*-16`
library;

/// Converts Flutter layout properties to Tailwind CSS utility classes.
class TailwindMapper {
  TailwindMapper._();

  // ───────────────────────────────────────────────────────────────────────────
  // Spacing
  // ───────────────────────────────────────────────────────────────────────────

  /// Converts a Flutter padding/margin value (in logical pixels) to a
  /// Tailwind spacing unit. Returns null if the value cannot be cleanly mapped.
  static String? pxToSpacingUnit(double px) {
    final unit = _spacingScale[px.round()];
    return unit?.toString();
  }

  /// Maps `EdgeInsets.all(N)` → `p-{unit}`.
  static String edgeInsetsAllToPadding(double value) {
    final unit = _closestSpacingUnit(value);
    return 'p-$unit';
  }

  /// Maps `EdgeInsets.symmetric(horizontal: H, vertical: V)` → `px-{h} py-{v}`.
  static String edgeInsetsSymmetricToPadding({
    required double horizontal,
    required double vertical,
  }) {
    final hUnit = _closestSpacingUnit(horizontal);
    final vUnit = _closestSpacingUnit(vertical);
    return 'px-$hUnit py-$vUnit';
  }

  /// Maps `EdgeInsets.only(top, right, bottom, left)` → `pt-* pr-* pb-* pl-*`.
  static String edgeInsetsOnlyToPadding({
    double top = 0,
    double right = 0,
    double bottom = 0,
    double left = 0,
  }) {
    final classes = <String>[];
    if (top != 0) classes.add('pt-${_closestSpacingUnit(top)}');
    if (right != 0) classes.add('pr-${_closestSpacingUnit(right)}');
    if (bottom != 0) classes.add('pb-${_closestSpacingUnit(bottom)}');
    if (left != 0) classes.add('pl-${_closestSpacingUnit(left)}');
    if (classes.isEmpty) return '';
    return classes.join(' ');
  }

  /// Maps a SizedBox width value → `w-{unit}`.
  static String? sizedBoxWidthToClass(double width) {
    final unit = _closestSpacingUnit(width);
    return 'w-$unit';
  }

  /// Maps a SizedBox height value → `h-{unit}`.
  static String? sizedBoxHeightToClass(double height) {
    final unit = _closestSpacingUnit(height);
    return 'h-$unit';
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Flex Alignment
  // ───────────────────────────────────────────────────────────────────────────

  /// Maps `MainAxisAlignment` enum value to a Tailwind `justify-*` class.
  static String mainAxisAlignmentToJustify(String enumValue) =>
      switch (enumValue) {
        'start' || 'MainAxisAlignment.start' => 'justify-start',
        'end' || 'MainAxisAlignment.end' => 'justify-end',
        'center' || 'MainAxisAlignment.center' => 'justify-center',
        'spaceBetween' || 'MainAxisAlignment.spaceBetween' => 'justify-between',
        'spaceAround' || 'MainAxisAlignment.spaceAround' => 'justify-around',
        'spaceEvenly' || 'MainAxisAlignment.spaceEvenly' => 'justify-evenly',
        _ => 'justify-start',
      };

  /// Maps `CrossAxisAlignment` enum value to a Tailwind `items-*` class.
  static String crossAxisAlignmentToItems(String enumValue) =>
      switch (enumValue) {
        'start' || 'CrossAxisAlignment.start' => 'items-start',
        'end' || 'CrossAxisAlignment.end' => 'items-end',
        'center' || 'CrossAxisAlignment.center' => 'items-center',
        'stretch' || 'CrossAxisAlignment.stretch' => 'items-stretch',
        'baseline' || 'CrossAxisAlignment.baseline' => 'items-baseline',
        _ => 'items-start',
      };

  /// Maps `Alignment` enum value to a Tailwind `self-*` class (for Align widget).
  static String alignmentToSelf(String enumValue) => switch (enumValue) {
        'topLeft' || 'Alignment.topLeft' => 'self-start',
        'topCenter' || 'Alignment.topCenter' => 'self-start',
        'topRight' || 'Alignment.topRight' => 'self-start',
        'centerLeft' || 'Alignment.centerLeft' => 'self-center',
        'center' || 'Alignment.center' => 'self-center',
        'centerRight' || 'Alignment.centerRight' => 'self-center',
        'bottomLeft' || 'Alignment.bottomLeft' => 'self-end',
        'bottomCenter' || 'Alignment.bottomCenter' => 'self-end',
        'bottomRight' || 'Alignment.bottomRight' => 'self-end',
        _ => 'self-auto',
      };

  // ───────────────────────────────────────────────────────────────────────────
  // Text Style → Font Size Heading Inference
  // ───────────────────────────────────────────────────────────────────────────

  /// Infers the HTML heading level from a Flutter font size.
  /// Returns 'h1'..'h4' or null for body text.
  static String? fontSizeToHeadingTag(double fontSize) => switch (fontSize) {
        >= 28 => 'h1',
        >= 22 => 'h2',
        >= 18 => 'h3',
        >= 16 => 'h4',
        _ => null,
      };

  /// Maps a fontSize to a Tailwind text size class.
  static String fontSizeToTextClass(double fontSize) => switch (fontSize) {
        >= 36 => 'text-4xl',
        >= 30 => 'text-3xl',
        >= 24 => 'text-2xl',
        >= 20 => 'text-xl',
        >= 18 => 'text-lg',
        >= 16 => 'text-base',
        >= 14 => 'text-sm',
        _ => 'text-xs',
      };

  // ───────────────────────────────────────────────────────────────────────────
  // Private Helpers
  // ───────────────────────────────────────────────────────────────────────────

  static int _closestSpacingUnit(double px) {
    // Find exact match first
    final exact = _spacingScale[px.round()];
    if (exact != null) return exact;

    // Find closest
    final sorted = _spacingScale.keys.toList()..sort();
    var closest = sorted.first;
    var minDiff = (px - closest).abs();
    for (final key in sorted) {
      final diff = (px - key).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = key;
      }
    }
    return _spacingScale[closest] ?? 4;
  }

  /// Flutter logical pixels → Tailwind spacing unit (1 unit = 4px).
  static const Map<int, int> _spacingScale = {
    0: 0,
    1: 0, // rounded to 0
    2: 0, // rounded to 0.5 (use 0 as fallback)
    4: 1,
    6: 1, // closest to 1
    8: 2,
    10: 2, // closest to 2
    12: 3,
    14: 3, // closest to 3
    16: 4,
    18: 4, // closest to 4
    20: 5,
    22: 5, // closest to 5
    24: 6,
    28: 7,
    32: 8,
    36: 9,
    40: 10,
    44: 11,
    48: 12,
    56: 14,
    64: 16,
    72: 18,
    80: 20,
    96: 24,
  };
}
