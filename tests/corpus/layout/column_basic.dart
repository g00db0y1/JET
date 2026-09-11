// corpus: column_basic
// Tests: Column (structural) + Padding (modifier) + Text (structural)
// Source: https://docs.flutter.dev/ui/widgets/layout#Column
// Expected: Padding → p-4 on div.flex.flex-col, Text → <p>
import 'package:flutter/widgets.dart';

class ColumnBasicDemo extends StatelessWidget {
  const ColumnBasicDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text('Hello World'),
          Text('From Flutter'),
        ],
      ),
    );
  }
}
