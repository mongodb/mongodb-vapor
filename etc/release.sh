#!/bin/bash

# usage: ./etc/release.sh [new version string]

# exit if any command fails
set -e

version=${1}
# Ensure version is non-empty
[ ! -z "${version}" ] || { echo "ERROR: Missing version string"; exit 1; }

# regenerate documentation with new version string
./etc/generate-docs.sh ${version}

# get the current branch before we switch
current_branch=$(git branch --show-current)

# switch to docs branch to commit and push
git checkout gh-pages

rm -rf docs/current
cp -r docs-temp docs/current
mv docs-temp docs/${version}

# build up documentation index
python3 ./_scripts/update-index.py

git add docs/
git commit -m "${version} docs"
git push

# go back to wherever we started
git checkout ${current_branch}

# update version string for handshake metadata
sourcery --sources Sources/MongoDBVapor \
        --templates Sources/MongoDBVapor/MongoDBVaporVersion.stencil \
        --output Sources/MongoDBVapor/MongoDBVaporVersion.swift \
        --args versionString=${version}

# update the README with the version string
etc/sed.sh -i "s/mongodb-vapor\", .upToNextMajor[^)]*)/mongodb-vapor\", .upToNextMajor(from: \"${version}\")/" README.md

git add Sources/MongoDBVapor/MongoDBVaporVersion.swift
git add README.md
git commit -m "${version}"

# tag release
git tag "v${version}"

# push changes
git push
git push --tags

# go to GitHub to publish release notes
echo "Successfully tagged release! \
Go here to publish release notes: https://github.com/mongodb/mongodb-vapor/releases/tag/v${version}"
