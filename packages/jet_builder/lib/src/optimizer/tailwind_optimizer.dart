import 'tailwind_dictionary.dart';

/// The Step 2 Optimizer that converts raw inline CSS into Tailwind classes.
class TailwindOptimizer {
  /// Scans the raw Jaspr code emitted by Step 1 for [Styles.raw('...')] patterns.
  /// It parses the raw CSS, maps it to Tailwind classes, and injects them.
  String optimize(String rawJasprCode) {
    // Regex to find: styles: Styles.raw('...')
    // Assumes Step 1 emits raw CSS exactly like this.
    final regex = RegExp(r"styles:\s*Styles\.raw\('([^']+)'\)");
    
    return rawJasprCode.replaceAllMapped(regex, (match) {
      final rawCss = match.group(1) ?? '';
      
      // Split by semicolon to get individual rules
      final rules = rawCss.split(';');
      
      final tailwindClasses = <String>[];
      final unmappedRules = <String>[];
      
      for (var rule in rules) {
        final trimmed = rule.trim();
        if (trimmed.isEmpty) continue;
        
        // Lookup in our dictionary
        final tailwind = tailwindDictionary[trimmed];
        if (tailwind != null) {
          tailwindClasses.add(tailwind);
        } else {
          // If we don't have a map for it, keep it as raw CSS so we don't break the layout!
          unmappedRules.add(trimmed);
        }
      }
      
      // Rebuild the component arguments
      final parts = <String>[];
      
      if (tailwindClasses.isNotEmpty) {
        parts.add("classes: '${tailwindClasses.join(' ')}'");
      }
      
      if (unmappedRules.isNotEmpty) {
        parts.add("styles: Styles.raw('${unmappedRules.join('; ')};')");
      }
      
      // If we stripped out styles entirely, but there are other properties in the component,
      // returning empty string might leave a dangling comma.
      // But since we replace exactly "styles: Styles.raw(...)", returning "classes: '...'" is perfectly syntactically sound!
      return parts.join(', ');
    });
  }
}
