<!-- markdownlint-disable MD007 MD024 -->
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com), and this project adheres to [Semantic Versioning](https://semver.org).

## [Unreleased]

### Added

- The `update-changelog` utility now automatically stages `CHANGELOG.md` in git. You can remove `&& git add CHANGELOG.md` from your `version` hook and leave only `update-changelog` in it.

## [0.1.0] — 2024–05–09

### Added

- The basic functionality of the `update-changelog` CLI utility.

[Unreleased]: https://github.com/firefoxic/update-changelog/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/firefoxic/update-changelog/releases/tag/v0.1.0
