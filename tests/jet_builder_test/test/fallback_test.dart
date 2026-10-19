import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:jet_builder/src/visitor/style_accumulator_visitor.dart';
import 'package:jet_builder/src/visitor/widget_node.dart';
import 'package:test/test.dart';

void main() {
  test('JetFallback skips parsing and returns raw code', () {
    final code = '''
      @JetFallback('JasprVideoPlayer(url: url)')
      class NativeVideoPlayer extends StatelessWidget {
        @override
        Widget build(BuildContext context) {
          return CustomCanvasVideo();
        }
      }
    ''';

    final result = parseString(content: code, throwIfDiagnostics: false);
    final visitor = StyleAccumulatorVisitor();
    result.unit.accept(visitor);

    final component = visitor.components.first;
    expect(component.name, 'NativeVideoPlayer');

    final body = component.buildBody;
    expect(body, isA<EcosystemNode>());
    expect((body as EcosystemNode).code, 'JasprVideoPlayer(url: url)');
  });
}
