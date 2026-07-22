// Architecture guardrails, checked by reading imports off disk.
//
// Two rules the whole codebase depends on (see docs/PRODUCTION_ROADMAP.md):
//   1. core/ must not depend on features/ — dependencies point one way.
//   2. core/zscore/ must not import Flutter — the engine stays pure Dart so it
//      can be tested headlessly and diffed against the WHO reference.
//
// A plain unit test (no Flutter binding) so it runs anywhere, including a
// machine without the Flutter test engine.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Package or relative import lines, e.g. import 'package:foo/bar.dart';
final _import = RegExp('''^\\s*import\\s+['"]([^'"]+)['"]''');

Iterable<File> _dartFilesUnder(String path) sync* {
  final dir = Directory(path);
  if (!dir.existsSync()) return;
  for (final e in dir.listSync(recursive: true)) {
    if (e is File &&
        e.path.endsWith('.dart') &&
        !e.path.endsWith('.g.dart') &&
        !e.path.contains('/generated/')) {
      yield e;
    }
  }
}

List<String> _importsOf(File f) {
  return f
      .readAsLinesSync()
      .map((l) => _import.firstMatch(l)?.group(1))
      .whereType<String>()
      .toList();
}

void main() {
  test('core/ does not depend on features/', () {
    final offenders = <String>[];
    for (final file in _dartFilesUnder('lib/core')) {
      for (final imp in _importsOf(file)) {
        if (imp.contains('package:cgms_app/features/') ||
            imp.contains('/features/')) {
          offenders.add('${file.path} -> $imp');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'core must not import features:\n${offenders.join('\n')}',
    );
  });

  test('core/zscore/ does not import Flutter', () {
    final offenders = <String>[];
    for (final file in _dartFilesUnder('lib/core/zscore')) {
      for (final imp in _importsOf(file)) {
        if (imp.startsWith('package:flutter/') ||
            imp.startsWith('package:flutter_')) {
          offenders.add('${file.path} -> $imp');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'the z-score engine must stay pure Dart:\n'
          '${offenders.join('\n')}',
    );
  });
}
