import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:process_run/process_run.dart';

import 'package:jet_cli/src/preview_command.dart';
import 'package:jet_builder/src/parser/flutter_ast_parser.dart';
import 'package:jet_builder/src/visitor/style_accumulator_visitor.dart';
import 'package:jet_builder/src/emitter/jaspr_emitter.dart';
import 'package:jet_builder/src/optimizer/tailwind_optimizer.dart';
import 'package:jet_builder/src/linter/sniffer.dart';
import 'package:jet_builder/src/linter/poison_sniffer.dart';
import 'package:jet_builder/src/linter/graphics_sniffer.dart';
import 'package:jet_builder/src/linter/animation_sniffer.dart';

/// Shared Sniffer Fleet registry used by the CLI pipeline.
final SnifferRegistry _snifferRegistry = SnifferRegistry()
  ..register(const PoisonSniffer())
  ..register(const GraphicsSniffer())
  ..register(const AnimationSniffer());

/// JET CLI — Unified developer entrypoint for the JET transpiler.
///
/// Usage:
///   jet init                   — Set up JET in a Flutter project
///   jet build                  — Transpile entire project via 3-step pipeline
///   jet build --watch (-w)     — Continuous generation on file changes
///   jet build -t <file>        — Instantly transpile a single target file
///   jet preview <file>         — Print transpiled Jaspr code to the terminal
///   jet lint                   — Run the Sniffer Fleet architectural linter
///   jet serve                  — Build then run jaspr serve
///   jet clean                  — Delete .jet_cache and generated .jaspr.dart files
void main(List<String> args) async {
  final buildParser = ArgParser()
    ..addOption(
      'target',
      abbr: 't',
      help: 'Target a single Dart file for instant transpilation.',
    )
    ..addFlag(
      'watch',
      abbr: 'w',
      negatable: false,
      help: 'Continuously watch for file changes and re-transpile.',
    )
    ..addOption(
      'output',
      abbr: 'o',
      defaultsTo: p.join('..', 'website', 'lib', 'ui'),
      help: 'Target output directory for promoted Jaspr components.',
    );

  final watchParser = ArgParser()
    ..addOption(
      'target',
      abbr: 't',
      help: 'Target a single Dart file to watch and transpile.',
    )
    ..addOption(
      'output',
      abbr: 'o',
      defaultsTo: p.join('..', 'website', 'lib', 'ui'),
      help: 'Target output directory for promoted Jaspr components.',
    );

  final parser = ArgParser()
    ..addCommand('init')
    ..addCommand('build', buildParser)
    ..addCommand('watch', watchParser)
    ..addCommand(
      'preview',
      ArgParser()
        ..addOption('line',
            abbr: 'l', help: 'Preview a specific line or widget'),
    )
    ..addCommand('lint')
    ..addCommand('serve')
    ..addCommand('clean')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.')
    ..addFlag('version',
        abbr: 'v', negatable: false, help: 'Show JET version.');

  late final ArgResults results;
  try {
    results = parser.parse(args);
  } on FormatException catch (e) {
    print('[JET] ❌ ${e.message}\n');
    _printUsage(parser);
    exit(1);
  }

  if (results['help'] as bool) {
    _printUsage(parser);
    exit(0);
  }

  if (results['version'] as bool) {
    print('JET v0.1.0-dev');
    exit(0);
  }

  if (results.command == null) {
    _printUsage(parser);
    exit(0);
  }

  final command = results.command!;
  switch (command.name) {
    case 'init':
      await _runInit();
    case 'build':
      final targetOption = command['target'] as String?;
      final restArgs = command.rest;
      final targetFile =
          targetOption ?? (restArgs.isNotEmpty ? restArgs.first : null);
      final watch = command['watch'] as bool;
      final outputDir = command['output'] as String;

      if (targetFile != null) {
        await _runBuildSingle(targetFile, outputDirPath: outputDir);
        if (watch) {
          await _runWatchSingle(targetFile, outputDirPath: outputDir);
        }
      } else {
        await _runBuildAll(outputDirPath: outputDir);
        if (watch) {
          await _runWatchAll(outputDirPath: outputDir);
        }
      }
    case 'watch':
      final targetOption = command['target'] as String?;
      final restArgs = command.rest;
      final targetFile =
          targetOption ?? (restArgs.isNotEmpty ? restArgs.first : null);
      final outputDir = command['output'] as String;

      if (targetFile != null) {
        await _runBuildSingle(targetFile, outputDirPath: outputDir);
        await _runWatchSingle(targetFile, outputDirPath: outputDir);
      } else {
        await _runBuildAll(outputDirPath: outputDir);
        await _runWatchAll(outputDirPath: outputDir);
      }
    case 'preview':
      final restArgs = command.rest;
      if (restArgs.isEmpty) {
        print(
            '[JET] ❌ Please specify a file to preview. Example: jet preview lib/ui/home.dart');
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
      final restArgs = command.rest;
      await _runLint(targetPath: restArgs.isNotEmpty ? restArgs.first : null);
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

  // Ensure .jet_cache/ is added to .gitignore
  final gitignoreFile = File('.gitignore');
  if (gitignoreFile.existsSync()) {
    final gitignoreContent = gitignoreFile.readAsStringSync();
    if (!gitignoreContent.contains('.jet_cache')) {
      final prefix = gitignoreContent.endsWith('\n') || gitignoreContent.isEmpty
          ? ''
          : '\n';
      gitignoreFile.writeAsStringSync(
        '$gitignoreContent$prefix# JET staging cache\n.jet_cache/\n',
      );
      print('[JET] 📝 Added .jet_cache/ to .gitignore.');
    }
  } else {
    gitignoreFile.writeAsStringSync('# JET staging cache\n.jet_cache/\n');
    print('[JET] 📝 Created .gitignore with .jet_cache/.');
  }

  final content = pubspecFile.readAsStringSync();

  if (content.contains('jet_annotations')) {
    print('[JET] ✅ JET is already initialized in this project.');
    exit(0);
  }

  print('''
[JET] Add the following to your pubspec.yaml:

  dependencies:
    jet_annotations: ^0.1.0

  dev_dependencies:
    jet_builder: ^0.1.0

Then run: dart pub get
Then run:
  jet build                      # Transpile entire project
  jet build --watch              # Continuous generation on file save
  jet build -t lib/ui/home.dart  # Single-file transpilation
''');
}

const List<String> _defaultSourceDirs = [
  'lib/ui',
  'lib/screens',
  'lib/widgets',
];

Future<void> _runBuildAll({String? outputDirPath}) async {
  print('[JET] 🚀 Starting 3-Step Disk-Backed Compiler Pipeline...');
  final stopwatch = Stopwatch()..start();

  final rawCacheDir = Directory(p.join('.jet_cache', 'raw'));
  final optCacheDir = Directory(p.join('.jet_cache', 'optimized'));

  if (!rawCacheDir.existsSync()) rawCacheDir.createSync(recursive: true);
  if (!optCacheDir.existsSync()) optCacheDir.createSync(recursive: true);

  int fileCount = 0;
  int componentCount = 0;

  // =========================================================================
  // STEP 1: The Raw Emitter (Speed)
  // Parses Flutter AST and writes unoptimized code to .jet_cache/raw/
  // =========================================================================
  print('[JET] ⚡ STEP 1: Generating Raw AST (Speed)...');
  for (final dirPath in _defaultSourceDirs) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) continue;

    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File &&
          entity.path.endsWith('.dart') &&
          !entity.path.endsWith('.jaspr.dart')) {
        final source = entity.readAsStringSync();
        final parser = FlutterAstParser();
        final parseResult = parser.parse(source: source, path: entity.path);

        if (!parseResult.isUsable) continue;

        final unit = parseResult.unit!;
        final violations = _snifferRegistry.analyzeAll(unit, entity.path);
        if (violations.isNotEmpty) {
          PoisonSniffer.reportViolations(violations);
        }

        final visitor =
            StyleAccumulatorVisitor(snifferRegistry: _snifferRegistry);
        unit.accept(visitor);

        if (visitor.components.isEmpty) continue;

        final emitter = JasprEmitter();
        final rawJasprCode = emitter.emitFile(
          components: visitor.components,
          sourceFile: entity.path,
          version: '0.1.0-dev',
        );

        final basename = p.basename(entity.path);
        final targetName = basename.replaceFirst('.dart', '.jaspr.dart');
        final rawCacheFile = File(p.join(rawCacheDir.path, targetName));
        rawCacheFile.writeAsStringSync(rawJasprCode);

        fileCount++;
        componentCount += visitor.components.length;
      }
    }
  }

  if (fileCount == 0) {
    print(
        '[JET] ⚠️ No Flutter UI files found in lib/ui, lib/screens, or lib/widgets.');
    return;
  }

  // =========================================================================
  // STEP 2: The Tailwind Optimizer (Accuracy)
  // Reads from .jet_cache/raw/ and optimizes CSS to Tailwind, saving to .jet_cache/optimized/
  // =========================================================================
  print('[JET] 🛠️ STEP 2: Running Tailwind Optimizer (Accuracy)...');
  for (final entity in rawCacheDir.listSync()) {
    if (entity is! File) continue;
    final filename = p.basename(entity.path);

    if (filename.endsWith('.jaspr.dart')) {
      final rawCode = entity.readAsStringSync();

      final optimizer = TailwindOptimizer();
      final optimizedCode = optimizer.optimize(rawCode);

      final optCacheFile = File(p.join(optCacheDir.path, filename));
      optCacheFile.writeAsStringSync(optimizedCode);
    }
  }

  // =========================================================================
  // STEP 3: Poison Sniffer & Promotion (Safety)
  // Reads from .jet_cache/optimized/, verifies it, and promotes to target
  // =========================================================================
  _runPoisonSnifferAndPromote(
    optCacheDir,
    outputDirPath: outputDirPath,
  );

  stopwatch.stop();
  print(
      '[JET] ✅ 3-Step Pipeline complete in ${stopwatch.elapsedMilliseconds}ms.');
  print(
      '[JET] 📂 Transpiled $componentCount components across $fileCount files.');
}

