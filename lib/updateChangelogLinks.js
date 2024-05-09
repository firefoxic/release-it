/**
 * Updates the CHANGELOG.md file by modifying the version link in the [Unreleased] section.
 *
 * @param {string} content - The content of the CHANGELOG.md file.
 * @param {string} newVersion - The new version number to be added.
 * @return {string} The modified CHANGELOG.md content.
 * @throws {Error} If the [Unreleased] link syntax is incorrect.
 */
export function updateChangelogLinks (content, newVersion) {
	let linkRegex = /(: .+\/compare\/v)([0-9.]+)(...HEAD)/
	let linkMatch = content.match(linkRegex)

	if (!linkMatch) throw new Error(`Invalid CHANGELOG.md: [Unreleased] link syntax is incorrect.`)

	let previousVersion = linkMatch[2]
	let existingVersionRegex = new RegExp(`\\[${previousVersion}\\]:`)
	let newVersionLinkPath = content.match(existingVersionRegex)
		? `${linkMatch[1]}${previousVersion}...v${newVersion}`
		: `${linkMatch[1].replace(`compare`, `releases/tag`)}${newVersion}`

	let newLinks = `${linkMatch[1]}${newVersion}${linkMatch[3]}\n[${newVersion}]${newVersionLinkPath}`

	return content.replace(linkRegex, newLinks)
}
