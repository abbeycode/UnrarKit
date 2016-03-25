#!/bin/bash

# Usage: get-release-notes.sh <version-number>
#
# Prints the release notes for a given version out of CHANGELOG.md

# Remove the "-beta#" from the end of the version number
[[ $1 =~ ^([0-9\.]+)(\-beta[0-9]*)?$ ]]
RELEASE_VERSION=${BASH_REMATCH[1]}

# Require release notes to be written
sed "/^## $RELEASE_VERSION$/,/^##/!d;//d;/^$/d" CHANGELOG.md