#!/bin/bash

echo

# Only potentially push to CocoaPods when it's a tagged build
if [ -z "$TRAVIS_TAG" ]; then
    echo -e "\nBuild is not tagged"
    exit 0
fi

# Make sure tag name looks like a version number
if ! [[ $TRAVIS_TAG =~ ^[0-9\.]+(\-beta[0-9]*)?$ ]]; then
    echo -e "\nBranch build not a valid version number: $TRAVIS_TAG"
    exit 1
else
    echo -e "\nTag looks like a version number: $TRAVIS_TAG"
fi

# Skip tests because they're assumed to have passed during the cocoapod-validate script or else
# this script wouldn't run
echo -e "\nLinting podspec..."
pod spec lint --fail-fast --skip-tests

if [ $? -ne 0 ]; then
    echo -e "\nPodspec failed lint. Run again with --verbose to troubleshoot"
    exit 1
fi

echo -e "\nExporting Carthage archive...\n"
# Exports ARCHIVE_PATH, used below
source ./Scripts/archive-carthage.sh

# Skip tests for reason stated above
echo -e "\nPushing to CocoaPods...\n"
pod trunk push --skip-tests

# If push is successful, add release to GitHub
if [ $? -ne 0 ]; then
    echo -e "\nPush to CocoaPods failed"
    exit 1
fi

RELEASE_NOTES=$(./Scripts/get-release-notes.py "$TRAVIS_TAG")
./Scripts/add-github-release.py $GITHUB_RELEASE_API_TOKEN $TRAVIS_REPO_SLUG $TRAVIS_TAG "$ARCHIVE_PATH" "$RELEASE_NOTES"