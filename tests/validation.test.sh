# Preconditions that must stop the release before anything is bumped.

test_rejects_a_non_release_branch() {
	make_repo 1.2.3 main

	run_release_it

	assert_failed
	assert_contains "$RELEASE_ERR" "Release can only be made from 'release*' branches"
	assert_eq "1.2.3" "$(package_version)" "the version stays untouched"
}

test_requires_a_changelog() {
	make_repo
	rm CHANGELOG.md

	run_release_it

	assert_failed
	assert_contains "$RELEASE_ERR" "CHANGELOG.md not found"
}

test_rejects_an_empty_unreleased_section() {
	make_repo 1.2.3 release ""

	run_release_it

	assert_failed
	assert_contains "$RELEASE_ERR" "No changes found in CHANGELOG.md [Unreleased] section"
}

test_rejects_an_unsupported_unreleased_heading() {
	make_repo 1.2.3 release $'### Removed\n\n- Something went away.'

	run_release_it

	assert_failed
	assert_contains "$RELEASE_ERR" "does not follow the expected format"
	assert_eq "1.2.3" "$(package_version)" "the version stays untouched"
}
