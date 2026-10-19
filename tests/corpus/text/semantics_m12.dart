
import 'package:flutter/material.dart';

class SemanticTest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Main Title', style: Theme.of(context).textTheme.headlineLarge),
        Text('Subtitle', style: TextStyle(fontSize: 24)),
        Text('Sub-subtitle', style: Theme.of(context).textTheme.titleLarge),
        Text('Normal Text'),
      ],
    );
  }
}
