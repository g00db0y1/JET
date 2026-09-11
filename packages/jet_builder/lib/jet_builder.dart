/// JET Builder — build_runner plugin for Flutter-to-Jaspr transpilation.
///
/// Add to your Flutter project's `dev_dependencies:`:
/// ```yaml
/// dev_dependencies:
///   jet_builder: ^0.1.0
///   build_runner: ^2.4.0
/// ```
///
/// Then run:
/// ```bash
/// dart run build_runner build
/// ```
///
/// JET will scan your `lib/ui/`, `lib/widgets/`, and `lib/screens/` directories
/// and generate `.jaspr.dart` files for each Flutter widget file.
library jet_builder;

export 'builder.dart';
