// corpus: scaffold_appbar
// Tests: Scaffold → <main>, AppBar → <header>, title Text → <h1>
// Also tests @JetRoute annotation extraction
// Source: https://docs.flutter.dev/ui/widgets#scaffold
import 'package:flutter/material.dart';
import 'package:jet_annotations/jet_annotations.dart';

@JetRoute(
  path: '/home',
  title: 'Home — My App',
  description: 'Welcome to the home page.',
)
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome!'),
            Text('Build for web and mobile.'),
          ],
        ),
      ),
    );
  }
}
