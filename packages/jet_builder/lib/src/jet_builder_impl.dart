import 'dart:async';

import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';

import 'emitter/jaspr_emitter.dart';
import 'linter/poison_sniffer.dart';
import 'parser/flutter_ast_parser.dart';
import 'visitor/style_accumulator_visitor.dart';

/// The core `build_runner` [Builder] implementation for JET.
///
/// Processes `.dart` files from the configured `generate_for` patterns
/// and emits `.jaspr.dart` Jaspr component files.
///
/// ## Pipeline
/// ```
/// [Input .dart file]
///       ↓
/// FlutterAstParser → CompilationUnit
///       ↓
/// PoisonSniffer → violations (non-fatal, logged to stderr)
///       ↓
/// StyleAccumulatorVisitor → List<ComponentNode>
///       ↓
/// JasprEmitter → Jaspr Dart source string
///       ↓
/// DartFormatter → formatted output
///       ↓
/// [Output .jaspr.dart file]
/// ```
class JetBuilderImpl implements Builder {
  JetBuilderImpl(this.options);

  final BuilderOptions options;

  static final _formatter =
      DartFormatter(languageVersion: DartFormatter.latestLanguageVersion);
  static const _parser = FlutterAstParser();
  static const _sniffer = PoisonSniffer();
  static const _emitter = JasprEmitter();

  @override
  Map<String, List<String>> get buildExtensions => {
        '.dart': ['.jaspr.dart'],
      };

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;
    final inputPath = inputId.path;

    // Read the source
    final source = await buildStep.readAsString(inputId);

    // Skip files that shouldn't be transpiled (routing, main.dart, etc.)
    if (_parser.shouldSkip(source, inputPath)) {
      log.fine('[JET] Skipping $inputPath — routing or main entry file');
      return;
    }

    // Skip files that contain no widget class declarations (quick check)
    if (!source.contains('StatelessWidget') &&
        !source.contains('StatefulWidget')) {
      log.fine('[JET] Skipping $inputPath — no Flutter widget classes found');
      return;
    }

    // Parse
    final parseResult = _parser.parse(source: source, path: inputPath);

    if (!parseResult.isUsable) {
      log.warning(
          '[JET] Parse failed for $inputPath: ${parseResult.failureMessage}');
      return;
    }

    if (parseResult.errors.isNotEmpty) {
      log.warning(
        '[JET] Parse errors in $inputPath: '
        '${parseResult.errors.map((e) => e.message).join(', ')}',
      );
    }

    final unit = parseResult.unit!;

    // Lint (non-fatal)
    final violations = _sniffer.analyze(unit: unit, filePath: inputPath);
    if (violations.isNotEmpty) {
      PoisonSniffer.reportViolations(violations);
    }

    // Visit
    final visitor = StyleAccumulatorVisitor();
    unit.accept(visitor);

    if (visitor.components.isEmpty) {
      log.fine('[JET] No components found in $inputPath');
      return;
    }

    // Emit
    var generated = _emitter.emitFile(
      components: visitor.components,
      sourceFile: inputPath,
    );

    // Format
    try {
      generated = _formatter.format(generated);
    } catch (e) {
      log.warning('[JET] Could not format generated output for $inputPath: $e');
      // Use unformatted output rather than failing
    }

    // Write output
    final outputId = inputId.changeExtension('.jaspr.dart');
    await buildStep.writeAsString(outputId, generated);

    log.info(
        '[JET] ✅ Generated ${outputId.path} (${visitor.components.length} component(s))');
  }
}
