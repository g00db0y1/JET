import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../emitter/tailwind_mapper.dart';
import 'widget_node.dart';

/// Traverses a Flutter widget AST and produces a [WidgetNode] IR tree.
///
/// ## How it works
///
/// The visitor maintains a **style accumulator bucket** — a list of Tailwind
/// CSS classes collected from ancestor [ModifierNode] widgets.
///
/// - **Modifier Nodes** (`Padding`, `Center`, `SizedBox`, etc.) do NOT produce
///   an HTML element. They push CSS classes into the bucket and delegate
///   to their single child.
///
/// - **Structural Nodes** (`Column`, `Row`, `Text`, etc.) flush the bucket,
///   attach the accumulated classes to their element, and recursively process
///   their children with a fresh bucket.
///
/// ## Usage
/// ```dart
/// final visitor = StyleAccumulatorVisitor();
/// final compilationUnit = ...; // from FlutterAstParser
/// compilationUnit.accept(visitor);
/// final components = visitor.components;
/// ```
class StyleAccumulatorVisitor extends RecursiveAstVisitor<void> {
  /// All top-level [ComponentNode]s found in the parsed file.
  final List<ComponentNode> components = [];

  /// Current accumulated CSS bucket (modifier classes waiting for a structural node).
  final List<String> _bucket = [];

  final Map<String, String> _eventBucket = {};

