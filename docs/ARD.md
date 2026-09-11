# Architecture Requirements Document — JET

## 1. System Overview

JET is a **build-time code generation tool** implemented as a `build_runner` `Builder`. It reads Flutter `.dart` source files and emits Jaspr `.dart` source files. It never modifies the original source. It runs entirely on the developer's local machine.

```
[Flutter .dart files]
        │
        ▼
  JetBuilder (build_runner plugin)
        │
        ├── FlutterAstParser (package:analyzer)
        │       └── Parses into CompilationUnit AST
        │
        ├── StyleAccumulatorVisitor (RecursiveAstVisitor)
        │       ├── Modifier Nodes → CSS class bucket (no HTML)
        │       └── Structural Nodes → WidgetNode IR (flush bucket)
        │
        ├── TailwindMapper
        │       └── Flutter property values → Tailwind utility classes
        │
        ├── JasprEmitter (code_builder + dart_style)
        │       ├── StatelessComponent (no @client)
        │       └── @client StatefulComponent (Islands)
        │
        └── PoisonSniffer (linter — runs in parallel)
                └── P-001 through P-004 violation reports
```

## 2. Package Architecture

### `jet_annotations` (published to pub.dev)
- **Purpose**: Compile-time annotations and no-op runtime extensions
- **Dart SDK dependency**: `^3.6.0`
- **Flutter SDK dependency**: YES (`package:flutter/widgets.dart` for the `Widget` extension)
- **Must NOT depend on**: `jet_builder`, `build_runner`, `analyzer`
- **Exported surface**: `WebHints` extension, `JetRoute` annotation class

### `jet_builder` (published to pub.dev as dev dependency)
- **Purpose**: The `build_runner` Builder that drives the entire transpilation pipeline
- **Dart SDK dependency**: `^3.6.0`
- **Flutter SDK dependency**: NO (reads Flutter AST as text; does not import Flutter)
- **Must NOT depend on**: `flutter`, `jaspr` (outputs Jaspr code as strings, not as imports)
- **Key dependencies**: `analyzer`, `build`, `source_gen`, `code_builder`, `dart_style`, `jet_annotations`

### `jet_cli` (published to pub.dev, installed globally)
- **Purpose**: Developer-facing CLI wrapper
- **Dart SDK dependency**: `^3.6.0`
- **Flutter SDK dependency**: NO
- **Must NOT depend on**: `flutter`
- **Key dependencies**: `args`, `process_run`, `path`

## 3. Dependency Rules (Enforced by Linter)

```
jet_annotations  ←  jet_builder  (reads annotations from AST text, no runtime import)
                 ←  jet_cli      (calls build_runner subprocess)
                 
User's Flutter project:
  dependencies:    jet_annotations    (runtime extension, zero overhead mobile)
  dev_dependencies: jet_builder       (build-time only)
                    build_runner      (orchestrator)
```

### The "Poison" Contract
Files in `lib/ui/` or `lib/widgets/` MAY import `package:flutter`.
Files anywhere else (state, models, services, repositories) MUST NOT import `package:flutter`.
This is enforced by Rule P-001.

## 4. Widget Translation Table (Normative)

### Modifier Nodes (emit NO HTML — accumulate CSS)
| Flutter Widget | Dart Constructor Pattern | CSS Output |
|---|---|---|
| `Padding(padding: EdgeInsets.all(N))` | `EdgeInsets.all` | `p-{N/4}` (Tailwind scale) |
| `Padding(padding: EdgeInsets.symmetric(h:H, v:V))` | `EdgeInsets.symmetric` | `px-{H/4} py-{V/4}` |
| `Padding(padding: EdgeInsets.only(...))` | `EdgeInsets.only` | `pt-* pr-* pb-* pl-*` |
| `Center()` | class name | `flex items-center justify-center` |
| `SizedBox(width: W)` | `width` param | `w-{W/4}` |
| `SizedBox(height: H)` | `height` param | `h-{H/4}` |
| `SizedBox(width: W, height: H)` | both params | `w-{W/4} h-{H/4}` |
| `Expanded()` | class name | `flex-1` |
| `Flexible()` | class name | `flex-auto` |
| `Align(alignment: Alignment.centerRight)` | alignment enum | `self-end` |
| `Align(alignment: Alignment.centerLeft)` | alignment enum | `self-start` |
| `Align(alignment: Alignment.center)` | alignment enum | `self-center` |

