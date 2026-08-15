# The [Unreleased] headings decide the semver bump.

test_changed_bumps_the_major_version() {
	release_from 1.2.3 release $'### Changed\n\n- A breaking change.'

	assert_eq "2.0.0" "$(package_version)"
}

test_added_bumps_the_minor_version() {
	release_from 1.2.3 release $'### Added\n\n- A brand new thing.'

	assert_eq "1.3.0" "$(package_version)"
}

test_fixed_bumps_the_patch_version() {
	release_from 1.2.3 release $'### Fixed\n\n- An embarrassing bug.'

	assert_eq "1.2.4" "$(package_version)"
}

test_changed_outranks_added_and_fixed() {
	release_from 1.2.3 release $'### Changed\n\n- A breaking change.\n\n### Added\n\n- A brand new thing.\n\n### Fixed\n\n- An embarrassing bug.'

	assert_eq "2.0.0" "$(package_version)"
}

test_added_outranks_fixed() {
	release_from 1.2.3 release $'### Added\n\n- A brand new thing.\n\n### Fixed\n\n- An embarrassing bug.'

	assert_eq "1.3.0" "$(package_version)"
}
