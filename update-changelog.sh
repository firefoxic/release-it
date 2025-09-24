#!/usr/bin/env bash

set -uo pipefail

readonly CHANGELOG_FILE="CHANGELOG.md"
readonly PACKAGE_JSON="package.json"

error() {
	echo -e "\033[0;31mError: $1\033[0m" >&2
	exit 1
}

update-changelog() {
	[[ -f "$CHANGELOG_FILE" ]] || error "$CHANGELOG_FILE not found"
	[[ -f "$PACKAGE_JSON" ]] || error "$PACKAGE_JSON not found"

	tag_name=$(git tag --points-at HEAD)
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
	' "$CHANGELOG_FILE" > "$temp_file"

	if [[ $? -ne 0 ]] || [[ ! -s "$temp_file" ]] || ! grep -q "\[$version\]:" "$temp_file"; then
		rm -f "$temp_file"
		error "AWK processing failed"
	fi

	mv "$temp_file" "$CHANGELOG_FILE"

	git tag -d $tag_name
	git add "$CHANGELOG_FILE" 2>/dev/null || true
	git commit --amend --no-edit -n
	git tag $tag_name
}

update-changelog
