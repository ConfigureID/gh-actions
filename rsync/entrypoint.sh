#!/bin/bash
# Auth
echo "$INPUT_CLOUD_CREDENTIALS" > /secrets.json
gcloud auth activate-service-account --key-file=/secrets.json
rm /secrets.json

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
    echo "Error - Destination not allowed ($INPUT_TO)"
    exit 1
fi

# Validate the directory is not empty
if [ -z "$(ls -A ${INPUT_PATH})" ]; then
    echo "Error - The source directory is empty. Publish not allowed"
    exit 1
else
    echo "The source directory contains files. Publish allowed"

    # Syncing files to bucket
    echo "Syncing bucket $INPUT_CLOUD_BUCKET ..."
    echo gsutil -m $CACHE_OPTIONS rsync -r -c $DELETE_OPTION -x '$INPUT_EXCLUDE' /github/workspace/$INPUT_PATH gs://$INPUT_CLOUD_BUCKET/$INPUT_TO | bash

    if [ $? -ne 0 ]; then
        echo "Syncing failed"
        exit 1
    fi
    echo "Done."
fi
