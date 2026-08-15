# What a finished release leaves behind: one commit, a rewritten changelog,
# a pushed tag, an npm publish and a GitHub release.

test_changelog_and_version_share_one_commit() {
	release_from 1.2.3 release

	local touched
	touched="$(git show --name-only --format= HEAD)"

	assert_contains "$touched" "package.json"
	assert_contains "$touched" "CHANGELOG.md"
	assert_eq "v1.3.0" "$(git tag --points-at HEAD)" "the tag points at that very commit"
}

test_changelog_gets_a_dated_release_heading() {
	release_from 1.2.3 release

	assert_contains "$(cat CHANGELOG.md)" "$(release_heading 1.3.0)"
}

test_changelog_keeps_an_emptied_unreleased_section() {
	release_from 1.2.3 release

	assert_contains "$(cat CHANGELOG.md)" "$(printf '## [Unreleased]\n\n%s' "$(release_heading 1.3.0)")"
}

test_changelog_entries_move_under_the_new_heading() {
	release_from 1.2.3 release

	assert_contains "$(cat CHANGELOG.md)" "$(printf '%s\n\n### Added\n\n- A brand new thing.' "$(release_heading 1.3.0)")"
}

test_changelog_links_are_rewritten() {
	release_from 1.2.3 release

	local changelog
	changelog="$(cat CHANGELOG.md)"

	assert_contains "$changelog" "[Unreleased]: https://github.com/acme/widget/compare/v1.3.0...HEAD"
	assert_contains "$changelog" "[1.3.0]: https://github.com/acme/widget/compare/v1.2.3...v1.3.0"
}

test_release_branch_and_tag_reach_the_remote() {
	release_from 1.2.3 release

	assert_eq "$(git rev-parse release)" "$(git rev-parse origin/release)"
	assert_contains "$(git ls-remote --tags "$ORIGIN")" "refs/tags/v1.3.0"
}

test_main_is_rebased_onto_the_release() {
	release_from 1.2.3 release

	assert_eq "main" "$(git branch --show-current)" "the script leaves the repository on main"
	assert_eq "$(git rev-parse release)" "$(git rev-parse main)"
	assert_eq "$(git rev-parse main)" "$(git rev-parse origin/main)"
}

test_stable_release_publishes_under_the_latest_tag() {
	release_from 1.2.3 release

	local args
	args="$(published_args)"

	assert_contains "$args" "--tag latest"
	assert_contains "$args" "--otp=123456"
	assert_not_contains "$args" "--provenance" "provenance is reserved for CI"
}

test_named_prerelease_publishes_under_its_own_tag() {
	release_from 1.2.3 release-beta

	assert_contains "$(published_args)" "--tag beta"
}

test_unnamed_prerelease_publishes_under_the_next_tag() {
	release_from 1.2.3 release-

	assert_contains "$(published_args)" "--tag next"
}

test_github_release_carries_the_changelog_entries() {
	release_from 1.2.3 release

	assert_contains "$(gh_args)" "release create v1.3.0 --title Release v1.3.0"
	assert_contains "$(gh_notes)" "- A brand new thing."
	assert_not_contains "$(gh_args)" "--prerelease" "a stable release is not a prerelease"
}

test_github_release_is_flagged_for_prereleases() {
	release_from 1.2.3 release-beta

	assert_contains "$(gh_args)" "release create v1.3.0-beta.0"
	assert_contains "$(gh_args)" "--prerelease"
}
