# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A single self-contained Bash script ([release-it.sh](release-it.sh)) published to npm as `@firefoxic/release-it` and exposed via the `bin` field as `release-it`. There is no build step, no source-to-dist transform and no dependencies — `package.json` has `"exports": null`, `"files": []`, and empty `devDependencies`. Editing the script *is* editing the product.

External tools the script shells out to are `git`, `pnpm` and `gh`, and nothing else. Keep it that way: an undeclared `jq` dependency lived here for a while, and version reads now go through `pnpm pkg get version`.

The repo is self-hosting: it releases itself with its own script via [.github/workflows/release.yaml](.github/workflows/release.yaml), which runs `./release-it.sh` directly (consumers are told to run `pnx @firefoxic/release-it` instead).

## Commands

```shell
pnpm test                        # whole suite
tests/run.sh changelog           # only tests whose suite/name matches the substring
tests/run.sh release/main_is     # narrow enough to select a single test
KEEP_SANDBOX=1 tests/run.sh …    # keep the temporary repositories for inspection

./release-it.sh --help      # -h — usage text
./release-it.sh --version   # -v — release-it's own version, not the project's
./release-it.sh --dry-run   # -n — walk the whole pipeline, change nothing
./release-it.sh             # full release; publishes for real — use the tests instead
```

There is no lint or build step.

## Tests

Pure Bash, zero dependencies, in [tests/](tests/). [tests/run.sh](tests/run.sh) discovers `tests/*.test.sh`, extracts every `test_*` function, and runs each one in its own process (`run.sh --one <file> <fn>`) with a fresh sandbox — so a failed assertion just exits non-zero.

[tests/helpers.sh](tests/helpers.sh) builds the sandbox: a bare `origin`, a working clone with `package.json` + `CHANGELOG.md` at a given version and on a given branch, plus stubs on `PATH`. Only `gh` and `pnpm publish` are stubbed — `pnpm version` runs for real, so version bumping is genuinely under test. `GIT_CONFIG_GLOBAL` is redirected into the sandbox, because the script runs `git config --global` under CI.

Two things the assertions depend on: the release heading uses a **non-breaking space** before the em dash (use `release_heading`, never a plain space), and `make_repo`'s third argument distinguishes unset (default entry) from empty (a changelog the script must reject).

## Release pipeline architecture

`main` runs seven functions in a fixed order ([release-it.sh:266-272](release-it.sh#L266-L272)); each depends on globals set by earlier ones (`CURRENT_BRANCH`, `RELEASE_TYPE`, `PRERELEASE_SUFFIX`, `RELEASE_DESCRIPTION`, `VERSION_TYPE`, `TAG_NAME`, `PRERELEASE_FLAG`, declared at the top of the file). Reordering the calls breaks the script.

1. **`validate_release_branch`** — the branch name is the only input for release type: `release` → stable, `release-` → unnamed prerelease, `release-<suffix>` → named prerelease with `PRERELEASE_SUFFIX=<suffix>`. Anything else is a hard error.
2. **`setup_authentication`** — `CI=true` configures a bot git identity and relies on npm trusted publishing; otherwise it prompts for an OTP.
3. **`detect_version_type`** — parses the `## [Unreleased]` section of `CHANGELOG.md` with awk. Heading present in it decides the bump, checked in this precedence order: `### Changed` → major, `### Added` → minor, `### Fixed` → patch. The extracted text is reused verbatim as the GitHub release notes.

	Those three are the *only* recognised headings and anything else is a hard error — a deliberate narrowing, not an oversight. `Removed` and `Deprecated` belong under `Changed`, `Security` under `Fixed` (the README explains why). Do not "complete" the Keep a Changelog set here.
4. **`create_version`** — calls `pnpm version`, which makes a commit *and* a tag. Bump keyword depends on whether the current version already carries a matching prerelease suffix (`prerelease` to increment, `pre<type>` to start a new track).
5. **`update-changelog`** — the subtle part. It deletes the tag `pnpm version` just created, rewrites `CHANGELOG.md` (inserts a `## [<version>] — <date>` heading below `## [Unreleased]` and rewrites the `[Unreleased]:` compare link, deriving `base_url` and the previous version from that link), then `git commit --amend`s the version commit, re-creates the tag on the amended commit, and force-pushes the tag if the remote already has it. So the version commit and the changelog edit end up as one commit. The awk program hard-fails if the `[Unreleased]` header or its link is missing or unparseable.
6. **`publish_to_npm`** — dist-tag follows release type: stable → `latest`, unnamed prerelease → `next`, named prerelease → the suffix itself. CI adds `--provenance`; local uses `--otp`.
7. **`create_github_release`** — `gh release create` with the changelog text as notes, then rebases `main` onto the release branch and pushes.

## Dry run

`--dry-run` routes every side effect through `run()`, which announces the command instead of executing it. Two places cannot use it and branch explicitly instead: `update-changelog` (it renders the new changelog into a temp file and shows a `diff` rather than moving it into place) and `create_github_release` (the notes arrive over a pipe).

The next version comes from `preview_version()`, which bumps a *copy* of `package.json` in a temp directory with `--no-git-tag-version`. This is deliberate: `pnpm version --dry-run` is not honoured by pnpm 11 — it rewrites `package.json` and creates the commit and tag anyway. Never reach for that flag here.

## Conventions

- **Typography matters here.** The changelog uses an em dash after the version, a non-breaking space before it, and *en dashes* as date separators (`2026–07–01`, produced by `date '+%Y–%m–%d'`). Do not normalize these to ASCII hyphens. The same applies to curly quotes in the help text.
- Function names are snake_case except `update-changelog`, which keeps the hyphen it inherited from the old CLI command name.
- Indentation is tabs (2-space for YAML), LF endings, per [.editorconfig](.editorconfig).
- `set -euo pipefail` is on; all failures go through `error()`, which prints in red to stderr and exits.
- `pnpm-workspace.yaml` pins `registries.default` to the public registry — required for trusted publishing; do not remove.
- Record user-visible changes in `CHANGELOG.md` under `## [Unreleased]` as part of the same change, using the `Changed`/`Added`/`Fixed` headings — the release script reads them to pick the version bump.
