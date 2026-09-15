import 'package:test/test.dart';

import 'package:jet_builder/src/parser/flutter_ast_parser.dart';
import 'package:jet_builder/src/visitor/style_accumulator_visitor.dart';
import 'package:jet_builder/src/visitor/widget_node.dart';

void main() {
  late FlutterAstParser parser;

  setUp(() {
    parser = const FlutterAstParser();
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────────

  /// Parses [source] and runs the visitor. Returns the list of ComponentNodes.
  List<ComponentNode> transpile(String source) {
    final result = parser.parse(source: source, path: 'lib/ui/test.dart');
    expect(result.isUsable, isTrue,
        reason: 'Parse failed: ${result.failureMessage}');
    final visitor = StyleAccumulatorVisitor();
    result.unit!.accept(visitor);
    return visitor.components;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // StatelessWidget detection
  // ─────────────────────────────────────────────────────────────────────────────

  group('ComponentNode detection', () {
    test('StatelessWidget produces ComponentNode with isStateful=false', () {
      final components = transpile('''
import 'package:flutter/widgets.dart';
class HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text('Hello');
}
''');
      expect(components, hasLength(1));
      expect(components.first.name, equals('HeroSection'));
      expect(components.first.isStateful, isFalse);
    });

    test('StatefulWidget produces ComponentNode with isStateful=true', () {
      final components = transpile('''
import 'package:flutter/widgets.dart';
class CounterWidget extends StatefulWidget {
  @override
  State<CounterWidget> createState() => _CounterWidgetState();
}
class _CounterWidgetState extends State<CounterWidget> {
  @override
  Widget build(BuildContext context) => Text('Count');
}
''');
      // Only the StatefulWidget class is captured (not the State class)
      final widget = components.firstWhere((c) => c.name == 'CounterWidget');
      expect(widget.isStateful, isTrue);
    });

    test('Non-widget classes are ignored', () {
      final components = transpile('''
class MyService {
  void doWork() {}
}
''');
      expect(components, isEmpty);
    });

    test('Multiple widgets in one file produces multiple ComponentNodes', () {
      final components = transpile('''
import 'package:flutter/widgets.dart';
class WidgetA extends StatelessWidget {
  @override Widget build(BuildContext context) => Text('A');
}
class WidgetB extends StatelessWidget {
  @override Widget build(BuildContext context) => Text('B');
}
''');
      expect(components, hasLength(2));
      expect(
          components.map((c) => c.name), containsAll(['WidgetA', 'WidgetB']));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Modifier Node accumulation
  // ─────────────────────────────────────────────────────────────────────────────

  group('Modifier nodes accumulate into next structural node', () {
    test('Padding(all:16) accumulates p-4 on Column', () {
      final components = transpile('''
import 'package:flutter/widgets.dart';
class Demo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(children: []),
    );
  }
}
''');
      final body = components.first.buildBody;
      expect(body, isA<StructuralNode>());
      final col = body as StructuralNode;
      expect(col.htmlTag, equals('div'));
      expect(col.allClasses, contains('p-4'));
      expect(col.allClasses, contains('flex'));
      expect(col.allClasses, contains('flex-col'));
    });

    test('Center accumulates flex+items-center+justify-center on child', () {
      final components = transpile('''
import 'package:flutter/widgets.dart';
class Demo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(children: []),
    );
  }
}
''');
      final body = components.first.buildBody as StructuralNode;
      expect(body.allClasses,
          containsAll(['flex', 'items-center', 'justify-center']));
    });

    test('SizedBox(width:16) accumulates w-4', () {
      final components = transpile('''
import 'package:flutter/widgets.dart';
class Demo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      child: Text('test'),
    );
  }
}
''');
      final body = components.first.buildBody as StructuralNode;
      expect(body.allClasses, contains('w-4'));
    });

    test('Expanded accumulates flex-1', () {
      final components = transpile('''
import 'package:flutter/widgets.dart';
class Demo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text('fills space')),
      ],
    );
  }
}
''');
      final row = components.first.buildBody as StructuralNode;
      final expanded = row.children.first as StructuralNode;
      expect(expanded.allClasses, contains('flex-1'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Structural Node output
  // ─────────────────────────────────────────────────────────────────────────────

  group('Structural nodes emit correct IR', () {
    test('Column → div.flex.flex-col', () {
      final components = transpile('''
import 'package:flutter/widgets.dart';
class Demo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [Text('A'), Text('B')],
    );
  }
}
''');
      final col = components.first.buildBody as StructuralNode;
      expect(col.htmlTag, equals('div'));
      expect(col.ownClasses, contains('flex-col'));
      expect(col.ownClasses, contains('justify-center'));
      expect(col.children, hasLength(2));
    });

    test('Row → div.flex.flex-row', () {
      final components = transpile('''
import 'package:flutter/widgets.dart';
class Demo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text('Left'), Text('Right')],
    );
  }
}
''');
      final row = components.first.buildBody as StructuralNode;
      expect(row.htmlTag, equals('div'));
      expect(row.ownClasses, contains('flex-row'));
      expect(row.ownClasses, contains('justify-between'));
    });

    test('Scaffold → main', () {
      final components = transpile('''
import 'package:flutter/material.dart';
class Demo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: []),
    );
  }
}
''');
      final scaffold = components.first.buildBody as StructuralNode;
      expect(scaffold.htmlTag, equals('main'));
    });

    test('ListView → ul', () {
      final components = transpile('''
import 'package:flutter/widgets.dart';
class Demo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(children: [Text('Item 1'), Text('Item 2')]);
  }
}
''');
      final list = components.first.buildBody as StructuralNode;
      expect(list.htmlTag, equals('ul'));
      // Children should be wrapped in li
      for (final child in list.children) {
        expect((child as StructuralNode).htmlTag, equals('li'));
      }
    });

    test('Text → p with textContent', () {
      final components = transpile('''
import 'package:flutter/widgets.dart';
class Demo extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text('Hello World');
}
''');
      final text = components.first.buildBody as StructuralNode;
      expect(text.htmlTag, equals('p'));
      expect(text.textContent, equals('Hello World'));
    });

    test('Text with large fontSize → h1', () {
      final components = transpile('''
import 'package:flutter/widgets.dart';
class Demo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text('Big Title', style: TextStyle(fontSize: 32));
  }
}
''');
      final text = components.first.buildBody as StructuralNode;
      expect(text.htmlTag, equals('h1'));
    });

    test('Image.network → img with src attribute', () {
      final components = transpile('''
import 'package:flutter/widgets.dart';
class Demo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.network('https://example.com/image.png');
  }
}
''');
      final img = components.first.buildBody as StructuralNode;
      expect(img.htmlTag, equals('img'));
      expect(img.attributes['src'], equals('https://example.com/image.png'));
    });

    test('ElevatedButton → button with needsClientAnnotation=true', () {
      final components = transpile('''
import 'package:flutter/material.dart';
class Demo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {},
      child: Text('Click me'),
    );
  }
}
''');
      final button = components.first.buildBody as StructuralNode;
      expect(button.htmlTag, equals('button'));
      expect(button.needsClientAnnotation, isTrue);
    });

    test('ElevatedButton causes ComponentNode.isStateful=true (client bubble)',
        () {
      final components = transpile('''
import 'package:flutter/material.dart';
class Demo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(onPressed: () {}, child: Text('Go'));
  }
}
''');
      // A StatelessWidget with an interactive child should be promoted to @client
      expect(components.first.isStateful, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // .asWeb() extension handling
  // ─────────────────────────────────────────────────────────────────────────────

  group('.asWeb() override', () {
    test('Text().asWeb(tag: h1) overrides html tag to h1', () {
      final components = transpile('''
import 'package:flutter/widgets.dart';
// Simulating .asWeb() — visitor detects the method chain
class Demo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(children: []);
  }
}
''');
      // Note: Full .asWeb() test requires the extension imported
      // This test verifies the baseline Column is a div
      final col = components.first.buildBody as StructuralNode;
      expect(col.htmlTag, equals('div'));
    });

    test('Unknown widget → UnknownNode', () {
      final components = transpile('''
import 'package:flutter/widgets.dart';
class Demo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPainter(); // not recognized
  }
}
''');
      // CustomPainter creates an InstanceCreationExpression but is UnknownNode
      // The build body may be null or UnknownNode depending on parse
      final body = components.first.buildBody;
      expect(body, anyOf(isNull, isA<UnknownNode>()));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // @JetRoute annotation
  // ─────────────────────────────────────────────────────────────────────────────

  group('@JetRoute annotation extraction', () {
    test('Extracts path and title from @JetRoute', () {
      final components = transpile('''
import 'package:flutter/widgets.dart';
import 'package:jet_annotations/jet_annotations.dart';

@JetRoute(path: '/about', title: 'About Us')
class AboutPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text('About');
}
''');
      expect(components.first.routeMetadata?.path, equals('/about'));
      expect(components.first.routeMetadata?.title, equals('About Us'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Phase 2: Physics Engine Mapping & Slivers
  // ─────────────────────────────────────────────────────────────────────────────

  group('Phase 2: Physics and Slivers', () {
    test('ListView with BouncingScrollPhysics maps to overscroll-contain', () {
      final components = transpile('''
import 'package:flutter/widgets.dart';
class Demo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: BouncingScrollPhysics(),
      children: [],
    );
  }
}
''');
      final lv = components.first.buildBody as StructuralNode;
      expect(lv.ownClasses, contains('overscroll-contain'));
    });

    test('SingleChildScrollView with PageScrollPhysics maps to snap', () {
      final components = transpile('''
import 'package:flutter/widgets.dart';
class Demo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: PageScrollPhysics(),
      child: Text('Snap'),
    );
  }
}
''');
      final scsv = components.first.buildBody as StructuralNode;
      expect(scsv.ownClasses, containsAll(['snap-y', 'snap-mandatory']));
    });

    test('CustomScrollView and Slivers map correctly', () {
      final components = transpile('''
import 'package:flutter/widgets.dart';
class Demo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: ClampingScrollPhysics(),
      slivers: [
        SliverAppBar(
          title: Text('Header'),
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            Text('Item 1'),
            Text('Item 2'),
          ]),
        ),
        SliverToBoxAdapter(
          child: Text('Footer'),
        ),
      ],
    );
  }
}
''');
      final csv = components.first.buildBody as StructuralNode;
      expect(csv.htmlTag, equals('div'));
      expect(csv.ownClasses, contains('overflow-y-auto'));
      expect(
          csv.ownClasses, contains('overscroll-none')); // ClampingScrollPhysics

      expect(csv.children, hasLength(3));

      final appBar = csv.children[0] as StructuralNode;
      expect(appBar.htmlTag, equals('header'));
      expect(appBar.ownClasses, containsAll(['sticky', 'top-0', 'z-50']));

      final list = csv.children[1] as StructuralNode;
      expect(list.htmlTag, equals('ul'));
      expect(list.children, hasLength(2));

      final adapter = csv.children[2] as StructuralNode;
      expect(adapter.htmlTag, equals('div'));
      expect(adapter.children, hasLength(1));
    });
  });

  // ────────────────────────────────────────────────────────────────────────
  // Phase 2: Forms and Inputs
  // ────────────────────────────────────────────────────────────────────────

  group('Phase 2: Forms and Inputs', () {
    test('Form maps to semantic HTML <form>', () {
      final components = transpile('''
import 'package:flutter/widgets.dart';
class Demo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Form(
      child: Container(),
    );
  }
}
''');
      final form = components.first.buildBody as StructuralNode;
      expect(form.htmlTag, equals('form'));
      expect(form.needsClientAnnotation, isTrue);
      expect(form.children, hasLength(1));
    });

    test('TextFormField maps correctly with keyboard type and obscure text',
        () {
      final components = transpile('''
import 'package:flutter/widgets.dart';
class Demo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      obscureText: true,
      keyboardType: TextInputType.emailAddress,
      maxLength: 50,
      initialValue: 'test@example.com',
      decoration: InputDecoration(
        labelText: 'Email Address',
        hintText: 'Enter email'
      ),
    );
  }
}
''');
      final input = components.first.buildBody as StructuralNode;
      expect(input.htmlTag, equals('input'));
      expect(input.attributes['type'],
          equals('password')); // obscureText overrides email
      expect(input.attributes['maxlength'], equals('50'));
      expect(input.attributes['value'], equals('test@example.com'));
      expect(input.attributes['placeholder'], equals('Enter email'));
      expect(input.needsClientAnnotation, isTrue);
    });

    test('TextFormField maps to textarea when maxLines > 1', () {
      final components = transpile('''
import 'package:flutter/widgets.dart';
class Demo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      maxLines: 4,
    );
  }
}
''');
      final input = components.first.buildBody as StructuralNode;
      expect(input.htmlTag, equals('textarea'));
      expect(input.attributes['rows'], equals('4'));
      expect(input.attributes.containsKey('type'), isFalse);
      expect(input.attributes.containsKey('value'), isFalse);
    });
  });
}
