import 'package:analyzer/dart/ast/ast.dart';
import '../visitor/widget_node.dart';
import 'sniffer.dart';

/// Sniffs for heavy graphics widgets (CustomPaint, Canvas, etc.)
/// and forces them into a FlutterEmbedView.
class GraphicsSniffer extends JetSniffer {
  const GraphicsSniffer();

  @override
  WidgetNode? sniffWidgetCreation(
      String typeName, String? constructorName, ArgumentList args) {
    if (const {
      'CustomPaint',
      'Canvas',
      'RepaintBoundary',
      'Texture',
      'BackdropFilter'
    }.contains(typeName)) {
      final rawCode = args.parent?.toSource() ?? '';
      return EcosystemNode(
        package: 'jaspr_flutter_embed',
        code: 'FlutterEmbedView(child: $rawCode)',
        needsClientAnnotation: true,
      );
    }
    return null;
  }
}
