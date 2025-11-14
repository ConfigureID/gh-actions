#!/bin/bash
set -euo pipefail

# Create secure temporary file for credentials
SECRETS_FILE=$(mktemp)
chmod 600 "$SECRETS_FILE"

# Ensure cleanup on exit
trap 'rm -f "$SECRETS_FILE"' EXIT

# Auth
echo "$INPUT_CLOUD_CREDENTIALS" > "$SECRETS_FILE"
gcloud auth activate-service-account --key-file="$SECRETS_FILE"

# Delete Files
if [[ $INPUT_DELETE == "true" ]]; then
    DELETE_OPTION='-d'
    echo "Delete -> true: Files removed from source will be removed from destination"
else
    DELETE_OPTION=''    
    echo "Delete -> false: No files will be removed from destination, just created or updated"
fi

# Cache Options
if [[ $INPUT_CACHE == "true" ]]; then
    CACHE_OPTIONS=''
    echo "Sync with CACHE"
else
    CACHE_OPTIONS='-h "Cache-Control:no-store"'    
    echo "Sync without CACHE"
fi

# Check destination
if [[ $INPUT_TO =~ $INPUT_ALLOWED_DESTINATION ]]; then
    echo "Destination allowed"
else
    echo "::error::Error - Destination not allowed ($INPUT_TO)" && exit 1
fi

# Validate the directory is not empty
if [ -z "$(ls -A ${INPUT_PATH})" ]; then
    echo "::error::Error - The source directory is empty. Publish not allowed" && exit 1
else
    echo "The source directory contains files. Publish allowed"

    # Syncing files to bucket
    echo "Syncing bucket $INPUT_CLOUD_BUCKET ..."

    # Build and execute gsutil command directly (avoid command injection)
    if [[ -n "$CACHE_OPTIONS" ]]; then
        gsutil -m -h "Cache-Control:no-store" rsync -r -c ${DELETE_OPTION} -x "$INPUT_EXCLUDE" "/github/workspace/$INPUT_PATH" "gs://$INPUT_CLOUD_BUCKET/$INPUT_TO"
    else
        gsutil -m rsync -r -c ${DELETE_OPTION} -x "$INPUT_EXCLUDE" "/github/workspace/$INPUT_PATH" "gs://$INPUT_CLOUD_BUCKET/$INPUT_TO"
    fi

    echo "Done."
fi
