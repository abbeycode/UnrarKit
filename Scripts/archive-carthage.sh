#!/bin/bash

set -ev

# Archives the Carthage packages, and prints the name of the archive

# Employing a workaround until Xcode 12 builds are fixed
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
source "${SCRIPTPATH}"/carthage.sh build --no-skip-current
source "${SCRIPTPATH}"/carthage.sh archive

export ARCHIVE_PATH="UnrarKit.framework.zip"