void _runPoisonSnifferAndPromote(
  Directory optCacheDir, {
  String? outputDirPath,
}) {
  print('[JET] 🛡️ STEP 3: Running Poison Sniffer & Promoting to Targets...');

  final jasprTargetDir =
      Directory(outputDirPath ?? p.join('..', 'website', 'lib', 'ui'));

  int promotedCount = 0;
  int poisonedCount = 0;

  for (final entity in optCacheDir.listSync()) {
    if (entity is! File) continue;
    final filename = p.basename(entity.path);

    if (filename.endsWith('.jaspr.dart')) {
      final optimizedCode = entity.readAsStringSync();

      // Prevent mobile-only plugins from reaching the web target.
      final isPoisoned = optimizedCode.contains('import \'dart:io\'') ||
          optimizedCode.contains('stripe_payment');

      if (isPoisoned) {
        print(
            '[JET] ☠️  POISON DETECTED in $filename. File blocked from promotion.');
        poisonedCount++;
        continue;
      }

      // Green-lighted! Promote to target and drop the .jaspr label.
      if (!jasprTargetDir.existsSync()) {
        jasprTargetDir.createSync(recursive: true);
      }

      final finalName = filename.replaceFirst('.jaspr.dart', '.dart');
      final targetFile = File(p.join(jasprTargetDir.path, finalName));
      targetFile.writeAsStringSync(optimizedCode);
      promotedCount++;
    }
  }

  print('[JET] ✅ Successfully promoted $promotedCount files to web safely.');
  if (poisonedCount > 0) {
    print('[JET] ⚠️ Blocked $poisonedCount poisoned files.');
  }
}

