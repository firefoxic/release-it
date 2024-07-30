import { exec } from "node:child_process"

/**
 * Executes a Git command.
 *
 * @param {string} command - The Git command to execute.
 * @return {Promise<void>} - A promise that resolves when the command is successfully executed.
 * @throws {Error} - If there is an error executing the command.
 */
export function executeGitCommand (command) {
	return new Promise((resolve, reject) => {
		exec(`git ${command}`, (error, stdout, stderr) => {
			if (error) {
				reject(new Error(`Runing "${command}" failed: ${error.message}`))

				return
			}
			if (stderr) {
				reject(new Error(`stderr: ${stderr}`))

				return
			}
			console.log(`stdout: ${stdout}`)
			resolve()
		})
	})
}

/**
 * Adds a file to the Git staging area.
 *
 * @param {string} filePath - The path to the file to add.
 * @return {Promise<void>} - A promise that resolves when the file is successfully added.
 * @throws {Error} - If there is an error adding the file.
 */
export function addFileToStaging (filePath) {
	return executeGitCommand(`add ${filePath}`)
}
