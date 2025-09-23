<!-- markdownlint-disable MD007 MD024 -->
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com), and this project adheres to [Semantic Versioning](https://semver.org).

## [Unreleased]

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

- The basic functionality of the `update-changelog` CLI utility.

[Unreleased]: https://github.com/firefoxic/update-changelog/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/firefoxic/update-changelog/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/firefoxic/update-changelog/compare/v0.2.1...v1.0.0
[0.2.1]: https://github.com/firefoxic/update-changelog/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/firefoxic/update-changelog/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/firefoxic/update-changelog/releases/tag/v0.1.0
