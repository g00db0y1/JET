import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';

/// Parses a Flutter Dart source string into an analyzer [CompilationUnit].
///
/// Uses `parseString()` from `package:analyzer/dart/analysis/utilities.dart`
/// for lightweight, dependency-free parsing without needing a full analysis context.
///
/// ## Usage
/// ```dart
/// final parser = FlutterAstParser();
/// final result = parser.parse(source: dartSourceCode, path: 'lib/ui/home.dart');
/// if (result.errors.isEmpty) {
///   result.unit.accept(visitor);
/// }
/// ```
class FlutterAstParser {
  const FlutterAstParser();

  /// Parses [source] Dart code and returns a [ParseResult].
  ///
  /// The [path] is used for error reporting only — the file does not need
  /// to exist on disk.
  ParseResult parse({required String source, required String path}) {
    try {
      final result =
          parseString(content: source, path: path, throwIfDiagnostics: false);
      final errors = result.errors
          .where((e) => e.errorCode.errorSeverity == ErrorSeverity.ERROR)
          .toList();

      return ParseResult(
        unit: result.unit,
        errors: errors,
        path: path,
      );
    } catch (e) {
      return ParseResult.failed(path: path, errorMessage: e.toString());
    }
  }

  /// Returns `true` if this file should be skipped (routing, main.dart, etc.).
  bool shouldSkip(String source, String path) {
    // Skip main.dart
    if (path.endsWith('main.dart')) return true;

    // Skip files that contain go_router or Navigator route configuration
    if (source.contains("import 'package:go_router/go_router.dart'") ||
        source.contains('import "package:go_router/go_router.dart"')) {
      return true;
    }

    // Skip files that are clearly router definitions
    if (source.contains('GoRouter(') || source.contains('GoRoute(')) {
      return true;
    }

    return false;
  }
}

/// The result of parsing a Dart source file.
class ParseResult {
  ParseResult({
    required this.unit,
    required this.errors,
    required this.path,
  }) : failed = false;

  ParseResult.failed({
    required this.path,
    required String errorMessage,
  })  : unit = null,
        errors = [],
        failed = true,
        failureMessage = errorMessage;

  /// The parsed AST root. Null if parsing failed catastrophically.
  final CompilationUnit? unit;

  /// Analyzer errors found during parsing.
  final List<AnalysisError> errors;

  /// The file path that was parsed.
  final String path;

  /// Whether parsing failed completely (e.g., file unreadable).
  final bool failed;

  /// Error message if [failed] is `true`.
  String? failureMessage;

  /// Whether this result is usable for transpilation.
  bool get isUsable => !failed && unit != null;
}
