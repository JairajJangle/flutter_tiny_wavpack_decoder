// Automated release helper. Runs in CI (see .github/workflows/release.yml) on
// every push to main.
//
// It reads the conventional commits since the last vX.Y.Z tag, decides the
// semantic-version bump, and (if a release is warranted) updates the version
// in pubspec.yaml and prepends a section to CHANGELOG.md. It then prints one of:
//
//   RELEASE=none        (nothing to release)
//   RELEASE=1.2.3       (release this version)
//
// The workflow reads that line and, on a real version, commits the changes,
// tags vX.Y.Z, and pushes. Pure dart:io, no package imports, so it runs with a
// plain `dart run tool/release.dart`.
//
// Bump rules (Conventional Commits):
//   BREAKING CHANGE / type! -> major
//   feat                    -> minor
//   fix, perf               -> patch
//   everything else         -> no release
import 'dart:io';

const _rs = '\x1e'; // record separator
const _us = '\x1f'; // unit separator

String _git(List<String> args) {
  final result = Process.runSync('git', args);
  if (result.exitCode != 0) {
    stderr.writeln('git ${args.join(' ')} failed:\n${result.stderr}');
    exit(1);
  }
  return (result.stdout as String).trim();
}

void main() {
  // Most recent release tag, if any.
  final describe = Process.runSync('git', [
    'describe',
    '--tags',
    '--abbrev=0',
    '--match',
    'v*',
  ]);
  final lastTag = describe.exitCode == 0
      ? (describe.stdout as String).trim()
      : '';

  final range = lastTag.isEmpty ? 'HEAD' : '$lastTag..HEAD';
  final log = _git([
    'log',
    range,
    '--no-merges',
    '--format=%h$_us%s$_us%b$_rs',
  ]);

  final features = <String>[];
  final fixes = <String>[];
  final breaking = <String>[];
  var bump = 0; // 0 none, 1 patch, 2 minor, 3 major

  final header = RegExp(r'^(\w+)(\([^)]*\))?(!)?:\s*(.+)$');
  for (final record in log.split(_rs)) {
    final trimmed = record.trim();
    if (trimmed.isEmpty) continue;
    final fields = trimmed.split(_us);
    final sha = fields[0];
    final subject = fields.length > 1 ? fields[1] : '';
    final body = fields.length > 2 ? fields[2] : '';

    final match = header.firstMatch(subject);
    if (match == null) continue;
    final type = match.group(1)!;
    final isBreaking =
        match.group(3) != null || body.contains('BREAKING CHANGE');
    final description = match.group(4)!;

    if (isBreaking) {
      breaking.add('$description ($sha)');
      if (bump < 3) bump = 3;
    }
    if (type == 'feat') {
      features.add('$description ($sha)');
      if (bump < 2) bump = 2;
    } else if (type == 'fix' || type == 'perf') {
      fixes.add('$description ($sha)');
      if (bump < 1) bump = 1;
    }
  }

  if (bump == 0) {
    stdout.writeln('RELEASE=none');
    return;
  }

  // Next version is computed from the last release tag, not pubspec, so it is
  // always greater than every existing tag even if pubspec lags behind.
  final pubspec = File('pubspec.yaml');
  final pubspecLines = pubspec.readAsLinesSync();
  final versionIndex = pubspecLines.indexWhere((l) => l.startsWith('version:'));
  final baseVersion = lastTag.isEmpty
      ? pubspecLines[versionIndex].substring('version:'.length).trim()
      : lastTag.replaceFirst('v', '');
  final numbers = baseVersion
      .split('+')
      .first
      .split('.')
      .map(int.parse)
      .toList();
  var major = numbers[0];
  var minor = numbers[1];
  var patch = numbers[2];
  if (bump == 3) {
    major++;
    minor = 0;
    patch = 0;
  } else if (bump == 2) {
    minor++;
    patch = 0;
  } else {
    patch++;
  }
  final next = '$major.$minor.$patch';

  pubspecLines[versionIndex] = 'version: $next';
  pubspec.writeAsStringSync('${pubspecLines.join('\n')}\n');

  // Prepend a CHANGELOG section under "## [Unreleased]".
  final now = DateTime.now().toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  final date = '${now.year}-${two(now.month)}-${two(now.day)}';

  final section = StringBuffer('## [$next] - $date\n');
  void group(String title, List<String> items) {
    if (items.isEmpty) return;
    section.writeln('\n### $title\n');
    for (final item in items) {
      section.writeln('- $item');
    }
  }

  group('BREAKING CHANGES', breaking);
  group('Features', features);
  group('Bug Fixes', fixes);

  final changelog = File('CHANGELOG.md');
  final content = changelog.readAsStringSync();
  const marker = '## [Unreleased]';
  final markerEnd = content.indexOf(marker) + marker.length;
  final updated =
      '${content.substring(0, markerEnd)}\n\n'
      '${section.toString().trimRight()}\n'
      '${content.substring(markerEnd)}';
  changelog.writeAsStringSync(updated);

  stdout.writeln('RELEASE=$next');
}
