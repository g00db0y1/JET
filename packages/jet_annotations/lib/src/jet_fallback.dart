/// Annotation to provide a fallback Jaspr component string for untranspilable Flutter widgets.
/// 
/// The JET AST parser will ignore the body of a widget decorated with this annotation
/// and instead inject the provided [jasprCode] directly into the output DOM tree.
/// 
/// Example:
/// ```dart
/// @JetFallback('WebVideoPlayer(url: url)')
/// class MobileNativeVideoPlayer extends StatelessWidget {
///   final String url;
///   // ... native Flutter video code ...
/// }
/// ```
class JetFallback {
  /// The raw Jaspr component code to inject in place of this widget.
  final String jasprCode;

  const JetFallback(this.jasprCode);
}
