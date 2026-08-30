<!-- markdownlint-disable MD007 MD024 -->
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com), and this project adheres to [Semantic Versioning](https://semver.org).

## [Unreleased]

## [6.0.1] — 2026–08–30

### Fixed

- A changelog entry that merely mentions a heading, such as “`### Changed` now bumps the minor version”, no longer counts as that heading. Previously such an entry under `### Added` made the release a major one — which is how `6.0.0` came to be, with no breaking changes in it. Only a whole line reading `### Changed`, `### Added` or `### Fixed` decides the bump now.

## [6.0.0] — 2026–08–30

### Added

- pnpm workspaces are now supported. When `pnpm-workspace.yaml` lists packages, every non-private package with entries under `[Unreleased]` in its own `CHANGELOG.md` is released — with its own version bump, a `<name>@<version>` tag, its own npm publish and its own GitHub release — all in one commit. Packages whose `[Unreleased]` section is empty are left alone, and the workspace root is never released. The `[Unreleased]` link of a package changelog has to point at the `<name>@<version>` tag.
- Below `1.0.0`, `### Changed` now bumps the minor version instead of the major one, for stable releases and prereleases alike: breaking changes are expected during initial development and should not push the package out of the `0.x` range on their own.
- `release-first-major` branch has been added to cut `1.0.0`. It bumps to the first major version whatever the `[Unreleased]` headings say, and refuses to run once the package is at `1.0.0` or above. Its prereleases come from `release-first-major-<name>` (`1.0.0-<name>.0`, …) and `release-first-major-` (`1.0.0-0`, …), just like the prereleases of any other version.

### Fixed

- A changelog that cannot be rewritten no longer leaves a version commit and a tag behind: the version is now committed together with the changelog, so a failed rewrite takes the bump back and leaves the working tree as it was.
- A release from a dirty working tree is now refused up front, with a message saying so. Previously `pnpm version` refused it, less clearly, after the OTP had already been entered.

## [5.2.1] — 2026–08–25

### Fixed

- A local release now checks the npm session before it changes anything, and runs `pnpm login` when there is none. Previously an unauthenticated machine got as far as pushing the version commit, the tag and the release branch, and only then failed to publish — leaving the branch and the tag to be deleted by hand.

## [5.2.0] — 2026–08–16

### Added

- `--dry-run` flag (shorthand: `-n`) has been added. It walks through the whole release — branch check, version bump, changelog rewrite, npm tag and GitHub release notes — and reports what would happen without writing, pushing or publishing anything.

### Fixed

- `--version` now reports the version of `@firefoxic/release-it` itself. Previously it printed the version of the package you were about to release.
- `jq` is no longer required. It was an undeclared dependency, and the version is now read with `pnpm` instead.
- A `CHANGELOG.md` that cannot be rewritten is now reported as an error. Previously the script died silently at that point, leaving a temporary file behind.
- A rejected push of the release branch now stops the release. Previously the failure was ignored, so the package was published and a GitHub release was created for a commit that never reached the remote.
- The OTP is no longer echoed to the terminal while you type it.

## [5.1.0] — 2026–07–01

### Added

- `--version` flag (shorthand: `-v`) has been added to show the current version of `@firefoxic/release-it`.

### Fixed

- The protocol in the repository's metadata URL now meets current requirements.

## [5.0.0] — 2026–05–10

### Changed

- Support for `npm` has been removed. Only `pnpm@11+` is now supported.
- `node.js` now requires version `22.22.0` or later.

## [4.1.0] — 2026–02–03

### Added

- `@firefoxic/release-it` will now automatically update `npm` if its version is older than `11.5.1`, which is the minimum version required for trusted publishing. You can now remove the `npm` update command from your GitHub Action.

## [4.0.1] — 2026–01–24

### Fixed

- The package no longer requires `pnpm`. But `pnpm` is highly recommended 😉

## [4.0.0] — 2025–12–08

### Changed

- The package now uses [trusted publishing](https://docs.npmjs.com/trusted-publishers) instead of NPM tokens. You should remove the line with `NPM_TOKEN` from your release pipeline (and also remove the `NPM_TOKEN` from secrets of your repository) and add a line with `registry-url: 'https://registry.npmjs.org'` (see the changes to the `release.yaml` file as an example).

## [3.0.0] — 2025–09–24

### Changed

- The project has been renamed to `@firefoxic/release-it`.
- The launch command for local installation has been renamed to `release-it`.
- The tool now not only updates the changelog, but also performs all other steps before and after that are necessary to publish a new version of the package. This means that you need to remove the commands and logic for raising the version and publishing it from the pipeline and scripts.

### Added

- Pre-release versions are now possible, and their names are determined based on the branch name.
- Before updating the changelog, the package version is now raised according to the version type (still selected based on the changelog content) and possible pre-release status.
- The package with the new version is now built and published to npm with the appropriate authentication — `NPM_TOKEN` for CI or `OTP` for local execution.
- A release of the published version is now automatically created on GitHub.

## [2.0.2] — 2025–09–24

### Fixed

- URLs for links are now generated correctly.

## [2.0.1] — 2025–09–23

### Fixed

- The description in the README.md file has now been corrected.

## [2.0.0] — 2025–09–23

### Changed

- The `update-changelog` command should now be called not in the `version` script of the package.json file, but immediately after the `pnpm version <release_type>` command.

### Added

- The project has been rewritten in `bash` and now does not depend on node.js or npm packages.

## [1.0.0] — 2024–10–30

### Changed

- The minimum required `node.js` version has been increased to `20.12.0`, except for version `21`.

## [0.2.1] — 2024–09–25

### Fixed

- The _space_ before the dash in the version heading is now _non-breaking_. This hardly affects anything, but for consistency of typography it should be like this everywhere.

## [0.2.0] — 2024–07–30

### Added

- The `update-changelog` utility now automatically stages `CHANGELOG.md` in git. You can remove `&& git add CHANGELOG.md` from your `version` hook and leave only `update-changelog` in it.

## [0.1.0] — 2024–05–09

### Added

- The basic functionality of the `update-changelog` CLI utility.

[Unreleased]: https://github.com/firefoxic/release-it/compare/v6.0.1...HEAD
[6.0.1]: https://github.com/firefoxic/release-it/compare/v6.0.0...v6.0.1
[6.0.0]: https://github.com/firefoxic/release-it/compare/v5.2.1...v6.0.0
[5.2.1]: https://github.com/firefoxic/release-it/compare/v5.2.0...v5.2.1
[5.2.0]: https://github.com/firefoxic/release-it/compare/v5.1.0...v5.2.0
[5.1.0]: https://github.com/firefoxic/release-it/compare/v5.0.0...v5.1.0
[5.0.0]: https://github.com/firefoxic/release-it/compare/v4.1.0...v5.0.0
[4.1.0]: https://github.com/firefoxic/release-it/compare/v4.0.1...v4.1.0
[4.0.1]: https://github.com/firefoxic/release-it/compare/v4.0.0...v4.0.1
[4.0.0]: https://github.com/firefoxic/release-it/compare/v3.0.0...v4.0.0
[3.0.0]: https://github.com/firefoxic/release-it/compare/v2.0.2...v3.0.0
[2.0.2]: https://github.com/firefoxic/release-it/compare/v2.0.1...v2.0.2
[2.0.1]: https://github.com/firefoxic/release-it/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/firefoxic/release-it/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/firefoxic/release-it/compare/v0.2.1...v1.0.0
[0.2.1]: https://github.com/firefoxic/release-it/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/firefoxic/release-it/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/firefoxic/release-it/releases/tag/v0.1.0