### Structural Nodes (flush CSS bucket, emit HTML)
| Flutter Widget | Jaspr Tag | Default Classes | Notes |
|---|---|---|---|
| `Column` | `div` | `flex flex-col` | + `justify-*` from `mainAxisAlignment`, `items-*` from `crossAxisAlignment` |
| `Row` | `div` | `flex flex-row` | + `justify-*` from `mainAxisAlignment`, `items-*` from `crossAxisAlignment` |
| `Wrap` | `div` | `flex flex-wrap` | |
| `Stack` | `div` | `relative` | children get `absolute` class |
| `ListView` | `ul` | `flex flex-col` | each child wrapped in `li` |
| `ListView.builder` | `ul` | `flex flex-col` | emits `// TODO(jet): resolve itemBuilder` |
| `GridView.count(crossAxisCount: N)` | `div` | `grid grid-cols-{N}` | |
| `Scaffold` | `main` | — | `body:` → children, `appBar:` → `header`, `bottomNavigationBar:` → `nav` |
| `AppBar(title: ...)` | `header` | `flex items-center px-4 py-2` | title → `h1` |
| `BottomNavigationBar` | `nav` | `flex justify-around` | |
| `Container` | `div` | — | decoration mapped to bg, border, rounded |
| `Card` | `div` | `rounded shadow p-4 bg-white` | |
| `Text(str)` | `p` | — | see §5 for heading inference |
| `RichText` | `p` | — | TextSpan → nested `span` |
| `Image.network(url)` | `img` | — | `src=url`, `alt` from `.asWeb(alt:...)` |
| `Image.asset(path)` | `img` | — | `src=/assets/{path}` |
| `Icon(Icons.X)` | `span` | `icon icon-{name}` | |
| `ElevatedButton` | `button` | `bg-blue-600 text-white rounded px-4 py-2` | triggers `@client` bubble |
| `TextButton` | `button` | `text-blue-600` | triggers `@client` bubble |
| `OutlinedButton` | `button` | `border border-blue-600 text-blue-600 rounded px-4 py-2` | triggers `@client` bubble |
| `TextField` | `input` | — | `type=text`, triggers `@client` bubble |
| `TextFormField` | `input` | — | `type=text` within `form`, triggers `@client` bubble |
| `Form` | `form` | — | triggers `@client` bubble |
| `Checkbox` | `input` | — | `type=checkbox`, triggers `@client` bubble |
| `Switch` | `input` | `toggle` | `type=checkbox role=switch`, triggers `@client` bubble |
| `Slider` | `input` | — | `type=range`, triggers `@client` bubble |
| `Divider` | `hr` | `border-t border-gray-200 my-2` | |
| `CircularProgressIndicator` | `div` | `animate-spin rounded-full border-4 border-t-transparent w-8 h-8` | |
| `LinearProgressIndicator` | `div` | `animate-pulse h-1 bg-blue-500 w-full` | |
| `Spacer` | `div` | `flex-1` | |

### Component Nodes
| Flutter Class | Jaspr Output | Annotation |
|---|---|---|
| `StatelessWidget` | `StatelessComponent` | none (pure SSR) |
| `StatefulWidget` | `StatefulComponent` | `@client` (Islands hydration) |

### Unsupported (graceful fallback)
| Widget | Output |
|---|---|
| `CustomPainter` | `// TODO(jet): FlutterEmbedView — use jaspr_flutter_embed` |
| `AnimatedBuilder` | `// TODO(jet): manual port — AnimatedBuilder` |
| `TweenAnimationBuilder` | `// TODO(jet): manual port — TweenAnimationBuilder` |
| Any unrecognized class | `// TODO(jet): manual port — {WidgetName}` |

## 5. Semantic Inference Rules (No `.asWeb()` Present)

Applied in this priority order (first match wins):
1. Widget has `@JetRoute` annotation → wrap output in `article` with route metadata comments
2. Widget is `Scaffold` at root → `main`
3. Widget is `AppBar` → `header`, title child → `h1`
4. Widget is `BottomNavigationBar` → `nav`
5. `Text` with `style.fontSize >= 28` → `h1`
6. `Text` with `style.fontSize >= 22` → `h2`
7. `Text` with `style.fontSize >= 18` → `h3`
8. `Text` with `style.fontWeight == FontWeight.bold` and fontSize >= 16 → `h4`
9. `Text` with no style or small font → `p`
10. First `Text` child inside `AppBar.title` → `h1` (regardless of font size)

## 6. File I/O Contract

### Input (what JetBuilder reads)
- **Pattern**: `lib/ui/**.dart`, `lib/widgets/**.dart`, `lib/screens/**.dart`
- **Configurable** via user's `build.yaml`: `generate_for: [lib/ui/**]`
- **Never reads**: `lib/main.dart`, routing files, adapter files

### Output (what JetBuilder writes)
- **Extension**: `.jaspr.dart` (e.g., `home_screen.dart` → `home_screen.jaspr.dart`)
- **Location**: same directory as input file (or configurable output dir)
- **Never overwrites**: existing non-generated files
- **Header**: every generated file starts with:
  ```dart
  // GENERATED BY JET — DO NOT EDIT MANUALLY
  // Source: {relative_input_path}
  // JET version: {version}
  // Generated at: {timestamp}
  ```

## 7. `build.yaml` Specification

```yaml
# packages/jet_builder/build.yaml
builders:
  jet_builder:
    import: "package:jet_builder/builder.dart"
    builder_factories: ["jetBuilder"]
    build_extensions: {".dart": [".jaspr.dart"]}
    auto_apply: dependents
    build_to: source
    defaults:
      generate_for:
        - lib/ui/**
        - lib/widgets/**
        - lib/screens/**
```

## 8. Error Handling Strategy

| Situation | Behavior |
|---|---|
| Parse error in input file | Log error with file + line, skip file, continue build |
| Unrecognized widget | Emit `// TODO(jet)` comment, continue |
| Linter violation (error) | Print to stderr as JSON, build continues (non-fatal) |
| Missing `.asWeb()` parameter | Use inference rules (§5) |
| `ListVIew.builder` itemBuilder | Emit `// TODO(jet): resolve itemBuilder`, skip children |
| File contains only routing | Skip entirely, log skip message |

## 9. Testing Architecture

### Unit Tests (per component)
- `parser_test.dart` — verify AST parsing produces correct node types
- `visitor_test.dart` — verify modifier accumulation and structural flushing
- `emitter_test.dart` — verify Jaspr string output matches golden files
- `linter_test.dart` — verify each poison rule triggers on corpus files

### Golden File Testing
- Input: `tests/corpus/{category}/{widget_pattern}.dart`
- Expected: `tests/expected/{category}/{widget_pattern}.jaspr.dart`
- Comparison: whitespace-normalized string diff

### Integration Test
- Run `dart run build_runner build` on the entire `tests/corpus/` directory
- Diff all generated files against `tests/expected/`
- Assert zero `dart analyze` warnings on generated files
