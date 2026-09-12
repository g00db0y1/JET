import 'dart:convert';
import 'dart:io';

import 'package:jet_builder/src/parser/flutter_ast_parser.dart';
import 'package:jet_builder/src/visitor/style_accumulator_visitor.dart';
import 'package:jet_builder/src/emitter/jaspr_emitter.dart';
import 'package:jet_builder/src/linter/poison_sniffer.dart';

/// JET MCP Server
/// Provides AI agents with tools to transpile code, run the PoisonSniffer, 
/// and query the Web Equivalent Dictionary.
void main() async {
  // Listen to stdin for JSON-RPC messages
  stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    if (line.trim().isEmpty) return;
    try {
      final request = jsonDecode(line);
      _handleRequest(request);
    } catch (e) {
      _sendError(null, -32700, 'Parse error', e.toString());
    }
  });
}

void _handleRequest(Map<String, dynamic> request) {
  final id = request['id'];
  final method = request['method'];
  final params = request['params'] ?? {};

  switch (method) {
    case 'initialize':
      _sendResponse(id, {
        'protocolVersion': '2024-11-05',
        'serverInfo': {
          'name': 'jet-mcp-server',
          'version': '0.1.0-dev',
        },
        'capabilities': {
          'tools': {},
        }
      });
      break;
    case 'notifications/initialized':
      // Do nothing
      break;
    case 'tools/list':
      _sendResponse(id, {
        'tools': [
          {
            'name': 'jet_analyze',
            'description': 'Run the JET PoisonSniffer to detect Flutter mobile plugins or bad architectures that prevent web transpilation.',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'file_path': {
                  'type': 'string',
                  'description': 'Absolute path to the Flutter Dart file.'
                }
              },
              'required': ['file_path']
            }
          },
          {
            'name': 'jet_transpile',
            'description': 'Transpile a Flutter UI file into Jaspr HTML/Tailwind code.',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'file_path': {
                  'type': 'string',
                  'description': 'Absolute path to the Flutter Dart file.'
                }
              },
              'required': ['file_path']
            }
          },
          {
            'name': 'jet_check_dependency',
            'description': 'Check if a Flutter dependency is compatible with Jaspr or requires JS interop.',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'package_name': {
                  'type': 'string',
                  'description': 'Name of the pub.dev package (e.g., shared_preferences)'
                }
              },
              'required': ['package_name']
            }
          },
          {
            'name': 'jet_suggest_fix',
            'description': 'Get official JET refactoring templates and suggestions for specific architectural violations.',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'rule_id': {
                  'type': 'string',
                  'description': 'The violation rule ID (e.g., P-001, P-002, P-004)'
                }
              },
              'required': ['rule_id']
            }
          }
        ]
      });
      break;
    case 'tools/call':
      final name = params['name'];
      final args = params['arguments'] ?? {};
      if (name == 'jet_analyze') {
        _handleAnalyze(id, args['file_path']);
      } else if (name == 'jet_transpile') {
        _handleTranspile(id, args['file_path']);
      } else if (name == 'jet_check_dependency') {
        _handleCheckDependency(id, args['package_name']);
      } else if (name == 'jet_suggest_fix') {
        _handleSuggestFix(id, args['rule_id']);
      } else {
        _sendError(id, -32601, 'Method not found', 'Unknown tool: $name');
      }
      break;
    default:
      if (id != null) {
        _sendError(id, -32601, 'Method not found', 'Unknown method: $method');
      }
  }
}

void _handleAnalyze(dynamic id, String? filePath) {
  if (filePath == null) {
    _sendError(id, -32602, 'Invalid params', 'file_path is required');
    return;
  }

  final file = File(filePath);
  if (!file.existsSync()) {
    _sendToolError(id, 'File not found: $filePath');
    return;
  }

  final parser = FlutterAstParser();
  final result = parser.parse(source: file.readAsStringSync(), path: filePath);
  
  if (!result.isUsable) {
    _sendToolResult(id, 'Parse failed: ${result.failureMessage}');
    return;
  }

  const sniffer = PoisonSniffer();
  final violations = sniffer.analyze(unit: result.unit!, filePath: filePath);

  if (violations.isEmpty) {
    _sendToolResult(id, '✅ No architectural violations found. Ready for web transpilation.');
  } else {
    final report = violations.map((v) => '[${v.rule}] Line ${v.line}: ${v.message}\n💡 Suggestion: ${v.suggestion ?? ""}').join('\n\n');
    _sendToolResult(id, '⚠️ Violations Found:\n\n$report');
  }
}

