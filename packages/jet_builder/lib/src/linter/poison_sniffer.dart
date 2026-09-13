import 'dart:convert';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// The JET Architectural Linter — detects code patterns that prevent web compilation.
///
/// Reports violations as structured JSON to stderr. The build continues
/// even when violations are found (non-fatal by design — see AD-005).
///
/// ## Rules
///
/// | Rule | Name | Description |
/// |------|------|-------------|
/// | P-001 | Flutter in Logic | `package:flutter` imported outside `lib/ui/` or `lib/widgets/` |
/// | P-002 | Navigation Poison | `context.go()` or `Navigator.push()` in transpilable UI |
/// | P-003 | Platform Plugin | Platform-only packages imported in shared logic |
/// | P-004 | Heavy setState | `await` or API calls inside `setState()` body |
class PoisonSniffer {
  const PoisonSniffer();

  /// Platform-specific packages mapping to their web equivalents or JS interop templates.
  static const platformPlugins = <String, WebEquivalent>{
    'shared_preferences': WebEquivalent(
      isPureDart: true,
      suggestion:
          'Use dart:html window.localStorage or package:web for local web storage.',
    ),
    'sqflite': WebEquivalent(
      isPureDart: true,
      suggestion:
          'Web browsers do not support SQLite natively. Use IndexedDB or migrate to a cross-platform DB like package:drift.',
    ),
    'path_provider': WebEquivalent(
      isPureDart: true,
      suggestion:
          'Web apps lack local filesystems. Use IndexedDB for blobs, or upload to a server.',
    ),
    'url_launcher': WebEquivalent(
      isPureDart: true,
      suggestion:
          "Use dart:html window.open(url, '_blank') to launch URLs on the web.",
    ),
    'connectivity_plus': WebEquivalent(
      isPureDart: true,
      suggestion:
          'Use window.navigator.onLine to check network status in Jaspr.',
    ),
    'stripe_payment': WebEquivalent(
      isPureDart: false,
      suggestion:
          'Stripe requires the official Stripe.js web SDK. You must use JavaScript Interop.',
      jsInteropTemplate: '''
// 1. Add <script src="https://js.stripe.com/v3/"></script> to web/index.html
// 2. Create an interop file (e.g. lib/ports/stripe_interop.dart):
@JS()
library stripe_interop;
import 'dart:js_interop';

@JS('Stripe')
external StripeJs get stripe;

extension type StripeJs._(JSObject _) implements JSObject {
  external JSPromise redirectToCheckout(JSObject options);
}
''',
    ),
    'firebase_core': WebEquivalent(
      isPureDart: false,
      suggestion:
          'Use the official Firebase JS SDK via dart:js_interop for Jaspr web builds.',
    ),
  };

  /// Analyzes a [CompilationUnit] for architectural violations.
  ///
  /// Returns a (possibly empty) list of [LinterViolation]s.
  List<LinterViolation> analyze({
    required CompilationUnit unit,
    required String filePath,
  }) {
    final violations = <LinterViolation>[];
    final visitor = _PoisonVisitor(filePath: filePath, violations: violations);
    unit.accept(visitor);
    return violations;
  }

  /// Prints violations to stderr as newline-delimited JSON.
  static void reportViolations(List<LinterViolation> violations) {
    if (violations.isEmpty) return;

    final report = {
      'violations': violations.map((v) => v.toJson()).toList(),
    };

    // ignore: avoid_print
    print('[JET LINTER] ${violations.length} violation(s) found:');
    for (final v in violations) {
      // ignore: avoid_print
      print(
          '  ${v.severity == 'error' ? '❌' : '⚠️'} [${v.rule}] ${v.file}:${v.line}');
      // ignore: avoid_print
      print('     ${v.message}');
      if (v.suggestion != null) {
        // ignore: avoid_print
        print('     💡 ${v.suggestion}');
      }
    }

    // Machine-readable JSON to stderr
    final encoded = const JsonEncoder.withIndent('  ').convert(report);
    // Use stderr for machine-readable output
    // In build_runner context, this goes to build log
    // ignore: avoid_print
    print(encoded);
  }
}

/// Visits an AST and populates [violations] with detected poison patterns.
class _PoisonVisitor extends RecursiveAstVisitor<void> {
  _PoisonVisitor({
    required this.filePath,
    required this.violations,
  });

  final String filePath;
  final List<LinterViolation> violations;

