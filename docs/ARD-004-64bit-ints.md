# AST Type Mapping Plan: 64-bit Integers

## The Problem
When Dart is compiled to JavaScript (`dart2js`), the Dart `int` type is mapped to a JavaScript `Number` (IEEE 754 double-precision float). This means integers lose precision if they exceed 53 bits (e.g., values > `9,007,199,254,740,991`). 

For modern apps using 64-bit Snowflake IDs (e.g., Postgres primary keys, Discord/Twitter IDs), passing these IDs to the web frontend results in data corruption and broken routing.


## SEO and Client-Side Hydration
It is critical to distinguish between **Server-Side Rendering (SSR)** and **Client-Side Hydration**.

Because JET transpiles Flutter into Jaspr, the resulting web application utilizes SSR. When a search engine crawler visits the page, the Jaspr server (running native Dart) generates pure HTML/CSS. **On the server, Dart natively supports 64-bit integers without precision loss.** 

Therefore, **SEO is 100% unaffected by the 64-bit integer limitation**. Search engines will always see the perfect HTML with the correct 64-bit IDs embedded. 

The strategies below apply **exclusively to client-side hydration**—when a real user's browser executes compiled web code (dart2js or dart2wasm) to make the page interactive. JET provides two options to support all developer needs:

## Strategy 1: The Modern Default (Wasm)
Dart and Jaspr now support **WebAssembly (`dart2wasm`)**. In WebAssembly, Dart's `int` is compiled to a true 64-bit integer. 
- **Plan:** Strongly recommend and default the Jaspr pipeline to target `dart2wasm`. If Wasm is used, no AST type mapping is needed, and performance is maximized.

## Strategy 2: AST Rewriting (For `dart2js` Environments)
For environments where `dart2js` is required (e.g., heavy JS interop or legacy browser support), JET can perform **Shadow Model Transpilation**.

### 1. The `@WebSafe` Annotation
We introduce an annotation in `jet_annotations`:
```dart
import 'package:jet_annotations/jet_annotations.dart';

class User {
  @WebSafe(type: WebType.string)
  final int id;
  
  final String name;
}
```

### 2. IR Model Rewriting
Currently, JET only transpiles UI files. We would expand the `FlutterAstParser` to process data models. During transpilation to the `.jet_cache`, the AST Visitor will intercept the `@WebSafe` annotation and rewrite the variable type for the Jaspr output:
```dart
// Transpiled for Jaspr (.jet_cache)
class User {
  final String id;
  
  final String name;
}
```

### 3. JSON Serialization Auto-Patching
Changing the type breaks serialization. The `jaspr_emitter` must intercept `fromJson` and `toJson` methods to inject casting logic.
**Original (Flutter):**
```dart
factory User.fromJson(Map<String, dynamic> json) => User(
  id: json['id'] as int,
);
```
**Transpiled (Jaspr):**
```dart
factory User.fromJson(Map<String, dynamic> json) => User(
  id: json['id'].toString(), // Safely parse the 64-bit JSON number/string as String
);
```

### 4. Linter Guard (P-005)
We add a new rule to the `PoisonSniffer`: **P-005 (Unsafe Web Integer)**.
The sniffer will flag any `int` property named `id`, `snowflake`, `uid`, etc., in the Flutter project and warn: 
> "Potential 64-bit integer truncation in dart2js. Annotate with @WebSafe(type: WebType.string) or ensure the project targets dart2wasm."
