# render_changelog is a pure function once its date is pinned: it reads one
# changelog and writes the rewritten one to stdout. Sourcing the script gives
# direct access to it — the guard at the bottom of release-it.sh keeps `main`
# from running. These tests cover the successful renderings byte for byte
# (the typography — NBSP, em dash, en dashes — is part of the format); the
# failure modes are covered end to end in changelog-rewrite.test.sh.
# shellcheck source=../release-it.sh
source "$RELEASE_IT"

FIXED_DATE="2026–08–31"

test_renders_a_release_between_existing_ones() {
	cd "$SANDBOX" || bail "cannot enter $SANDBOX"
	write_changelog 1.2.3 $'### Added\n\n- A brand new thing.'

	local expected
	expected="$(
		printf '# Changelog\n\n'
		printf '## [Unreleased]\n\n'
		printf '## [1.3.0]%s%s %s\n\n' "$NBSP" "$EM_DASH" "$FIXED_DATE"
		printf '### Added\n\n- A brand new thing.\n\n'
		printf '## [1.2.3]%s%s 2026%s01%s01\n\n' "$NBSP" "$EM_DASH" "$EN_DASH" "$EN_DASH"
		printf '### Fixed\n\n- An older fix.\n\n'
		printf '[Unreleased]: https://github.com/acme/widget/compare/v1.3.0...HEAD\n'
		printf '[1.3.0]: https://github.com/acme/widget/compare/v1.2.3...v1.3.0\n'
		printf '[1.2.3]: https://github.com/acme/widget/releases/tag/v1.2.3\n'
	)"

	assert_eq "$expected" "$(render_changelog CHANGELOG.md 1.3.0 v "$FIXED_DATE")" "the rendered changelog differs"
}

# The very first release: no release headings in the body yet, the link
# definitions come right after the [Unreleased] section.
test_renders_the_first_release_with_no_prior_headings() {
	cd "$SANDBOX" || bail "cannot enter $SANDBOX"
	{
		printf '# Changelog\n\n'
		printf '## [Unreleased]\n\n'
		printf '### Added\n\n- The very first feature.\n\n'
		printf '[Unreleased]: https://github.com/acme/widget/compare/v0.0.0...HEAD\n'
		printf '[0.0.0]: https://github.com/acme/widget/releases/tag/v0.0.0\n'
	} > CHANGELOG.md

	local expected
	expected="$(
		printf '# Changelog\n\n'
		printf '## [Unreleased]\n\n'
		printf '## [0.1.0]%s%s %s\n\n' "$NBSP" "$EM_DASH" "$FIXED_DATE"
		printf '### Added\n\n- The very first feature.\n\n'
		printf '[Unreleased]: https://github.com/acme/widget/compare/v0.1.0...HEAD\n'
		printf '[0.1.0]: https://github.com/acme/widget/compare/v0.0.0...v0.1.0\n'
		printf '[0.0.0]: https://github.com/acme/widget/releases/tag/v0.0.0\n'
	)"

	assert_eq "$expected" "$(render_changelog CHANGELOG.md 0.1.0 v "$FIXED_DATE")" "the rendered changelog differs"
}

test_moves_a_prerelease_track_link_along() {
	cd "$SANDBOX" || bail "cannot enter $SANDBOX"
	write_changelog 1.0.0-beta.0 $'### Added\n\n- A brand new thing.'

	local output
	output="$(render_changelog CHANGELOG.md 1.0.0-beta.1 v "$FIXED_DATE")"

	assert_contains "$output" "## [1.0.0-beta.1]${NBSP}${EM_DASH} ${FIXED_DATE}"
	assert_contains "$output" '[Unreleased]: https://github.com/acme/widget/compare/v1.0.0-beta.1...HEAD'
	assert_contains "$output" '[1.0.0-beta.1]: https://github.com/acme/widget/compare/v1.0.0-beta.0...v1.0.0-beta.1'
}

# A workspace package tags as `<name>@<version>`, and a scoped name puts a
# second `@` and a slash into the compare link.
test_renders_a_scoped_workspace_package_link() {
	cd "$SANDBOX" || bail "cannot enter $SANDBOX"
	write_changelog 1.2.3 $'### Fixed\n\n- A fix.' '@firefoxic/widget@'

	local output
	output="$(render_changelog CHANGELOG.md 1.2.4 '@firefoxic/widget@' "$FIXED_DATE")"

	assert_contains "$output" "## [1.2.4]${NBSP}${EM_DASH} ${FIXED_DATE}"
	assert_contains "$output" '[Unreleased]: https://github.com/acme/widget/compare/@firefoxic/widget@1.2.4...HEAD'
	assert_contains "$output" '[1.2.4]: https://github.com/acme/widget/compare/@firefoxic/widget@1.2.3...@firefoxic/widget@1.2.4'
}

# Without a fourth argument the heading carries today's date — the shape the
# release pipeline itself relies on.
test_defaults_to_todays_date() {
	cd "$SANDBOX" || bail "cannot enter $SANDBOX"
	write_changelog 1.2.3 $'### Added\n\n- A brand new thing.'

	assert_contains "$(render_changelog CHANGELOG.md 1.3.0 v)" "$(release_heading 1.3.0)"
}
