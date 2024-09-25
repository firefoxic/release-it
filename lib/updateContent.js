import { formatDate } from "./formatDate.js"
import { getNewVersion } from "./getNewVersion.js"
import { updateChangelogLinks } from "./updateChangelogLinks.js"

/**
 * Updates the content of the CHANGELOG.md file with the latest version.
 *
 * @param {string} content - The content of the CHANGELOG.md file.
 * @return {Promise<string>} - The updated content of the CHANGELOG.md file.
 * @throws {Error} - If the CHANGELOG.md format is invalid.
 */
export async function updateContent (content) {
	let separator = `[Unreleased]`
	let changelogParts = content.split(separator)

	if (changelogParts.length !== 3) throw new Error(`Invalid CHANGELOG.md: [Unreleased] link not found.`)

	let newVersion = await getNewVersion()
	let currentDate = formatDate((new Date))

	changelogParts[1] = `\n\n## [${newVersion}] — ${currentDate}${changelogParts[1]}`
	changelogParts[2] = updateChangelogLinks(changelogParts[2], newVersion)

	return changelogParts.join(separator)
}
