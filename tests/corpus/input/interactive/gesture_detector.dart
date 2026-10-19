import 'package:flutter/widgets.dart';

class GestureDemo extends StatelessWidget {
  const GestureDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        print('tapped');
      },
      onDoubleTap: () {
        print('double tapped');
      },
      onPanUpdate: (details) {
        print('panning');
      },
      child: Container(
        color: const Color(0xFF000000),
        child: const Text('Touch me'),
      ),
    );
  }
}
