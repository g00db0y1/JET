# jet_cli

Unified command-line interface for the [JET (Jaspr Engine Transpiler)](https://github.com/g00db0y1/JET) ecosystem.

## Commands

```bash
# Set up JET in a Flutter project
jet init

# Transpile the entire project once via the 3-step .jet_cache pipeline
jet build

# Continuous generation — watch source files and re-transpile on save
jet build --watch
# (or: jet build -w / jet watch)

# Single-file transpilation via -t / --target flag (or positional argument)
jet build -t lib/ui/home.dart
jet build lib/ui/home.dart

# Watch a single target file continuously
jet build -w -t lib/ui/home.dart

# Preview transpiled Jaspr code directly in the terminal
jet preview lib/ui/home.dart

# Run the Sniffer Fleet architectural linter
jet lint

# Clean .jet_cache and generated .jaspr.dart files
jet clean
```

