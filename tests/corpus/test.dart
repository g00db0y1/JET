import 'package:flutter/widgets.dart';

class Demo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      child: Container(),
    );
  }
}
