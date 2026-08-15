# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A single self-contained Bash script ([release-it.sh](release-it.sh)) published to npm as `@firefoxic/release-it` and exposed via the `bin` field as `release-it`. There is no build step, no source-to-dist transform, no dependencies, and no test suite — `package.json` has `"exports": null`, `"files": []`, and empty `devDependencies`. Editing the script *is* editing the product.

The repo is self-hosting: it releases itself with its own script via [.github/workflows/release.yaml](.github/workflows/release.yaml), which runs `./release-it.sh` directly (consumers are told to run `pnx @firefoxic/release-it` instead).

## Commands

```shell
./release-it.sh --help      # -h — usage text
./release-it.sh --version   # -v — reads .version from package.json via jq
./release-it.sh             # full release; refuses to run outside a release* branch
```

There is no lint/test/build command. Verify changes by reading the script and, if needed, exercising individual functions in a throwaway git repo — running `main` end to end publishes to npm and GitHub for real.

## Release pipeline architecture

`main` runs seven functions in a fixed order ([release-it.sh:266-272](release-it.sh#L266-L272)); each depends on globals set by earlier ones (`CURRENT_BRANCH`, `RELEASE_TYPE`, `PRERELEASE_SUFFIX`, `RELEASE_DESCRIPTION`, `VERSION_TYPE`, `TAG_NAME`, `PRERELEASE_FLAG`, declared at the top of the file). Reordering the calls breaks the script.

1. **`validate_release_branch`** — the branch name is the only input for release type: `release` → stable, `release-` → unnamed prerelease, `release-<suffix>` → named prerelease with `PRERELEASE_SUFFIX=<suffix>`. Anything else is a hard error.
2. **`setup_authentication`** — `CI=true` configures a bot git identity and relies on npm trusted publishing; otherwise it prompts for an OTP.
3. **`detect_version_type`** — parses the `## [Unreleased]` section of `CHANGELOG.md` with awk. Heading present in it decides the bump, checked in this precedence order: `### Changed` → major, `### Added` → minor, `### Fixed` → patch. The extracted text is reused verbatim as the GitHub release notes.
4. **`create_version`** — calls `pnpm version`, which makes a commit *and* a tag. Bump keyword depends on whether the current version already carries a matching prerelease suffix (`prerelease` to increment, `pre<type>` to start a new track).
5. **`update-changelog`** — the subtle part. It deletes the tag `pnpm version` just created, rewrites `CHANGELOG.md` (inserts a `## [<version>] — <date>` heading below `## [Unreleased]` and rewrites the `[Unreleased]:` compare link, deriving `base_url` and the previous version from that link), then `git commit --amend`s the version commit, re-creates the tag on the amended commit, and force-pushes the tag if the remote already has it. So the version commit and the changelog edit end up as one commit. The awk program hard-fails if the `[Unreleased]` header or its link is missing or unparseable.
6. **`publish_to_npm`** — dist-tag follows release type: stable → `latest`, unnamed prerelease → `next`, named prerelease → the suffix itself. CI adds `--provenance`; local uses `--otp`.
7. **`create_github_release`** — `gh release create` with the changelog text as notes, then rebases `main` onto the release branch and pushes.

## Conventions

- **Typography matters here.** The changelog uses an em dash after the version, a non-breaking space before it, and *en dashes* as date separators (`2026–07–01`, produced by `date '+%Y–%m–%d'`). Do not normalize these to ASCII hyphens. The same applies to curly quotes in the help text.
- Function names are snake_case except `update-changelog`, which keeps the hyphen it inherited from the old CLI command name.
- Indentation is tabs (2-space for YAML), LF endings, per [.editorconfig](.editorconfig).
- `set -euo pipefail` is on; all failures go through `error()`, which prints in red to stderr and exits.
- `pnpm-workspace.yaml` pins `registries.default` to the public registry — required for trusted publishing; do not remove.
- Record user-visible changes in `CHANGELOG.md` under `## [Unreleased]` as part of the same change, using the `Changed`/`Added`/`Fixed` headings — the release script reads them to pick the version bump.
