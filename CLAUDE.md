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

[tests/helpers.sh](tests/helpers.sh) builds the sandbox: a bare `origin`, a working clone with `package.json` + `CHANGELOG.md` at a given version and on a given branch, plus stubs on `PATH`. Only `gh` and pnpm's registry commands (`publish`, `whoami`, `login`) are stubbed — `pnpm version` runs for real, so version bumping is genuinely under test. The stubbed session is a file, `$NPM_SESSION`: it starts out populated, `log_out_of_npm` empties it, and `NPM_LOGIN_FAILS` / `NPM_LOGIN_IS_EMPTY` make the stubbed `pnpm login` fail. `GIT_CONFIG_GLOBAL` is redirected into the sandbox, because the script runs `git config --global` under CI.

Two things the assertions depend on: the release heading uses a **non-breaking space** before the em dash (use `release_heading`, never a plain space), and `make_repo`'s third argument distinguishes unset (default entry) from empty (a changelog the script must reject). The same unset/empty distinction applies to `add_package`'s fourth argument in the workspace fixture (`make_workspace` + `add_package` + `finish_workspace`), where an empty `[Unreleased]` section means "not part of this release" rather than an error.

## Release pipeline architecture

`main` runs eight functions in a fixed order; each depends on globals set by earlier ones (`CURRENT_BRANCH`, `RELEASE_TYPE`, `PRERELEASE_SUFFIX`, `PRERELEASE_FLAG`, and the per-package arrays `PKG_DIRS`/`PKG_NAMES`/`PKG_NOTES`/`PKG_TYPES`/`PKG_VERSIONS`/`PKG_TAGS`, which run in step — index i describes the same package in each — declared at the top of the file). Reordering the calls breaks the script.

A pnpm workspace whose `pnpm-workspace.yaml` lists packages is a monorepo (`MONOREPO=true`, detected via `pnpm ls -r --depth -1 --parseable` in `discover_packages`, step 3 — it fills `WORKSPACE_DIRS` with the candidates, or `.`, and errors when a workspace has only private packages): the release candidates are the non-private workspace packages, the root is never one, and tags are `<name>@<version>` instead of `v<version>` (`tag_prefix`). A plain repository is the degenerate case of one candidate living in `.`.

1. **`validate_release_branch`** — the branch name is the only input for release type: `release` → stable, `release-first-major` → stable with `FIRST_MAJOR=true`, `release-first-major-` / `release-first-major-<suffix>` → its prereleases (the prefix is peeled off first, before the suffix fallback), `release-` → unnamed prerelease, `release-<suffix>` → named prerelease with `PRERELEASE_SUFFIX=<suffix>`. Anything else is a hard error.
2. **`setup_authentication`** — `CI=true` configures a bot git identity and relies on npm trusted publishing; otherwise `ensure_npm_login` checks `pnpm whoami`, runs `pnpm login` when there is no session, and then the OTP is prompted for. The login check lives here, in step 2, on purpose: the registry only refuses an unauthenticated publish in step 7, once the commit, the tag and the branch are already on the remote and can only be undone by hand. Under `--dry-run` a missing session is reported and no login is started.
3. **`discover_packages`** — see above.
4. **`detect_version_type`** — parses the `## [Unreleased]` section of each candidate's `CHANGELOG.md` with awk. Heading present in it decides the bump, checked in this precedence order: `### Changed` → major, `### Added` → minor, `### Fixed` → patch. The extracted text is reused verbatim as the GitHub release notes. In a monorepo an *empty* section merely drops the package from this release (releasing nothing at all is still an error); for a single package it is an error straight away. Each selected package lands in the `PKG_*` arrays.

	Those three are the *only* recognised headings and anything else is a hard error — a deliberate narrowing, not an oversight. `Removed` and `Deprecated` belong under `Changed`, `Security` under `Fixed` (the README explains why). Do not "complete" the Keep a Changelog set here.

	`cap_version_type_below_first_major` then adjusts the result per package (through `CAPPED_VERSION_TYPE` — `note` output would corrupt a `$(…)` capture): while the current major is `0`, `major` becomes `minor` (breaking changes are expected before 1.0.0), and on `release-first-major` the type is forced to `major` — after the headings have been validated, so the release notes are still required — and the branch errors out once the major is already ≥ 1 (a `1.0.0-…` prerelease is allowed through). `create_version` then spells the first-major versions out explicitly (`1.0.0`, `1.0.0-<suffix>.0`, `1.0.0-0`, or `prerelease` within a track) via `first_major_bump` — `pnpm version premajor` from a `1.0.0` prerelease would jump to `2.0.0`.
5. **`create_version`** — refuses a dirty working tree (the release commit adds files by name, so anything else would be left out), then bumps every package's `package.json` in place with `pnpm version … --no-git-tag-version`. No commit, no tag yet — those wait for the changelogs. Bump keyword depends on whether the current version already carries a matching prerelease suffix (`prerelease` to increment, `pre<type>` to start a new track).
6. **`update-changelog`** — renders every changelog to a temp file first (`render_changelog` inserts a `## [<version>] — <date>` heading below `## [Unreleased]` and rewrites the `[Unreleased]:` compare link, deriving `base_url` and the previous version from that link — the awk program hard-fails if the header or the link is missing or unparseable), and only when *all* of them rendered moves them into place, so a failure takes the version bumps back with `git checkout` and leaves the tree clean. Then one commit (message: the bare version for a single package, the tag list for a workspace), one tag per package, push branch and tags (force when the remote already has the tag).
7. **`publish_to_npm`** — one `pnpm publish` per package (via `pnpm -C <dir>` in a workspace — `pnpm_in`); dist-tag follows release type: stable → `latest`, unnamed prerelease → `next`, named prerelease → the suffix itself. CI adds `--provenance`; local uses `--otp`.
8. **`create_github_release`** — one `gh release create` per package with that package's changelog text as notes, then rebases `main` onto the release branch and pushes, once.

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
