# JET 🚀
**Bridging the Flutter and Jaspr Ecosystems**

JET (Jaspr Engine Transpiler) is an ultra-fast, drop-in compiler that allows you to write Flutter mobile apps and automatically transpile their UI components into pure [Jaspr](https://pub.dev/packages/jaspr) DOM trees and Tailwind CSS for the web.

JET isn't a WebView wrapper—it compiles declarative Flutter logic (like `Column`, `Row`, `Container`) directly into semantic HTML/CSS, resulting in near-zero payload overhead and perfect SEO.

## Features
- ⚡ **Lightning Fast AST Crawler**: Transpiles hundreds of UI files in milliseconds.
- 🎯 **Tailwind CSS Generation**: Converts Flutter's rendering properties (`EdgeInsets`, `BoxDecoration`, `Colors`) into standard Tailwind utility classes.
- 🤖 **MCP Server Integration**: Features a local, offline Model Context Protocol (MCP) server so your AI agent (like Cursor or Claude) can autonomously analyze architecture, check web compatibility, and auto-apply JS interop templates.
- 🏗️ **Architectural Mentorship (PoisonSniffer)**: Actively prevents developers from polluting shared code with mobile-only plugins and suggests exact Web Equivalents (or JS Interop mappings).
- 🔄 **Atomic Syncing (`.jet_cache`)**: Isolates generated web files from your mobile workspace.

---

## 🚀 Quick Start (CLI)

### 1. Install the CLI
JET is distributed as a set of developer packages.
```bash
dart pub global activate jet_cli
```

### 2. Instant Preview
Want to see how a specific Flutter widget translates to Jaspr/Tailwind? Use the preview command. You can even target a specific line number to transpile a single component out of a massive file!
```bash
jet preview lib/ui/home_page.dart --line 42
```

### 3. Build & Sync (The `.jet_cache` Architecture)
Instead of polluting your Flutter project with `build_runner` files, JET uses a highly optimized AST pipeline.
```bash
jet build
```
When you run `jet build`, it:
1. Scans `lib/ui`, `lib/screens`, and `lib/widgets`.
2. Parses the Flutter widgets and compiles them.
3. Streams the outputs into a `.jet_cache/` staging directory.
4. Atomically syncs the pure `.dart` Jaspr files directly to your target web folder (e.g., `../website/lib/ui/`).

---

## 🤖 The JET MCP Server (For AI Agents)

JET acts as an AI-first compiler. We bundle a local Model Context Protocol (MCP) server so your AI assistant knows exactly how to bridge Flutter and Jaspr.

The server exposes 4 tools to your AI:
1. `jet_analyze`: Runs the PoisonSniffer to detect bad architectures or mobile-only plugins.
2. `jet_transpile`: Returns the Jaspr DOM conversion of a Flutter file.
3. `jet_check_dependency`: Checks if a pub.dev package is pure-Dart compatible or requires JS interop (and provides the exact JS template).
4. `jet_suggest_fix`: Outputs official JET refactoring code snippets (e.g., how to convert `Navigator.push` to stateless callbacks).

**No internet required.** The MCP server runs 100% locally via stdio.

---

## 🏗️ The Architectural Linter (`PoisonSniffer`)

Flutter's biggest obstacle to the web is architectural pollution (using `dart:io` or mobile plugins in shared logic). The `PoisonSniffer` enforces clear boundaries.

**Rules Enforced:**
* `P-001`: No Flutter SDK in shared logic/models.
* `P-002`: No Navigation logic (`context.go`, `Navigator.push`) deep in UI components.
* `P-003`: No Platform-specific plugins in UI code.
* `P-004`: No heavy `await` or API calls inside `setState` bodies.

If it catches a violation, it doesn't just error out. It checks the **Web Equivalent Dictionary** and mentors the developer on exactly how to fix it (e.g., "Use `window.localStorage` instead of `shared_preferences`").

---

## 🧪 Testing
JET relies on "Golden Tests" (snapshot tests). The `tests/corpus/` directory contains a curated list of Flutter widget combinations. The transpiled output is checked character-for-character against `tests/expected/` to guarantee zero regressions.

```bash
dart test tests/jet_builder_test/test/golden_test.dart
```

---

## 🗺️ Roadmap to v1.0.0 (The Render Expansion)
Currently, JET flawlessly handles ~80% of standard UI layouts (Columns, Rows, Containers, styling). To handle the final 20% of edge-case enterprise Flutter apps, the following features are in active development:

- 🛡️ **`@JetFallback` Safety Valve**: For custom canvas drawings or shaders, this annotation will let you bypass the transpiler and inject a manual Jaspr component.
- 🏎️ **Physics Engine Translation**: Mapping Flutter's `BouncingScrollPhysics` and `PageScrollPhysics` to CSS `overscroll-behavior` and `scroll-snap`.
- 🎬 **Animations to CSS**: Translating `AnimatedContainer` and `AnimationController` to the Web Animations API / CSS Transitions.
- 📜 **Slivers**: Converting `CustomScrollView` and `SliverAppBar` into advanced CSS Grid behaviors.
- 📝 **Semantic Forms**: Deep mapping of `TextFormField` and `FormState` to accessible HTML5 `<form>` validation.
