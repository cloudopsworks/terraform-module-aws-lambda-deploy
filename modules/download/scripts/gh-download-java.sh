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
type curl grep sed tr gh >&2
xargs=$(which gxargs || which xargs)

# Validate settings.
[ -f ~/.secrets ] && source ~/.secrets
[ "$GITHUB_API_TOKEN" ] || { echo "Error: Please define GITHUB_API_TOKEN variable." >&2; exit 1; }
[ $# -ne 6 ] && { echo "Usage: $0 [owner] [repo] [version] [package_name] [package_type] [name]"; exit 1; }
[ "$TRACE" ] && set -x
read owner repo version package_name package_type name <<<$@

CURL_ARGS="-LJ"

export GH_TOKEN=$GITHUB_API_TOKEN

package_url=$(gh api graphql -F owner=$owner -F repo=$repo \
-F packageType=$package_type -F names="$package_name" \
-F version="2.9.0" -F query='
query($owner: String!, $repo: String!, $packageType: PackageType!, $names: [String!], $version: String!) {
  repository(owner: $owner, name: $repo) {
    packages(first: 10, packageType: $packageType, names: $names) {
      edges {
        node {
          id
          name
          packageType
          version(version: $version) {
            id
            version
            files(first: 10) {
              edges {
                node {
                  name
                  url
                }
              }
            }
          }
        }
      }
    }
  }
}' -q '.data.repository.packages.edges[0].node.version.files.edges[].node | select(.name | test(".*.jar$")).url')

# Download asset file.
echo "Downloading asset..." >&2
curl $CURL_ARGS -H 'Accept: application/octet-stream' "$package_url" -o $name
echo "$0 done." >&2
