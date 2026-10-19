import 'package:analyzer/dart/ast/ast.dart';
import '../visitor/widget_node.dart';
import 'poison_sniffer.dart'; // for LinterViolation

/// Base class for all JET AST sniffers.
/// Sniffers can act as both passive linters and active AST intercepts.
abstract class JetSniffer {
  const JetSniffer();

  /// Analyzes the compilation unit and returns any architectural violations.
  List<LinterViolation> analyze(CompilationUnit unit, String filePath) =>
      const [];

  /// Intercepts widget creation during transpilation.
  /// Return a [WidgetNode] to override standard transpilation, or null to pass.
  WidgetNode? sniffWidgetCreation(
          String typeName, String? constructorName, ArgumentList args) =>
      null;
}

/// A registry that coordinates the active sniffer plugins.
class SnifferRegistry {
  final List<JetSniffer> _sniffers = [];

  void register(JetSniffer sniffer) {
    _sniffers.add(sniffer);
  }

  /// Runs all registered sniffers over the unit and collects violations.
  List<LinterViolation> analyzeAll(CompilationUnit unit, String filePath) {
    final violations = <LinterViolation>[];
    for (final sniffer in _sniffers) {
      violations.addAll(sniffer.analyze(unit, filePath));
    }
    return violations;
  }

  /// Allows sniffers to intercept and replace widget creation during transpilation.
  WidgetNode? interceptWidgetCreation(
      String typeName, String? constructorName, ArgumentList args) {
    for (final sniffer in _sniffers) {
      final node = sniffer.sniffWidgetCreation(typeName, constructorName, args);
      if (node != null) return node;
    }
    return null;
  }
}
