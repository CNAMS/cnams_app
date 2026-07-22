// NFR-16 guard: fail the build if a user-facing string is hardcoded instead of
// coming from AppLocalizations.
//
// This is deliberately a lightweight lexical check, not a full AST pass: it
// flags string literals handed straight to Text(...) in lib/, which is where
// the mistake actually happens. Strings that legitimately aren't UI copy
// (keys, debug text, asset paths) can opt out with an `// i18n-ignore` comment
// on the same line.
//
// Run: dart run tool/check_hardcoded_strings.dart
// See docs/PRODUCTION_ROADMAP.md — Phase P0.

import 'dart:io';

/// Matches Text('literal') or Text("literal") with a non-trivial literal.
final _textLiteral = RegExp(r'''\bText\(\s*(['"])(.*?)\1''');

void main() {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    stderr.writeln('No lib/ directory found; run from the project root.');
    exit(2);
  }

  final violations = <String>[];

  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    // Skip generated code.
    if (entity.path.endsWith('.g.dart') ||
        entity.path.contains('/generated/')) {
      continue;
    }

    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains('// i18n-ignore')) continue;

      for (final match in _textLiteral.allMatches(line)) {
        final literal = match.group(2) ?? '';
        // Ignore empty and interpolation-only strings; the concern is real copy.
        if (literal.trim().isEmpty) continue;
        violations.add('${entity.path}:${i + 1}: Text("$literal")');
      }
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('OK: no hardcoded user-facing strings found.');
    return;
  }

  stderr.writeln('NFR-16: hardcoded user-facing strings found.');
  stderr.writeln('Move these into lib/core/l10n/hi.arb (and en.arb), or add '
      '`// i18n-ignore` if the string is genuinely not UI copy.\n');
  for (final v in violations) {
    stderr.writeln('  $v');
  }
  exit(1);
}
