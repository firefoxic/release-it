import { readFile } from "node:fs/promises"

/**
 * Asynchronously reads the version number from the package.json file and returns it.
 *
 * @return {Promise<string>} - A Promise that resolves with the version number from the package.json file.
 */
export async function getNewVersion () {
	let packageJson = JSON.parse(await readFile(`package.json`, `utf-8`))

	return packageJson.version
}
