#!/bin/bash

set -ev

# Archives the Carthage packages, and prints the name of the archive

carthage build --no-skip-current
carthage archive

export ARCHIVE_PATH="UnrarKit.framework.zip"