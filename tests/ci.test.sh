# Under CI the script authenticates differently: a bot identity for git and
# trusted publishing instead of an OTP prompt.

test_ci_publishes_with_provenance_and_without_an_otp() {
	make_repo 1.2.3 release

	CI=true run_release_it
	assert_succeeded

	local args
	args="$(published_args)"

	assert_contains "$args" "--provenance"
	assert_contains "$args" "--tag latest"
	assert_not_contains "$args" "--otp"
}

test_ci_configures_a_bot_git_identity() {
	make_repo 1.2.3 release

	CI=true run_release_it
	assert_succeeded

	assert_contains "$(cat "$GIT_CONFIG_GLOBAL")" "actions@users.noreply.github.com"
}
