/// JET Annotations — semantic HTML hints for the JET transpiler.
///
/// Add to your Flutter project's `dependencies:`:
/// ```yaml
/// dependencies:
///   jet_annotations: ^0.1.0
/// ```
///
/// ## Usage
/// ```dart
/// import 'package:jet_annotations/jet_annotations.dart';
///
/// // Use .asWeb() to provide semantic HTML hints
/// Text('Dashboard').asWeb(tag: 'h1', classes: 'text-2xl font-bold');
///
/// // Use @JetRoute to add SEO metadata to page screens
/// @JetRoute(path: '/about', title: 'About Us', description: 'Learn about our team.')
/// class AboutScreen extends StatelessWidget { ... }
/// ```
library jet_annotations;

export 'src/web_hints.dart';
export 'src/jet_route.dart';
export 'src/jet_fallback.dart';
