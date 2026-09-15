import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:dart_style/dart_style.dart';

import 'package:jet_builder/src/parser/flutter_ast_parser.dart';
import 'package:jet_builder/src/visitor/style_accumulator_visitor.dart';
import 'package:jet_builder/src/emitter/jaspr_emitter.dart';

void main() {
  // Pass UPDATE_GOLDENS=true to overwrite the expected files
  final updateGoldens = Platform.environment['UPDATE_GOLDENS'] == 'true';

  // Resolve paths relative to the test project root
  final corpusDir = Directory('../../tests/corpus');
  final expectedDir = Directory('../../tests/expected');

  group('Golden Tests - Flutter to Jaspr', () {
    if (!corpusDir.existsSync()) {
      print('⚠️ Corpus directory not found at ${corpusDir.path}');
      return;
    }

    final dartFiles = corpusDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    for (final file in dartFiles) {
      final relativePath = p.relative(file.path, from: corpusDir.path);

      test('Matches golden output for $relativePath', () {
        final sourceCode = file.readAsStringSync();
        final parser = FlutterAstParser();
        final result = parser.parse(source: sourceCode, path: file.path);

        expect(result.isUsable, isTrue,
            reason: 'AST Parse failed: ${result.failureMessage}');

        final visitor = StyleAccumulatorVisitor();
        result.unit!.accept(visitor);

        final emitter = JasprEmitter();
        final rawGeneratedCode = emitter.emitFile(
          components: visitor.components,
          sourceFile: file.path,
          version: 'test-golden', // Hardcoded version for deterministic tests
        );

        final generatedCode = DartFormatter(languageVersion: DartFormatter.latestLanguageVersion).format(rawGeneratedCode);

        final expectedFile = File(p.join(
          expectedDir.path,
          relativePath.replaceFirst('.dart', '.expected.dart'),
        ));

        if (updateGoldens || !expectedFile.existsSync()) {
          // Write/Update the golden file
          expectedFile.parent.createSync(recursive: true);
          expectedFile.writeAsStringSync(generatedCode);
          print('✅ Generated golden for $relativePath');
        } else {
          // Compare against existing golden file
          final expectedCode = expectedFile.readAsStringSync();

          // Strip timestamps and normalize line endings for deterministic comparison
          final generatedNoTime = generatedCode
              .replaceAll(RegExp(r'// Generated at: .*\n'), '')
              .replaceAll('\r\n', '\n');
              
          final expectedNoTime = expectedCode
              .replaceAll(RegExp(r'// Generated at: .*\n'), '')
              .replaceAll('\r\n', '\n');

          expect(
            generatedNoTime,
            equals(expectedNoTime),
            reason:
                'Generated Jaspr code does not match the golden file for $relativePath.',
          );
        }
      });
    }
  });
}
