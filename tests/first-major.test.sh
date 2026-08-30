# Below 1.0.0 breaking changes stay in the 0.x range; 1.0.0 is cut on purpose.

test_changed_bumps_the_minor_version_below_first_major() {
	release_from 0.4.2 release $'### Changed\n\n- A breaking change.'

	assert_eq "0.5.0" "$(package_version)"
	assert_contains "$RELEASE_OUT" "0.4.2 is below 1.0.0"
	assert_contains "$(published_args)" "--tag latest"
}

test_changed_caps_a_prerelease_below_first_major() {
	release_from 0.4.2 release-beta $'### Changed\n\n- A breaking change.'

	assert_eq "0.5.0-beta.0" "$(package_version)"
}

test_first_major_branch_releases_1_0_0() {
	release_from 0.4.2 release-first-major $'### Fixed\n\n- A small thing, and yet 1.0.0.'

	assert_eq "1.0.0" "$(package_version)"
	assert_eq "v1.0.0" "$(git describe --tags --exact-match)"
	assert_contains "$(published_args)" "--tag latest"
	assert_not_contains "$(gh_args)" "--prerelease"
	assert_contains "$(gh_args)" "release create v1.0.0"
}

test_first_major_branch_still_needs_release_notes() {
	make_repo 0.4.2 release-first-major ""

	run_release_it

	assert_failed
	assert_contains "$RELEASE_ERR" "No changes found in CHANGELOG.md [Unreleased] section"
	assert_eq "0.4.2" "$(package_version)" "the version stays untouched"
}

test_first_major_branch_refuses_an_already_released_major() {
	make_repo 1.2.3 release-first-major

	run_release_it

	assert_failed
	assert_contains "$RELEASE_ERR" "The first major version has already been released (1.2.3)"
	assert_eq "1.2.3" "$(package_version)" "the version stays untouched"
	assert_eq "" "$(published_args)" "nothing is published"
}

test_dry_run_reports_the_first_major() {
	make_repo 0.4.2 release-first-major

	run_release_it --dry-run
	assert_succeeded

	assert_contains "$RELEASE_OUT" "0.4.2 → 1.0.0"
	assert_eq "0.4.2" "$(package_version)"
}
