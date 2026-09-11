# Product Requirements Document — JET

## 1. Product Vision
JET is a **drop-in Dart package** that automatically transpiles Flutter widget trees into semantically correct, SSR-optimized Jaspr web components. Developers add it to `dev_dependencies`, run `dart run build_runner build`, and get production-ready web UI.

## 2. User Stories

### Developer Stories
| ID | As a… | I want to… | So that… |
|----|-------|------------|----------|
| US-001 | Flutter developer | Add JET to my existing project without changing my folder structure | I don't have to migrate anything |
| US-002 | Flutter developer | Annotate a `Text` widget with `.asWeb(tag: 'h1')` | The generated web output uses a semantic `<h1>` tag for SEO |
| US-003 | Flutter developer | Annotate a screen class with `@JetRoute(path: '/about', title: 'About Us')` | The Jaspr route gets the right `<title>` and `<meta>` tags |
| US-004 | Flutter developer | Run `jet lint` on my project | I get a clear report of which files are blocking web compilation |
| US-005 | Flutter developer | Point `jet build` at my `lib/ui/` folder | All supported widgets are translated to `.jaspr.dart` files automatically |
| US-006 | Jaspr developer | Import generated components into my Jaspr web app | I have a complete, working starting point for my web UI |
| US-007 | Flutter developer | Have unsupported widgets gracefully handled | I get a `// TODO(jet): manual port` comment, not a crash |

### Developer Experience Stories
| ID | Story |
|----|-------|
| DX-001 | Zero changes to existing Flutter code for basic transpilation |
| DX-002 | `.asWeb()` has zero runtime overhead on mobile (returns `this`) |
| DX-003 | All generated Jaspr files pass `dart analyze` with zero warnings |
| DX-004 | `jet init` scaffolds everything in < 30 seconds |
| DX-005 | Linter output is human-readable AND machine-readable (JSON to stderr) |

## 3. Functional Requirements

### FR-001: Widget Translation
The transpiler MUST translate all widgets listed in the Widget Translation Table (see ARD §4) without errors. Unsupported widgets MUST produce a `// TODO(jet): manual port — {WidgetName}` comment and NOT crash the build.

### FR-002: Modifier Node Flattening
Modifier nodes (`Padding`, `Center`, `SizedBox`, `Expanded`, `Flexible`, `Align`) MUST NOT produce HTML tags. Their properties MUST be accumulated into the nearest enclosing Structural Node's CSS class list.

### FR-003: StatefulWidget Islands
Any `StatefulWidget` MUST produce a Jaspr component annotated with `@client` to enable client-side hydration. The generated component MUST include `initState`, `dispose`, and `setState` lifecycle mapping.

### FR-004: `.asWeb()` Extension
The `.asWeb()` method MUST:
- Accept `tag`, `classes`, `id`, `alt`, and `ariaLabel` parameters
- Be a **no-op at runtime** on mobile (returns the Widget unchanged)
- Be intercepted by the AST visitor before code generation
- Override the default inferred HTML tag for the target widget

### FR-005: Semantic Inference
When no `.asWeb()` annotation exists, the visitor MUST apply the heuristics defined in ARD §5 (font size → heading level, `Scaffold` → `<main>`, etc.).

### FR-006: Linter Rules
The linter MUST detect and report (without crashing the build):
- P-001: `package:flutter` imported outside `lib/ui/` or `lib/widgets/`
- P-002: `context.go()` or `Navigator.push()` in transpilable UI files
- P-003: Platform plugins (`shared_preferences`, `path_provider`, etc.) in shared logic
- P-004: `await` expressions or API calls inside `setState()` bodies

### FR-007: Routing Exclusion
The transpiler MUST skip any file that contains `go_router` or Navigator route configuration. It MUST log a `// JET: routing excluded — handle in platform layer` comment instead of crashing.

## 4. Non-Functional Requirements
| NFR | Requirement |
|-----|-------------|
| NFR-001 | Build time: transpiling 50 widget files < 30 seconds |
| NFR-002 | Generated code: zero `dart analyze` warnings |
| NFR-003 | Generated code: formatted by `dart_style` |
| NFR-004 | No changes to user's existing source files (build_to: source, generated only) |
| NFR-005 | Compatible with Dart SDK ≥ 3.6.0 |
| NFR-006 | Compatible with Jaspr ≥ 0.20.0 |

## 5. Acceptance Criteria (v1.0 Release Gate)
- [ ] All 11 corpus widget files produce output matching golden files (95%+ char accuracy)
- [ ] `dart analyze` returns zero errors on all generated files
- [ ] `jet lint` detects all 4 poison rules on the `poison_import_test.dart` corpus file
- [ ] `.asWeb(tag: 'h1')` produces `h1(...)` in Jaspr output
- [ ] `StatefulWidget` always produces `@client`-annotated component
- [ ] `jet init` runs on a fresh Flutter project and succeeds
