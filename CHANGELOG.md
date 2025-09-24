<!-- markdownlint-disable MD007 MD024 -->
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com), and this project adheres to [Semantic Versioning](https://semver.org).

## [Unreleased]

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

[Unreleased]: https://github.com/firefoxic/release-it/compare/v3.0.0...HEAD
[3.0.0]: https://github.com/firefoxic/release-it/compare/v2.0.2...v3.0.0
[2.0.2]: https://github.com/firefoxic/release-it/compare/v2.0.1...v2.0.2
[2.0.1]: https://github.com/firefoxic/release-it/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/firefoxic/release-it/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/firefoxic/release-it/compare/v0.2.1...v1.0.0
[0.2.1]: https://github.com/firefoxic/release-it/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/firefoxic/release-it/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/firefoxic/release-it/releases/tag/v0.1.0
