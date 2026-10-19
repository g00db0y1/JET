import 'package:analyzer/dart/ast/ast.dart';
import '../visitor/widget_node.dart';
import 'sniffer.dart';

/// Sniffs for heavy animation widgets (TweenAnimationBuilder, Lottie, Rive, etc.)
/// and forces them into a FlutterEmbedView or equivalent client boundary.
class AnimationSniffer extends JetSniffer {
  const AnimationSniffer();

  @override
  WidgetNode? sniffWidgetCreation(
      String typeName, String? constructorName, ArgumentList args) {
    if (const {
      'TweenAnimationBuilder',
      'AnimatedBuilder',
      'Lottie',
      'RiveAnimation',
      'Hero'
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
