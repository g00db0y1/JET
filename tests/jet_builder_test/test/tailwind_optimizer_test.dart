import 'package:test/test.dart';
import 'package:jet_builder/src/optimizer/tailwind_optimizer.dart';

void main() {
  group('TailwindOptimizer', () {
    late TailwindOptimizer optimizer;

    setUp(() {
      optimizer = TailwindOptimizer();
    });

    test('replaces exact raw styles with tailwind classes', () {
      final rawCode =
          "div(styles: Styles.raw('display: flex; flex-direction: column;'), [text('Hello')])";
      final optimized = optimizer.optimize(rawCode);

      expect(optimized, "div(classes: 'flex flex-col', [text('Hello')])");
    });

    test('preserves unknown styles as raw CSS', () {
      final rawCode =
          "div(styles: Styles.raw('display: flex; custom-property: 10px;'), [text('Hello')])";
      final optimized = optimizer.optimize(rawCode);

      expect(optimized,
          "div(classes: 'flex', styles: Styles.raw('custom-property: 10px;'), [text('Hello')])");
    });

    test('handles multiple style blocks in one file', () {
      final rawCode = '''
        div(styles: Styles.raw('width: 100%;'), [
          span(styles: Styles.raw('font-weight: bold;'), [text('Text')])
        ])
      ''';

      final optimized = optimizer.optimize(rawCode);

      expect(optimized, contains("classes: 'w-full'"));
      expect(optimized, contains("classes: 'font-bold'"));
      expect(optimized, isNot(contains("Styles.raw")));
    });
  });
}
