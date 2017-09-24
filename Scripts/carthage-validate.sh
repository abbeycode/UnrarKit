#!/bin/bash

REPO="github \"$TRAVIS_REPO_SLUG\""
BRANCH=$TRAVIS_BRANCH

if [ -z ${TRAVIS+x} ]; then
    REPO="git \"`pwd`\""
    BRANCH=`git branch | grep ^\* | cut -c 3-`
    echo "Not running in Travis. Setting REPO ($REPO) and BRANCH ($BRANCH)"
fi

if [ -n "$TRAVIS" ] && [ "$TRAVIS_PULL_REQUEST" != "false" ]; then
    REPO="github \"$TRAVIS_PULL_REQUEST_SLUG\""
    BRANCH=$TRAVIS_PULL_REQUEST_BRANCH
    echo "Build is for a Pull Request. Overriding REPO ($REPO) and BRANCH ($BRANCH)"
fi

if [ ! -d "CarthageValidation" ]; then
    mkdir "CarthageValidation"
fi

pushd CarthageValidation > /dev/null

rm Cartfile
rm Cartfile.resolved
rm -rf Carthage

echo "$REPO \"$BRANCH\"" > Cartfile

carthage bootstrap --configuration Debug --verbose
EXIT_CODE=$?

echo "Checking for build products..."

if [ ! -d "Carthage/Build/Mac/UnrarKit.framework" ]; then
    echo "No Mac library built"
    EXIT_CODE=1
fi

if [ ! -d "Carthage/Build/iOS/UnrarKit.framework" ]; then
    echo "No iOS library built"
    EXIT_CODE=1
fi

popd > /dev/null

exit $EXIT_CODE