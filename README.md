# JET

> **Dart Dual-UI Architecture** — Automatically transpile Flutter widgets to Jaspr SSR components.

[![Dart SDK](https://img.shields.io/badge/dart-%3E%3D3.6.0-blue)](https://dart.dev)

## What is JET?

JET is a drop-in `build_runner` plugin that converts your existing Flutter widget code into production-ready [Jaspr](https://jaspr.site) web components — giving you SEO-optimized, server-side rendered HTML from a single Dart codebase.

**Write once in Flutter. Get native mobile AND semantic web.**

```
dart run build_runner build
# → Your Flutter widgets become Jaspr SSR components automatically
```

## Packages

| Package | Description | Install |
|---------|-------------|---------|
| [`jet_annotations`](./packages/jet_annotations/) | `.asWeb()` extension + `@JetRoute` annotation | `dependencies` |
| [`jet_builder`](./packages/jet_builder/) | build_runner transpiler plugin | `dev_dependencies` |
| [`jet_cli`](./packages/jet_cli/) | `jet init`, `jet build`, `jet lint`, `jet serve` | `dart pub global activate jet_cli` |

## Quick Start

```yaml
# pubspec.yaml in your Flutter project
dependencies:
  jet_annotations: ^0.1.0

dev_dependencies:
  jet_builder: ^0.1.0
  build_runner: ^2.4.0
```

```dart
// Your existing Flutter code — no changes needed
class HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text('Welcome').asWeb(tag: 'h1', classes: 'text-3xl font-bold'),
          Text('Build for mobile and web from one codebase.'),
        ],
      ),
    );
  }
}
```

```bash
dart run build_runner build
# Generates: lib/ui/hero_section.jaspr.dart
```

```dart
// Generated Jaspr output (do not edit manually)
class HeroSection extends StatelessComponent {
  @override
  Iterable<Component> build(BuildContext context) sync* {
    yield div(classes: 'flex flex-col p-4', [
      h1(classes: 'text-3xl font-bold', [text('Welcome')]),
      p([], [text('Build for mobile and web from one codebase.')]),
    ]);
  }
}
```

## How It Works

JET runs a 4-step pipeline at build time:

1. **Parse** — `package:analyzer` reads your Flutter `.dart` files into an AST
2. **Visit** — `StyleAccumulatorVisitor` traverses the tree, collecting layout properties
3. **Map** — `TailwindMapper` converts Flutter props (padding, alignment) to Tailwind classes
4. **Emit** — `JasprEmitter` generates clean Jaspr component code

**Modifier nodes** (`Padding`, `Center`, `SizedBox`) become CSS — no wrapper divs.  
**Structural nodes** (`Column`, `Row`, `Scaffold`, `Text`) become semantic HTML.  
**StatelessWidget** → pure SSR (zero JavaScript).  
**StatefulWidget** → `@client` Islands (hydrated in browser).

## Architectural Linter

Run `jet lint` to detect code that would prevent web compilation:

```
[JET P-001] ❌ Flutter SDK in logic file
  File: lib/state/auth_controller.dart:12
  import 'package:flutter/widgets.dart'
  Fix: Extract to abstract interface + platform adapters
```

## Status

🚧 **Active development** — v0.1.0-dev (local only, GitHub + pub.dev coming soon)

## License

MIT
