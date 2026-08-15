# The release must not continue past a push it could not make.

# Simulates a colleague pushing to the release branch first.
advance_the_remote_branch() {
	git clone -q "$ORIGIN" "$SANDBOX/other"
	git -C "$SANDBOX/other" config user.email "other@example.com"
	git -C "$SANDBOX/other" config user.name "Other"
	git -C "$SANDBOX/other" switch -q release
	git -C "$SANDBOX/other" commit -q --allow-empty -m "Someone else's work"
	git -C "$SANDBOX/other" push -q origin release
}

test_a_rejected_branch_push_stops_the_release() {
	make_repo 1.2.3 release
	advance_the_remote_branch

	run_release_it

	assert_failed
	assert_contains "$RELEASE_ERR" "rejected"
	assert_eq "" "$(published_args)" "nothing is published"
	assert_eq "" "$(gh_args)" "no GitHub release is created"
}

test_a_rejected_branch_push_leaves_the_tag_off_the_remote() {
	make_repo 1.2.3 release
	advance_the_remote_branch

	run_release_it

	assert_failed
	assert_not_contains "$(git ls-remote --tags "$ORIGIN")" "refs/tags/v1.3.0"
}

test_a_missing_remote_stops_the_release() {
	make_repo 1.2.3 release
	git remote remove origin

	run_release_it

	assert_failed
	assert_eq "" "$(published_args)" "nothing is published"
}