Future<void> _runBuildSingle(
  String filePath, {
  String? outputDirPath,
}) async {
  final entity = File(filePath);
  if (!entity.existsSync()) {
    print('[JET] ❌ File not found: $filePath');
    return;
  }

  final stopwatch = Stopwatch()..start();
  print('[JET] 🎯 Single-file transpilation target: $filePath');

  final rawCacheDir = Directory(p.join('.jet_cache', 'raw'));
  final optCacheDir = Directory(p.join('.jet_cache', 'optimized'));
  final jasprTargetDir =
      Directory(outputDirPath ?? p.join('..', 'website', 'lib', 'ui'));

  if (!rawCacheDir.existsSync()) rawCacheDir.createSync(recursive: true);
  if (!optCacheDir.existsSync()) optCacheDir.createSync(recursive: true);
  if (!jasprTargetDir.existsSync()) jasprTargetDir.createSync(recursive: true);

  final source = entity.readAsStringSync();
  final parser = FlutterAstParser();
  final parseResult = parser.parse(source: source, path: filePath);

  if (!parseResult.isUsable) {
    print('[JET] ❌ Parse failed for $filePath');
    return;
  }

  final unit = parseResult.unit!;
  final violations = _snifferRegistry.analyzeAll(unit, filePath);
  if (violations.isNotEmpty) {
    PoisonSniffer.reportViolations(violations);
  }

  final visitor = StyleAccumulatorVisitor(snifferRegistry: _snifferRegistry);
  unit.accept(visitor);

  if (visitor.components.isEmpty) {
    print('[JET] ⚠️ No transpiled components found in $filePath');
    return;
  }

  final emitter = JasprEmitter();
  final rawJasprCode = emitter.emitFile(
    components: visitor.components,
    sourceFile: filePath,
    version: '0.1.0-dev',
  );

  final basename = p.basename(filePath);
  final targetName = basename.replaceFirst('.dart', '.jaspr.dart');

  // Step 1: Raw
  final rawCacheFile = File(p.join(rawCacheDir.path, targetName));
  rawCacheFile.writeAsStringSync(rawJasprCode);

  // Step 2: Optimize
  final optimizer = TailwindOptimizer();
  final optimizedCode = optimizer.optimize(rawJasprCode);

  final optCacheFile = File(p.join(optCacheDir.path, targetName));
  optCacheFile.writeAsStringSync(optimizedCode);

  // Step 3: Poison Sniff & Promote
  final isPoisoned = optimizedCode.contains('import \'dart:io\'') ||
      optimizedCode.contains('stripe_payment');

  if (isPoisoned) {
    print(
        '[JET] ☠️ POISON DETECTED in $targetName. File blocked from promotion.');
    return;
  }

  final finalName = targetName.replaceFirst('.jaspr.dart', '.dart');
  final targetFile = File(p.join(jasprTargetDir.path, finalName));
  targetFile.writeAsStringSync(optimizedCode);

  stopwatch.stop();
  print(
      '[JET] ✅ Built & promoted $basename -> ${targetFile.path} (${stopwatch.elapsedMilliseconds}ms)');
}

