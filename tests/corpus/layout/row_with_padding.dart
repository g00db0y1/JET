// corpus: row_with_padding
// Tests: Row (structural) + SizedBox (modifier) + Expanded (modifier) + Padding (modifier)
// Source: https://docs.flutter.dev/ui/widgets/layout#Row
import 'package:flutter/widgets.dart';

class RowWithPaddingDemo extends StatelessWidget {
  const RowWithPaddingDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('Label'),
          SizedBox(width: 8),
          Expanded(
            child: Text('Value'),
          ),
        ],
      ),
    );
  }
}
