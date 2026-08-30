# A pnpm workspace: every package with an [Unreleased] entry is released,
# with its own version, tag, npm publish and GitHub release, in one commit.

two_packages() {
	make_workspace
	add_package packages/widget widget 1.2.3
	add_package packages/gadget gadget 0.4.0 $'### Fixed\n\n- A gadget fix.'
	finish_workspace "${1:-release}"
}

test_every_package_with_changes_is_released() {
	two_packages
	run_release_it
	assert_succeeded

	assert_eq "1.3.0" "$(pnpm -C packages/widget pkg get version)"
	assert_eq "0.4.1" "$(pnpm -C packages/gadget pkg get version)"
}

test_packages_without_changes_are_left_alone() {
	make_workspace
	add_package packages/widget widget 1.2.3
	add_package packages/gadget gadget 0.4.0 ""
	finish_workspace
	run_release_it
	assert_succeeded

	assert_eq "0.4.0" "$(pnpm -C packages/gadget pkg get version)"
	assert_eq "widget@1.3.0" "$(git tag --points-at HEAD)" "the untouched package gets no tag"
	assert_not_contains "$(published_args)" "gadget" "the untouched package is not published"
	assert_not_contains "$(git show --name-only --format= HEAD)" "gadget"
}

test_the_root_and_private_packages_are_never_released() {
	make_workspace
	add_package packages/widget widget 1.2.3
	add_package packages/internal internal 0.1.0 $'### Added\n\n- Something internal.' true
	finish_workspace
	run_release_it
	assert_succeeded

	assert_eq "0.1.0" "$(pnpm -C packages/internal pkg get version)"
	assert_not_contains "$(published_args)" "internal"
	assert_not_contains "$(published_args)" "monorepo"
	assert_eq "widget@1.3.0" "$(git tag --points-at HEAD)"
}

test_the_root_needs_no_changelog() {
	two_packages
	[[ ! -f CHANGELOG.md ]] || bail "the fixture root should have no changelog"

	run_release_it
	assert_succeeded
}

test_tags_carry_the_package_name() {
	two_packages
	run_release_it
	assert_succeeded

	assert_eq $'gadget@0.4.1\nwidget@1.3.0' "$(git tag --points-at HEAD | sort)"
	assert_contains "$(git ls-remote --tags "$ORIGIN")" "refs/tags/widget@1.3.0"
	assert_contains "$(git ls-remote --tags "$ORIGIN")" "refs/tags/gadget@0.4.1"
}

test_scoped_names_work_in_tags_and_links() {
	make_workspace
	add_package packages/widget @acme/widget 1.2.3
	finish_workspace
	run_release_it
	assert_succeeded

	assert_eq "@acme/widget@1.3.0" "$(git tag --points-at HEAD)"
	assert_contains "$(cat packages/widget/CHANGELOG.md)" "[1.3.0]: https://github.com/acme/widget/compare/@acme/widget@1.2.3...@acme/widget@1.3.0"
	assert_contains "$(published_args)" "-C packages/widget publish"
}

test_all_bumps_and_changelogs_share_one_commit() {
	two_packages
	local before
	before="$(git rev-parse HEAD)"

	run_release_it
	assert_succeeded

	assert_eq "$before" "$(git rev-parse HEAD~1)" "exactly one commit was added"
	local touched
	touched="$(git show --name-only --format= HEAD)"
	assert_contains "$touched" "packages/widget/package.json"
	assert_contains "$touched" "packages/widget/CHANGELOG.md"
	assert_contains "$touched" "packages/gadget/package.json"
	assert_contains "$touched" "packages/gadget/CHANGELOG.md"
	assert_eq "gadget@0.4.1, widget@1.3.0" "$(git log -1 --format=%s)"
}

test_each_changelog_is_rewritten_with_its_own_tags() {
	two_packages
	run_release_it
	assert_succeeded

	local widget gadget
	widget="$(cat packages/widget/CHANGELOG.md)"
	gadget="$(cat packages/gadget/CHANGELOG.md)"

	assert_contains "$widget" "$(release_heading 1.3.0)"
	assert_contains "$widget" "[Unreleased]: https://github.com/acme/widget/compare/widget@1.3.0...HEAD"
	assert_contains "$widget" "[1.3.0]: https://github.com/acme/widget/compare/widget@1.2.3...widget@1.3.0"
	assert_contains "$gadget" "$(release_heading 0.4.1)"
	assert_contains "$gadget" "[0.4.1]: https://github.com/acme/widget/compare/gadget@0.4.0...gadget@0.4.1"
}

test_each_package_is_published_from_its_directory() {
	two_packages
	run_release_it
	assert_succeeded

	assert_contains "$(published_args)" "-C packages/widget publish --access public --tag latest"
	assert_contains "$(published_args)" "-C packages/gadget publish --access public --tag latest"
}

