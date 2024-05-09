/**
 * Formats a given date into a string in the format "YYYY–MM–DD".
 *
 * @param {Date} date - The date to be formatted.
 * @return {string} The formatted date string.
 */
export function formatDate (date) {
	let yyyy = date.getFullYear()
	let mm = String(date.getMonth() + 1).padStart(2, `0`)
	let dd = String(date.getDate()).padStart(2, `0`)

	return `${yyyy}–${mm}–${dd}`
}
