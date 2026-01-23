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

error() {
	echo -e "\033[0;31mError: $1\033[0m" >&2
	exit 1
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

setup_authentication() {
	if [[ "${CI:-}" == "true" ]]; then
		git config --global user.email "actions@users.noreply.github.com"
		git config --global user.name "GitHub Actions"
	else
		echo -n "Enter NPM OTP: "
		read -r NPM_OTP
	fi
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

create_version() {
	local current_version=$(jq -r '.version' package.json)

	if [[ "$RELEASE_TYPE" == "stable" ]]; then
		npm version "$VERSION_TYPE"
		PRERELEASE_FLAG=""
	elif [[ "$RELEASE_TYPE" == "unnamed" ]]; then
		if [[ "$current_version" =~ -[0-9]+$ ]]; then
			npm version prerelease
		else
			npm version "pre$VERSION_TYPE"
		fi
		PRERELEASE_FLAG="--prerelease"
	else
		if [[ "$current_version" =~ -${PRERELEASE_SUFFIX}\.[0-9]+$ ]]; then
			npm version prerelease
		else
			npm version "pre$VERSION_TYPE" --preid="$PRERELEASE_SUFFIX"
		fi
		PRERELEASE_FLAG="--prerelease"
	fi

	TAG_NAME=$(git describe --tags --abbrev=0)
}

update-changelog() {
	local changelog_file="CHANGELOG.md"
	[[ -f "$changelog_file" ]] || error "$changelog_file not found"

	tag_name=$(git tag --points-at HEAD)
	git tag -d $tag_name

	version=${tag_name#v}
	temp_file=$(mktemp)

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
	' "$changelog_file" > "$temp_file"

	if [[ $? -ne 0 ]] || [[ ! -s "$temp_file" ]] || ! grep -q "\[$version\]:" "$temp_file"; then
		rm -f "$temp_file"
		error "AWK processing failed"
	fi

	mv "$temp_file" "$changelog_file"

	git add "$changelog_file" 2>/dev/null || true
	git commit --amend --no-edit -n
	git tag $tag_name
	git push origin "$CURRENT_BRANCH" || true

	if git ls-remote --tags origin | grep -q "refs/tags/$tag_name"; then
		git push --force origin "refs/tags/$tag_name"
	else
		git push origin "refs/tags/$tag_name"
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
		npm publish --provenance --access public --tag "$npm_tag"
	else
		npm publish --access public --tag "$npm_tag" --otp="$NPM_OTP"
	fi
}

create_github_release() {
	if ! command -v gh >/dev/null 2>&1; then
		error "GitHub CLI (gh) is required but not installed.\nInstall from: https://cli.github.com"
	fi

	if [[ "${CI:-}" != "true" ]] && [[ -z "${GITHUB_TOKEN:-}" ]] && ! gh auth status >/dev/null 2>&1; then
		error "GitHub CLI not authenticated.\nRun 'gh auth login' or set GITHUB_TOKEN environment variable."
	fi

	echo "$RELEASE_DESCRIPTION" | gh release create "$TAG_NAME" \
		--title "Release $TAG_NAME" \
		--notes-file - \
		$PRERELEASE_FLAG

	git fetch --all
	git switch main
	git rebase "$CURRENT_BRANCH"
	git push origin main
}

show_help() {
	cat << EOF
📦 Bump, publish and release new version for npm package

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help     Show this help message

REQUIREMENTS:
    • Node.js
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

AUTHENTICATION:
    • Local: Enter OTP interactively
    • CI: Uses NPM trusted publishing
    • GitHub Release: Requires 'gh auth login' or GITHUB_TOKEN

EXAMPLES:
    $0                          # Interactive OTP
    GITHUB_TOKEN=... $0         # With GitHub release
    gh auth login && $0         # GitHub auth via CLI

EOF
}

main() {
	while [[ $# -gt 0 ]]; do
		case $1 in
			-h|--help)
				show_help
				exit 0
				;;
			*)
				show_help
				error "Unknown option: $1"
				;;
		esac
	done

	validate_release_branch
	setup_authentication
	detect_version_type
	create_version
	update-changelog
	publish_to_npm
	create_github_release
}

main "$@"
