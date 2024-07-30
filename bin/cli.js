#!/usr/bin/env node

import { addFileToStaging } from "../lib/gitCommands.js"
import { updateChangelog } from "../lib/updateChangelog.js"

await updateChangelog()

await addFileToStaging(`CHANGELOG.md`)
