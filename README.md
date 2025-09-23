# @firefoxic/update-changelog

[![License: MIT][license-image]][license-url]
[![Changelog][changelog-image]][changelog-url]
[![NPM version][npm-image]][npm-url]
[![Test Status][test-image]][test-url]

CLI utility for automatic update of `CHANGELOG.md`.

## Purpose

Increasing the version of a package usually requires creating a commit (extra for history) with a message something like `Prepare release`. This commit should manually add a header to `CHANGELOG.md` with the new version and the release date, and change the links to the comparison at the bottom of the file.

The `update-changelog` utility gets rid of this chore, random typos, and an unnecessary commit.

## Installation

```shell
pnpm add -D @firefoxic/update-changelog
```

## Usage

When creating a new version, simply do not create the `Prepare release` commit. Just run `update-changelog` directly after the `pnpm version <release_type>` command.

You can use it in your CI pipeline. See the [`release.yaml`](https://github.com/firefoxic/update-changelog/blob/main/.github/workflows/release.yaml) file for an example.

## Some restrictions

The `update-changelog` expects the following:

- The name of the changelog file is `CHANGELOG.md`.
- The format of the changelog is consistent with [Keep a changelog](https://keepachangelog.com).
- Descriptions of all user-important changes are already in the changelog under the heading `[Unreleased]`. Ideally, you should commit them along with the changes themselves.
- If this is the first release of a package, there should be only one reference for [Unreleased] at the end of the changelog in the following format for correct reference updating:

	```md
	[Unreleased]: https://github.com/<user-name>/<project-name>/compare/v0.0.1...HEAD
	```

	**Example:** [the state of this project's changelog](https://github.com/firefoxic/update-changelog/commit/37b9102f8673fedae2cdeaf9e44f027360617cea#diff-06572a96a58dc510037d5efa622f9bec8519bc1beab13c9f251e97e657a9d4edR7-R14) before the first release.

[license-url]: https://github.com/firefoxic/update-changelog/blob/main/LICENSE.md
[license-image]: https://img.shields.io/badge/License-MIT-limegreen.svg

[changelog-url]: https://github.com/firefoxic/update-changelog/blob/main/CHANGELOG.md
[changelog-image]: https://img.shields.io/badge/CHANGELOG-md-limegreen

[npm-url]: https://npmjs.com/package/@firefoxic/update-changelog
[npm-image]: https://badge.fury.io/js/@firefoxic%2Fupdate-changelog.svg

[test-url]: https://github.com/firefoxic/update-changelog/actions
[test-image]: https://github.com/firefoxic/update-changelog/actions/workflows/test.yml/badge.svg?branch=main
