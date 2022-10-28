#!/bin/bash

# This script will copy all the files from the repo located at $CUSTOM_ACTION_REPO_SUBDIRECTORY to the $DESTINTATION_PATH
# It will keep the repo owner and name but remove the branch/tag, so the location is stable (it won't change when the actions version change)

# Example: 
# if input: 
#   $CUSTOM_ACTION_REPO_SUBDIRECTORY: /home/runner/work/_actions/ConfigureID/gh-actions/v8/deploy
#   $DESTINTATION_PATH: /home/runner/work/repo/.github/actions
# Result:
#  Files from "/home/runner/work/_actions/ConfigureID/gh-actions/v8" (note it's the repo root dir, not the deploy action dir)
#  will be copied to "/home/runner/work/repo/.github/actions/ConfigureID/gh-actions" (without v8)

# Get the repo root path 
CUSTOM_ACTIONS_PATH=$(dirname $CUSTOM_ACTION_REPO_SUBDIRECTORY)

# Get the actions repo name (eg gh-actions)
CUSTOM_ACTIONS_NAME=$(basename $(dirname $CUSTOM_ACTIONS_PATH))

# Get the actions repo owner (eg ConfigureID)
CUSTOM_ACTIONS_OWNER=$(basename $(dirname $(dirname $CUSTOM_ACTIONS_PATH)))

# Generate output directory
OUT_DIR="$DESTINTATION_PATH/$CUSTOM_ACTIONS_OWNER/$CUSTOM_ACTIONS_NAME"

# Create all necessary directories and copy the files
mkdir -p $OUT_DIR
cp -r $CUSTOM_ACTIONS_PATH/* $OUT_DIR