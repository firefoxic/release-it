#!/usr/bin/env bash

set -uo pipefail

readonly CHANGELOG_FILE="CHANGELOG.md"
readonly PACKAGE_JSON="package.json"

error() {
	echo -e "\033[0;31mError: $1\033[0m" >&2
	exit 1
}

[[ -f "$CHANGELOG_FILE" ]] || error "$CHANGELOG_FILE not found"
[[ -f "$PACKAGE_JSON" ]] || error "$PACKAGE_JSON not found"

tag_name=$(git tag --points-at HEAD)
version=${tag_name#v}
current_date=$(date '+%Y–%m–%d')

temp1=$(mktemp)
sed "/^## \[Unreleased\]$/a\\
\\
## [$version] — $current_date" "$CHANGELOG_FILE" > "$temp1"

prev_version=$(grep -oP '(?<=compare/v)[0-9]+\.[0-9]+\.[0-9]+(?=\.\.\.HEAD)' "$temp1" | head -1)

if [[ -z "$prev_version" ]]; then
	rm -f "$temp1"
	error "Could not extract previous version from changelog"
fi

temp2=$(mktemp)

sed -E "/^\[Unreleased\]: / {
	s/(compare\/v)[0-9]+\.[0-9]+\.[0-9]+(\.\.\.HEAD)/\1$version\2/
	a\\
[$version]: https://github.com/firefoxic/update-changelog/compare/v$prev_version...v$version
}" "$temp1" > "$temp2"

if [[ -s "$temp2" ]]; then
	mv "$temp2" "$CHANGELOG_FILE"
else
	rm -f "$temp1" "$temp2"
	error "Changelog updating failed"
fi

rm -f "$temp1"

git tag -d $tag_name
git add "$CHANGELOG_FILE" 2>/dev/null || true
git commit --amend --no-edit -n
git tag $tag_name
