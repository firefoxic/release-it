# Flags that short-circuit before any release work happens.

test_help_flag_prints_usage() {
	run_release_it --help

	assert_succeeded
	assert_contains "$RELEASE_OUT" "USAGE:"
	assert_contains "$RELEASE_OUT" "BRANCH REQUIREMENTS:"
}

test_help_shorthand_prints_usage() {
	run_release_it -h

	assert_succeeded
	assert_contains "$RELEASE_OUT" "USAGE:"
}

test_unknown_option_reports_an_error() {
	run_release_it --nope

	assert_failed
	assert_contains "$RELEASE_ERR" "Unknown option: --nope"
	assert_contains "$RELEASE_OUT" "USAGE:"
}

test_version_flag_prints_a_version() {
	make_repo 4.5.6

	run_release_it --version

	assert_succeeded
	assert_eq "4.5.6" "$RELEASE_OUT" "the version of the surrounding project is reported"
}
