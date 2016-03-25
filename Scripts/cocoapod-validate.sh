#!/bin/bash

set -ev

if [ -z "$TRAVIS_TAG" ]; then
    TRAVIS_TAG_SUBSTITUTED=1
    export TRAVIS_TAG="$(git tag -l | tail -1)"
    echo "Not a tagged build. Using last tag ($TRAVIS_TAG) for pod lib lint..."
fi

# Lint the podspec to check for errors. Don't call `pod spec lint`, because we want it to evaluate locally
pod lib lint

if [ -n "$TRAVIS_TAG_SUBSTITUTED" ]; then
    echo "Unsetting TRAVIS_TAG..."
    unset TRAVIS_TAG
fi
