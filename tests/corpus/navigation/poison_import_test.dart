// corpus: poison_import_test
// Tests: P-001 (Flutter in logic), P-002 (Navigator.push in UI)
// This file should trigger linter violations — NOT generate clean output
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';  // P-003

class PoisonedScreen extends StatelessWidget {
  const PoisonedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Poisoned'),
        ElevatedButton(
          // P-002: Navigator.push in UI
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PoisonedScreen()),
          ),
          child: Text('Go to next'),
        ),
      ],
    );
  }
}

// P-001: This class is in a UI file but imports shared_preferences
// which is a platform plugin (should be in an adapter)
class BadController {
  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('key', 'value');
  }
}
