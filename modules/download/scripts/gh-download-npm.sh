#!/usr/bin/env bash
##
# (c) 2022-2024 - Cloud Ops Works LLC - https://cloudops.works/
#            On GitHub: https://github.com/cloudopsworks
#            Distributed Under Apache v2.0 License
#
# Script to download asset file from tag release using GitHub API v3.
# See: http://stackoverflow.com/a/35688093/55075
CWD="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"

# Check dependencies.
set -e
type curl grep sed tr gh npm node yq >&2
xargs=$(which gxargs || which xargs)

# Validate settings.
[ -f ~/.secrets ] && source ~/.secrets
[ "$GITHUB_API_TOKEN" ] || { echo "Error: Please define GITHUB_API_TOKEN variable." >&2; exit 1; }
[ $# -ne 6 ] && { echo "Usage: $0 [owner] [repo] [version] [package_name] [package_type] [name]"; exit 1; }
[ "$TRACE" ] && set -x
read owner repo version package_name package_type name <<<$@

CURL_ARGS="-LJ"

#obtain registry form the pattern of package name @registry/package_name
registry=$(echo $package_name | sed -n 's/^\(.*\)\/.*/\1/p')

echo "//npm.pkg.github.com/:_authToken=${GITHUB_API_TOKEN}" >> $HOME/.npmrc
echo "${registry}:registry=https://npm.pkg.github.com/" >> $HOME/.npmrc

npm version

# Download asset file.
echo "Downloading asset..." >&2
DEST_DIR=$(dirname $name)
ANAME=$(npm pack --ignore-scripts ${package_name}@${version} --pack-destination $DEST_DIR --json | yq e '.[].filename')
FNAME=$(echo "$ANAME" | tr -d '@' | tr '/' '-')
echo "Moving $DEST_DIR/$FNAME to $name"
mv $DEST_DIR/$FNAME $name
echo "$0 done." >&2