test_each_package_gets_its_own_github_release() {
	two_packages
	run_release_it
	assert_succeeded

	assert_contains "$(gh_args)" "release create widget@1.3.0 --title Release widget@1.3.0"
	assert_contains "$(gh_args)" "release create gadget@0.4.1 --title Release gadget@0.4.1"
	assert_contains "$(gh_notes)" "- A brand new thing."
	assert_contains "$(gh_notes)" "- A gadget fix."
}

test_main_is_rebased_once() {
	two_packages
	run_release_it
	assert_succeeded

	assert_eq "main" "$(git branch --show-current)"
	assert_eq "$(git rev-parse release)" "$(git rev-parse origin/main)"
}

test_a_prerelease_branch_applies_to_every_package() {
	two_packages release-beta
	run_release_it
	assert_succeeded

	assert_eq "1.3.0-beta.0" "$(pnpm -C packages/widget pkg get version)"
	assert_eq "0.4.1-beta.0" "$(pnpm -C packages/gadget pkg get version)"
	assert_contains "$(published_args)" "-C packages/widget publish --access public --tag beta"
	assert_contains "$(gh_args)" "release create gadget@0.4.1-beta.0 --title Release gadget@0.4.1-beta.0 --notes-file - --prerelease"
}

test_first_major_is_cut_for_every_package() {
	make_workspace
	add_package packages/widget widget 0.9.0
	add_package packages/gadget gadget 0.2.0 $'### Fixed\n\n- A gadget fix.'
	finish_workspace release-first-major
	run_release_it
	assert_succeeded

	assert_eq "1.0.0" "$(pnpm -C packages/widget pkg get version)"
	assert_eq "1.0.0" "$(pnpm -C packages/gadget pkg get version)"
}

test_first_major_refuses_a_package_already_past_it() {
	two_packages release-first-major
	run_release_it

	assert_failed
	assert_contains "$RELEASE_ERR" "packages/widget is at 1.2.3"
	assert_eq "" "$(published_args)"
}

test_rejects_a_workspace_with_nothing_to_release() {
	make_workspace
	add_package packages/widget widget 1.2.3 ""
	finish_workspace
	run_release_it

	assert_failed
	assert_contains "$RELEASE_ERR" "No package has changes"
	assert_eq "" "$(published_args)"
}

test_rejects_a_workspace_of_private_packages_only() {
	make_workspace
	add_package packages/internal internal 0.1.0 $'### Added\n\n- Something.' true
	finish_workspace
	run_release_it

	assert_failed
	assert_contains "$RELEASE_ERR" "every one of them is private"
}

test_a_broken_changelog_stops_the_whole_release() {
	make_workspace
	add_package packages/widget widget 1.2.3
	add_package packages/gadget gadget 0.4.0 $'### Fixed\n\n- A gadget fix.'
	sed -i 's|^\[Unreleased\]: .*|[Unreleased]: https://example.com/whatever|' packages/gadget/CHANGELOG.md
	finish_workspace
	run_release_it

	assert_failed
	assert_contains "$RELEASE_ERR" "packages/gadget/CHANGELOG.md could not be rewritten"
	assert_eq "1.2.3" "$(pnpm -C packages/widget pkg get version)" "the other bump is taken back"
	assert_eq "" "$(git status --porcelain)" "the working tree is left clean"
	assert_eq "" "$(published_args)"
}

test_dry_run_previews_every_package_and_changes_nothing() {
	two_packages
	local head
	head="$(git rev-parse HEAD)"

	run_release_it --dry-run
	assert_succeeded

	assert_contains "$RELEASE_OUT" "→ pnpm -C packages/widget version minor"
	assert_contains "$RELEASE_OUT" "1.2.3 → 1.3.0"
	assert_contains "$RELEASE_OUT" "→ pnpm -C packages/gadget version patch"
	assert_contains "$RELEASE_OUT" "0.4.0 → 0.4.1"
	assert_contains "$RELEASE_OUT" "→ packages/gadget/CHANGELOG.md would change:"
	assert_contains "$RELEASE_OUT" "→ gh release create widget@1.3.0"
	assert_eq "$head" "$(git rev-parse HEAD)"
	assert_eq "" "$(git status --porcelain)"
	assert_eq "1.2.3" "$(pnpm -C packages/widget pkg get version)"
	assert_eq "" "$(published_args)"
}

test_a_package_before_its_first_release_can_sit_a_release_out() {
	make_workspace
	add_package packages/widget widget 1.2.3
	add_package packages/gadget gadget 0.0.1 ""
	# A changelog with no releases yet: [Unreleased] is followed directly by
	# its link definition, which must not be mistaken for release notes.
	printf '# Changelog\n\n## [Unreleased]\n\n[Unreleased]: https://github.com/acme/widget/compare/gadget@0.0.1...HEAD\n' > packages/gadget/CHANGELOG.md
	finish_workspace
	run_release_it
	assert_succeeded

	assert_eq "0.0.1" "$(pnpm -C packages/gadget pkg get version)"
	assert_eq "widget@1.3.0" "$(git tag --points-at HEAD)"
}
