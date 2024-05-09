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

## Configuration

In the `scripts` section of your `package.json`, add a `version` hook that will run when `pnpm version patch` (or `minor`, or `major`) is executed after updating the version in `package.json`, but before creating the commit.

```json
{
	"scripts": {
		"version": "update-changelog && git add CHANGELOG.md".
	},
}
```

Optionally, other hooks can be added to conveniently automate package publishing (see `package.json` of this project for an example).

## Some restrictions

The `update-changelog` expects the following:

- The name of the changelog file is `CHANGELOG.md`.
- The format of the changelog is consistent with [Keep a changelog](https://keepachangelog.com).
- Descriptions of all user-important changes are already in the changelog under the heading `[Unreleased]`. Ideally, you should commit them along with the changes themselves.
- If this is the first release of a package, there should be only one reference for [Unreleased] at the end of the changelog in the following format for correct reference updating:

	```md
	[Unreleased]: https://github.com/<user-name>/<project-name>/compare/v0.0.1...HEAD
	```

## Usage

When publishing a new version, simply do not create the `Prepare release` commit. Running `pnpm version patch` (or `minor`, or `major`) will now do everything for you 🥳

[license-url]: https://github.com/firefoxic/update-changelog/blob/main/LICENSE.md
[license-image]: https://img.shields.io/badge/License-MIT-limegreen.svg

[changelog-url]: https://github.com/firefoxic/update-changelog/blob/main/CHANGELOG.md
[changelog-image]: https://img.shields.io/badge/CHANGELOG-md-limegreen

[npm-url]: https://npmjs.com/package/@firefoxic/update-changelog
[npm-image]: https://badge.fury.io/js/@firefoxic%2Fupdate-changelog.svg

[test-url]: https://github.com/firefoxic/update-changelog/actions
[test-image]: https://github.com/firefoxic/update-changelog/actions/workflows/test.yml/badge.svg?branch=main
