# jet_cli

The command-line interface for the [JET](https://github.com/your-repo/JET) Flutter-to-Jaspr transpilation ecosystem.

JET CLI provides convenience wrappers around `build_runner` and `jaspr` to simplify your workflow when building dual-UI applications.

## Installation

Activate the CLI globally:

```bash
dart pub global activate jet_cli
```

*(Note: During local development of the JET project itself, run `dart run jet_cli:jet <command>` or `dart packages/jet_cli/bin/jet.dart <command>`)*

## Commands

### `jet init`

Initializes JET in your existing Flutter project. 
It prints instructions (or automatically edits your `pubspec.yaml`) to add `jet_annotations` to your `dependencies` and `jet_builder` to your `dev_dependencies`.

### `jet build`

Runs the JET transpiler to generate Jaspr components from your Flutter UI.
Under the hood, this runs:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### `jet lint`

Runs the JET architectural linter without generating any code.
This checks your Flutter codebase for "poison" patterns (e.g., using `Navigator.push` in a transpilable UI file, or importing `package:flutter` in a shared logic file) and reports violations to stderr.

### `jet serve`

Builds the Jaspr web components and starts the Jaspr development server.
Under the hood, this runs `jet build` followed by `jaspr serve`.

### `jet clean`

Deletes all generated `.jaspr.dart` files from your project directory.
