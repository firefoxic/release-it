#!/usr/bin/env bash
#
# Test runner for release-it.
#
#   tests/run.sh                 run every test
#   tests/run.sh changelog       run only tests whose suite or name matches
#   KEEP_SANDBOX=1 tests/run.sh  leave the temporary repositories in place
#
# Each test function runs in its own process with a fresh sandbox.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Internal entry point: run one test function and exit with its status.
if [[ "${1:-}" == "--one" ]]; then
	# shellcheck source=tests/helpers.sh
	source "$TESTS_DIR/helpers.sh"
	# shellcheck source=/dev/null
	source "$2"
	setup_sandbox
	"$3"
	exit $?
fi

if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
	GREEN=$'\033[0;32m' RED=$'\033[0;31m' DIM=$'\033[2m' RESET=$'\033[0m'
else
	GREEN="" RED="" DIM="" RESET=""
fi

for tool in git pnpm; do
	command -v "$tool" >/dev/null 2>&1 || {
		printf '%s is required to run the tests\n' "$tool" >&2
		exit 1
	}
done

pattern=${1:-}
passed=0
failed=0

for file in "$TESTS_DIR"/*.test.sh; do
	suite="$(basename "$file" .test.sh)"
	printed_suite=""

	while read -r fn; do
		[[ -n "$pattern" ]] && [[ "$suite/$fn" != *"$pattern"* ]] && continue

		if [[ -z "$printed_suite" ]]; then
			printf '%s%s%s\n' "$DIM" "$suite" "$RESET"
			printed_suite="yes"
		fi

		output="$("$TESTS_DIR/run.sh" --one "$file" "$fn" 2>&1)"

		if [[ $? -eq 0 ]]; then
			passed=$((passed + 1))
			printf '  %s✓%s %s\n' "$GREEN" "$RESET" "${fn#test_}"
		else
			failed=$((failed + 1))
			printf '  %s✗ %s%s\n' "$RED" "${fn#test_}" "$RESET"
			[[ -n "$output" ]] && printf '%s\n' "$output" | sed 's/^/      /'
		fi
	done < <(grep -o '^test_[A-Za-z0-9_]*' "$file")
done

printf '\n%s passed, %s failed\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
