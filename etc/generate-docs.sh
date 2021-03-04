#!/bin/bash

# usage: ./etc/generate-docs.sh [new version string]

# exit if any command fails
set -e

if ! command -v jazzy > /dev/null; then
  gem install jazzy || { echo "ERROR: Failed to locate or install jazzy; please install yourself with 'gem install jazzy' (you may need to use sudo)"; exit 1; }
fi

if ! command -v sourcekitten > /dev/null; then
  echo "ERROR: Failed to locate SourceKitten; please install yourself and/or add to your \$PATH"; exit 1
fi

version=${1}

# Ensure version is non-empty
[ ! -z "${version}" ] || { echo "ERROR: Missing version string"; exit 1; }

# ensure we have fresh build data for the docs generation process
rm -rf .build

# obtain BSON library and driver versions from Package.resolved
bson_version="$(python3 etc/get_dep_version.py swift-bson)"
driver_version="$(python3 etc/get_dep_version.py mongo-swift-driver)"

git clone --depth 1 --branch "v${bson_version}" https://github.com/mongodb/swift-bson
working_dir=${PWD}
cd swift-bson
sourcekitten doc --spm --module-name SwiftBSON > ${working_dir}/bson-docs.json
cd $working_dir

git clone --depth 1 --branch "v${driver_version}" https://github.com/mongodb/mongo-swift-driver
working_dir=${PWD}
cd mongo-swift-driver
sourcekitten doc --spm --module-name MongoSwift > ${working_dir}/mongoswift-docs.json
cd $working_dir

# consolidate all guides from across repos
mkdir Guides-Temp
cp swift-bson/Guides/*.md Guides-Temp/
cp mongo-swift-driver/Guides/*.md Guides-Temp/

jazzy_args=(--clean
            --github-file-prefix https://github.com/mongodb/mongodb-vapor/tree/v${version} 
            --module-version "${version}"
            --documentation "Guides-Temp/*.md")

sourcekitten doc --spm --module-name MongoDBVapor > mongodbvapor-docs.json
args=("${jazzy_args[@]}"  --output "docs-temp" --module "MongoDBVapor" --config ".jazzy.yml" 
        --sourcekitten-sourcefile mongoswift-docs.json,bson-docs.json,mongodbvapor-docs.json
        --root-url "https://mongodb.github.io/mongodb-vapor")
jazzy "${args[@]}"

rm -rf swift-bson
rm -rf mongo-swift-driver
rm mongoswift-docs.json
rm bson-docs.json
rm mongodbvapor-docs.json
rm -rf Guides-Temp

# we can only pass a single GitHub file prefix above, so we need to correct the BSON file paths throughout the docs.

# Jazzy generates the links for each file by taking the base path we provide above as --github-file-prefix and tacking on
#  the path of each file relative to the project's root directory. since we check out swift-bson from the root of the driver,
# all of the generated URLs for BSON symbols are of the form
# ....mongo-swift-driver/tree/v[driver version]/swift-bson/... (and similar for driver symbols.)
# Here we replace all occurrences of this with the correct GitHub root URLs, e.g. swift-bson/tree/v[bson version].
# note: we have to pass -print0 to `find` and pass -0 to `xargs` because some of the file names have spaces in them, which by
# default xargs will treat as a delimiter.
find docs-temp -name "*.html" -print0 | \
xargs -0 etc/sed.sh -i "s/mongodb-vapor\/tree\/v${version}\/swift-bson/swift-bson\/tree\/v${bson_version}/"

find docs-temp -name "*.html" -print0 | \
xargs -0 etc/sed.sh -i "s/mongodb-vapor\/tree\/v${version}\/mongo-swift-driver/mongo-swift-driver\/tree\/v${driver_version}/"
