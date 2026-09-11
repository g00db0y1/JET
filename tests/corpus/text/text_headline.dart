// corpus: text_headline
// Tests: .asWeb() override for semantic heading tags
// Also tests font-size based inference without .asWeb()
// Source: https://docs.flutter.dev/ui/widgets/text
import 'package:flutter/widgets.dart';
import 'package:jet_annotations/jet_annotations.dart';

class TextHeadlineDemo extends StatelessWidget {
  const TextHeadlineDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // .asWeb() explicitly sets h1
        Text('Page Title').asWeb(tag: 'h1', classes: 'text-4xl font-bold'),
        // Font size >= 22 → h2 by inference
        Text(
          'Section Heading',
          style: TextStyle(fontSize: 24),
        ),
        // Font size >= 18 → h3 by inference
        Text(
          'Subsection',
          style: TextStyle(fontSize: 18),
        ),
        // Body text → p
        Text('Regular paragraph text goes here.'),
      ],
    );
  }
}
