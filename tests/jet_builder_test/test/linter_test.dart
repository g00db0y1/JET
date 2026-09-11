import 'package:test/test.dart';

import 'package:jet_builder/src/parser/flutter_ast_parser.dart';
import 'package:jet_builder/src/linter/poison_sniffer.dart';

void main() {
  late FlutterAstParser parser;
  late PoisonSniffer sniffer;

  setUp(() {
    parser = const FlutterAstParser();
    sniffer = const PoisonSniffer();
  });

  List<LinterViolation> lint(String source, {String path = 'lib/state/controller.dart'}) {
    final result = parser.parse(source: source, path: path);
    if (!result.isUsable) return [];
    return sniffer.analyze(unit: result.unit!, filePath: path);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // P-001: Flutter SDK in logic files
  // ─────────────────────────────────────────────────────────────────────────────

  group('P-001: Flutter SDK in logic files', () {
    test('Flags package:flutter import in lib/state/ file', () {
      final violations = lint(
        "import 'package:flutter/widgets.dart';\nvoid main() {}",
        path: 'lib/state/auth_controller.dart',
      );
      expect(violations.where((v) => v.rule == 'P-001'), isNotEmpty);
      expect(violations.first.severity, equals('error'));
      expect(violations.first.message, contains('package:flutter'));
    });

    test('Does NOT flag package:flutter in lib/ui/ file', () {
      final violations = lint(
        "import 'package:flutter/widgets.dart';\nvoid main() {}",
        path: 'lib/ui/home_screen.dart',
      );
      expect(violations.where((v) => v.rule == 'P-001'), isEmpty);
    });

    test('Does NOT flag package:flutter in lib/widgets/ file', () {
      final violations = lint(
        "import 'package:flutter/material.dart';\nvoid main() {}",
        path: 'lib/widgets/my_button.dart',
      );
      expect(violations.where((v) => v.rule == 'P-001'), isEmpty);
    });

    test('Does NOT flag package:flutter in lib/screens/ file', () {
      final violations = lint(
        "import 'package:flutter/material.dart';\nvoid main() {}",
        path: 'lib/screens/dashboard.dart',
      );
      expect(violations.where((v) => v.rule == 'P-001'), isEmpty);
    });

    test('Does not flag non-flutter imports in logic files', () {
      final violations = lint(
        "import 'dart:async';\nimport 'package:riverpod/riverpod.dart';\nvoid main() {}",
        path: 'lib/state/auth_controller.dart',
      );
      expect(violations.where((v) => v.rule == 'P-001'), isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // P-002: Navigation poison in UI files
  // ─────────────────────────────────────────────────────────────────────────────

  group('P-002: Navigation poison', () {
    test('Flags context.go() in UI file', () {
      final violations = lint('''
import 'package:flutter/widgets.dart';
class Demo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    context.go('/dashboard');
    return Container();
  }
}
''', path: 'lib/ui/login_screen.dart');
      expect(violations.where((v) => v.rule == 'P-002'), isNotEmpty);
    });

    test('Flags Navigator.push() in UI file', () {
      final violations = lint('''
import 'package:flutter/widgets.dart';
class Demo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Container()));
    return Container();
  }
}
''', path: 'lib/ui/home.dart');
      expect(violations.where((v) => v.rule == 'P-002'), isNotEmpty);
    });

    test('Flags Navigator.pushNamed() in UI file', () {
      final violations = lint('''
void navigate(context) {
  Navigator.pushNamed(context, '/profile');
}
''', path: 'lib/ui/home.dart');
      expect(violations.where((v) => v.rule == 'P-002'), isNotEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // P-003: Platform plugin imports
  // ─────────────────────────────────────────────────────────────────────────────

  group('P-003: Platform plugin imports', () {
    test('Flags shared_preferences in logic file', () {
      final violations = lint(
        "import 'package:shared_preferences/shared_preferences.dart';\nvoid main() {}",
        path: 'lib/state/storage_service.dart',
      );
      expect(violations.where((v) => v.rule == 'P-003'), isNotEmpty);
    });

    test('Flags path_provider in logic file', () {
      final violations = lint(
        "import 'package:path_provider/path_provider.dart';\nvoid main() {}",
        path: 'lib/services/file_service.dart',
      );
      expect(violations.where((v) => v.rule == 'P-003'), isNotEmpty);
    });

    test('Does not flag dart:io in logic files (dart:io is cross-platform)', () {
      final violations = lint(
        "import 'dart:io';\nvoid main() {}",
        path: 'lib/state/some_service.dart',
      );
      expect(violations.where((v) => v.rule == 'P-003'), isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // P-004: Heavy setState
  // ─────────────────────────────────────────────────────────────────────────────

  group('P-004: Heavy logic in setState', () {
    test('Flags await inside setState', () {
      final violations = lint('''
import 'package:flutter/widgets.dart';
class Demo extends StatefulWidget {
  @override State createState() => _DemoState();
}
class _DemoState extends State<Demo> {
  @override
  Widget build(BuildContext context) => Container();
  
  void _load() {
    setState(() async {
      await Future.delayed(Duration(seconds: 1));
    });
  }
}
''', path: 'lib/ui/demo.dart');
      expect(violations.where((v) => v.rule == 'P-004'), isNotEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Clean files produce no violations
  // ─────────────────────────────────────────────────────────────────────────────

  group('Clean code produces no violations', () {
    test('Pure Dart logic file with no Flutter is clean', () {
      final violations = lint('''
import 'dart:async';

abstract class AuthService {
  Future<String?> getToken();
  Future<void> logout();
}
''', path: 'lib/ports/auth_service.dart');
      expect(violations, isEmpty);
    });

    test('Flutter UI file with no navigation is clean', () {
      final violations = lint('''
import 'package:flutter/widgets.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onSignOut;
  const HomeScreen({super.key, required this.onSignOut});
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Home'),
        ElevatedButton(onPressed: onSignOut, child: Text('Sign Out')),
      ],
    );
  }
}
''', path: 'lib/ui/home_screen.dart');
      expect(violations, isEmpty);
    });
  });
}
