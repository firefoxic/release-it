# Outside CI the npm session is opened before the release writes anything:
# an unauthenticated publish is only refused at the end of the pipeline, when
# the commit, the tag and the branch are already on the remote.

test_a_missing_session_is_opened_before_the_release_starts() {
	make_repo 1.2.3 release
	log_out_of_npm

	run_release_it
	assert_succeeded

	assert_contains "$(login_attempts)" "login"
	assert_contains "$RELEASE_OUT" "No npm session found"
	assert_contains "$(published_args)" "--otp=123456"
}

test_an_existing_session_is_left_alone() {
	release_from 1.2.3 release

	assert_eq "" "$(login_attempts)" "no login is attempted"
	assert_contains "$RELEASE_OUT" "Logged in to npm as tester"
}

test_a_failed_login_stops_the_release_before_anything_is_written() {
	make_repo 1.2.3 release
	log_out_of_npm
	export NPM_LOGIN_FAILS=true

	run_release_it

	assert_failed
	assert_contains "$RELEASE_ERR" "npm login failed"
	assert_eq "1.2.3" "$(package_version)" "the version is untouched"
	assert_eq "" "$(published_args)" "nothing is published"
	assert_eq "" "$(gh_args)" "no GitHub release is created"
	assert_not_contains "$(git ls-remote --tags "$ORIGIN")" "refs/tags/v1.3.0"
}

test_a_login_that_leaves_no_session_stops_the_release() {
	make_repo 1.2.3 release
	log_out_of_npm
	export NPM_LOGIN_IS_EMPTY=true

	run_release_it

	assert_failed
	assert_contains "$RELEASE_ERR" "no usable session"
	assert_eq "1.2.3" "$(package_version)" "the version is untouched"
	assert_eq "" "$(published_args)" "nothing is published"
}

test_ci_relies_on_trusted_publishing_and_never_logs_in() {
	make_repo 1.2.3 release
	log_out_of_npm

	CI=true run_release_it
	assert_succeeded

	assert_eq "" "$(login_attempts)" "no login is attempted under CI"
}

test_a_dry_run_reports_the_missing_session_without_opening_one() {
	make_repo 1.2.3 release
	log_out_of_npm

	run_release_it --dry-run
	assert_succeeded

	assert_contains "$RELEASE_OUT" "→ pnpm login"
	assert_eq "" "$(login_attempts)" "no login is attempted in a dry run"
}
