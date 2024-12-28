#!/usr/bin/env bash

# - Catch errors early on and prevent unintended behavior.  
# - Avoid issues caused by unset variables.
# - Easily identify and debug errors within pipelines.
set -euo pipefail

# Check for uncommited changes
if [ -n "$(git status --porcelain)" ]; then
	printf "\nError: commit your changes before proceed"
	exit 1
fi

# list tags (semver)
GIT_TAGS=$(git tag --sort=version:refname)

# Get last tag (most recent) if any
GIT_TAG_LATEST=$(echo "$GIT_TAGS" | tail -n 1)

# no previous tags default to v0.0.0
if [ -z "$GIT_TAG_LATEST" ]; then
	GIT_TAG_LATEST="v0.0.0"
fi

# replace v prefix with nothing
GIT_TAG_LATEST=$(echo "$GIT_TAG_LATEST" | sed 's/^v//') 

echo "$GIT_TAG_LATEST"

# first argument passed to the script (a.k.a. patch, minor or major) 
VERSION_TYPE="${1-}"
VERSION_NEXT=""

if [ "$VERSION_TYPE" = "patch" ]; then
	VERSION_NEXT="$(echo "$GIT_TAG_LATEST" | awk -F. '{$3++; print $1"."$2"."$3}')"
elif [ "$VERSION_TYPE" = "minor" ]; then
	VERSION_NEXT="$(echo "$GIT_TAG_LATEST" | awk -F. '{$2++; $3=0; print $1"."$2"."$3}')"
elif [ "$VERSION_TYPE" = "major" ]; then	
  VERSION_NEXT="$(echo "$GIT_TAG_LATEST" | awk -F. '{$1++; $2=0; $3=0; print $1"."$2"."$3}')"
else
  printf "\nError: invalid VERSION_TYPE: must be patch, minor or major\n\n"
  exit 1
fi

echo "Next version: $VERSION_NEXT"

## Get latest
git checkout main
git pull origin main

## Update version also on package.json file to keep in sync

sed -i "s/\"version\": \".*\"/\"version\": \"$VERSION_NEXT\"/" package.json

git add .
git commit -m "chore(release): v.$VERSION_NEXT"

# Create an annotated tag
git tag -a "v$VERSION_NEXT" -m "Release: v$VERSION_NEXT"
git push origin main --following-tags

# new branch for deployment (restore point-ish)
git checkout -b "v.$VERSION_NEXT"
git push -u origin "v.$VERSION_NEXT"

./deploy_test_CDN &

wait

./deploy_stage_CDN
