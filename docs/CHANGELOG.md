# Changelog — JET

All notable changes to this project will be documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### Added
- `jet_annotations`: `.asWeb()` Widget extension with `tag`, `classes`, `id`, `alt`, `ariaLabel` params
- `jet_annotations`: `@JetRoute` annotation with `path`, `title`, `description`, `openGraphTags` params
- `jet_builder`: `JetBuilder` build_runner plugin skeleton
- `jet_builder`: `FlutterAstParser` — parses Dart source into `CompilationUnit` via `package:analyzer`
- `jet_builder`: `WidgetNode` sealed IR class hierarchy (`ModifierNode`, `StructuralNode`, `ComponentNode`, `UnknownNode`)
- `jet_builder`: `StyleAccumulatorVisitor` — traverses AST, accumulates CSS, flushes at structural boundaries
- `jet_builder`: `TailwindMapper` — Flutter property values → Tailwind utility classes
- `jet_builder`: `JasprEmitter` — emits Jaspr Dart component code from IR
- `jet_builder`: `PoisonSniffer` — architectural linter (P-001 through P-004)
- `jet_cli`: `jet init`, `jet build`, `jet lint`, `jet serve`, `jet clean` commands
- `tests/corpus/`: 11 canonical widget pattern files from Flutter widget catalog
- `tests/expected/`: Golden Jaspr output files for all corpus widget patterns
- `docs/`: BRD, PRD, ARD, DEPENDENCIES, decisionlog initialized

---

## [0.1.0-dev] — Target (not yet released)
Initial local development release. Not published to pub.dev.
