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

test_version_flag_prints_the_tools_own_version() {
	make_repo 4.5.6

	run_release_it --version

	assert_succeeded
	assert_eq "$(own_version)" "$RELEASE_OUT" "release-it reports itself, not the project it would release"
	assert_not_contains "$RELEASE_OUT" "4.5.6"
}

# How package managers actually expose the bin: a link in `node_modules/.bin`.
test_version_flag_follows_a_symlinked_bin() {
	make_repo 4.5.6
	mkdir -p "$SANDBOX/bin-link"
	ln -s "$RELEASE_IT" "$SANDBOX/bin-link/release-it"

	RELEASE_OUT="$("$SANDBOX/bin-link/release-it" --version 2>"$SANDBOX/stderr")"
	RELEASE_STATUS=$?

	assert_succeeded
	assert_eq "$(own_version)" "$RELEASE_OUT"
}
