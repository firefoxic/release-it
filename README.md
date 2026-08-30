# @firefoxic/release-it

[![License: MIT][license-image]][license-url]
[![Changelog][changelog-image]][changelog-url]
[![Test Status][test-image]][test-url]

A powerful release script that automates the entire release process including updating changelog, npm publishing (using `pnpm`) and GitHub releases.

## Purpose

Publishing a new version of a package is a routine sequence of several steps involving running commands, editing files, entering passwords, copying text to GitHub, and so on. It's easy to make a mistake at any stage, especially when editing CHANGELOG.md. Do it all with a single command or push to the release branch.

### Usage

- In GitHub CI

	1. Create a release action. See the [`release.yaml`](https://github.com/firefoxic/release-it/blob/main/.github/workflows/release.yaml) file for an example, where important points are described in the comments.
	2. In the settings of your package on <https://npmjs.com>, enable [trusted publishing](https://docs.npmjs.com/trusted-publishers) (if you haven't already).
	3. Push the branch named starting with `release` (see below) to GitHub.

- Locally

	1. On the branch with a name starting with `release` (see below), just run:

		```shell
		pnpm dlx @firefoxic/release-it
		# or
		# pnx @firefoxic/release-it
		```

	2. If the machine has no npm session, the script runs `pnpm login` before it touches
		the repository, so a login that fails leaves nothing to clean up.
	3. And enter OTP.

- Preview

	To check what a release would do — which version it picks, how `CHANGELOG.md` would change, under which npm tag it would publish — without changing anything:

	```shell
	pnpm dlx @firefoxic/release-it --dry-run
	```

### Requirements

- [**pnpm**](https://pnpm.io/installation#on-posix-systems)
- [Node.js](https://nodejs.org) (you can install it using [pnpm](https://pnpm.io/cli/runtime))
- Git repository with GitHub remote
- [**GitHub CLI (gh)**](https://cli.github.com) for locally using

	```shell
	# First time setup — authenticate with GitHub
	gh auth login
	```

#### Branch-based Release Types

The release script uses branch names to determine the release type:

- **`release`** → Stable release (e.g., `1.1.0`)
- **`release-first-major`** → The first major release, `1.0.0` (see below)
- **`release-first-major-rc`** → A prerelease of it (e.g., `1.0.0-rc.1`); `release-first-major-` → a numbered one (e.g., `1.0.0-1`)
- **`release-alpha`** → Alpha prerelease (e.g., `1.0.0-alpha.1`)
- **`release-beta`** → Beta prerelease (e.g., `1.0.0-beta.1`)
- **`release-rc`** → Release candidate (e.g., `1.0.0-rc.1`)
- **`release-`** → Numbered prerelease (e.g., `1.0.0-1`)

#### Version Detection

The script automatically determines the version bump based on changelog content:

- **`### Changed`** → Major version (breaking changes)
- **`### Added`** → Minor version (new features)
- **`### Fixed`** → Patch version (bug fixes)

These three are the only headings the script recognises; any other one stops the release. That narrowing is deliberate — three headings map one to one onto the three parts of a semantic version, so nothing is left to interpretation. The remaining [Keep a Changelog](https://keepachangelog.com) headings fold into them:

- **`Removed`** → **`Changed`**. Taking functionality away is a change, and a breaking one.
- **`Security`** → **`Fixed`**. Closing a vulnerability is a bug fix.
- **`Deprecated`** → **`Changed`**. Semantic Versioning treats a deprecation as a minor change, but deprecation messages often force a change to an established workflow, and that is a major change by nature.

#### Before 1.0.0

While the package is below `1.0.0`, **`### Changed`** bumps the minor version, not the major one: `0.4.2` → `0.5.0`. Semantic Versioning reserves `0.y.z` for initial development, where anything may change at any time, so a breaking change there is expected and is not a reason to leave the range. The same cap applies to prereleases (`0.5.0-beta.0`, not `1.0.0-beta.0`).

Reaching `1.0.0` is a deliberate decision, so it is made with a branch rather than a heading. Release from **`release-first-major`** and the version becomes `1.0.0` regardless of which headings the `[Unreleased]` section carries — it still has to be non-empty, since it becomes the release notes. The branch works only once: with the package already at `1.0.0` or above it refuses to run, and `release` takes over from there.

The first major can be tried out first: `release-first-major-<name>` publishes `1.0.0-<name>.0`, `1.0.0-<name>.1`, … under the `<name>` dist-tag, and `release-first-major-` publishes `1.0.0-0`, `1.0.0-1`, … under `next` — exactly as `release-<name>` and `release-` do for any other version. Once such a prerelease is out, `release-first-major` turns it into `1.0.0`.

#### Authentication

- **CI/CD**: Uses NPM trusted publishing
- **Local**: Checks the npm session up front, runs `pnpm login` when there is none, and only then asks for an OTP — all before the version commit, the tag and the branch exist
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

[test-url]: https://github.com/firefoxic/release-it/actions
[test-image]: https://github.com/firefoxic/release-it/actions/workflows/test.yaml/badge.svg?branch=main
