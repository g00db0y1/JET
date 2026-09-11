import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:process_run/process_run.dart';

import 'package:jet_cli/src/preview_command.dart';
import 'package:jet_builder/src/parser/flutter_ast_parser.dart';
import 'package:jet_builder/src/visitor/style_accumulator_visitor.dart';
import 'package:jet_builder/src/emitter/jaspr_emitter.dart';

/// JET CLI — Developer convenience tool for the JET transpiler.
///
/// Usage:
///   jet init           — Add jet_annotations + jet_builder to pubspec.yaml
///   jet build          — Run the transpiler (entire project via build_runner)
///   jet build <file>   — Instantly transpile a single file
///   jet preview <file> — Instantly print transpiled Jaspr code to the terminal
///   jet lint           — Run only the JET linter (no code generation)
///   jet serve          — Build then run jaspr serve
///   jet clean          — Delete generated .jaspr.dart files
void main(List<String> args) async {
  final parser = ArgParser()
    ..addCommand('init')
    ..addCommand('build')
    ..addCommand(
      'preview',
      ArgParser()..addOption('line', abbr: 'l', help: 'Preview a specific line or widget'),
    )
    ..addCommand('lint')
    ..addCommand('serve')
    ..addCommand('clean')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.')
    ..addFlag('version', abbr: 'v', negatable: false, help: 'Show JET version.');

  final results = parser.parse(args);

  if (results['help'] as bool || results.command == null) {
    _printUsage(parser);
    exit(0);
  }

  if (results['version'] as bool) {
    print('JET v0.1.0-dev');
    exit(0);
  }

  final command = results.command!;
  switch (command.name) {
    case 'init':
      await _runInit();
    case 'build':
      final restArgs = command.rest;
      if (restArgs.isNotEmpty) {
        // Run single file build (save to disk)
        await _runBuildSingle(restArgs.first);
      } else {
        await _runBuildAll();
      }
    case 'preview':
      final restArgs = command.rest;
      if (restArgs.isEmpty) {
        print('[JET] ❌ Please specify a file to preview. Example: jet preview lib/ui/home.dart');
        exit(1);
      }
      
      int? lineNumber;
      final lineArg = command['line'] as String?;
      if (lineArg != null) {
        lineNumber = int.tryParse(lineArg);
        if (lineNumber == null) {
          print('[JET] ❌ Invalid line number: $lineArg');
          exit(1);
        }
      }

      await runPreview(restArgs.first, lineNumber: lineNumber);
    case 'lint':
      await _runLint();
    case 'serve':
      await _runServe();
    case 'clean':
      await _runClean();
    default:
      _printUsage(parser);
      exit(1);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Commands
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _runInit() async {
  print('[JET] Initializing JET in the current project...');

  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('[JET] ❌ No pubspec.yaml found. Are you in a Flutter project root?');
    exit(1);
  }

  final content = pubspecFile.readAsStringSync();

  if (content.contains('jet_annotations')) {
    print('[JET] ✅ JET is already initialized in this project.');
    exit(0);
  }

  // Instructions instead of auto-editing (safe for any pubspec format)
  print('''
[JET] Add the following to your pubspec.yaml:

  dependencies:
    jet_annotations: ^0.1.0

  dev_dependencies:
    jet_builder: ^0.1.0
    build_runner: ^2.4.0

Then run: dart pub get
Then run: jet build
''');
}

Future<void> _runBuildAll() async {
  print('[JET] 🚀 Starting lightning-fast AST build...');
  final stopwatch = Stopwatch()..start();

  final sourceDirs = ['lib/ui', 'lib/screens', 'lib/widgets'];
  final cacheDir = Directory('.jet_cache');
  if (!cacheDir.existsSync()) {
    cacheDir.createSync(recursive: true);
  }

  int fileCount = 0;
  int componentCount = 0;

  for (final dirPath in sourceDirs) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) continue;

    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart') && !entity.path.endsWith('.jaspr.dart')) {
        final source = entity.readAsStringSync();
        final parser = FlutterAstParser();
        final parseResult = parser.parse(source: source, path: entity.path);

        if (!parseResult.isUsable) continue;

        final visitor = StyleAccumulatorVisitor();
        parseResult.unit!.accept(visitor);

        if (visitor.components.isEmpty) continue;

        final emitter = JasprEmitter();
        final jasprCode = emitter.emitFile(
          components: visitor.components,
          sourceFile: entity.path,
          version: '0.1.0-dev',
        );

        // Write to cache using original basename
        final basename = p.basename(entity.path);
        final cacheFile = File(p.join(cacheDir.path, basename));
        cacheFile.writeAsStringSync(jasprCode);

        fileCount++;
        componentCount += visitor.components.length;
      }
    }
  }

  stopwatch.stop();
  if (fileCount == 0) {
    print('[JET] ⚠️ No Flutter UI files found in lib/ui, lib/screens, or lib/widgets.');
  } else {
    print('[JET] ✅ Build complete in ${stopwatch.elapsedMilliseconds}ms.');
    print('[JET] 📂 Transpiled $componentCount components across $fileCount files to .jet_cache/');
  }
}

Future<void> _runBuildSingle(String filePath) async {
  // For now, _runBuildSingle just runs the preview logic but writes to disk.
  // In the future, this will write to .jet_cache.
  print('[JET] 🏗️ Transpiling single file: $filePath');
  // Temporary implementation using preview logic for output
  await runPreview(filePath); // We can refactor this to save to disk later
}

Future<void> _runLint() async {
  print('[JET] Running JET linter only...');
  final result = await run(
    'dart run build_runner build --delete-conflicting-outputs --define=jet_builder:jet_builder=lint_only=true',
    verbose: true,
  );
  if (result.first.exitCode != 0) {
    print('[JET] Lint complete with violations (see above).');
  } else {
    print('[JET] ✅ No violations found.');
  }
}

Future<void> _runServe() async {
  print('[JET] Building first...');
  await _runBuildAll();
  print('[JET] Starting jaspr serve...');
  await run('jaspr serve', verbose: true);
}

Future<void> _runClean() async {
  print('[JET] Cleaning generated .jaspr.dart files...');
  var count = 0;
  await for (final entity in Directory.current.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.jaspr.dart')) {
      print('[JET] Deleting ${p.relative(entity.path)}');
      await entity.delete();
      count++;
    }
  }
  print('[JET] ✅ Deleted $count generated file(s).');
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

void _printUsage(ArgParser parser) {
  print('''
JET — Flutter to Jaspr transpiler CLI

Usage: jet <command> [options]

Commands:
  init    Add JET packages to your project's pubspec.yaml
  build   Run the JET transpiler (dart run build_runner build)
  lint    Run only the JET architectural linter
  serve   Build and serve the Jaspr web app
  clean   Delete all generated .jaspr.dart files

${parser.usage}

Examples:
  jet init          # Set up JET in a Flutter project
  jet build         # Generate Jaspr components from Flutter UI
  jet lint          # Check for architectural violations only
  jet clean         # Remove all generated files
''');
}
