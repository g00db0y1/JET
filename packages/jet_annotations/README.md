# jet_annotations

Semantic HTML hints and routing metadata for the [JET](https://github.com/your-repo/JET) Flutter-to-Jaspr transpiler.

This package provides annotations and extensions that you can apply to your Flutter widgets. **At runtime on mobile, these are completely ignored and have zero performance overhead.** At build time, the JET transpiler consumes them to generate SEO-friendly, semantic HTML for your Jaspr web application.

## Installation

Add this to your Flutter project's `dependencies`:

```yaml
dependencies:
  jet_annotations: ^0.1.0
```

*(Note: During local development of JET, this is managed via Dart Workspaces)*

## Usage

### 1. Semantic HTML Hints with `.asWeb()`

By default, JET maps basic Flutter widgets to generic HTML tags (e.g., `Text` -> `<p>`, `Column` -> `<div>`). Use `.asWeb()` to override this behavior and provide specific semantic tags, extra CSS classes, or accessibility attributes.

```dart
import 'package:flutter/material.dart';
import 'package:jet_annotations/jet_annotations.dart';

class HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Renders as: <h1 class="text-4xl font-bold">Welcome</h1>
        Text('Welcome').asWeb(tag: 'h1', classes: 'text-4xl font-bold'),
        
        // Renders as: <img src="..." alt="Hero Image" />
        Image.network('https://...').asWeb(alt: 'Hero Image'),
      ],
    ).asWeb(tag: 'section', ariaLabel: 'Hero'); 
    // The column renders as <section aria-label="Hero">
  }
}
```

### 2. Page Routing with `@JetRoute`

Use the `@JetRoute` annotation on top-level screen widgets. JET will extract this metadata to generate proper Jaspr routes, `<title>` tags, and SEO `<meta>` tags.

```dart
import 'package:flutter/material.dart';
import 'package:jet_annotations/jet_annotations.dart';

@JetRoute(
  path: '/about',
  title: 'About Us — Acme Corp',
  description: 'Learn about our mission, team, and values.',
  openGraphTags: [
    'og:type:website',
    'og:image:https://acme.com/og-image.png',
  ]
)
class AboutScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(...);
  }
}
```

## How it works

The `.asWeb()` extension method on `Widget` is literally just:

```dart
Widget asWeb({String tag = 'div', String? classes, String? id, String? alt, String? ariaLabel}) => this;
```

It returns `this`. It does absolutely nothing when your Flutter app is running. However, when you run `jet build` (or `dart run build_runner build`), the JET AST analyzer intercepts the method call, reads the parameters, and strips the call from the transpiled Jaspr output while applying the semantic hints to the generated HTML.
