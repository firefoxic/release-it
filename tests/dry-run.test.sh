# --dry-run must report the whole release without leaving a trace.

test_dry_run_leaves_the_working_tree_alone() {
	make_repo 1.2.3 release
	local head changelog
	head="$(git rev-parse HEAD)"
	changelog="$(cat CHANGELOG.md)"

	run_release_it --dry-run
	assert_succeeded

	assert_eq "1.2.3" "$(package_version)"
	assert_eq "$changelog" "$(cat CHANGELOG.md)"
	assert_eq "$head" "$(git rev-parse HEAD)"
	assert_eq "release" "$(git branch --show-current)"
	assert_eq "" "$(git status --porcelain)"
}

test_dry_run_creates_no_tags() {
	make_repo 1.2.3 release

	run_release_it --dry-run
	assert_succeeded

	assert_eq "v1.2.3" "$(git tag)"
	assert_not_contains "$(git ls-remote --tags "$ORIGIN")" "refs/tags/v1.3.0"
}

test_dry_run_neither_publishes_nor_releases() {
	make_repo 1.2.3 release

	run_release_it --dry-run
	assert_succeeded

	assert_eq "" "$(published_args)" "nothing is published"
	assert_eq "" "$(gh_args)" "no GitHub release is created"
}

test_dry_run_reports_the_next_version() {
	make_repo 1.2.3 release

	run_release_it --dry-run
	assert_succeeded

	assert_contains "$RELEASE_OUT" "1.2.3 → 1.3.0"
	assert_contains "$RELEASE_OUT" "pnpm publish --access public --tag latest"
	assert_contains "$RELEASE_OUT" "gh release create v1.3.0"
}

test_dry_run_reports_a_prerelease() {
	make_repo 1.2.3 release-beta

	run_release_it --dry-run
	assert_succeeded

	assert_contains "$RELEASE_OUT" "1.2.3 → 1.3.0-beta.0"
	assert_contains "$RELEASE_OUT" "--tag beta"
	assert_contains "$RELEASE_OUT" "--prerelease"
}

test_dry_run_shows_the_changelog_diff() {
	make_repo 1.2.3 release

	run_release_it --dry-run
	assert_succeeded

	assert_contains "$RELEASE_OUT" "+$(release_heading 1.3.0)"
	assert_contains "$RELEASE_OUT" "+[1.3.0]: https://github.com/acme/widget/compare/v1.2.3...v1.3.0"
}

test_dry_run_shows_the_release_notes() {
	make_repo 1.2.3 release

	run_release_it --dry-run
	assert_succeeded

	assert_contains "$RELEASE_OUT" "- A brand new thing."
}

test_dry_run_never_asks_for_an_otp() {
	make_repo 1.2.3 release

	RELEASE_OUT="$("$RELEASE_IT" --dry-run </dev/null 2>"$SANDBOX/stderr")"
	RELEASE_STATUS=$?
	RELEASE_ERR="$(cat "$SANDBOX/stderr")"

	assert_succeeded
	assert_not_contains "$RELEASE_OUT" "Enter NPM_OTP"
}

test_dry_run_still_validates_the_branch() {
	make_repo 1.2.3 main

	run_release_it --dry-run

	assert_failed
	assert_contains "$RELEASE_ERR" "Release can only be made from 'release*' branches"
}

test_dry_run_still_validates_the_changelog() {
	make_repo 1.2.3 release ""

	run_release_it --dry-run

	assert_failed
	assert_contains "$RELEASE_ERR" "No changes found in CHANGELOG.md [Unreleased] section"
}