void _handleTranspile(dynamic id, String? filePath) {
  if (filePath == null) {
    _sendError(id, -32602, 'Invalid params', 'file_path is required');
    return;
  }

  final file = File(filePath);
  if (!file.existsSync()) {
    _sendToolError(id, 'File not found: $filePath');
    return;
  }

  final parser = FlutterAstParser();
  final result = parser.parse(source: file.readAsStringSync(), path: filePath);
  
  if (!result.isUsable) {
    _sendToolError(id, 'Parse failed: ${result.failureMessage}');
    return;
  }

  final visitor = StyleAccumulatorVisitor();
  result.unit!.accept(visitor);

  if (visitor.components.isEmpty) {
    _sendToolError(id, 'No valid Flutter widgets found to transpile.');
    return;
  }

  final emitter = JasprEmitter();
  final code = emitter.emitFile(components: visitor.components, sourceFile: filePath, version: 'MCP');
  
  _sendToolResult(id, code);
}

void _handleCheckDependency(dynamic id, String? packageName) {
  if (packageName == null) {
    _sendError(id, -32602, 'Invalid params', 'package_name is required');
    return;
  }

  final equivalent = PoisonSniffer.platformPlugins[packageName];
  if (equivalent == null) {
    _sendToolResult(id, 'No specific restrictions or web equivalents found for "$packageName". It may be cross-platform compatible natively.');
    return;
  }

  var response = '📦 Package: $packageName\n';
  response += '✅ Pure Dart Equivalent: ${equivalent.isPureDart}\n\n';
  response += '🌐 Web Suggestion:\n${equivalent.suggestion}\n';

  if (equivalent.jsInteropTemplate != null) {
    response += '\n💡 JS Interop Template:\n${equivalent.jsInteropTemplate}';
  }

  _sendToolResult(id, response);
}

void _handleSuggestFix(dynamic id, String? ruleId) {
  if (ruleId == null) {
    _sendError(id, -32602, 'Invalid params', 'rule_id is required');
    return;
  }

  String response;
  switch (ruleId.toUpperCase()) {
    case 'P-001':
      response = '''
💡 Fix for P-001: Flutter in shared logic
Do not import `package:flutter/...` in shared services/models.
Extract UI-dependent logic to abstract interfaces in `lib/ports/`, then implement them in your Flutter/Jaspr entry points.
''';
      break;
    case 'P-002':
      response = '''
💡 Fix for P-002: Navigation Poison (context.go or Navigator)
UI components should be pure and stateless regarding routing.
Replace `Navigator.push` or `context.go` with callback props:

```dart
// Before:
ElevatedButton(onPressed: () => context.go('/details'), child: Text('Go'));

// After:
final VoidCallback onNavigateDetails;
ElevatedButton(onPressed: onNavigateDetails, child: Text('Go'));
```
''';
      break;
    case 'P-004':
      response = '''
💡 Fix for P-004: Heavy logic inside setState()
Do not place `await` or API calls inside `setState`.
Use Riverpod for async state management.

```dart
// Before:
setState(() {
  _data = await fetchApi();
});

// After (Using Riverpod):
ref.read(dataProvider.notifier).fetch();
```
''';
      break;
    case 'P-003':
      response = 'For P-003 (Platform Plugins), please use the `jet_check_dependency` tool to get the specific JS Interop template for your plugin.';
      break;
    default:
      response = 'Unknown rule ID: $ruleId. Valid rules are P-001, P-002, P-003, P-004.';
  }

  _sendToolResult(id, response);
}

void _sendResponse(dynamic id, dynamic result) {
  final msg = {
    'jsonrpc': '2.0',
    'id': id,
    'result': result,
  };
  print(jsonEncode(msg));
}

void _sendError(dynamic id, int code, String message, String data) {
  final msg = {
    'jsonrpc': '2.0',
    'id': id,
    'error': {
      'code': code,
      'message': message,
      'data': data,
    }
  };
  print(jsonEncode(msg));
}

void _sendToolResult(dynamic id, String text) {
  _sendResponse(id, {
    'content': [
      {'type': 'text', 'text': text}
    ]
  });
}

void _sendToolError(dynamic id, String text) {
  _sendResponse(id, {
    'isError': true,
    'content': [
      {'type': 'text', 'text': text}
    ]
  });
}
