# Business Requirements Document — JET

## 1. Overview
**Project Name**: JET (Dart Dual-UI Architecture)  
**Version**: 0.1.0-dev  
**Date**: 2026-09-11  
**Status**: Draft

## 2. Problem Statement
Flutter teams are forced to choose between:
- **Native mobile performance** (Flutter) — but no SEO, no semantic HTML, no SSR
- **Web-first frameworks** (Next.js, SvelteKit) — but a second language, second codebase, and lost Dart/Flutter investment

Flutter Web's WebGL/Canvas renderer is fundamentally incompatible with search engine indexing and produces zero semantic HTML.

## 3. Business Goals
1. **Eliminate the "write it twice" tax** — one Flutter UI codebase powers both native mobile and SEO-optimized web
2. **Make Jaspr adoption frictionless** — teams don't need to learn a new component model; JET generates it
3. **Protect existing Flutter investment** — drop-in tool, no migration or rewrite required
4. **Own the Dart full-stack ecosystem gap** — no comparable open-source tool exists as of 2026

## 4. Stakeholders
| Role | Interest |
|------|----------|
| Flutter developers | Gain SSR web output without rewriting UI |
| Dart full-stack teams | Share code across mobile and web with one language |
| Jaspr adopters | Generate initial component code from existing Flutter codebases |
| Open source contributors | Extend widget coverage, contribute new translators |

## 5. Success Metrics (v1.0)
| Metric | Target |
|--------|--------|
| Widget coverage | ≥ 30 common Flutter widgets translated correctly |
| Transpilation accuracy | ≥ 95% match on corpus golden files |
| Drop-in time | < 5 minutes from `pub add` to first generated file |
| Linter precision | Zero false positives on P-001 / P-002 rules |
| `dart analyze` violations | 0 in all generated output |

## 6. Scope
### In Scope (v1.0)
- Layout widgets: `Column`, `Row`, `Stack`, `Wrap`, `ListView`, `GridView`, `Scaffold`, `AppBar`, `Container`, `Padding`, `Center`, `SizedBox`, `Expanded`, `Flexible`, `Align`
- Text widgets: `Text`, `RichText`
- Input widgets: `TextField`, `TextFormField`, `ElevatedButton`, `TextButton`, `Checkbox`, `Switch`, `Form`
- Media widgets: `Image.network`, `Image.asset`, `Icon`
- Utility: `Divider`, `CircularProgressIndicator`
- `.asWeb()` semantic hint extension
- `@JetRoute` SEO annotation
- Architectural linter (P-001 through P-004)
- `jet_cli` convenience commands

### Out of Scope (v1.0)
- `CustomPainter` / complex animations (→ `FlutterEmbedView` fallback comment)
- Navigation/routing code generation
- Theme system translation
- MCP Server (→ Milestone 2)
- pub.dev publication (→ after GitHub)

## 7. Distribution Model
- **Local development**: `path:` dependencies in user's pubspec.yaml
- **Phase 2**: GitHub open source repository (MIT License)
- **Phase 3**: pub.dev publication (`jet_annotations`, `jet_builder`, `jet_cli`)
