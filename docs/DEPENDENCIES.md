# Dependencies — JET

Last updated: 2026-09-11

## Runtime Dependencies

### `jet_annotations`
| Package | Version | Purpose | Source |
|---------|---------|---------|--------|
| `flutter` | SDK | Widget extension host (`WebHints on Widget`) | Flutter SDK |

## Build/Dev Dependencies

### `jet_builder`
| Package | Version Constraint | Purpose | pub.dev |
|---------|-------------------|---------|---------|
| `analyzer` | `^7.0.0` | Dart AST parsing — reads Flutter source into CompilationUnit | [link](https://pub.dev/packages/analyzer) |
| `build` | `^2.4.0` | Builder interface (`Builder`, `BuildStep`) | [link](https://pub.dev/packages/build) |
| `source_gen` | `^2.0.0` | Generator utilities on top of `build` | [link](https://pub.dev/packages/source_gen) |
| `code_builder` | `^4.10.0` | Structured Dart AST → string code generation | [link](https://pub.dev/packages/code_builder) |
| `dart_style` | `^2.3.0` | Dart code formatter for generated output | [link](https://pub.dev/packages/dart_style) |
| `jet_annotations` | `^0.1.0-dev` | Reads `.asWeb()` / `@JetRoute` from parsed AST | local |

### `jet_cli`
| Package | Version Constraint | Purpose | pub.dev |
|---------|-------------------|---------|---------|
| `args` | `^2.5.0` | CLI argument parsing | [link](https://pub.dev/packages/args) |
| `path` | `^1.9.0` | Cross-platform path manipulation | [link](https://pub.dev/packages/path) |
| `process_run` | `^1.0.0` | Spawn build_runner / jaspr subprocess | [link](https://pub.dev/packages/process_run) |

### `tests/jet_builder_test`
| Package | Version Constraint | Purpose |
|---------|-------------------|---------|
| `test` | `^1.25.0` | Dart test runner |
| `build_test` | `^2.2.0` | Testing `build_runner` builders in isolation |
| `jet_builder` | local | Subject under test |

## User-Installed Dependencies (not part of JET itself)
| Package | Role | Where |
|---------|------|-------|
| `jaspr` | Target web framework | User's Jaspr web project |
| `jaspr_cli` | Serve the generated web app | global activation |
| `build_runner` | Orchestrates `jet_builder` | User's `dev_dependencies` |
| `riverpod` | Pure-Dart state management | User's `shared_core` / pure Dart packages |
| `freezed` | Domain model codegen | User's domain layer |
