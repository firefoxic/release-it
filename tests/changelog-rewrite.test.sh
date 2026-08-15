# A changelog the rewriter cannot handle must be reported, not silently fatal.

test_reports_a_missing_unreleased_link() {
	make_repo 1.2.3 release
	grep -v '^\[Unreleased\]: ' CHANGELOG.md > CHANGELOG.next
	mv CHANGELOG.next CHANGELOG.md
	git commit -qam "Drop the [Unreleased] link"

	run_release_it

	assert_failed
	assert_contains "$RELEASE_ERR" "[Unreleased] link not found"
	assert_contains "$RELEASE_ERR" "CHANGELOG.md could not be rewritten"
	assert_eq "" "$(published_args)" "nothing is published"
	assert_eq "" "$(gh_args)" "no GitHub release is created"
}

test_reports_an_unparsable_unreleased_link() {
	make_repo 1.2.3 release
	sed -i 's|^\[Unreleased\]: .*|[Unreleased]: https://example.com/whatever|' CHANGELOG.md
	git commit -qam "Mangle the [Unreleased] link"

	run_release_it

	assert_failed
	assert_contains "$RELEASE_ERR" "Could not parse [Unreleased] link"
	assert_contains "$RELEASE_ERR" "CHANGELOG.md could not be rewritten"
}

# The section detector matches the heading loosely, the rewriter anchors it,
# so a stray trailing space gets past the first and trips the second.
test_reports_a_heading_the_rewriter_cannot_anchor() {
	make_repo 1.2.3 release
	sed -i 's|^## \[Unreleased\]$|## [Unreleased] |' CHANGELOG.md
	git commit -qam "Add a trailing space to the [Unreleased] heading"

	run_release_it

	assert_failed
	assert_contains "$RELEASE_ERR" "## [Unreleased] header not found"
	assert_contains "$RELEASE_ERR" "CHANGELOG.md could not be rewritten"
}

test_dry_run_reports_a_broken_changelog_too() {
	make_repo 1.2.3 release
	grep -v '^\[Unreleased\]: ' CHANGELOG.md > CHANGELOG.next
	mv CHANGELOG.next CHANGELOG.md
	git commit -qam "Drop the [Unreleased] link"

	run_release_it --dry-run

	assert_failed
	assert_contains "$RELEASE_ERR" "CHANGELOG.md could not be rewritten"
	assert_eq "1.2.3" "$(package_version)" "the dry run still changes nothing"
}
