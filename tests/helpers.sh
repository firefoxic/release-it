# Shared fixtures, stubs and assertions for the release-it test suite.
#
# Every test runs in its own process with its own sandbox, so a failed
# assertion can simply exit non-zero and let the runner report it.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$TESTS_DIR/.." && pwd)"
RELEASE_IT="$ROOT_DIR/release-it.sh"
REAL_PNPM="$(command -v pnpm)"

RELEASE_OUT=""
RELEASE_ERR=""
RELEASE_STATUS=0

# Typography is part of the output format: a non-breaking space before the em
# dash of a release heading, and en dashes inside the date.
NBSP=$'\u00a0'
EM_DASH=$'\u2014'
EN_DASH=$'\u2013'

# “## [1.3.0] — 2026–08–16”, exactly as the script renders it.
release_heading() {
	printf '## [%s]%s%s %s' "$1" "$NBSP" "$EM_DASH" "$(date "+%Y${EN_DASH}%m${EN_DASH}%d")"
}

# --- assertions -------------------------------------------------------------

bail() {
	printf '%s\n' "$1" >&2
	exit 1
}

assert_eq() {
	local expected=$1 actual=$2 message=${3:-values differ}

	[[ "$expected" == "$actual" ]] && return 0

	printf 'expected: %s\n  actual: %s\n' "$expected" "$actual" >&2
	bail "$message"
}

assert_contains() {
	local haystack=$1 needle=$2 message=${3:-substring not found}

	[[ "$haystack" == *"$needle"* ]] && return 0

	printf 'looked for: %s\nin:\n%s\n' "$needle" "$haystack" >&2
	bail "$message"
}

assert_not_contains() {
	local haystack=$1 needle=$2 message=${3:-unexpected substring}

	[[ "$haystack" != *"$needle"* ]] && return 0

	printf 'did not want: %s\nin:\n%s\n' "$needle" "$haystack" >&2
	bail "$message"
}

assert_succeeded() {
	[[ "$RELEASE_STATUS" -eq 0 ]] && return 0

	printf 'exit status: %s\nstdout:\n%s\nstderr:\n%s\n' "$RELEASE_STATUS" "$RELEASE_OUT" "$RELEASE_ERR" >&2
	bail "${1:-release-it was expected to succeed}"
}

assert_failed() {
	[[ "$RELEASE_STATUS" -ne 0 ]] && return 0

	printf 'stdout:\n%s\n' "$RELEASE_OUT" >&2
	bail "${1:-release-it was expected to fail}"
}

# --- sandbox ----------------------------------------------------------------

# Prepares an isolated environment: stubbed `gh` and `pnpm publish` on PATH,
# and a throwaway global git config so that `git config --global` (which the
# script runs under CI) can never reach the real one.
setup_sandbox() {
	SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/release-it-test.XXXXXX")"
	ORIGIN="$SANDBOX/origin.git"
	WORK="$SANDBOX/work"
	GH_LOG="$SANDBOX/gh.log"
	GH_NOTES="$SANDBOX/gh-notes.txt"
	PUBLISH_LOG="$SANDBOX/publish.log"
	LOGIN_LOG="$SANDBOX/login.log"
	# The stubbed npm session: present means logged in, absent means not.
	NPM_SESSION="$SANDBOX/npm-session"

	export GH_LOG GH_NOTES PUBLISH_LOG LOGIN_LOG NPM_SESSION REAL_PNPM
	export GIT_CONFIG_GLOBAL="$SANDBOX/gitconfig"

	# The script switches to trusted publishing when it sees CI=true, which
	# GitHub Actions sets for the test job itself. Tests that want the CI
	# path opt in with `CI=true run_release_it`; everything else expects the
	# local path. GITHUB_TOKEN is dropped for the same reason: with it set,
	# the script skips `gh auth status`, and whether that call shows up in
	# the gh log would depend on the machine running the tests.
	unset CI GITHUB_TOKEN

	: > "$GIT_CONFIG_GLOBAL"
	: > "$GH_LOG"
	: > "$GH_NOTES"
	: > "$PUBLISH_LOG"
	: > "$LOGIN_LOG"
	printf 'tester\n' > "$NPM_SESSION"

	write_stubs
	export PATH="$SANDBOX/bin:$PATH"

	[[ -n "${KEEP_SANDBOX:-}" ]] || trap 'rm -rf "$SANDBOX"' EXIT
}

# `gh` is replaced wholesale; `pnpm` only has the registry commands
# intercepted, so that the real version bumping logic stays under test.
write_stubs() {
	mkdir -p "$SANDBOX/bin"

	cat > "$SANDBOX/bin/gh" <<-'STUB'
		#!/usr/bin/env bash
		printf '%s\n' "$*" >> "$GH_LOG"
		# Appended, not overwritten: a workspace release makes several.
		[[ "${1:-}" == "release" ]] && cat >> "$GH_NOTES"
		exit 0
	STUB

	cat > "$SANDBOX/bin/pnpm" <<-'STUB'
		#!/usr/bin/env bash
		args=("$@")
		# The script addresses workspace packages with `pnpm -C <dir> …`.
		[[ "${1:-}" == "-C" ]] && shift 2
		case "${1:-}" in
			publish)
				printf '%s\n' "${args[*]}" >> "$PUBLISH_LOG"
				exit 0
				;;
			whoami)
				[[ -s "$NPM_SESSION" ]] || {
					printf 'ERR_PNPM_AUTH_UNAUTHORIZED\n' >&2
					exit 1
				}
				cat "$NPM_SESSION"
				exit 0
				;;
			login)
				printf '%s\n' "$*" >> "$LOGIN_LOG"
				[[ "${NPM_LOGIN_FAILS:-}" == "true" ]] && exit 1
				[[ "${NPM_LOGIN_IS_EMPTY:-}" == "true" ]] || printf 'tester\n' > "$NPM_SESSION"
				exit 0
				;;
		esac
		exec "$REAL_PNPM" "${args[@]}"
	STUB

	chmod +x "$SANDBOX/bin/gh" "$SANDBOX/bin/pnpm"
}

