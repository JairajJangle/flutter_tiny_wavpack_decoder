// Semantic-release configuration for the Flutter package.
//
// Mirrors the react-native-tiny-wavpack-decoder setup: conventional commits on
// `main` drive the version bump, changelog, git tag, and GitHub release. The
// difference is the target manifest: instead of the npm plugin bumping
// package.json, @semantic-release/exec writes the computed version into
// pubspec.yaml, and the pushed `v{version}` tag triggers publish.yml, which
// runs `dart pub publish` against pub.dev over OIDC.
//
// Commit types and the bump they cause (Angular convention):
//   fix:            -> patch (1.0.0 -> 1.0.1)
//   feat:           -> minor (1.0.0 -> 1.1.0)
//   feat!/fix!/     -> major (1.0.0 -> 2.0.0)
//   BREAKING CHANGE:
// Other types (docs, chore, refactor, test, ci, build, style) do not release.
module.exports = {
  branches: [
    'main',
    {
      name: 'beta',
      prerelease: true, // Marks this as a prerelease channel.
    },
  ],
  plugins: [
    '@semantic-release/commit-analyzer', // Analyzes commits for the version bump.
    '@semantic-release/release-notes-generator', // Generates release notes.
    '@semantic-release/changelog', // Updates CHANGELOG.md.
    [
      // Writes the computed version into pubspec.yaml before the changelog is
      // committed. Only the top-level `version:` key is touched.
      '@semantic-release/exec',
      {
        prepareCmd:
          "sed -i 's/^version: .*/version: ${nextRelease.version}/' pubspec.yaml",
      },
    ],
    '@semantic-release/github', // Creates the GitHub release and the v{version} tag.
    [
      '@semantic-release/git',
      {
        assets: ['pubspec.yaml', 'CHANGELOG.md'],
        message:
          'chore(release): ${nextRelease.version} [skip ci]\n\n${nextRelease.notes}',
      },
    ],
  ],
};
