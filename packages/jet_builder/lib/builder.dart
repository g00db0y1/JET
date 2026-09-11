import 'package:build/build.dart';
import 'src/jet_builder_impl.dart';

/// Factory function registered in `build.yaml`.
///
/// This is the entry point called by `build_runner` when it processes
/// a Flutter `.dart` file matching the configured `generate_for` patterns.
Builder jetBuilder(BuilderOptions options) => JetBuilderImpl(options);
