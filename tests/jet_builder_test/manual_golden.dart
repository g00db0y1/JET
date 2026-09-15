
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:dart_style/dart_style.dart';
import 'package:jet_builder/src/parser/flutter_ast_parser.dart';
import 'package:jet_builder/src/visitor/style_accumulator_visitor.dart';
import 'package:jet_builder/src/emitter/jaspr_emitter.dart';

void main() {
  final corpusDir = Directory('../../tests/corpus');
  final expectedDir = Directory('../../tests/expected');

  final dartFiles = corpusDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  for (final file in dartFiles) {
    final relativePath = p.relative(file.path, from: corpusDir.path);
    final sourceCode = file.readAsStringSync();
    final parser = FlutterAstParser();
    final result = parser.parse(source: sourceCode, path: file.path);
    final visitor = StyleAccumulatorVisitor();
    result.unit!.accept(visitor);
    final emitter = JasprEmitter();
    final generatedCode = DartFormatter(languageVersion: DartFormatter.latestLanguageVersion).format(emitter.emitFile(
      components: visitor.components,
      sourceFile: file.path,
      version: 'test-golden',
    ));
    final expectedFile = File(p.join(
      expectedDir.path, 
      relativePath.replaceFirst('.dart', '.expected.dart'),
    ));
    expectedFile.parent.createSync(recursive: true);
    expectedFile.writeAsStringSync(generatedCode);
    print('Updated ' + relativePath);
  }
}

