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
