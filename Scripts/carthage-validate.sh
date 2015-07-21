#!/bin/bash

if [ -z ${TRAVIS+x} ]; then
    TRAVIS_BUILD_DIR="/Users/Dov/Source Code/UnrarKit"
    TRAVIS_BRANCH=carthage
fi

if [ ! -d "CarthageValidation" ]; then
    mkdir "CarthageValidation"
fi

pushd CarthageValidation > /dev/null

rm Cartfile
rm Cartfile.resolved
rm -rf Carthage

echo "git \"$TRAVIS_BUILD_DIR\" \"$TRAVIS_BRANCH\"" > Cartfile

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