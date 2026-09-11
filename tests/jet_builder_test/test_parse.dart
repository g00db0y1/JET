import 'package:jet_builder/src/parser/flutter_ast_parser.dart';
import 'package:jet_builder/src/visitor/style_accumulator_visitor.dart';

void main() {
  print('Starting parse...');
  final parser = FlutterAstParser();
  final source = '''
import 'package:flutter/widgets.dart';
class HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(children: [Text('Hello')]);
  }
}
''';
  
  final result = parser.parse(source: source, path: 'test.dart');
  print('Parsed!');
  
  final visitor = StyleAccumulatorVisitor();
  print('Visiting...');
  result.unit!.accept(visitor);
  print('Done!');
}
