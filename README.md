# @firefoxic/release-it

[![License: MIT][license-image]][license-url]
[![Changelog][changelog-image]][changelog-url]
[![NPM version][npm-image]][npm-url]

A powerful release script that automates the entire release process including updating changelog, npm publishing and GitHub releases.

## Purpose

Publishing a new version of a package is a routine sequence of several steps involving running commands, editing files, entering passwords, copying text to GitHub, and so on. It's easy to make a mistake at any stage, especially when editing CHANGELOG.md. Do it all with a single command or push to the release branch.

### Usage

Locally just run:

```shell
pnpm dlx @firefoxic/release-it
```

and enter OTP.

Or add running with two secret tokens in your CI pipeline:

```yaml
- run: pnpm dlx @firefoxic/release-it
  env:
    NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

See [`release.yaml`](https://github.com/firefoxic/release-it/blob/main/.github/workflows/release.yaml) file as an example.

### Requirements

- Node.js and pnpm
- Git repository with GitHub remote
- [**GitHub CLI (gh)**](https://cli.github.com) for locally using

	```shell
	# First time setup — authenticate with GitHub
	gh auth login
	```

#### Branch-based Release Types

The release script uses branch names to determine the release type:

- **`release`** → Stable release (e.g., `1.0.0`)
- **`release-alpha`** → Alpha prerelease (e.g., `1.0.0-alpha.1`)
- **`release-beta`** → Beta prerelease (e.g., `1.0.0-beta.1`)
- **`release-rc`** → Release candidate (e.g., `1.0.0-rc.1`)
- **`release-`** → Numbered prerelease (e.g., `1.0.0-1`)

#### Version Detection

The script automatically determines the version bump based on changelog content:

- **`### Changed`** → Major version (breaking changes)
- **`### Added`** → Minor version (new features)
- **`### Fixed`** → Patch version (bug fixes)

#### Authentication

- **CI/CD**: Uses `NPM_TOKEN` environment variable automatically
- **Local**: Interactive OTP prompt or `--otp` flag
- **GitHub**: Requires `gh auth login` or `GITHUB_TOKEN` environment variable

#### Changelog restrictions

- The name of the changelog file is `CHANGELOG.md`.
- The format of the changelog is consistent with [Keep a changelog](https://keepachangelog.com).
- Descriptions of all user-important changes are already in the changelog under the heading `[Unreleased]`. Ideally, you should commit them along with the changes themselves.
- If this is the first release of a package, there should be only one reference for [Unreleased] at the end of the changelog in the following format for correct reference updating:

	```md
	[Unreleased]: https://github.com/<user-name>/<project-name>/compare/v0.0.1...HEAD
	```

[license-url]: https://github.com/firefoxic/release-it/blob/main/LICENSE.md
[license-image]: https://img.shields.io/badge/License-MIT-limegreen.svg

[changelog-url]: https://github.com/firefoxic/release-it/blob/main/CHANGELOG.md
[changelog-image]: https://img.shields.io/badge/CHANGELOG-md-limegreen

[npm-url]: https://npmjs.com/package/@firefoxic/release-it
[npm-image]: https://badge.fury.io/js/@firefoxic%2Frelease-it.svg
