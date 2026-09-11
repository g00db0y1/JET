# Decision Log — JET

Decisions are logged in the format: `[UD|AD]-NNN | Status | Title`
- `UD` = User Decision (explicitly chosen by the project owner)
- `AD` = Agent Decision (made by the coding agent to fill a gap not covered by docs)
- Status: `USED` | `SUPERSEDED` | `REJECTED`

---

## UD-001 | USED | Product Model: Drop-in Package, Not Project Scaffold
**Date**: 2026-09-11  
**Decision**: JET is distributed as a set of pub.dev packages (`jet_annotations`, `jet_builder`, `jet_cli`) that developers add to *existing* Flutter projects. It is NOT a project template or monorepo scaffold that users clone.  
**Rationale**: Users want to drop JET into any Dart ecosystem project without migration. Quoted: *"we want the JET project to be drop into any of the project and it should work"*  
**Impact**: Changes monorepo structure (no `apps/`), requires self-contained test corpus, drives pub.dev distribution model.

---

## UD-002 | USED | State Management: Riverpod (pure Dart)
**Date**: 2026-09-11  
**Decision**: JET recommends and generates Riverpod-compatible state patterns using `riverpod` (pure Dart, not `flutter_riverpod`) in shared code.  
**Rationale**: Pure Dart Riverpod works in both Flutter and Jaspr environments without Flutter SDK dependency contamination.

---

## UD-003 | USED | CSS Output: Tailwind Utility Classes
**Date**: 2026-09-11  
**Decision**: The transpiler emits Tailwind CSS utility classes for all layout and styling.  
**Rationale**: Tailwind is utility-first and maps cleanly to Flutter's declarative layout properties (padding, flex direction, alignment). No custom CSS files needed.

---

## UD-004 | USED | Monorepo Structure: Dart 3.6 Native Workspaces
**Date**: 2026-09-11  
**Decision**: The JET development repository uses Dart 3.6+ native `workspace` field in the root `pubspec.yaml`.  
**Rationale**: Native Dart Workspaces provide shared resolution and IDE performance without requiring Melos. Avoids additional toolchain dependency.

---

## UD-005 | USED | Test Corpus: Flutter Widget Catalog (Docs-Derived)
**Date**: 2026-09-11  
**Decision**: The transpiler is tested against a curated set of widget pattern files derived from the official Flutter widget catalog documentation, not a specific user app.  
**Rationale**: Makes JET's correctness verifiable without depending on any particular Flutter codebase. Corpus represents the canonical Flutter widget surface.  
**Source**: https://docs.flutter.dev/ui/widgets

---

## UD-006 | USED | Local-First Development, GitHub + pub.dev Later
**Date**: 2026-09-11  
**Decision**: Initial development is local. `publish_to: none` in all `pubspec.yaml` files during development. GitHub and pub.dev publication in Phase 2.  
**Rationale**: Quoted: *"we work locally for the mean time but we will go on github and pub dev"*

---

## AD-001 | USED | MCP Server Deferred to Milestone 2
**Date**: 2026-09-11  
**Decision**: The MCP stdio server (AI IDE integration) is out of scope for the initial milestone. Linter output will be structured JSON to stderr, ready for MCP wrapping later.  
**Rationale**: Keeps M1 focused on the transpiler pipeline. MCP is an enhancement, not a correctness requirement.

---

## AD-002 | USED | `build_to: source` for Generated Files
**Date**: 2026-09-11  
**Decision**: `build.yaml` uses `build_to: source` so `.jaspr.dart` files appear alongside Flutter source in the user's `lib/` directory.  
**Rationale**: This allows developers to inspect, version-control (or gitignore), and directly import the generated Jaspr files into their web project without additional config.

---

## AD-003 | USED | `jet_builder` Does NOT Import `jaspr` at Runtime
**Date**: 2026-09-11  
**Decision**: The `jet_builder` package generates Jaspr code as strings using `code_builder`. It does NOT `import 'package:jaspr/jaspr.dart'` itself.  
**Rationale**: Prevents a Jaspr version conflict in the user's Flutter project (which does not have Jaspr installed). The generated strings reference Jaspr APIs; the builder itself doesn't.

---

## AD-004 | USED | Tailwind Scale: 1 Flutter logical pixel = 0.25 Tailwind unit
**Date**: 2026-09-11  
**Decision**: Flutter's `EdgeInsets.all(16)` maps to Tailwind `p-4` (16px = 4 × 4px Tailwind scale).  
**Rationale**: Tailwind's default spacing scale is 4px per unit. Flutter's common padding values (8, 12, 16, 24, 32) map cleanly to (2, 3, 4, 6, 8).

---

## AD-005 | USED | Non-Fatal Linter: Build Continues on Violations
**Date**: 2026-09-11  
**Decision**: Linter violations are printed as structured JSON to stderr but do NOT halt the build or throw exceptions.  
**Rationale**: Allows partial adoption — teams can see what needs fixing without blocking their CI pipeline. Fatal errors reserved for actual parse failures.
