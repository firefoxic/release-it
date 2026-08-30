#!/usr/bin/env bash
set -euo pipefail

CURRENT_BRANCH=""
RELEASE_TYPE=""
PRERELEASE_SUFFIX=""
NPM_OTP=""
PRERELEASE_FLAG=""
FIRST_MAJOR=false
DRY_RUN=false

# A pnpm workspace releases several packages at once; a plain repository is
# the degenerate case of one package living in `.`. The arrays run in step:
# index i describes the same package in each of them.
MONOREPO=false
WORKSPACE_DIRS=()
PKG_DIRS=()
PKG_NAMES=()
PKG_NOTES=()
PKG_TYPES=()
PKG_VERSIONS=()
PKG_TAGS=()
CAPPED_VERSION_TYPE=""

error() {
	echo -e "\033[0;31mError: $1\033[0m" >&2
	exit 1
}

note() {
	echo -e "\033[0;36m$1\033[0m"
}

# Directory holding this script, with symlinks resolved — package managers
# link the bin into `node_modules/.bin` rather than copying it.
script_dir() {
	local source="${BASH_SOURCE[0]}" dir

	while [[ -L "$source" ]]; do
		dir=$(cd -P "$(dirname "$source")" && pwd)
		source=$(readlink "$source")
		[[ "$source" == /* ]] || source="$dir/$source"
	done

	cd -P "$(dirname "$source")" && pwd
}

package_version() {
	pnpm -C "${1:-.}" pkg get version
}

# `v1.3.0` for a single package; `widget@1.3.0` inside a workspace, where a
# bare version could not tell the packages apart.
tag_prefix() {
	if [[ "$MONOREPO" == "true" ]]; then
		echo "${PKG_NAMES[$1]}@"
	else
		echo "v"
	fi
}

# Runs pnpm in a package directory, through `run`. The directory is only
# spelled out in a workspace: `pnpm -C . publish` would be noise otherwise.
pnpm_in() {
	local dir=$1
	shift

	[[ "$MONOREPO" == "true" ]] && set -- -C "$dir" "$@"
	run pnpm "$@"
}

# Runs a command, or merely announces it under --dry-run.
run() {
	if [[ "$DRY_RUN" == "true" ]]; then
		note "→ $*"
	else
		"$@"
	fi
}

validate_release_branch() {
	CURRENT_BRANCH=$(git branch --show-current)

	if [[ ! "$CURRENT_BRANCH" =~ ^release ]]; then
		error "Release can only be made from 'release*' branches. Current branch: $CURRENT_BRANCH"
	fi

	local branch="$CURRENT_BRANCH"

	# `release-first-major` is a stable 1.0.0; `release-first-major-<suffix>`
	# and `release-first-major-` are its prereleases. The prefix is peeled off
	# first, so that the rest is parsed like any other release branch — the
	# fallback below would otherwise read it as a prerelease named
	# “first-major”.
	if [[ "$branch" == "release-first-major" ]] || [[ "$branch" == release-first-major-* ]]; then
		FIRST_MAJOR=true
		branch="release${branch#release-first-major}"
	fi

	if [[ "$branch" == "release" ]]; then
		RELEASE_TYPE="stable"
	elif [[ "$branch" == "release-" ]]; then
		RELEASE_TYPE="unnamed"
	else
		RELEASE_TYPE="named"
		PRERELEASE_SUFFIX="${branch#release-}"
	fi
}

# A `pnpm-workspace.yaml` that lists packages makes this a monorepo, and the
# publishable packages it lists are the release candidates — the root, which
# only holds them together, is never one of them. Without a workspace the
# repository itself is the single candidate.
discover_packages() {
	local root dir listed=0

	root=$(pwd -P)

	while IFS= read -r dir; do
		[[ "$dir" == "$root" ]] && continue
		listed=$((listed + 1))
		[[ "$(pnpm -C "$dir" pkg get private 2>/dev/null)" == "true" ]] && continue
		WORKSPACE_DIRS+=("${dir#"$root/"}")
	done < <(pnpm ls -r --depth -1 --parseable 2>/dev/null)

	if [[ "$listed" -eq 0 ]]; then
		WORKSPACE_DIRS=(".")
		return
	fi

	[[ ${#WORKSPACE_DIRS[@]} -gt 0 ]] || error "The workspace has no publishable packages: every one of them is private."

	MONOREPO=true
	note "pnpm workspace with ${#WORKSPACE_DIRS[@]} publishable package(s): ${WORKSPACE_DIRS[*]}"
}

# The registry only turns an unauthenticated publish away at the very end of
# the pipeline, once the version commit, the tag and the branch have already
# been pushed — too late to retry without deleting them by hand. So the session
# is opened here instead, before anything is written.
ensure_npm_login() {
	local user

	if user=$(pnpm whoami 2>/dev/null) && [[ -n "$user" ]]; then
		note "Logged in to npm as $user."
		return
	fi

	if [[ "$DRY_RUN" == "true" ]]; then
		note "→ pnpm login — no npm session was found"
		return
	fi

	note "No npm session found — logging in first."
	pnpm login || error "npm login failed. Run 'pnpm login', then release again."

	user=$(pnpm whoami 2>/dev/null) || user=""
	[[ -n "$user" ]] || error "npm login left no usable session. Run 'pnpm login', then release again."

	note "Logged in to npm as $user."
}

setup_authentication() {
	if [[ "${CI:-}" == "true" ]]; then
		run git config --global user.email "actions@users.noreply.github.com"
		run git config --global user.name "GitHub Actions"
		return
	fi

	ensure_npm_login

	if [[ "$DRY_RUN" == "true" ]]; then
		NPM_OTP="<otp>"
		return
	fi

	echo -n "Enter NPM_OTP: "
	# -s keeps the one-time password off the screen; the newline the user
	# typed is not echoed either, so it has to be printed here.
	read -rs NPM_OTP
	echo
}

# The section runs until the next release heading — or the link definitions,
# which come right after [Unreleased] in a changelog with no releases yet.
unreleased_notes() {
	awk '/## \[Unreleased\]/{flag=1; next} /## \[/ || /^\[[^]]+\]: /{flag=0} flag' "$1" | sed '/^[[:space:]]*$/d'
}

# Every candidate's changelog decides whether, and how far, it is released.
# A single package with nothing under [Unreleased] is an error; a workspace
# package with nothing there is simply not part of this release.
detect_version_type() {
	local dir changelog notes type

	for dir in "${WORKSPACE_DIRS[@]}"; do
		changelog="$dir/CHANGELOG.md"
		[[ "$dir" == "." ]] && changelog="CHANGELOG.md"
		[[ -f "$changelog" ]] || error "$changelog not found"

		notes=$(unreleased_notes "$changelog")

		if [[ -z "$notes" ]]; then
			[[ "$MONOREPO" == "true" ]] || error "No changes found in CHANGELOG.md [Unreleased] section"
			continue
		elif echo "$notes" | grep -q '### Changed'; then
			type="major"
		elif echo "$notes" | grep -q '### Added'; then
			type="minor"
		elif echo "$notes" | grep -q '### Fixed'; then
			type="patch"
		else
			error "$changelog Unreleased section is empty or does not follow the expected format."
		fi

		cap_version_type_below_first_major "$dir" "$type"

		PKG_DIRS+=("$dir")
		PKG_NAMES+=("$(pnpm -C "$dir" pkg get name)")
		PKG_NOTES+=("$notes")
		PKG_TYPES+=("$CAPPED_VERSION_TYPE")
	done

	[[ ${#PKG_DIRS[@]} -gt 0 ]] || error "No package has changes in its CHANGELOG.md [Unreleased] section"

	if [[ "$MONOREPO" == "true" ]]; then
		note "Releasing: ${PKG_DIRS[*]}"
	fi
}

# Reaching 1.0.0 is a decision, not a side effect of a changelog heading:
# below it a breaking change is expected, so `### Changed` only bumps the
# minor version, and the first major is cut from `release-first-major`.
# Leaves the version type to use for the package in $1 in CAPPED_VERSION_TYPE.
cap_version_type_below_first_major() {
	local dir=$1 version_type=$2 current_version major label
	current_version=$(package_version "$dir")
	major=${current_version%%.*}
	label=$([[ "$MONOREPO" == "true" ]] && echo "$dir is at $current_version" || echo "$current_version")

	if [[ "$FIRST_MAJOR" == "true" ]]; then
		# A prerelease of 1.0.0 is still on the way there.
		if [[ "$major" -ne 0 ]] && [[ ! "$current_version" =~ ^1\.0\.0- ]]; then
			error "The first major version has already been released ($label). Release from the 'release' branch instead."
		fi

		note "Releasing the first major version from '$CURRENT_BRANCH'."
		CAPPED_VERSION_TYPE="major"
		return
	fi

	if [[ "$major" -eq 0 ]] && [[ "$version_type" == "major" ]]; then
		note "Bumping the minor version instead of the major one: $label is below 1.0.0. Release from 'release-first-major' to cut 1.0.0."
		CAPPED_VERSION_TYPE="minor"
		return
	fi

	CAPPED_VERSION_TYPE="$version_type"
}

# Bumps a throwaway copy of package.json to learn the next version without
# touching the repository — `pnpm version --dry-run` still rewrites files.
preview_version() {
	local dir=$1 sandbox
	shift
	sandbox=$(mktemp -d)

	cp "$dir/package.json" "$sandbox/package.json"
	(cd "$sandbox" && pnpm version "$@" --no-git-tag-version >/dev/null && package_version)

	rm -rf "$sandbox"
}

# `pnpm version premajor` from a 1.0.0 prerelease would land on 2.0.0, so
# the first major and its prerelease tracks are spelled out explicitly.
first_major_bump() {
	local current_version=$1

	if [[ "$RELEASE_TYPE" == "stable" ]]; then
		echo "1.0.0"
	elif [[ "$RELEASE_TYPE" == "unnamed" ]]; then
		if [[ "$current_version" =~ ^1\.0\.0-[0-9]+$ ]]; then
			echo "prerelease"
		else
			echo "1.0.0-0"
		fi
	else
		if [[ "$current_version" =~ ^1\.0\.0-${PRERELEASE_SUFFIX}\.[0-9]+$ ]]; then
			echo "prerelease"
		else
			echo "1.0.0-$PRERELEASE_SUFFIX.0"
		fi
	fi
}

# Bumps every package.json in place. The commit and the tags wait for the
# changelogs, so that all of it lands in one commit.
create_version() {
	local i dir current_version next_version bump=()

	# The release commit picks up the manifests and the changelogs by name,
	# so anything else lying around would be left out of it — and out of
	# the tag.
	[[ -z "$(git status --porcelain)" ]] || error "The working tree is not clean. Commit or stash the changes, then release again."

	[[ "$RELEASE_TYPE" == "stable" ]] && PRERELEASE_FLAG="" || PRERELEASE_FLAG="--prerelease"

	for i in "${!PKG_DIRS[@]}"; do
		dir=${PKG_DIRS[$i]}
		current_version=$(package_version "$dir")

		if [[ "$FIRST_MAJOR" == "true" ]]; then
			bump=("$(first_major_bump "$current_version")")
		elif [[ "$RELEASE_TYPE" == "stable" ]]; then
			bump=("${PKG_TYPES[$i]}")
		elif [[ "$RELEASE_TYPE" == "unnamed" ]]; then
			if [[ "$current_version" =~ -[0-9]+$ ]]; then
				bump=(prerelease)
			else
				bump=("pre${PKG_TYPES[$i]}")
			fi
		else
			if [[ "$current_version" =~ -${PRERELEASE_SUFFIX}\.[0-9]+$ ]]; then
				bump=(prerelease)
			else
				bump=("pre${PKG_TYPES[$i]}" "--preid=$PRERELEASE_SUFFIX")
			fi
		fi

		if [[ "$DRY_RUN" == "true" ]]; then
			pnpm_in "$dir" version "${bump[@]}"
			next_version=$(preview_version "$dir" "${bump[@]}")
			note "  $current_version → $next_version"
		else
			pnpm_in "$dir" version "${bump[@]}" --no-git-tag-version
			next_version=$(package_version "$dir")
		fi

		PKG_VERSIONS+=("$next_version")
		PKG_TAGS+=("$(tag_prefix "$i")$next_version")
	done
}

# Inserts the release heading below [Unreleased] and moves the compare link
# along, deriving the base URL and the previous version from that link.
render_changelog() {
	local changelog_file=$1 version=$2 tag_prefix=$3

	awk -v version="$version" -v tag_prefix="$tag_prefix" -v date="$(date '+%Y–%m–%d')" '
	BEGIN {
		found_unreleased_header = 0
		found_unreleased_link = 0
		base_url = ""
		prev_version = ""
	}

	/^## \[Unreleased\]$/ {
		print $0
		print ""
		print "## [" version "] — " date
		found_unreleased_header = 1
		next
	}

	/^\[Unreleased\]: / {
		found_unreleased_link = 1

		link = substr($0, length("[Unreleased]: ") + 1)
		marker = "/compare/" tag_prefix
		pos = index(link, marker)

		if (pos > 0 && link ~ /\.\.\.HEAD$/) {
			base_url = substr(link, 1, pos - 1 + length(marker))
			prev_version = substr(link, pos + length(marker))
			sub(/\.\.\.HEAD$/, "", prev_version)
		}

		if (base_url == "" || prev_version !~ /^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$/) {
			print "Could not parse [Unreleased] link: " $0 > "/dev/stderr"
			exit 1
		}

		print "[Unreleased]: " base_url version "...HEAD"
		print "[" version "]: " base_url prev_version "..." tag_prefix version
		next
	}

	{ print }

	END {
		if (!found_unreleased_header) {
			print "Error: ## [Unreleased] header not found" > "/dev/stderr"
			exit 1
		}
		if (!found_unreleased_link) {
			print "Error: [Unreleased] link not found" > "/dev/stderr"
			exit 1
		}
		if (base_url == "" || prev_version == "") {
			print "Error: Could not extract version info from [Unreleased] link" > "/dev/stderr"
			exit 1
		}
	}
	' "$changelog_file"
}

update-changelog() {
	local i dir changelog_file temp_file version awk_status message
	local changelog_files=() temp_files=() package_files=()

	for i in "${!PKG_DIRS[@]}"; do
		dir=${PKG_DIRS[$i]}
		version=${PKG_VERSIONS[$i]}
		changelog_file="$dir/CHANGELOG.md"
		[[ "$dir" == "." ]] && changelog_file="CHANGELOG.md"
		temp_file=$(mktemp)
		awk_status=0

		render_changelog "$changelog_file" "$version" "$(tag_prefix "$i")" > "$temp_file" || awk_status=$?

		# `set -e` would otherwise abort right here, before the diagnosis below.
		if [[ "$awk_status" -ne 0 ]] || [[ ! -s "$temp_file" ]] || ! grep -q "\[$version\]:" "$temp_file"; then
			rm -f "$temp_file" "${temp_files[@]}"
			# The bumped manifests are the only change so far; take them back.
			[[ "$DRY_RUN" == "true" ]] || git checkout -- "${PKG_DIRS[@]/%//package.json}"
			error "$changelog_file could not be rewritten"
		fi

		changelog_files+=("$changelog_file")
		temp_files+=("$temp_file")
		package_files+=("$dir/package.json")
	done

	if [[ "$DRY_RUN" == "true" ]]; then
		for i in "${!PKG_DIRS[@]}"; do
			note "→ ${changelog_files[$i]} would change:"
			# `diff` reports 1 whenever the files differ, which is the whole point.
			diff --unified=1 "${changelog_files[$i]}" "${temp_files[$i]}" | tail -n +3 || true
			rm -f "${temp_files[$i]}"
		done
		note "→ commit the version bump with ${changelog_files[*]}, then tag ${PKG_TAGS[*]}"
		run git push origin "$CURRENT_BRANCH"
		for i in "${!PKG_DIRS[@]}"; do
			run git push origin "refs/tags/${PKG_TAGS[$i]}"
		done
		return
	fi

	for i in "${!PKG_DIRS[@]}"; do
		mv "${temp_files[$i]}" "${changelog_files[$i]}"
	done

	# `pnpm version` would have spelled the commit as the bare version; a
	# workspace release lists its tags instead.
	if [[ "$MONOREPO" == "true" ]]; then
		message=$(IFS=,; echo "${PKG_TAGS[*]}")
		message=${message//,/, }
	else
		message=${PKG_VERSIONS[0]}
	fi

	git add "${package_files[@]}" "${changelog_files[@]}"
	git commit -m "$message" -n
	for i in "${!PKG_DIRS[@]}"; do
		git tag "${PKG_TAGS[$i]}"
	done

	# A rejected push has to stop the release: publishing and the GitHub
	# release both come next, and both would point at an unpushed commit.
	git push origin "$CURRENT_BRANCH"

	for i in "${!PKG_DIRS[@]}"; do
		if git ls-remote --exit-code --tags origin "refs/tags/${PKG_TAGS[$i]}" >/dev/null; then
			git push --force origin "refs/tags/${PKG_TAGS[$i]}"
		else
			git push origin "refs/tags/${PKG_TAGS[$i]}"
		fi
	done
}

publish_to_npm() {
	local npm_tag="latest"

	if [[ -n "$PRERELEASE_FLAG" ]]; then
		if [[ "$RELEASE_TYPE" == "unnamed" ]]; then
			npm_tag="next"
		else
			npm_tag="$PRERELEASE_SUFFIX"
		fi
	fi

	local dir
	for dir in "${PKG_DIRS[@]}"; do
		if [[ "${CI:-}" == "true" ]]; then
			pnpm_in "$dir" publish --provenance --access public --tag "$npm_tag"
		else
			pnpm_in "$dir" publish --access public --tag "$npm_tag" --otp="$NPM_OTP"
		fi
	done
}

create_github_release() {
	if ! command -v gh >/dev/null 2>&1; then
		error "GitHub CLI (gh) is required but not installed.\nInstall from: https://cli.github.com"
	fi

	if [[ "${CI:-}" != "true" ]] && [[ -z "${GITHUB_TOKEN:-}" ]] && ! gh auth status >/dev/null 2>&1; then
		error "GitHub CLI not authenticated.\nRun 'gh auth login' or set GITHUB_TOKEN environment variable."
	fi

	local i tag
	for i in "${!PKG_DIRS[@]}"; do
		tag=${PKG_TAGS[$i]}

		if [[ "$DRY_RUN" == "true" ]]; then
			note "→ gh release create $tag --title \"Release $tag\"${PRERELEASE_FLAG:+ $PRERELEASE_FLAG}"
			note "  with these notes:"
			echo "${PKG_NOTES[$i]}"
		else
			echo "${PKG_NOTES[$i]}" | gh release create "$tag" \
				--title "Release $tag" \
				--notes-file - \
				$PRERELEASE_FLAG
		fi
	done

	run git fetch --all
	run git switch main
	run git rebase "$CURRENT_BRANCH"
	run git push origin main
}

show_help() {
	cat << EOF
📦 Bump, publish and release new version for npm package using pnpm

USAGE:
    release-it [OPTIONS]

OPTIONS:
    -h, --help     Show this help message
    -v, --version  Show current version
    -n, --dry-run  Report what a release would do, changing nothing

REQUIREMENTS:
    • Node.js
    • pnpm
    • Git repository with proper remote setup
    • GitHub CLI (gh) must be installed: https://cli.github.com

BRANCH REQUIREMENTS:
    • Must be on a branch starting with “release”
    • “release”                    → stable release          (e.g., 1.1.0)
    • “release-first-major”        → the first major release (1.0.0)
    • “release-first-major-<name>” → its prerelease          (e.g., 1.0.0-rc.0)
    • “release-alpha”              → prerelease              (e.g., 1.0.0-alpha.0)
    • “release-beta”               → prerelease              (e.g., 1.0.0-beta.0)
    • “release-rc”                 → release candidate       (e.g., 1.0.0-rc.0)
    • or another prerelease name, even...
    • “release-”                   → unnamed prerelease      (e.g., 1.0.0-0)

VERSION DETECTION:
    • ### Changed → major version bump
    • ### Added   → minor version bump
    • ### Fixed   → patch version bump

    Below 1.0.0, ### Changed bumps the minor version instead: breaking
    changes are expected there. Cut 1.0.0 from “release-first-major”
    (or its prereleases from “release-first-major-<name>”), which go to
    the first major whatever the headings say.

    No other heading is recognised. See the README for how the remaining
    Keep a Changelog headings fold into these three.

PNPM WORKSPACES:
    In a pnpm workspace every package keeps its own CHANGELOG.md, and
    every non-private package with entries under [Unreleased] is
    released — with its own version, a “<name>@<version>” tag, its own
    npm publish and GitHub release — in one commit. Packages with an
    empty [Unreleased] section are left alone; the root never is
    released. The compare link in a package changelog names its tag:
    …/compare/<name>@1.2.3...HEAD

AUTHENTICATION:
    • Local: Checks the npm session, runs 'pnpm login' when there is none,
      then asks for an OTP — all before anything is committed or pushed
    • CI: Uses NPM trusted publishing
    • GitHub Release: Requires 'gh auth login' or GITHUB_TOKEN

EXAMPLES:
    release-it                          # Interactive OTP
    release-it --dry-run                # Preview without releasing
    GITHUB_TOKEN=... release-it         # With GitHub release
    gh auth login && release-it         # GitHub auth via CLI

EOF
}

main() {
	while [[ $# -gt 0 ]]; do
		case $1 in
			-h|--help)
				show_help
				exit 0
				;;
			-v|--version)
				(cd "$(script_dir)" && package_version) 2>/dev/null || echo "Version not found"
				exit 0
				;;
			-n|--dry-run)
				DRY_RUN=true
				shift
				;;
			*)
				show_help
				error "Unknown option: $1"
				;;
		esac
	done

	if [[ "$DRY_RUN" == "true" ]]; then
		note "Dry run — nothing will be written, pushed or published."
	fi

	validate_release_branch
	setup_authentication
	discover_packages
	detect_version_type
	create_version
	update-changelog
	publish_to_npm
	create_github_release
}

main "$@"
