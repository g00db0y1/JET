import 'dart:async';
import 'dart:io';

import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as p;

import 'emitter/jaspr_emitter.dart';
import 'linter/animation_sniffer.dart';
import 'linter/graphics_sniffer.dart';
import 'linter/poison_sniffer.dart';
import 'linter/sniffer.dart';
import 'optimizer/tailwind_optimizer.dart';
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
/// JasprEmitter -> raw Jaspr Dart source string (.jet_cache/raw/)
///       ->
/// TailwindOptimizer -> optimized Jaspr Dart source string (.jet_cache/optimized/)
///       ->
/// Generated Code Poison Sniffer -> blocks if poisoned
///       ->
/// DartFormatter -> formatted output
///       ->
/// [Output .jaspr.dart file]
/// ```
class JetBuilderImpl implements Builder {
  JetBuilderImpl(this.options);

  final BuilderOptions options;

  static final _formatter =
      DartFormatter(languageVersion: DartFormatter.latestLanguageVersion);
  static const _parser = FlutterAstParser();
  static final _snifferRegistry = SnifferRegistry()
    ..register(const PoisonSniffer())
    ..register(const GraphicsSniffer())
    ..register(const AnimationSniffer());
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
    final violations = _snifferRegistry.analyzeAll(unit, inputPath);
    if (violations.isNotEmpty) {
      PoisonSniffer.reportViolations(violations);
    }

    // Visit
    final visitor = StyleAccumulatorVisitor(snifferRegistry: _snifferRegistry);
    unit.accept(visitor);

    if (visitor.components.isEmpty) {
      log.fine('[JET] No components found in $inputPath');
      return;
    }

    // Step 1: Emit Raw (Speed)
    final rawJasprCode = _emitter.emitFile(
      components: visitor.components,
      sourceFile: inputPath,
    );

    try {
      final rawCacheDir = Directory('.jet_cache/raw');
      if (!rawCacheDir.existsSync()) rawCacheDir.createSync(recursive: true);
      final targetName =
          p.basename(inputPath).replaceFirst('.dart', '.jaspr.dart');
      File(p.join(rawCacheDir.path, targetName))
          .writeAsStringSync(rawJasprCode);
    } catch (_) {} // Ignore file system errors in build_runner

    // Step 2: Optimize (Accuracy)
    final optimizer = TailwindOptimizer();
    final optimizedCode = optimizer.optimize(rawJasprCode);

    try {
      final optCacheDir = Directory('.jet_cache/optimized');
      if (!optCacheDir.existsSync()) optCacheDir.createSync(recursive: true);
      final targetName =
          p.basename(inputPath).replaceFirst('.dart', '.jaspr.dart');
      File(p.join(optCacheDir.path, targetName))
          .writeAsStringSync(optimizedCode);
    } catch (_) {}

    // Step 3: Poison Sniff (Safety)
    final isPoisoned = optimizedCode.contains('import \'dart:io\'') ||
        optimizedCode.contains('stripe_payment');

    if (isPoisoned) {
      log.severe(
          '[JET] ☠️ POISON DETECTED in $inputPath. Blocked from emitting.');
      return;
    }

    // Format
    var generated = optimizedCode;
    try {
      generated = _formatter.format(generated);
    } catch (e) {
      log.warning('[JET] Could not format generated output for $inputPath: $e');
    }

    // Write output (Promotion)
    final outputId = inputId.changeExtension('.jaspr.dart');
    await buildStep.writeAsString(outputId, generated);

    log.info(
        '[JET] ✅ Generated ${outputId.path} (${visitor.components.length} component(s))');
  }
}
