// Automated Flutter test reporter and GitHub Actions summary generator.
// Parses `flutter test --reporter json` output and outputs a detailed Markdown
// table containing passed, skipped (with reasons), and failed tests (with full
// error stack traces). Writes to GITHUB_STEP_SUMMARY and test_summary.md.
//
// Run: dart run tool/report_tests.dart

import 'dart:convert';
import 'dart:io';

class TestEntry {
  TestEntry({
    required this.id,
    required this.name,
    this.suitePath,
  });

  final int id;
  final String name;
  final String? suitePath;
  String? result;
  bool isSkipped = false;
  String? skipReason;
  final List<String> errors = [];
  final List<String> messages = [];
}

Future<void> main(List<String> args) async {
  final stopwatch = Stopwatch()..start();
  stdout.writeln('Running Flutter test suite with JSON reporter...');

  var flutterExe = 'flutter';
  if (Platform.isLinux || Platform.isMacOS) {
    if (File('/home/danish1075/flutter/bin/flutter').existsSync()) {
      flutterExe = '/home/danish1075/flutter/bin/flutter';
    }
  }

  final process = await Process.start(
    flutterExe,
    ['test', '--reporter', 'json', ...args],
    runInShell: true,
  );

  final suites = <int, String>{}; // suiteID -> path
  final tests = <int, TestEntry>{};
  final passed = <TestEntry>[];
  final failed = <TestEntry>[];
  final skipped = <TestEntry>[];

  final lineStream =
      process.stdout.transform(utf8.decoder).transform(const LineSplitter());

  await for (final line in lineStream) {
    if (line.trim().isEmpty) continue;
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      final type = json['type'] as String?;

      switch (type) {
        case 'suite':
          final suite = json['suite'] as Map<String, dynamic>?;
          if (suite != null) {
            final id = suite['id'] as int;
            final path = suite['path'] as String? ?? '';
            suites[id] = path;
          }
          break;

        case 'testStart':
          final t = json['test'] as Map<String, dynamic>?;
          if (t != null) {
            final id = t['id'] as int;
            final name = t['name'] as String? ?? 'Unnamed test';
            final suiteId = t['suiteID'] as int?;
            final path = suiteId != null ? suites[suiteId] : null;
            final entry = TestEntry(
              id: id,
              name: name,
              suitePath: path,
            );
            tests[id] = entry;
          }
          break;

        case 'error':
          final testId = json['testID'] as int?;
          if (testId != null && tests.containsKey(testId)) {
            final err = json['error'] as String? ?? '';
            final stack = json['stackTrace'] as String? ?? '';
            var fullError = err;
            if (stack.isNotEmpty) {
              fullError = '$err\n$stack';
            }
            tests[testId]!.errors.add(fullError);
          }
          break;

        case 'print':
          final testId = json['testID'] as int?;
          if (testId != null && tests.containsKey(testId)) {
            final msg = json['message'] as String? ?? '';
            tests[testId]!.messages.add(msg);
            if (msg.startsWith('Skip:')) {
              tests[testId]!.skipReason = msg.replaceFirst('Skip:', '').trim();
            }
          }
          break;

        case 'testDone':
          final testId = json['testID'] as int?;
          final hidden = json['hidden'] as bool? ?? false;
          if (hidden) continue;

          if (testId != null && tests.containsKey(testId)) {
            final entry = tests[testId]!;
            final res = json['result'] as String? ?? 'unknown';
            final isSkip = json['skipped'] as bool? ?? false;

            entry.result = res;
            entry.isSkipped = isSkip;

            // Ignore internal loading tests (like "loading test/...")
            if (entry.name.startsWith('loading ') && entry.suitePath != null) {
              continue;
            }

            if (isSkip) {
              skipped.add(entry);
              stdout.writeln('  [SKIPPED] ${entry.name}');
            } else if (res == 'success' && entry.errors.isEmpty) {
              passed.add(entry);
              stdout.writeln('  [PASSED] ${entry.name}');
            } else {
              failed.add(entry);
              stdout.writeln('  [FAILED] ${entry.name}');
            }
          }
          break;

        default:
          break;
      }
    } catch (_) {
      // Non-JSON line from flutter tool / compiler warnings
    }
  }

  final exitCode = await process.exitCode;
  stopwatch.stop();

  final totalCount = passed.length + failed.length + skipped.length;
  final durationSec = (stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1);

  // Build GitHub Markdown Summary
  final buf = StringBuffer();
  buf.writeln('## Flutter Test Suite Report\n');
  buf.writeln(
    failed.isEmpty
        ? '### All tests completed successfully in ${durationSec}s!'
        : '### ${failed.length} test(s) failed in ${durationSec}s',
  );
  buf.writeln();

  buf.writeln('| Metric | Count | Status |');
  buf.writeln('|:-------|:-----:|:------:|');
  buf.writeln('| **Total Tests** | `$totalCount` | Total |');
  buf.writeln('| **Passed** | `${passed.length}` | Passed |');
  final failStatus = failed.isEmpty ? '-' : 'Failed';
  buf.writeln('| **Failed** | `${failed.length}` | $failStatus |');
  final skipStatus = skipped.isEmpty ? '-' : 'Skipped';
  buf.writeln('| **Skipped** | `${skipped.length}` | $skipStatus |');
  buf.writeln();

  // Failed tests section with collapsible error stack traces
  if (failed.isNotEmpty) {
    buf.writeln('### Failed Tests (${failed.length})\n');
    for (final f in failed) {
      final location = f.suitePath != null ? '`(${f.suitePath})`' : '';
      buf.writeln('#### ${f.name} $location\n');
      if (f.errors.isNotEmpty) {
        buf.writeln('<details><summary>View Error & Stack Trace</summary>\n');
        buf.writeln('```');
        buf.writeln(f.errors.join('\n\n'));
        buf.writeln('```\n');
        buf.writeln('</details>\n');
      } else if (f.messages.isNotEmpty) {
        buf.writeln('<details><summary>Output Logs</summary>\n');
        buf.writeln('```');
        buf.writeln(f.messages.join('\n'));
        buf.writeln('```\n');
        buf.writeln('</details>\n');
      }
    }
  }

  // Skipped tests section
  if (skipped.isNotEmpty) {
    buf.writeln('### Skipped Tests (${skipped.length})\n');
    buf.writeln('| Test Name | Suite | Reason / Note |');
    buf.writeln('|:----------|:------|:--------------|');
    for (final s in skipped) {
      final file = s.suitePath != null ? '`${s.suitePath}`' : '-';
      final reason = s.skipReason ??
          (s.messages.isNotEmpty ? s.messages.first : 'Skipped');
      buf.writeln('| **${s.name}** | $file | $reason |');
    }
    buf.writeln();
  }

  // Passed tests collapsible list
  if (passed.isNotEmpty) {
    buf.writeln('### Passed Tests (${passed.length})\n');
    buf.writeln(
      '<details><summary>Click to expand all passed tests</summary>\n',
    );
    for (final p in passed) {
      final file = p.suitePath != null ? '`(${p.suitePath})`' : '';
      buf.writeln('- [x] **${p.name}** $file');
    }
    buf.writeln('\n</details>\n');
  }

  final report = buf.toString();

  // Save report to file for workflow steps or PR comments
  final reportFile = File('test_summary.md');
  await reportFile.writeAsString(report);
  stdout.writeln('\nSaved test report to test_summary.md');

  // Write to GitHub Actions step summary if running in CI
  final githubSummaryPath = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (githubSummaryPath != null && githubSummaryPath.isNotEmpty) {
    final summaryFile = File(githubSummaryPath);
    await summaryFile.writeAsString(report, mode: FileMode.append);
    stdout.writeln('Appended test report to GITHUB_STEP_SUMMARY');
  }

  if (failed.isNotEmpty || exitCode != 0) {
    stderr.writeln('\nTests failed! Exiting with code 1.');
    exit(1);
  } else {
    stdout.writeln('\nAll tests passed cleanly!');
    exit(0);
  }
}
