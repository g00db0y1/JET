/// Annotates a [StatelessWidget] as a top-level page route for the JET transpiler.
///
/// When the JET transpiler encounters a class annotated with `@JetRoute`,
/// it generates:
/// - An `article` wrapper around the page content
/// - Jaspr route metadata comments with SEO tags
/// - A `<title>` tag matching [title]
/// - A `<meta name="description">` tag if [description] is provided
///
/// ## Example
/// ```dart
/// @JetRoute(
///   path: '/about',
///   title: 'About Us — Acme Corp',
///   description: 'Learn about our mission, team, and values.',
/// )
/// class AboutScreen extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) { ... }
/// }
/// ```
///
/// The generated Jaspr component will include:
/// ```dart
/// // JET: Route /about | title: About Us — Acme Corp
/// // JET: meta description: Learn about our mission, team, and values.
/// class AboutScreen extends StatelessComponent { ... }
/// ```
class JetRoute {
  /// The URL path for this route (e.g., `'/about'`, `'/products/:id'`).
  final String path;

  /// The page title for the `<title>` HTML tag and browser tab.
  final String title;

  /// Optional meta description for SEO (`<meta name="description" content="...">`).
  final String? description;

  /// Optional Open Graph tags for social media sharing.
  /// Each entry should be in the format `'property:content'`.
  /// Example: `['og:image:https://example.com/og.png', 'og:type:website']`
  final List<String>? openGraphTags;

  const JetRoute({
    required this.path,
    required this.title,
    this.description,
    this.openGraphTags,
  });
}
