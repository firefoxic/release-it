#!/usr/bin/env bash
set -euo pipefail

CURRENT_BRANCH=""
RELEASE_TYPE=""
PRERELEASE_SUFFIX=""
NPM_OTP=""
RELEASE_DESCRIPTION=""
VERSION_TYPE=""
TAG_NAME=""
PRERELEASE_FLAG=""
DRY_RUN=false

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
	pnpm pkg get version
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

	if [[ "$CURRENT_BRANCH" == "release" ]]; then
		RELEASE_TYPE="stable"
	elif [[ "$CURRENT_BRANCH" == "release-" ]]; then
		RELEASE_TYPE="unnamed"
	else
		RELEASE_TYPE="named"
		PRERELEASE_SUFFIX="${CURRENT_BRANCH#release-}"
	fi
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

detect_version_type() {
	[[ -f "CHANGELOG.md" ]] || error "CHANGELOG.md not found"

	RELEASE_DESCRIPTION=$(awk '/## \[Unreleased\]/{flag=1; next} /## \[/{flag=0} flag' CHANGELOG.md | sed '/^[[:space:]]*$/d')

	if [[ -z "$RELEASE_DESCRIPTION" ]]; then
		error "No changes found in CHANGELOG.md [Unreleased] section"
	elif echo "$RELEASE_DESCRIPTION" | grep -q '### Changed'; then
		VERSION_TYPE="major"
	elif echo "$RELEASE_DESCRIPTION" | grep -q '### Added'; then
		VERSION_TYPE="minor"
	elif echo "$RELEASE_DESCRIPTION" | grep -q '### Fixed'; then
		VERSION_TYPE="patch"
	else
		error "CHANGELOG.md Unreleased section is empty or does not follow the expected format."
	fi
}

# Bumps a throwaway copy of package.json to learn the next version without
# touching the repository — `pnpm version --dry-run` still rewrites files.
preview_version() {
	local sandbox
	sandbox=$(mktemp -d)

	cp package.json "$sandbox/package.json"
	(cd "$sandbox" && pnpm version "$@" --no-git-tag-version >/dev/null && package_version)

	rm -rf "$sandbox"
}

create_version() {
	local current_version bump=()
	current_version=$(package_version)

	if [[ "$RELEASE_TYPE" == "stable" ]]; then
		bump=("$VERSION_TYPE")
		PRERELEASE_FLAG=""
	elif [[ "$RELEASE_TYPE" == "unnamed" ]]; then
		if [[ "$current_version" =~ -[0-9]+$ ]]; then
			bump=(prerelease)
		else
			bump=("pre$VERSION_TYPE")
		fi
		PRERELEASE_FLAG="--prerelease"
	else
		if [[ "$current_version" =~ -${PRERELEASE_SUFFIX}\.[0-9]+$ ]]; then
			bump=(prerelease)
		else
			bump=("pre$VERSION_TYPE" "--preid=$PRERELEASE_SUFFIX")
		fi
		PRERELEASE_FLAG="--prerelease"
	fi

	if [[ "$DRY_RUN" == "true" ]]; then
		run pnpm version "${bump[@]}"
		TAG_NAME="v$(preview_version "${bump[@]}")"
		note "  $current_version → ${TAG_NAME#v}"
	else
		pnpm version "${bump[@]}"
		TAG_NAME="v$(package_version)"
	fi
}