# Puts the sandbox in the state of a machine that never ran `pnpm login`.
log_out_of_npm() {
	: > "$NPM_SESSION"
}

# --- fixture repository -----------------------------------------------------

# Builds a package repository with a bare `origin`, an already released
# version and an [Unreleased] section, then checks out the release branch.
make_repo() {
	local version=${1:-1.2.3}
	local branch=${2:-release}
	# Unset means “give me the usual entry”; an empty string means “leave the
	# section empty”, which is a case the script has to reject.
	local unreleased=${3-$'### Added\n\n- A brand new thing.'}

	git init -q --bare -b main "$ORIGIN"
	git init -q -b main "$WORK"
	cd "$WORK" || bail "cannot enter $WORK"

	git config user.email "tester@example.com"
	git config user.name "Tester"
	git remote add origin "$ORIGIN"

	write_package_json "$version"
	write_changelog "$version" "$unreleased"
	printf 'gitChecks: false\n' > pnpm-workspace.yaml

	git add -A
	git commit -qm "Initial commit"
	git tag "v$version"
	git push -q -u origin main
	git push -q origin "v$version"

	if [[ "$branch" != "main" ]]; then
		git switch -qc "$branch"
		git push -q -u origin "$branch"
	fi
}

write_package_json() {
	printf '{\n\t"name": "widget",\n\t"version": "%s",\n\t"license": "MIT"\n}\n' "$1" > package.json
}

# The third argument is the tag prefix of the compare link: `v` for a single
# package, `<name>@` for a workspace package.
write_changelog() {
	local previous=$1 unreleased=$2 tag_prefix=${3:-v}

	{
		printf '# Changelog\n\n'
		printf '## [Unreleased]\n\n'
		[[ -n "$unreleased" ]] && printf '%s\n\n' "$unreleased"
		printf '## [%s]%s%s 2026%s01%s01\n\n' "$previous" "$NBSP" "$EM_DASH" "$EN_DASH" "$EN_DASH"
		printf '### Fixed\n\n- An older fix.\n\n'
		printf '[Unreleased]: https://github.com/acme/widget/compare/%s%s...HEAD\n' "$tag_prefix" "$previous"
		printf '[%s]: https://github.com/acme/widget/releases/tag/%s%s\n' "$previous" "$tag_prefix" "$previous"
	} > CHANGELOG.md
}

# --- fixture workspace ------------------------------------------------------

# A pnpm workspace is built in three moves: `make_workspace` lays down the
# private root, `add_package` adds one package at a time, and
# `finish_workspace` commits, tags and checks out the release branch.
make_workspace() {
	git init -q --bare -b main "$ORIGIN"
	git init -q -b main "$WORK"
	cd "$WORK" || bail "cannot enter $WORK"

	git config user.email "tester@example.com"
	git config user.name "Tester"
	git remote add origin "$ORIGIN"

	printf '{\n\t"name": "monorepo",\n\t"private": true\n}\n' > package.json
	printf 'packages:\n  - packages/*\ngitChecks: false\n' > pnpm-workspace.yaml
	WORKSPACE_TAGS=()
}

# add_package <dir> <name> <version> [unreleased] [private]
add_package() {
	local dir=$1 name=$2 version=$3
	local unreleased=${4-$'### Added\n\n- A brand new thing.'}
	local private=${5:-false}

	mkdir -p "$dir"
	(
		cd "$dir" || bail "cannot enter $dir"
		printf '{\n\t"name": "%s",\n\t"version": "%s",\n\t"license": "MIT",\n\t"private": %s\n}\n' "$name" "$version" "$private" > package.json
		write_changelog "$version" "$unreleased" "$name@"
	)
	WORKSPACE_TAGS+=("$name@$version")
}

finish_workspace() {
	local branch=${1:-release} tag

	git add -A
	git commit -qm "Initial commit"
	for tag in "${WORKSPACE_TAGS[@]}"; do
		git tag "$tag"
	done
	git push -q -u origin main
	git push -q origin --tags

	if [[ "$branch" != "main" ]]; then
		git switch -qc "$branch"
		git push -q -u origin "$branch"
	fi
}

# --- running the script -----------------------------------------------------

# Captures stdout, stderr and the exit status; stdin carries the OTP that the
# script prompts for outside CI.
run_release_it() {
	RELEASE_OUT="$(printf '%s\n' "${OTP_INPUT:-123456}" | "$RELEASE_IT" "$@" 2>"$SANDBOX/stderr")"
	RELEASE_STATUS=$?
	RELEASE_ERR="$(cat "$SANDBOX/stderr")"
}

# The common “arrange and release” path, asserting that it went through.
release_from() {
	make_repo "$@"
	run_release_it
	assert_succeeded
}

package_version() {
	"$REAL_PNPM" pkg get version
}

# The version of release-it itself, read straight from its own manifest.
own_version() {
	(cd "$ROOT_DIR" && "$REAL_PNPM" pkg get version)
}

published_args() {
	cat "$PUBLISH_LOG"
}

gh_args() {
	cat "$GH_LOG"
}

gh_notes() {
	cat "$GH_NOTES"
}

login_attempts() {
	cat "$LOGIN_LOG"
}
