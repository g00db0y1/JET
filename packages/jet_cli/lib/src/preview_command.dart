import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:analyzer/dart/ast/ast.dart';
import 'package:jet_builder/src/parser/flutter_ast_parser.dart';
import 'package:jet_builder/src/visitor/style_accumulator_visitor.dart';
import 'package:jet_builder/src/emitter/jaspr_emitter.dart';

Future<void> runPreview(String filePath, {int? lineNumber}) async {
  final file = File(filePath);
  if (!file.existsSync()) {
    print('[JET] ❌ File not found: $filePath');
    exit(1);
  }

  print(
      '[JET] 🚀 Previewing $filePath${lineNumber != null ? ' (Line $lineNumber)' : ''}...\n');

  final source = file.readAsStringSync();
  final stopwatch = Stopwatch()..start();

  final parser = FlutterAstParser();
  final parseResult = parser.parse(source: source, path: filePath);

  if (!parseResult.isUsable) {
    print('[JET] ❌ Failed to parse $filePath');
    print(parseResult.failureMessage ?? 'Unknown error');
    exit(1);
  }

  if (parseResult.errors.isNotEmpty) {
    print('[JET] ⚠️ Syntax errors found in file:');
    for (final err in parseResult.errors) {
      print('  - ${err.message} at offset ${err.offset}');
    }
  }

  // Filter by line number if provided
  String? targetClassName;
  if (lineNumber != null) {
    final lineInfo = parseResult.unit!.lineInfo;
    for (final decl in parseResult.unit!.declarations) {
      if (decl is ClassDeclaration) {
        final startLine = lineInfo.getLocation(decl.offset).lineNumber;
        final endLine = lineInfo.getLocation(decl.end).lineNumber;
        if (lineNumber >= startLine && lineNumber <= endLine) {
          targetClassName = decl.name.lexeme;
          break;
        }
      }
    }

    if (targetClassName == null) {
      print('[JET] ⚠️ No widget class found spanning line $lineNumber.');
      exit(0);
    }
    print('[JET] 🎯 Found target widget: $targetClassName');
  }

  final visitor = StyleAccumulatorVisitor();
  parseResult.unit!.accept(visitor);

  final emitter = JasprEmitter();

  var componentsToEmit = visitor.components;
  if (targetClassName != null) {
    componentsToEmit =
        componentsToEmit.where((c) => c.name == targetClassName).toList();
  }

  if (componentsToEmit.isEmpty) {
    print('[JET] ⚠️ No transpiled components found.');
    exit(0);
  }

  final jasprCode = emitter.emitFile(
    components: componentsToEmit,
    sourceFile: filePath,
    version: '0.1.0-dev',
  );

  stopwatch.stop();

  // Print Output
  print(
      '// ─────────────────────────────────────────────────────────────────────────────');
  print('// ✨ Transpiled to Jaspr in ${stopwatch.elapsedMilliseconds}ms');
  print(
      '// ─────────────────────────────────────────────────────────────────────────────\n');
  print(jasprCode);

  // Feature 2: Save preview@filename.jaspr.dart in .jet_cache if it was a full file
  if (lineNumber == null) {
    final cacheDir = Directory('.jet_cache');
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }
    final basename = p.basename(filePath);
    // Label it as .jaspr.dart in the cache so JET knows its target environment!
    final newName = 'preview@${basename.replaceFirst('.dart', '.jaspr.dart')}';
    final cacheFile = File(p.join(cacheDir.path, newName));
    cacheFile.writeAsStringSync(jasprCode);
    print('\n[JET] 📂 Saved full preview to ${cacheFile.path}');
  }
}
