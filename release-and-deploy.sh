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

# no previous tags default to package.json
if [ -z "$GIT_TAG_LATEST" ]; then
	GIT_TAG_LATEST="v$(grep -m 1 '"version"' package.json | awk -F: '{ print $2 }' | tr -d '", ')"		
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

# Capture the PID of the background process
PID=$!

# Wait for the background process to finish
wait $PID

# Capture the exit status of the background process
EXIT_STATUS=$?

# Check if the deploy_test_CDN process completed successfully
if [ $EXIT_STATUS -ne 0 ]; then
  echo "Error: deploy_test_CDN failed with exit code $EXIT_STATUS"
  exit 1
else
  echo "deploy_test_CDN completed successfully."
  echo "Executing deployment script deploy_stage_CDN ..."
  ./deploy_stage_CDN
fi