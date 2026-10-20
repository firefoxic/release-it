# The branch name decides whether a release is stable and how it is suffixed.

test_named_prerelease_starts_a_new_track() {
	release_from 1.2.3 release-beta

	assert_eq "1.3.0-beta.0" "$(package_version)"
}

test_named_prerelease_increments_within_its_track() {
	release_from 1.3.0-beta.0 release-beta

	assert_eq "1.3.0-beta.1" "$(package_version)"
}

test_named_prerelease_restarts_when_the_suffix_differs() {
	release_from 1.3.0-beta.0 release-rc

	assert_eq "1.4.0-rc.0" "$(package_version)"
}

test_unnamed_prerelease_starts_a_new_track() {
	release_from 1.2.3 release-

	assert_eq "1.3.0-0" "$(package_version)"
}

test_unnamed_prerelease_increments_within_its_track() {
	release_from 1.3.0-0 release-

	assert_eq "1.3.0-1" "$(package_version)"
}

# A prerelease is committed in two: the version bump first, then the changelog.
# The branch is rolled back to the first, so the manifest keeps the prerelease
# version and the changelog stays untouched — ready for the next prerelease.
# The tag holds the changelog commit.

test_prerelease_splits_the_version_bump_from_the_changelog() {
	release_from 1.2.3 release-beta

	local bump_commit changelog_commit
	bump_commit="$(git rev-parse "v1.3.0-beta.0^")"
	changelog_commit="$(git rev-parse "v1.3.0-beta.0")"

	assert_eq "$bump_commit" "$(git rev-parse HEAD)" "the branch head is the version bump commit"
	assert_contains "$(git show --name-only --format= "$bump_commit")" "package.json"
	assert_not_contains "$(git show --name-only --format= "$bump_commit")" "CHANGELOG.md"
	assert_contains "$(git show --name-only --format= "$changelog_commit")" "CHANGELOG.md"
	assert_not_contains "$(git show --name-only --format= "$changelog_commit")" "package.json"
}

test_prerelease_leaves_the_changelog_for_the_next_one() {
	release_from 1.2.3 release-beta

	assert_contains "$(cat CHANGELOG.md)" "## [Unreleased]"
	assert_contains "$(cat CHANGELOG.md)" "### Added"
	assert_not_contains "$(cat CHANGELOG.md)" "$(release_heading 1.3.0-beta.0)"
}

test_prerelease_leaves_the_manifest_on_the_prerelease_version() {
	release_from 1.2.3 release-beta

	assert_eq "1.3.0-beta.0" "$(package_version)"
	assert_eq "$(git rev-parse release-beta)" "$(git rev-parse origin/release-beta)"
	assert_eq "$(git rev-parse main)" "$(git rev-parse origin/main)"
	assert_eq "" "$(git status --porcelain)"
}

test_prerelease_tag_carries_the_changelog_commit() {
	release_from 1.2.3 release-beta

	assert_contains "$(git show "v1.3.0-beta.0:CHANGELOG.md")" "$(release_heading 1.3.0-beta.0)"
	assert_contains "$(git ls-remote --tags "$ORIGIN")" "refs/tags/v1.3.0-beta.0"
}

test_a_prerelease_can_be_followed_by_the_next_one() {
	release_from 1.2.3 release-beta

	git switch -q release-beta
	run_release_it
	assert_succeeded

	assert_eq "1.3.0-beta.1" "$(package_version)"
	assert_contains "$(git show "v1.3.0-beta.1:CHANGELOG.md")" "$(release_heading 1.3.0-beta.1)"
}
