import { readFile, writeFile } from "node:fs/promises"

import { updateContent } from "./updateContent.js"

/**
 * Updates the CHANGELOG.md file with the latest version.
 *
 * @return {Promise<void>} - A promise that resolves when the CHANGELOG.md file is successfully updated.
 * @throws {Error} - If there is an error updating the CHANGELOG.md file.
 */
export async function updateChangelog () {
	try {
		let changelogPath = `CHANGELOG.md`
		let changelogContent = await readFile(changelogPath, `utf-8`)

		changelogContent = await updateContent(changelogContent)

		await writeFile(changelogPath, changelogContent)
	} catch (error) {
		console.error(`Error updating CHANGELOG.md:`, error)
	}
}