/// Continuously watches the project UI directories and runs single-file
/// transpilation whenever a `.dart` source file is created or modified.
Future<void> _runWatchAll({String? outputDirPath}) async {
  final existingDirs = _defaultSourceDirs
      .map(Directory.new)
      .where((d) => d.existsSync())
      .toList();

  if (existingDirs.isEmpty) {
    print(
        '[JET] ⚠️ No source directories (lib/ui, lib/screens, lib/widgets) found to watch.');
    return;
  }

  print(
      '\n[JET] 👀 Continuous generation active — watching ${existingDirs.map((d) => d.path).join(', ')} (Press Ctrl+C to stop)...');

  final debounceTimers = <String, Timer>{};
  final subscriptions = <StreamSubscription<FileSystemEvent>>[];

  for (final dir in existingDirs) {
    final sub = dir.watch(recursive: true).listen((event) {
      final path = event.path;
      if (!path.endsWith('.dart') || path.endsWith('.jaspr.dart')) return;

      debounceTimers[path]?.cancel();
      debounceTimers[path] = Timer(const Duration(milliseconds: 150), () async {
        if (event is FileSystemDeleteEvent || !File(path).existsSync()) {
          _handleDeletedFile(path, outputDirPath: outputDirPath);
          return;
        }
        print('\n[JET] 🔄 Change detected in ${p.relative(path)}');
        await _runBuildSingle(path, outputDirPath: outputDirPath);
      });
    });
    subscriptions.add(sub);
  }

  // Keep process alive until SIGINT
  await ProcessSignal.sigint.watch().first;
  print('\n[JET] 🛑 Stopping continuous generation watcher...');
  for (final timer in debounceTimers.values) {
    timer.cancel();
  }
  for (final sub in subscriptions) {
    await sub.cancel();
  }
}

/// Continuously watches a single target `.dart` file and re-transpiles on save.
Future<void> _runWatchSingle(
  String filePath, {
  String? outputDirPath,
}) async {
  final file = File(filePath);
  if (!file.existsSync()) {
    print('[JET] ❌ Cannot watch non-existent file: $filePath');
    return;
  }

  final normalizedTarget = p.normalize(file.absolute.path);
  print(
      '\n[JET] 👀 Watching single target file: $filePath (Press Ctrl+C to stop)...');

  Timer? debounceTimer;
  final sub = file.parent.watch().listen((event) {
    final eventAbsPath = p.normalize(File(event.path).absolute.path);
    if (eventAbsPath != normalizedTarget) return;

    debounceTimer?.cancel();
    debounceTimer = Timer(const Duration(milliseconds: 150), () async {
      if (!file.existsSync()) return;
      print('\n[JET] 🔄 Change detected in $filePath');
      await _runBuildSingle(filePath, outputDirPath: outputDirPath);
    });
  });

  await ProcessSignal.sigint.watch().first;
  print('\n[JET] 🛑 Stopping single-file watcher...');
  debounceTimer?.cancel();
  await sub.cancel();
}