  // Whether this file is in a "logic" location (not ui/widgets/screens)
  bool get _isLogicFile {
    final lower = filePath.toLowerCase();
    return !lower.contains('/ui/') &&
        !lower.contains('/widgets/') &&
        !lower.contains('/screens/');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // P-001: Flutter SDK in logic files
  // ───────────────────────────────────────────────────────────────────────────

  @override
  void visitImportDirective(ImportDirective node) {
    final importUri = node.uri.stringValue ?? '';

    // P-001: Flutter in logic files
    if (_isLogicFile && importUri.startsWith('package:flutter/')) {
      violations.add(LinterViolation(
        rule: 'P-001',
        severity: 'error',
        file: filePath,
        line: _getLine(node),
        message: 'Flutter SDK imported in logic file: $importUri',
        suggestion:
            'Extract to an abstract interface in lib/ports/ and create platform adapters. '
            'Only lib/ui/, lib/widgets/, and lib/screens/ may import package:flutter.',
      ));
    }

    // P-003: Platform plugins in logic files
    if (_isLogicFile) {
      for (final entry in PoisonSniffer.platformPlugins.entries) {
        final plugin = entry.key;
        final equivalent = entry.value;
        if (importUri.contains(plugin)) {
          var fullSuggestion =
              'Create an abstract interface in lib/ports/ and move $plugin usage to a mobile adapter.\n\n'
              '🌐 Web Equivalent:\n${equivalent.suggestion}';

          if (equivalent.jsInteropTemplate != null) {
            fullSuggestion +=
                '\n\n💡 JS Interop Template:\n${equivalent.jsInteropTemplate}';
          }

          violations.add(LinterViolation(
            rule: 'P-003',
            severity: 'error',
            file: filePath,
            line: _getLine(node),
            message: 'Platform plugin "$plugin" imported in shared logic file.',
            suggestion: fullSuggestion,
          ));
        }
      }
    }

    super.visitImportDirective(node);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // P-002: Navigation poison in UI files
  // ───────────────────────────────────────────────────────────────────────────

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;
    final targetSrc = node.target?.toSource() ?? '';

    // context.go(...) — go_router
    if (targetSrc == 'context' && methodName == 'go') {
      violations.add(LinterViolation(
        rule: 'P-002',
        severity: 'error',
        file: filePath,
        line: _getLine(node),
        message: 'context.go() detected in a transpilable UI file.',
        suggestion: 'Replace with a VoidCallback parameter: '
            '`final VoidCallback onNavigate; ... onPressed: onNavigate`. '
            'Pass the actual route from the platform-specific router.',
      ));
    }

    // Navigator.push / Navigator.pushNamed / Navigator.pushReplacement
    if (targetSrc == 'Navigator' &&
        (methodName == 'push' ||
            methodName == 'pushNamed' ||
            methodName == 'pushReplacement')) {
      violations.add(LinterViolation(
        rule: 'P-002',
        severity: 'error',
        file: filePath,
        line: _getLine(node),
        message: 'Navigator.$methodName() detected in a transpilable UI file.',
        suggestion:
            'Replace with a callback prop and let the platform router handle navigation. '
            'Example: `final VoidCallback on${_capitalize(methodName.replaceFirst('push', ''))};`',
      ));
    }

    // P-004: Heavy logic inside setState()
    if (node.methodName.name == 'setState') {
      final args = node.argumentList.arguments;
      if (args.isNotEmpty && args.first is FunctionExpression) {
        final fn = args.first as FunctionExpression;
        final body = fn.body;
        final bodySrc = body.toSource();

        if (bodySrc.contains('await ')) {
          violations.add(LinterViolation(
            rule: 'P-004',
            severity: 'warning',
            file: filePath,
            line: _getLine(node),
            message: 'async/await detected inside setState() body.',
            suggestion:
                'Move async logic to a Riverpod provider or repository. '
                'Call setState() only to update local UI state after the async operation completes.',
          ));
        }

        final apiCallPattern =
            RegExp(r'\b(fetch|httpGet|httpPost|loadData|getUser|apiCall)\b');
        if (apiCallPattern.hasMatch(bodySrc)) {
          violations.add(LinterViolation(
            rule: 'P-004',
            severity: 'warning',
            file: filePath,
            line: _getLine(node),
            message: 'Possible API call detected inside setState() body.',
            suggestion:
                'Move data fetching to a Riverpod AsyncNotifier or FutureProvider. '
                'Keep setState() for simple local UI state changes only.',
          ));
        }
      }
    }

    super.visitMethodInvocation(node);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Helpers
  // ───────────────────────────────────────────────────────────────────────────

  int _getLine(AstNode node) {
    // Returns byte offset as a line approximation.
    // Full line info requires LineInfo from the parsed result (available in JetBuilderImpl).
    return node.offset;
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// A single architectural violation detected by [PoisonSniffer].
class LinterViolation {
  const LinterViolation({
    required this.rule,
    required this.severity,
    required this.file,
    required this.line,
    required this.message,
    this.suggestion,
  });

  /// Rule identifier (e.g., `'P-001'`).
  final String rule;

  /// `'error'` or `'warning'`.
  final String severity;

  /// Relative file path.
  final String file;

  /// Line number (1-based) of the violation.
  final int line;

  /// Human-readable description.
  final String message;

  /// Optional suggested fix.
  final String? suggestion;

  Map<String, dynamic> toJson() => {
        'rule': rule,
        'severity': severity,
        'file': file,
        'line': line,
        'message': message,
        if (suggestion != null) 'suggestion': suggestion,
      };
}

/// Represents web compatibility guidance for a platform-specific package.
class WebEquivalent {
  const WebEquivalent({
    required this.isPureDart,
    required this.suggestion,
    this.jsInteropTemplate,
  });

  final bool isPureDart;
  final String suggestion;
  final String? jsInteropTemplate;
}
