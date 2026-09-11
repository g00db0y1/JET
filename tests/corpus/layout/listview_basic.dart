// corpus: listview_basic
// Tests: ListView → <ul> with <li> wrapping
// Source: https://docs.flutter.dev/ui/widgets/scrolling#ListView
import 'package:flutter/widgets.dart';

class ListViewDemo extends StatelessWidget {
  const ListViewDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: EdgeInsets.all(8),
          child: Text('Item One'),
        ),
        Padding(
          padding: EdgeInsets.all(8),
          child: Text('Item Two'),
        ),
        Padding(
          padding: EdgeInsets.all(8),
          child: Text('Item Three'),
        ),
      ],
    );
  }
}