update-changelog() {
	local changelog_file="CHANGELOG.md"
	[[ -f "$changelog_file" ]] || error "$changelog_file not found"

	local version="${TAG_NAME#v}"
	local temp_file awk_status=0
	temp_file=$(mktemp)

	# The tag is dropped here and recreated after the amend, so that it ends up
	# on the commit carrying both the bumped version and the changelog entry.
	[[ "$DRY_RUN" == "true" ]] || git tag -d "$TAG_NAME"

	awk -v version="$version" -v date="$(date '+%Y–%m–%d')" '
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

		if (match($0, /^\[Unreleased\]: (.+\/compare\/v)([0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?)(\.\.\.HEAD)$/, parts)) {
			base_url = parts[1]
			prev_version = parts[2]

			print "[Unreleased]: " base_url version "...HEAD"
			print "[" version "]: " base_url prev_version "...v" version
		} else {
			print "Could not parse [Unreleased] link: " $0 > "/dev/stderr"
			exit 1
		}
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
	' "$changelog_file" > "$temp_file" || awk_status=$?

	# `set -e` would otherwise abort right here, before the diagnosis below.
	if [[ "$awk_status" -ne 0 ]] || [[ ! -s "$temp_file" ]] || ! grep -q "\[$version\]:" "$temp_file"; then
		rm -f "$temp_file"
		error "$changelog_file could not be rewritten"
	fi

	if [[ "$DRY_RUN" == "true" ]]; then
		note "→ $changelog_file would change:"
		# `diff` reports 1 whenever the files differ, which is the whole point.
		diff --unified=1 "$changelog_file" "$temp_file" | tail -n +3 || true
		rm -f "$temp_file"
		note "→ amend the version commit with $changelog_file, then tag $TAG_NAME"
		run git push origin "$CURRENT_BRANCH"
		run git push origin "refs/tags/$TAG_NAME"
		return
	fi

	mv "$temp_file" "$changelog_file"

	git add "$changelog_file"
	git commit --amend --no-edit -n
	git tag "$TAG_NAME"

	# A rejected push has to stop the release: publishing and the GitHub
	# release both come next, and both would point at an unpushed commit.
	git push origin "$CURRENT_BRANCH"

	if git ls-remote --tags origin | grep -q "refs/tags/$TAG_NAME"; then
		git push --force origin "refs/tags/$TAG_NAME"
	else
		git push origin "refs/tags/$TAG_NAME"
	fi
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

	if [[ "${CI:-}" == "true" ]]; then
		run pnpm publish --provenance --access public --tag "$npm_tag"
	else
		run pnpm publish --access public --tag "$npm_tag" --otp="$NPM_OTP"
	fi
}

create_github_release() {
	if ! command -v gh >/dev/null 2>&1; then
		error "GitHub CLI (gh) is required but not installed.\nInstall from: https://cli.github.com"
	fi

	if [[ "${CI:-}" != "true" ]] && [[ -z "${GITHUB_TOKEN:-}" ]] && ! gh auth status >/dev/null 2>&1; then
		error "GitHub CLI not authenticated.\nRun 'gh auth login' or set GITHUB_TOKEN environment variable."
	fi

	if [[ "$DRY_RUN" == "true" ]]; then
		note "→ gh release create $TAG_NAME --title \"Release $TAG_NAME\"${PRERELEASE_FLAG:+ $PRERELEASE_FLAG}"
		note "  with these notes:"
		echo "$RELEASE_DESCRIPTION"
	else
		echo "$RELEASE_DESCRIPTION" | gh release create "$TAG_NAME" \
			--title "Release $TAG_NAME" \
			--notes-file - \
			$PRERELEASE_FLAG
	fi

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
    • “release”       → stable release     (e.g., 1.0.0)
    • “release-alpha” → prerelease         (e.g., 1.0.0-alpha.0)
    • “release-beta”  → prerelease         (e.g., 1.0.0-beta.0)
    • “release-rc”    → release candidate  (e.g., 1.0.0-rc.0)
    • or another prerelease name, even...
    • “release-”      → unnamed prerelease (e.g., 1.0.0-0)

VERSION DETECTION:
    • ### Changed → major version bump
    • ### Added   → minor version bump
    • ### Fixed   → patch version bump

    No other heading is recognised. See the README for how the remaining
    Keep a Changelog headings fold into these three.

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
	detect_version_type
	create_version
	update-changelog
	publish_to_npm
	create_github_release
}

main "$@"