  Map<String, String> _popEvents() {
    final e = Map<String, String>.from(_eventBucket);
    _eventBucket.clear();
    return e;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Primary entry: visit class declarations to find widgets
  // ───────────────────────────────────────────────────────────────────────────

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final superclass = node.extendsClause?.superclass.name2.lexeme;
    if (superclass != 'StatelessWidget' && superclass != 'StatefulWidget') {
      super.visitClassDeclaration(node);
      return;
    }

    final isStateful = superclass == 'StatefulWidget';
    final className = node.name.lexeme;

    // Check for @JetRoute annotation
    JetRouteMetadata? routeMetadata;
    for (final annotation in node.metadata) {
      if (annotation.name.name == 'JetRoute') {
        routeMetadata = _extractJetRouteMetadata(annotation);
      }
    }

    // Find the build() method to extract the widget tree
    WidgetNode? buildBody;
    for (final member in node.members) {
      if (member is MethodDeclaration && member.name.lexeme == 'build') {
        buildBody = _visitBuildMethod(member);
      }
    }

    // Detect if any child needs client annotation (interactive widgets)
    final needsClient = isStateful || _treeNeedsClient(buildBody);

    final component = ComponentNode(
      name: className,
      isStateful: needsClient,
      buildBody: buildBody,
      routeMetadata: routeMetadata,
    );
    components.add(component);
    // Don't call super — we manually process members above
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Core dispatch: visitExpr converts any Expression to a WidgetNode
  // ───────────────────────────────────────────────────────────────────────────

  /// Converts an [Expression] AST node to a [WidgetNode].
  ///
  /// This is the primary recursive dispatch method. It inspects the expression
  /// type and delegates to the appropriate handler without using the analyzer's
  /// `accept()` visit-dispatch (which has incompatible generic type constraints).
  WidgetNode? visitExpr(Expression? expr) {
    if (expr == null) return null;

    // Handle .asWeb() method chain first, or widget constructors parsed as methods
    if (expr is MethodInvocation) {
      if (expr.methodName.name == 'asWeb') {
        return _visitAsWeb(expr);
      } else {
        // Without full resolution, Foo() is parsed as a MethodInvocation.
        String typeName;
        String? constructorName;
        if (expr.target != null) {
          typeName = expr.target!.toSource();
          constructorName = expr.methodName.name;
        } else {
          typeName = expr.methodName.name;
          constructorName = null;
        }
        return _dispatchWidgetCreation(
            typeName, constructorName, expr.argumentList);
      }
    }

    // Handle widget constructor calls with explicit new/const: const WidgetName(...)
    if (expr is InstanceCreationExpression) {
      final typeName = expr.constructorName.type.name2.lexeme;
      final constructorName = expr.constructorName.name?.name;
      return _dispatchWidgetCreation(
          typeName, constructorName, expr.argumentList);
    }

    // Handle simple identifier references (e.g., const SomeWidget())
    if (expr is SimpleIdentifier) {
      return null; // Can't resolve without type context
    }

    // Handle parenthesized expressions
    if (expr is ParenthesizedExpression) {
      return visitExpr(expr.expression);
    }

    return null;
  }

  WidgetNode? _dispatchWidgetCreation(
      String typeName, String? constructorName, ArgumentList args) {
    return switch (typeName) {
      // ── Modifier Nodes ──────────────────────────────────────────────────
      'Padding' => _visitPadding(args),
      'Center' => _visitCenter(args),
      'SizedBox' => _visitSizedBox(args),
      'Expanded' => _visitExpanded(args),
      'GestureDetector' => _visitGestureDetector(args),
      'InkWell' => _visitGestureDetector(args),
      'Flexible' => _visitFlexible(args),
      'Align' => _visitAlign(args),

      // ── Layout Structural Nodes ──────────────────────────────────────────
      'Column' => _visitColumn(args),
      'Row' => _visitRow(args),
      'Wrap' => _visitWrap(args),
      'Stack' => _visitStack(args),
      'ListView' when constructorName == null => _visitListView(args),
      'ListView' when constructorName == 'builder' => _visitListViewBuilder(),
      'SingleChildScrollView' => _visitSingleChildScrollView(args),
      'CustomScrollView' => _visitCustomScrollView(args),
      'SliverList' => _visitSliverList(args),
      'SliverToBoxAdapter' => _visitSliverToBoxAdapter(args),
      'SliverAppBar' => _visitSliverAppBar(args),
      'GridView' when constructorName == 'count' => _visitGridViewCount(args),
      'Scaffold' => _visitScaffold(args),
      'AppBar' => _visitAppBar(args),
      'BottomNavigationBar' => _visitBottomNavigationBar(args),
      'Container' => _visitContainer(args),
      'Card' => _visitCard(args),

      // ── Text Nodes ──────────────────────────────────────────────────────
      'Text' => _visitText(args),
      'RichText' => _visitRichText(),

      // ── Media Nodes ─────────────────────────────────────────────────────
      'Image' when constructorName == 'network' => _visitImageNetwork(args),
      'Image' when constructorName == 'asset' => _visitImageAsset(args),

      // ── Interactive Nodes (trigger @client) ──────────────────────────────
      'ElevatedButton' => _visitButton(
          args, 'bg-blue-600 text-white rounded px-4 py-2 hover:bg-blue-700'),
      'TextButton' => _visitButton(args, 'text-blue-600 hover:underline'),
      'OutlinedButton' => _visitButton(
          args, 'border border-blue-600 text-blue-600 rounded px-4 py-2'),
      'TextField' || 'TextFormField' => _visitTextField(args),
      'Form' => _visitForm(args),
      'Checkbox' => _visitCheckbox(),
      'Switch' => _visitSwitch(),

      // ── Utility Nodes ───────────────────────────────────────────────────
      'Divider' => _visitDivider(),
      'Spacer' => _visitSpacer(),
      'CircularProgressIndicator' => _visitCircularProgress(),
      'LinearProgressIndicator' => _visitLinearProgress(),
      'Icon' => _visitIcon(args),

      // ── Unsupported Nodes ───────────────────────────────────────────────
      _ => UnknownNode(originalWidgetName: typeName),
    };
  }

  // ───────────────────────────────────────────────────────────────────────────
  // .asWeb() method chain detection
  // ───────────────────────────────────────────────────────────────────────────

  WidgetNode? _visitAsWeb(MethodInvocation node) {
    // Visit the target widget (before .asWeb())
    final targetNode = visitExpr(node.target);
    if (targetNode is! StructuralNode) return targetNode;

    // Extract .asWeb() parameters
    final args = node.argumentList;
    final tag = _getStringArg(args, 'tag') ?? targetNode.htmlTag;
    final classes = _getStringArg(args, 'classes');
    final id = _getStringArg(args, 'id');
    final alt = _getStringArg(args, 'alt');
    final ariaLabel = _getStringArg(args, 'ariaLabel');

    final extraClasses = <String>[
      if (classes != null) ...classes.split(' '),
    ];
    final extraAttrs = <String, String>{
      ...targetNode.attributes,
      if (id != null) 'id': id,
      if (alt != null) 'alt': alt,
      if (ariaLabel != null) 'aria-label': ariaLabel,
    };

    return StructuralNode(
      events: targetNode.events,
      htmlTag: tag,
      ownClasses: [...targetNode.ownClasses, ...extraClasses],
      accumulatedClasses: targetNode.accumulatedClasses,
      children: targetNode.children,
      attributes: extraAttrs,
      textContent: targetNode.textContent,
      needsClientAnnotation: targetNode.needsClientAnnotation,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Modifier Node Handlers
  // ───────────────────────────────────────────────────────────────────────────

  WidgetNode? _visitPadding(ArgumentList args) {
    final padding = _getArgNamed(args, 'padding');
    final classes = _parsePaddingExpression(padding);
    _bucket.addAll(classes);
    final child = _getArgNamed(args, 'child');
    return visitExpr(child);
  }

  WidgetNode? _visitCenter(ArgumentList args) {
    _bucket.addAll(['flex', 'items-center', 'justify-center']);
    final child = _getArgNamed(args, 'child');
    return visitExpr(child);
  }

  WidgetNode? _visitSizedBox(ArgumentList args) {
    final widthExpr = _getArgNamed(args, 'width');
    final heightExpr = _getArgNamed(args, 'height');

    final width = widthExpr != null ? _parseDouble(widthExpr) : null;
    final height = heightExpr != null ? _parseDouble(heightExpr) : null;

    if (width != null)
      _bucket.add(TailwindMapper.sizedBoxWidthToClass(width) ?? 'w-auto');
    if (height != null)
      _bucket.add(TailwindMapper.sizedBoxHeightToClass(height) ?? 'h-auto');

    final child = _getArgNamed(args, 'child');
    return visitExpr(child) ??
        const StructuralNode(htmlTag: 'div', ownClasses: [], children: []);
  }

  WidgetNode? _visitExpanded(ArgumentList args) {
    _bucket.add('flex-1');
    final child = _getArgNamed(args, 'child');
    return visitExpr(child);
  }

  WidgetNode? _visitFlexible(ArgumentList args) {
    _bucket.add('flex-auto');
    final child = _getArgNamed(args, 'child');
    return visitExpr(child);
  }

  WidgetNode? _visitGestureDetector(ArgumentList args) {
    final tap = _getArgNamed(args, 'onTap');
    if (tap != null) {
      _eventBucket['click'] = 'onTap';
      _bucket.add('cursor-pointer');
    }
    final doubleTap = _getArgNamed(args, 'onDoubleTap');
    if (doubleTap != null) _eventBucket['dblclick'] = 'onDoubleTap';
    final panStart =
        _getArgNamed(args, 'onPanStart') ?? _getArgNamed(args, 'onScaleStart');
    if (panStart != null)
      _eventBucket['pointerdown'] = 'onPanStart / onScaleStart';
    final panUpdate = _getArgNamed(args, 'onPanUpdate') ??
        _getArgNamed(args, 'onScaleUpdate');
    if (panUpdate != null)
      _eventBucket['pointermove'] = 'onPanUpdate / onScaleUpdate';
    final child = _getArgNamed(args, 'child');
    return visitExpr(child);
  }

  WidgetNode? _visitAlign(ArgumentList args) {
    final alignmentExpr = _getArgNamed(args, 'alignment');
    if (alignmentExpr != null) {
      final alignStr = alignmentExpr.toSource();
      _bucket.add(TailwindMapper.alignmentToSelf(alignStr));
    }
    final child = _getArgNamed(args, 'child');
    return visitExpr(child);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Structural Node Handlers — Layout
  // ───────────────────────────────────────────────────────────────────────────

  StructuralNode _visitColumn(ArgumentList args) {
    final _events = _popEvents();
    final classes = _flushBucketWith(['flex', 'flex-col']);
    _applyMainAxis(args, classes);
    _applyCrossAxis(args, classes);
    return StructuralNode(
      events: _events,
      htmlTag: 'div',
      ownClasses: classes,
      children: _visitChildrenList(args),
    );
  }

  StructuralNode _visitRow(ArgumentList args) {
    final _events = _popEvents();
    final classes = _flushBucketWith(['flex', 'flex-row']);
    _applyMainAxis(args, classes);
    _applyCrossAxis(args, classes);
    return StructuralNode(
      events: _events,
      htmlTag: 'div',
      ownClasses: classes,
      children: _visitChildrenList(args),
    );
  }

  StructuralNode _visitWrap(ArgumentList args) {
    final _events = _popEvents();
    final classes = _flushBucketWith(['flex', 'flex-wrap']);
    return StructuralNode(
      events: _events,
      htmlTag: 'div',
      ownClasses: classes,
      children: _visitChildrenList(args),
    );
  }

  StructuralNode _visitStack(ArgumentList args) {
    final _events = _popEvents();
    final classes = _flushBucketWith(['relative']);
    return StructuralNode(
      events: _events,
      htmlTag: 'div',
      ownClasses: classes,
      children: _visitChildrenList(args),
    );
  }

  StructuralNode _visitListView(ArgumentList args) {
    final _events = _popEvents();
    final classes = _flushBucketWith(['flex', 'flex-col', 'overflow-y-auto']);
    _applyPhysics(args, classes);
    return StructuralNode(
      events: _events,
      htmlTag: 'ul',
      ownClasses: classes,
      children: _visitChildrenListWrapped(args, wrapTag: 'li'),
    );
  }

  StructuralNode _visitListViewBuilder() {
    final _events = _popEvents();
    final classes = _flushBucketWith(['flex', 'flex-col', 'overflow-y-auto']);
    return StructuralNode(
      events: _events,
      htmlTag: 'ul',
      ownClasses: classes,
      children: [
        const UnknownNode(originalWidgetName: 'ListView.builder:itemBuilder')
      ],
    );
  }

  StructuralNode _visitSingleChildScrollView(ArgumentList args) {
    // Default to vertical scrolling, check scrollDirection if needed
    final directionExpr = _getArgNamed(args, 'scrollDirection');
    final isHorizontal =
        directionExpr?.toSource().contains('horizontal') ?? false;

    final _events = _popEvents();
    final classes = _flushBucketWith([
      'flex',
      isHorizontal ? 'flex-row' : 'flex-col',
      isHorizontal ? 'overflow-x-auto' : 'overflow-y-auto'
    ]);

    _applyPhysics(args, classes);

    final child = visitExpr(_getArgNamed(args, 'child'));

    return StructuralNode(
      events: _events,
      htmlTag: 'div',
      ownClasses: classes,
      children: child != null ? [child] : [],
    );
  }

  StructuralNode _visitCustomScrollView(ArgumentList args) {
    final _events = _popEvents();
    final classes = _flushBucketWith(['flex', 'flex-col', 'overflow-y-auto']);
    _applyPhysics(args, classes);

    // CustomScrollView uses 'slivers' instead of 'children'
    final sliversExpr = _getArgNamed(args, 'slivers');
    List<WidgetNode> slivers = [];
    if (sliversExpr is ListLiteral) {
      slivers = sliversExpr.elements
          .whereType<Expression>()
          .map(visitExpr)
          .whereType<WidgetNode>()
          .toList();
    }

    return StructuralNode(
      events: _events,
      htmlTag: 'div',
      ownClasses: classes,
      children: slivers,
    );
  }

  StructuralNode _visitSliverList(ArgumentList args) {
    // On the web, slivers inside a scrolling flexbox can just act as a standard flex block.
    final _events = _popEvents();
    final classes = _flushBucketWith(['flex', 'flex-col']);

    // In Flutter, SliverList usually takes a delegate. For AST parsing we'll extract delegate children if possible.
    final delegateExpr = _getArgNamed(args, 'delegate');
    List<WidgetNode> children = [];
    if (delegateExpr is InstanceCreationExpression ||
        delegateExpr is MethodInvocation) {
      String delegateName = '';
      NodeList<Expression>? delegateArgs;

      if (delegateExpr is InstanceCreationExpression) {
        delegateName = delegateExpr.constructorName.type.name2.lexeme;
        delegateArgs = delegateExpr.argumentList.arguments;
      } else if (delegateExpr is MethodInvocation) {
        delegateName = delegateExpr.methodName.name;
        delegateArgs = delegateExpr.argumentList.arguments;
      }

      if (delegateName == 'SliverChildListDelegate' && delegateArgs != null) {
        if (delegateArgs.isNotEmpty) {
          final firstArg = delegateArgs.first;
          if (firstArg is ListLiteral) {
            children = firstArg.elements
                .whereType<Expression>()
                .map(visitExpr)
                .whereType<WidgetNode>()
                .toList();
          }
        }
      } else {
        children = [
          const UnknownNode(
              originalWidgetName: 'SliverList:SliverChildBuilderDelegate')
        ];
      }
    }

    return StructuralNode(
      events: _events,
      htmlTag: 'ul',
      ownClasses: classes,
      children: children,
    );
  }

  StructuralNode _visitSliverToBoxAdapter(ArgumentList args) {
    final child = visitExpr(_getArgNamed(args, 'child'));
    final _events = _popEvents();
    final classes = _flushBucketWith([]);
    return StructuralNode(
      events: _events,
      htmlTag: 'div',
      ownClasses: classes,
      children: child != null ? [child] : [],
    );
  }

  StructuralNode _visitSliverAppBar(ArgumentList args) {
    // A SliverAppBar typically becomes a sticky header
    final _events = _popEvents();
    final classes =
        _flushBucketWith(['sticky', 'top-0', 'z-50', 'bg-white', 'shadow']);

    final titleNode = visitExpr(_getArgNamed(args, 'title'));

    return StructuralNode(
      events: _events,
      htmlTag: 'header',
      ownClasses: classes,
      children: titleNode != null ? [titleNode] : [],
    );
  }

  StructuralNode _visitGridViewCount(ArgumentList args) {
    final crossAxisCountExpr = _getArgNamed(args, 'crossAxisCount');
    final count =
        crossAxisCountExpr != null ? (_parseInt(crossAxisCountExpr) ?? 2) : 2;
    final _events = _popEvents();
    final classes = _flushBucketWith(['grid', 'grid-cols-$count', 'gap-4']);
    return StructuralNode(
      events: _events,
      htmlTag: 'div',
      ownClasses: classes,
      children: _visitChildrenList(args),
    );
  }

  StructuralNode _visitScaffold(ArgumentList args) {
    final _events = _popEvents();
    final classes = _flushBucketWith(['min-h-screen', 'flex', 'flex-col']);
    final children = <WidgetNode>[];

    final appBarNode = visitExpr(_getArgNamed(args, 'appBar'));
    if (appBarNode != null) children.add(appBarNode);

    final bodyNode = visitExpr(_getArgNamed(args, 'body'));
    if (bodyNode != null) children.add(bodyNode);

    final navNode = visitExpr(_getArgNamed(args, 'bottomNavigationBar'));
    if (navNode != null) children.add(navNode);

    return StructuralNode(
      events: _events,
      htmlTag: 'main',
      ownClasses: classes,
      children: children,
    );
  }

  StructuralNode _visitAppBar(ArgumentList args) {
    final _events = _popEvents();
    final classes = _flushBucketWith(
        ['flex', 'items-center', 'px-4', 'py-2', 'bg-white', 'shadow']);
    final children = <WidgetNode>[];

    var titleNode = visitExpr(_getArgNamed(args, 'title'));
    // Promote Text child of AppBar title to h1
    if (titleNode is StructuralNode && titleNode.htmlTag == 'p') {
      titleNode = StructuralNode(
        events: _events,
        htmlTag: 'h1',
        ownClasses: ['text-xl', 'font-semibold'],
        children: titleNode.children,
        textContent: titleNode.textContent,
        attributes: titleNode.attributes,
      );
    }
    if (titleNode != null) children.add(titleNode);

    return StructuralNode(
      events: _events,
      htmlTag: 'header',
      ownClasses: classes,
      children: children,
    );
  }

  StructuralNode _visitBottomNavigationBar(ArgumentList args) {
    final _events = _popEvents();
    final classes = _flushBucketWith([
      'flex',
      'justify-around',
      'items-center',
      'py-2',
      'bg-white',
      'border-t'
    ]);
    return StructuralNode(
      events: _events,
      htmlTag: 'nav',
      ownClasses: classes,
      children: _visitChildrenList(args),
    );
  }

  StructuralNode _visitContainer(ArgumentList args) {
    final _events = _popEvents();
    final classes = _flushBucketWith([]);
    final colorExpr = _getArgNamed(args, 'color');
    if (colorExpr != null) classes.add('bg-gray-100');
    final childNode = visitExpr(_getArgNamed(args, 'child'));
    return StructuralNode(
      events: _events,
      htmlTag: 'div',
      ownClasses: classes,
      children: childNode != null ? [childNode] : [],
    );
  }

  StructuralNode _visitCard(ArgumentList args) {
    final _events = _popEvents();
    final classes =
        _flushBucketWith(['rounded-lg', 'shadow', 'p-4', 'bg-white']);
    final childNode = visitExpr(_getArgNamed(args, 'child'));
    return StructuralNode(
      events: _events,
      htmlTag: 'div',
      ownClasses: classes,
      children: childNode != null ? [childNode] : [],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Structural Node Handlers — Text
  // ───────────────────────────────────────────────────────────────────────────

  StructuralNode _visitText(ArgumentList args) {
    final textExpr = args.arguments.firstOrNull;
    final textContent = textExpr != null ? _extractStringLiteral(textExpr) : '';

    // Check style for heading inference
    final styleExpr = _getArgNamed(args, 'style');
    String htmlTag = 'p';
    final ownClasses = <String>[];

    if (styleExpr != null) {
      final fontSize = _extractFontSize(styleExpr);
      if (fontSize != null) {
        final headingTag = TailwindMapper.fontSizeToHeadingTag(fontSize);
        if (headingTag != null) htmlTag = headingTag;
        ownClasses.add(TailwindMapper.fontSizeToTextClass(fontSize));
      }
    }

    final _events = _popEvents();
    final accumulatedClasses = List<String>.from(_bucket);
    _bucket.clear();

    return StructuralNode(
      events: _events,
      htmlTag: htmlTag,
      ownClasses: ownClasses,
      accumulatedClasses: accumulatedClasses,
      children: [],
      textContent: textContent,
    );
  }

  StructuralNode _visitRichText() {
    final _events = _popEvents();
    final accumulatedClasses = List<String>.from(_bucket);
    _bucket.clear();
    return StructuralNode(
      events: _events,
      htmlTag: 'p',
      ownClasses: [],
      accumulatedClasses: accumulatedClasses,
      children: [const UnknownNode(originalWidgetName: 'RichText:TextSpan')],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Structural Node Handlers — Media
  // ───────────────────────────────────────────────────────────────────────────

  StructuralNode _visitImageNetwork(ArgumentList args) {
    final srcExpr = args.arguments.firstOrNull;
    final src = srcExpr != null ? _extractStringLiteral(srcExpr) : '';
    final _events = _popEvents();
    final accumulatedClasses = List<String>.from(_bucket);
    _bucket.clear();
    return StructuralNode(
      events: _events,
      htmlTag: 'img',
      ownClasses: [],
      accumulatedClasses: accumulatedClasses,
      children: [],
      attributes: {if (src.isNotEmpty) 'src': src, 'alt': ''},
    );
  }

  StructuralNode _visitImageAsset(ArgumentList args) {
    final pathExpr = args.arguments.firstOrNull;
    final assetPath = pathExpr != null ? _extractStringLiteral(pathExpr) : '';
    final _events = _popEvents();
    final accumulatedClasses = List<String>.from(_bucket);
    _bucket.clear();
    return StructuralNode(
      events: _events,
      htmlTag: 'img',
      ownClasses: [],
      accumulatedClasses: accumulatedClasses,
      children: [],
      attributes: {
        if (assetPath.isNotEmpty) 'src': '/assets/$assetPath',
        'alt': '',
      },
    );
  }

  StructuralNode _visitIcon(ArgumentList args) {
    final iconExpr = args.arguments.firstOrNull;
    final iconName = iconExpr != null
        ? iconExpr.toSource().replaceAll('Icons.', '').replaceAll('_', '-')
        : 'unknown';
    final _events = _popEvents();
    final accumulatedClasses = List<String>.from(_bucket);
    _bucket.clear();
    return StructuralNode(
      events: _events,
      htmlTag: 'span',
      ownClasses: ['icon', 'icon-$iconName'],
      accumulatedClasses: accumulatedClasses,
      children: [],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Structural Node Handlers — Interactive (trigger @client)
  // ───────────────────────────────────────────────────────────────────────────

  StructuralNode _visitButton(ArgumentList args, String buttonClasses) {
    final _events = _popEvents();
    final accumulatedClasses = List<String>.from(_bucket);
    _bucket.clear();
    final childNode = visitExpr(_getArgNamed(args, 'child'));
    return StructuralNode(
      events: _events,
      htmlTag: 'button',
      ownClasses: buttonClasses.split(' '),
      accumulatedClasses: accumulatedClasses,
      children: childNode != null ? [childNode] : [],
      needsClientAnnotation: true,
    );
  }

  StructuralNode _visitTextField(ArgumentList args) {
    final _events = _popEvents();
    final accumulatedClasses = List<String>.from(_bucket);
    _bucket.clear();

    final attrs = <String, String>{};

    // Parse keyboardType
    final keyboardExpr = _getArgNamed(args, 'keyboardType');
    if (keyboardExpr is PropertyAccess) {
      final name = keyboardExpr.propertyName.name;
      if (name == 'emailAddress')
        attrs['type'] = 'email';
      else if (name == 'number' || name == 'numberWithOptions')
        attrs['type'] = 'number';
      else if (name == 'phone')
        attrs['type'] = 'tel';
      else if (name == 'url')
        attrs['type'] = 'url';
      else
        attrs['type'] = 'text';
    } else if (keyboardExpr is PrefixedIdentifier) {
      final name = keyboardExpr.identifier.name;
      if (name == 'emailAddress')
        attrs['type'] = 'email';
      else if (name == 'number' || name == 'numberWithOptions')
        attrs['type'] = 'number';
      else if (name == 'phone')
        attrs['type'] = 'tel';
      else if (name == 'url')
        attrs['type'] = 'url';
      else
        attrs['type'] = 'text';
    } else {
      attrs['type'] = 'text';
    }

    // Parse obscureText
    final obscureExpr = _getArgNamed(args, 'obscureText');
    if (obscureExpr is BooleanLiteral && obscureExpr.value) {
      attrs['type'] = 'password';
    }

    // Parse maxLength
    final maxLenExpr = _getArgNamed(args, 'maxLength');
    if (maxLenExpr is IntegerLiteral) {
      attrs['maxlength'] = maxLenExpr.value.toString();
    }

    // Parse initialValue (for TextFormField)
    final initialExpr = _getArgNamed(args, 'initialValue');
    if (initialExpr is StringLiteral) {
      attrs['value'] = initialExpr.stringValue ?? '';
    }

    // Parse decoration for hintText/labelText
    final decorationExpr = _getArgNamed(args, 'decoration');
    ArgumentList? decorArgs;
    if (decorationExpr is InstanceCreationExpression) {
      decorArgs = decorationExpr.argumentList;
    } else if (decorationExpr is MethodInvocation) {
      decorArgs = decorationExpr.argumentList;
    }

    if (decorArgs != null) {
      final hintExpr = _getArgNamed(decorArgs, 'hintText');
      if (hintExpr is StringLiteral && hintExpr.stringValue != null) {
        attrs['placeholder'] = hintExpr.stringValue!;
      }

      final labelExpr = _getArgNamed(decorArgs, 'labelText');
      if (labelExpr is StringLiteral &&
          labelExpr.stringValue != null &&
          !attrs.containsKey('placeholder')) {
        attrs['placeholder'] = labelExpr
            .stringValue!; // Fallback label to placeholder for simple inputs
      }
    }

    // Parse maxLines
    final maxLinesExpr = _getArgNamed(args, 'maxLines');
    bool isTextArea = false;
    if (maxLinesExpr is IntegerLiteral &&
        maxLinesExpr.value != null &&
        maxLinesExpr.value! > 1) {
      isTextArea = true;
      attrs['rows'] = maxLinesExpr.value.toString();
      attrs.remove('type');
      attrs.remove('value'); // textareas put content inside tags
    }

    return StructuralNode(
      events: _events,
      htmlTag: isTextArea ? 'textarea' : 'input',
      ownClasses: ['border', 'rounded', 'px-3', 'py-2', 'w-full'],
      accumulatedClasses: accumulatedClasses,
      children: [], // Inputs are self-closing, textarea children injected elsewhere if needed
      attributes: attrs,
      needsClientAnnotation: true,
    );
  }

  StructuralNode _visitForm(ArgumentList args) {
    final _events = _popEvents();
    final accumulatedClasses = List<String>.from(_bucket);
    _bucket.clear();

    final childNode = visitExpr(_getArgNamed(args, 'child'));

    return StructuralNode(
      events: _events,
      htmlTag: 'form',
      ownClasses: [],
      accumulatedClasses: accumulatedClasses,
      children: childNode != null ? [childNode] : [],
      needsClientAnnotation: true, // Forms have state
    );
  }

  StructuralNode _visitCheckbox() {
    final _events = _popEvents();
    final accumulatedClasses = List<String>.from(_bucket);
    _bucket.clear();
    return StructuralNode(
      events: _events,
      htmlTag: 'input',
      ownClasses: ['rounded'],
      accumulatedClasses: accumulatedClasses,
      children: [],
      attributes: {'type': 'checkbox'},
      needsClientAnnotation: true,
    );
  }

  StructuralNode _visitSwitch() {
    final _events = _popEvents();
    final accumulatedClasses = List<String>.from(_bucket);
    _bucket.clear();
    return StructuralNode(
      events: _events,
      htmlTag: 'input',
      ownClasses: ['toggle'],
      accumulatedClasses: accumulatedClasses,
      children: [],
      attributes: {'type': 'checkbox', 'role': 'switch'},
      needsClientAnnotation: true,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Structural Node Handlers — Utility
  // ───────────────────────────────────────────────────────────────────────────

  StructuralNode _visitDivider() {
    final _events = _popEvents();
    final accumulatedClasses = List<String>.from(_bucket);
    _bucket.clear();
    return StructuralNode(
      events: _events,
      htmlTag: 'hr',
      ownClasses: ['border-t', 'border-gray-200', 'my-2'],
      accumulatedClasses: accumulatedClasses,
      children: [],
    );
  }

  StructuralNode _visitSpacer() {
    final _events = _popEvents();
    final accumulatedClasses = List<String>.from(_bucket);
    _bucket.clear();
    return StructuralNode(
      events: _events,
      htmlTag: 'div',
      ownClasses: ['flex-1'],
      accumulatedClasses: accumulatedClasses,
      children: [],
    );
  }

  StructuralNode _visitCircularProgress() {
    final _events = _popEvents();
    final accumulatedClasses = List<String>.from(_bucket);
    _bucket.clear();
    return StructuralNode(
      events: _events,
      htmlTag: 'div',
      ownClasses: [
        'animate-spin',
        'rounded-full',
        'border-4',
        'border-gray-200',
        'border-t-blue-600',
        'w-8',
        'h-8',
      ],
      accumulatedClasses: accumulatedClasses,
      children: [],
    );
  }

  StructuralNode _visitLinearProgress() {
    final _events = _popEvents();
    final accumulatedClasses = List<String>.from(_bucket);
    _bucket.clear();
    return StructuralNode(
      events: _events,
      htmlTag: 'div',
      ownClasses: ['animate-pulse', 'h-1', 'bg-blue-600', 'w-full', 'rounded'],
      accumulatedClasses: accumulatedClasses,
      children: [],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Private helpers
  // ───────────────────────────────────────────────────────────────────────────

  WidgetNode? _visitBuildMethod(MethodDeclaration method) {
    // Find the first return statement expression in build()
    final finder = _ReturnExpressionFinder();
    method.body.accept(finder);
    return visitExpr(finder.returnExpression);
  }

  /// Visits the `children:` list argument and returns [WidgetNode]s.
  List<WidgetNode> _visitChildrenList(ArgumentList args) {
    final childrenExpr = _getArgNamed(args, 'children');
    if (childrenExpr is ListLiteral) {
      return childrenExpr.elements
          .whereType<Expression>()
          .map(visitExpr)
          .whereType<WidgetNode>()
          .toList();
    }
    return [];
  }

  /// Like [_visitChildrenList] but wraps each child in a [wrapTag] element.
  List<WidgetNode> _visitChildrenListWrapped(
    ArgumentList args, {
    required String wrapTag,
  }) {
    return _visitChildrenList(args).map((child) {
      return StructuralNode(
        events: _popEvents(),
        htmlTag: wrapTag,
        ownClasses: [],
        children: [child],
      );
    }).toList();
  }

  /// Flushes the accumulator bucket and prepends to [ownClasses].
  List<String> _flushBucketWith(List<String> ownClasses) {
    final flushed = List<String>.from(_bucket);
    _bucket.clear();
    return [...flushed, ...ownClasses];
  }

  void _applyMainAxis(ArgumentList args, List<String> classes) {
    final expr = _getArgNamed(args, 'mainAxisAlignment');
    if (expr != null) {
      classes.add(TailwindMapper.mainAxisAlignmentToJustify(expr.toSource()));
    }
  }

  void _applyCrossAxis(ArgumentList args, List<String> classes) {
    final expr = _getArgNamed(args, 'crossAxisAlignment');
    if (expr != null) {
      classes.add(TailwindMapper.crossAxisAlignmentToItems(expr.toSource()));
    }
  }

  void _applyPhysics(ArgumentList args, List<String> classes) {
    final expr = _getArgNamed(args, 'physics');
    if (expr != null) {
      final source = expr.toSource();
      if (source.contains('BouncingScrollPhysics')) {
        classes.add('overscroll-contain');
      } else if (source.contains('ClampingScrollPhysics')) {
        classes.add('overscroll-none');
      } else if (source.contains('PageScrollPhysics')) {
        classes.addAll(['snap-y', 'snap-mandatory']);
      }
    }
  }

  List<String> _parsePaddingExpression(Expression? expr) {
    if (expr == null) return [];
    final src = expr.toSource();

    if (src.startsWith('EdgeInsets.all(')) {
      final match = RegExp(r'EdgeInsets\.all\((\d+\.?\d*)\)').firstMatch(src);
      if (match != null) {
        final value = double.parse(match.group(1)!);
        return [TailwindMapper.edgeInsetsAllToPadding(value)];
      }
    } else if (src.startsWith('EdgeInsets.symmetric(')) {
      final hMatch = RegExp(r'horizontal:\s*(\d+\.?\d*)').firstMatch(src);
      final vMatch = RegExp(r'vertical:\s*(\d+\.?\d*)').firstMatch(src);
      final h = hMatch != null ? double.parse(hMatch.group(1)!) : 0.0;
      final v = vMatch != null ? double.parse(vMatch.group(1)!) : 0.0;
      return [
        TailwindMapper.edgeInsetsSymmetricToPadding(horizontal: h, vertical: v)
      ];
    } else if (src.startsWith('EdgeInsets.only(')) {
      final top = _extractEdgeInsetsPart(src, 'top');
      final right = _extractEdgeInsetsPart(src, 'right');
      final bottom = _extractEdgeInsetsPart(src, 'bottom');
      final left = _extractEdgeInsetsPart(src, 'left');
      final result = TailwindMapper.edgeInsetsOnlyToPadding(
        top: top,
        right: right,
        bottom: bottom,
        left: left,
      );
      return result.isNotEmpty ? result.split(' ') : [];
    }

    return [];
  }

  double _extractEdgeInsetsPart(String src, String part) {
    final match = RegExp('$part:\\s*(\\d+\\.?\\d*)').firstMatch(src);
    return match != null ? double.parse(match.group(1)!) : 0.0;
  }

  Expression? _getArgNamed(ArgumentList args, String name) {
    for (final arg in args.arguments) {
      if (arg is NamedExpression && arg.name.label.name == name) {
        return arg.expression;
      }
    }
    return null;
  }

  String? _getStringArg(ArgumentList args, String name) {
    final expr = _getArgNamed(args, name);
    if (expr == null) return null;
    return _extractStringLiteral(expr);
  }

  String _extractStringLiteral(Expression expr) {
    if (expr is StringLiteral) {
      return expr.stringValue ??
          expr.toSource().replaceAll("'", '').replaceAll('"', '');
    }
    return expr.toSource();
  }

  double? _parseDouble(Expression expr) {
    if (expr is IntegerLiteral) return expr.value?.toDouble();
    if (expr is DoubleLiteral) return expr.value;
    return null;
  }

  int? _parseInt(Expression expr) {
    if (expr is IntegerLiteral) return expr.value;
    return null;
  }

  double? _extractFontSize(Expression styleExpr) {
    final src = styleExpr.toSource();
    final match = RegExp(r'fontSize:\s*(\d+\.?\d*)').firstMatch(src);
    return match != null ? double.parse(match.group(1)!) : null;
  }

  JetRouteMetadata _extractJetRouteMetadata(Annotation annotation) {
    final args = annotation.arguments;
    if (args == null) {
      return const JetRouteMetadata(path: '/', title: '');
    }
    String path = '/';
    String title = '';
    String? description;
    for (final arg in args.arguments) {
      if (arg is NamedExpression) {
        final name = arg.name.label.name;
        final value = _extractStringLiteral(arg.expression);
        switch (name) {
          case 'path':
            path = value;
          case 'title':
            title = value;
          case 'description':
            description = value;
        }
      }
    }
    return JetRouteMetadata(path: path, title: title, description: description);
  }

  bool _treeNeedsClient(WidgetNode? node) {
    if (node == null) return false;
    return switch (node) {
      StructuralNode(needsClientAnnotation: true) => true,
      StructuralNode(events: final e) when e.isNotEmpty => true,
      StructuralNode(:final children) => children.any(_treeNeedsClient),
      ComponentNode(:final buildBody) => _treeNeedsClient(buildBody),
      _ => false,
    };
  }
}

/// Helper visitor that finds the first return expression in a method body.
class _ReturnExpressionFinder extends RecursiveAstVisitor<void> {
  Expression? returnExpression;

  @override
  void visitReturnStatement(ReturnStatement node) {
    returnExpression ??= node.expression;
  }

  @override
  void visitExpressionFunctionBody(ExpressionFunctionBody node) {
    returnExpression ??= node.expression;
  }
}