void _handleDeletedFile(String filePath, {String? outputDirPath}) {
  final basename = p.basename(filePath);
  final cacheName = basename.replaceFirst('.dart', '.jaspr.dart');
  final rawCacheFile = File(p.join('.jet_cache', 'raw', cacheName));
  final optCacheFile = File(p.join('.jet_cache', 'optimized', cacheName));

  if (rawCacheFile.existsSync()) rawCacheFile.deleteSync();
  if (optCacheFile.existsSync()) optCacheFile.deleteSync();

  print('[JET] 🗑️  Cleaned cached artifacts for deleted file: $basename');
}

Future<void> _runLint({String? targetPath}) async {
  print('[JET] 🔍 Running JET Sniffer Fleet architectural linter...');
  final parser = FlutterAstParser();
  final allViolations = <LinterViolation>[];
  int scannedFiles = 0;

  if (targetPath != null) {
    final file = File(targetPath);
    if (!file.existsSync()) {
      print('[JET] ❌ File not found: $targetPath');
      exit(1);
    }
    final parseResult =
        parser.parse(source: file.readAsStringSync(), path: targetPath);
    if (parseResult.isUsable) {
      scannedFiles++;
      allViolations
          .addAll(_snifferRegistry.analyzeAll(parseResult.unit!, targetPath));
    }
  } else {
    final libDir = Directory('lib');
    if (!libDir.existsSync()) {
      print('[JET] ⚠️ No lib/ directory found in current directory.');
      return;
    }

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is File &&
          entity.path.endsWith('.dart') &&
          !entity.path.endsWith('.jaspr.dart')) {
        final parseResult = parser.parse(
          source: entity.readAsStringSync(),
          path: entity.path.replaceAll('\\', '/'),
        );
        if (parseResult.isUsable) {
          scannedFiles++;
          allViolations.addAll(_snifferRegistry.analyzeAll(
            parseResult.unit!,
            entity.path.replaceAll('\\', '/'),
          ));
        }
      }
    }
  }

  if (allViolations.isNotEmpty) {
    PoisonSniffer.reportViolations(allViolations);
    print(
        '[JET] ⚠️ Lint complete: ${allViolations.length} violation(s) across $scannedFiles file(s).');
    exitCode = 1;
  } else {
    print('[JET] ✅ No violations found ($scannedFiles file(s) scanned).');
  }
}

Future<void> _runServe() async {
  print('[JET] Building first...');
  await _runBuildAll();
  print('[JET] Starting jaspr serve...');
  await run('jaspr serve', verbose: true);
}

Future<void> _runClean() async {
  print('[JET] Cleaning .jet_cache and generated .jaspr.dart files...');
  var count = 0;

  final cacheDir = Directory('.jet_cache');
  if (cacheDir.existsSync()) {
    await cacheDir.delete(recursive: true);
    print('[JET] Deleted .jet_cache/');
  }

  await for (final entity in Directory.current.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.jaspr.dart')) {
      print('[JET] Deleting ${p.relative(entity.path)}');
      await entity.delete();
      count++;
    }
  }
  print('[JET] ✅ Cleaned cache and deleted $count generated file(s).');
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

void _printUsage(ArgParser parser) {
  print('''
JET — Flutter to Jaspr Transpiler CLI

Usage: jet <command> [options]

Commands:
  init      Set up JET in a Flutter project
  build     Run the JET transpiler (full project, single file, or continuous watch)
  watch     Continuously watch and transpile Flutter UI files
  preview   Print transpiled Jaspr code directly to the terminal
  lint      Run the JET Sniffer Fleet architectural linter
  serve     Build and serve the Jaspr web app
  clean     Delete .jet_cache and all generated .jaspr.dart files

Build Options (jet build):
  -t, --target <file>    Transpile a single target file (or pass <file> positionally)
  -w, --watch            Continuously watch for file changes and re-transpile
  -o, --output <dir>     Target directory for promoted Jaspr files (default: ../website/lib/ui)

${parser.usage}

Examples:
  jet init                           # Set up JET in a Flutter project
  jet build                          # Transpile entire project once
  jet build --watch                  # Continuous generation on file save
  jet build -t lib/ui/home.dart      # Single-file transpilation via -t flag
  jet build lib/ui/home.dart         # Single-file transpilation (positional)
  jet build -w -t lib/ui/home.dart   # Watch and auto-transpile a single file
  jet preview lib/ui/home.dart       # Preview generated Jaspr output in terminal
  jet lint                           # Check for architectural violations
  jet clean                          # Remove cache and generated files
''');
}
