import 'package:flutter/widgets.dart';

/// Extension on [Widget] that provides semantic HTML hints to the JET transpiler.
///
/// At **runtime** on mobile, all methods return `this` unchanged — zero overhead.
/// At **build time**, the JET transpiler's AST visitor intercepts the method call,
/// extracts the parameters, and uses them to generate semantic HTML output.
///
/// ## Example
/// ```dart
/// // Default: Text → <p>
/// Text('Hello')
///
/// // With .asWeb(): Text → <h1 class="text-3xl font-bold">
/// Text('Hello').asWeb(tag: 'h1', classes: 'text-3xl font-bold')
///
/// // Image with alt text for accessibility
/// Image.network(url).asWeb(alt: 'Hero banner image')
/// ```
extension WebHints on Widget {
  /// Provides semantic HTML hints to the JET transpiler.
  ///
  /// Parameters:
  /// - [tag]: The HTML element to use (e.g., `'h1'`, `'section'`, `'article'`).
  ///   Overrides the default inferred tag.
  /// - [classes]: Additional Tailwind CSS classes to append to the generated element.
  /// - [id]: The HTML `id` attribute for the generated element.
  /// - [alt]: Alt text for image elements (`<img alt="...">`).
  /// - [ariaLabel]: ARIA label for accessibility (`aria-label="..."`).
  ///
  /// **Note**: This method is a no-op at runtime. The JET transpiler strips the
  /// `.asWeb()` call before compilation so it never appears in your mobile build.
  Widget asWeb({
    String tag = 'div',
    String? classes,
    String? id,
    String? alt,
    String? ariaLabel,
  }) =>
      this;
}
