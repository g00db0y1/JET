# JET Transpilation Mapping Status

This document provides a visual mapping of which Flutter keywords, properties, and widgets JET can perfectly transpile today, which ones are on the roadmap (hard), and the target Jaspr keywords we emit.

## 🟢 100% Supported (The Happy Path)
These core architectural building blocks map flawlessly to Jaspr and Tailwind CSS.

| Flutter Widget | Transpiled Jaspr DOM | Tailwind Equivalent | Notes |
|----------------|----------------------|----------------------|-------|
| `Column` | `div` | `flex flex-col` | Handles `mainAxisAlignment` and `crossAxisAlignment`. |
| `Row` | `div` | `flex flex-row` | |
| `Container` | `div` | - | Pure layout box. |
| `SizedBox` | `div` | `w-[X] h-[Y]` | Height/Width maps to arbitrary Tailwind values. |
| `Padding` | `div` | `p-[X] px-[X] py-[X]` | Flutter scale maps to Tailwind `/4` scale. |
| `Center` | `div` | `flex items-center justify-center` | |
| `Expanded` | `div` | `flex-1` | Used inside Flex containers. |
| `Text` | `p` or `span` | - | Structural text node. |
| `TextStyle` | `style` modifier | `text-[color] text-[size] font-[weight]` | E.g. `Colors.red` -> `text-red-500`. |
| `BoxDecoration`| `style` modifier | `bg-[color] rounded-[radius] border` | Supports `borderRadius`, `color`, `border`. |

## 🟡 Partially Supported (Work in Progress)
These components work for basic use-cases but are missing advanced Flutter API parity.

| Flutter Widget | Transpiled Jaspr DOM | Missing Capabilities |
|----------------|----------------------|----------------------|
| `TextField` | `input(type: 'text')` | Deep bindings for `TextEditingController`, focus nodes, and input formatters. |
| `ListView` | `div (overflow-y-auto)` | `ListView.builder` lazy loading virtualization (requires JS intersection observer mapping). |
| `ElevatedButton`| `button` | Deep Material ripple effects. Basic hover/click is supported. |
| `Image.network`| `img(src: ...)` | Caching, error builders, and `Image.asset` bundle resolution. |

## 🔴 Hard / Untranspilable (Milestone 3 Frontier)
These components rely heavily on Flutter's Dart math engine, Skia canvas, or platform specifics.

| Flutter Concept | Why is it hard? | Target Web Equivalent |
|-----------------|-----------------|-----------------------|
| `BouncingScrollPhysics` | Flutter calculates rubber-banding mathematically per frame in Dart. | CSS `overscroll-behavior: auto` (relies on browser). |
| `PageScrollPhysics` | Paging math calculated in Dart. | CSS `scroll-snap-type: x mandatory` |
| `CustomPaint` / `Canvas`| Imperative Skia drawing instructions. | HTML5 `<canvas>` and JS Canvas API. Extremely difficult to map 1:1. |
| `CustomScrollView` (Slivers) | Sliver layout protocol is fundamentally different from HTML flow. | Advanced CSS Grid or nested Flexbox math. |
| `AnimationController` | Dart `Ticker` triggers 60fps rebuilds. Too slow for DOM updates. | CSS Transitions, `@keyframes`, or Web Animations API. |
| `GestureDetector` | Flutter handles pan/scale velocity. | JS Pointer Events (`pointerdown`, `pointermove`). |
| `Form` & `TextFormField` | `GlobalKey<FormState>` validation. | HTML5 Semantic `<form>` with `onSubmit` validation logic. |

## 💡 The Proposed Safety Valve
Because elements like `CustomPaint` or complex Shaders cannot be reliably compiled to the DOM, JET Milestone 3 will introduce the **`@JetFallback`** annotation.

```dart
// If JET encounters a widget with this annotation, it skips parsing the AST 
// for this node and directly outputs the Jaspr code provided in the fallback.
@JetFallback(WebVideoPlayer(url: url))
class MobileNativeVideoPlayer extends StatelessWidget {
  // ... native flutter video code ...
}
```
