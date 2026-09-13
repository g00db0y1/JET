/// Intermediate Representation (IR) for the JET transpiler pipeline.
///
/// The [StyleAccumulatorVisitor] transforms a Flutter AST into a tree of
/// [WidgetNode]s. The [JasprEmitter] then walks this tree to generate
/// the final Jaspr Dart source.
library;

/// Base sealed class for all IR node types.
sealed class WidgetNode {
  const WidgetNode();
}

// ─────────────────────────────────────────────────────────────────────────────
// Modifier Node
// ─────────────────────────────────────────────────────────────────────────────

/// A Flutter widget that contributes CSS classes but emits NO HTML element.
///
/// Examples: [Padding], [Center], [SizedBox], [Expanded], [Flexible], [Align].
///
/// The style accumulator collects these into a bucket. When a [StructuralNode]
/// is reached, the bucket is flushed as CSS classes on that node's element.
class ModifierNode extends WidgetNode {
  const ModifierNode({required this.tailwindClasses});

  /// The Tailwind CSS utility classes contributed by this modifier widget.
  final List<String> tailwindClasses;

  @override
  String toString() => 'ModifierNode(classes: ${tailwindClasses.join(' ')})';
}

// ─────────────────────────────────────────────────────────────────────────────
// Structural Node
// ─────────────────────────────────────────────────────────────────────────────

/// A Flutter widget that emits an HTML element in the Jaspr output.
///
/// Examples: [Column], [Row], [Text], [Image], [ElevatedButton].
///
/// When the visitor hits a structural node, it:
/// 1. Flushes the accumulated CSS bucket into [accumulatedClasses]
/// 2. Applies the widget's own [ownClasses]
/// 3. Recursively processes [children]
class StructuralNode extends WidgetNode {
  const StructuralNode({
    required this.htmlTag,
    required this.ownClasses,
    required this.children,
    this.accumulatedClasses = const [],
    this.attributes = const {},
    this.textContent,
    this.needsClientAnnotation = false,
  });

  /// The HTML tag to emit (e.g., `'div'`, `'h1'`, `'p'`, `'img'`).
  final String htmlTag;

  /// CSS classes derived from this widget's own properties.
  final List<String> ownClasses;

  /// CSS classes accumulated from ancestor [ModifierNode]s.
  final List<String> accumulatedClasses;

  /// Child nodes to render inside this element.
  final List<WidgetNode> children;

  /// Additional HTML attributes (e.g., `{'src': 'https://...', 'alt': '...'}`).
  final Map<String, String> attributes;

  /// Text content for leaf text nodes (e.g., `Text('Hello')` → `textContent: 'Hello'`).
  final String? textContent;

  /// If `true`, this node or an ancestor must trigger `@client` on the
  /// enclosing [ComponentNode]. Set when the widget is interactive
  /// (buttons, inputs, forms).
  final bool needsClientAnnotation;

  /// All CSS classes merged together (accumulated + own).
  List<String> get allClasses => [...accumulatedClasses, ...ownClasses];

  @override
  String toString() =>
      'StructuralNode(<$htmlTag class="${allClasses.join(' ')}">, children: ${children.length})';
}

// ─────────────────────────────────────────────────────────────────────────────
// Component Node
// ─────────────────────────────────────────────────────────────────────────────

/// Represents a Flutter widget class ([StatelessWidget] or [StatefulWidget]).
///
/// Emitted as a Jaspr [StatelessComponent] or `@client` [StatefulComponent].
class ComponentNode extends WidgetNode {
  const ComponentNode({
    required this.name,
    required this.isStateful,
    required this.buildBody,
    this.routeMetadata,
    this.constructorParams = const [],
  });

  /// The class name (e.g., `'HeroSection'`, `'LoginScreen'`).
  final String name;

  /// If `true`, maps to a `@client StatefulComponent`.
  /// If `false`, maps to a pure SSR `StatelessComponent`.
  final bool isStateful;

  /// The root node returned by the Flutter `build()` method.
  final WidgetNode? buildBody;

  /// Optional route metadata from `@JetRoute` annotation.
  final JetRouteMetadata? routeMetadata;

  /// Constructor parameter names for the generated component.
  final List<ComponentParam> constructorParams;

  @override
  String toString() => 'ComponentNode(${isStateful ? '@client ' : ''}$name)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Unknown Node
// ─────────────────────────────────────────────────────────────────────────────

/// A Flutter widget that JET does not know how to translate.
///
/// Emitted as a `// TODO(jet): manual port — {widgetName}` comment.
class UnknownNode extends WidgetNode {
  const UnknownNode({required this.originalWidgetName});

  /// The name of the unrecognized Flutter widget.
  final String originalWidgetName;

  @override
  String toString() => 'UnknownNode($originalWidgetName)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Supporting Data Classes
// ─────────────────────────────────────────────────────────────────────────────

/// Metadata extracted from a `@JetRoute(...)` annotation.
class JetRouteMetadata {
  const JetRouteMetadata({
    required this.path,
    required this.title,
    this.description,
    this.openGraphTags = const [],
  });

  final String path;
  final String title;
  final String? description;
  final List<String> openGraphTags;
}

/// A constructor parameter for a generated Jaspr component.
class ComponentParam {
  const ComponentParam({
    required this.name,
    required this.type,
    this.isRequired = true,
  });

  final String name;
  final String type;
  final bool isRequired;
}
