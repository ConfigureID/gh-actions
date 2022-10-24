#!/bin/bash
# Auth
echo "$INPUT_CLOUD_CREDENTIALS" > /secrets.json
gcloud auth activate-service-account --key-file=/secrets.json
rm /secrets.json

# Check destination
if [[ $INPUT_TO =~ $INPUT_CHECK_DESTINATION ]]; then
    echo "Destination exists"
else
    echo "Error - Destination doesn't exist"
    exit 1
fi

# Validate the directory is not empty
if [ -z "$(ls -A ${PATH})" ]; then
    echo "Empty"
    exit 1
else
    echo "Not Empty"

    if [ $INPUT_CACHE ]; then
            # Sync files to bucket WITH CACHE
        echo "Syncing bucket $BUCKET ..."
        gsutil -m rsync -r -c -d -x "$INPUT_EXCLUDE" /github/workspace/$PATH gs://$INPUT_CLOUD_BUCKET/$INPUT_TO

        if [ $? -ne 0 ]; then
            echo "Syncing with CACHE failed"
            exit 1
        fi
        echo "Done."

    else
        # Sync files to bucket WHIOUT CACHE
        echo "Syncing bucket $BUCKET ..."
        gsutil -m -h "Cache-Control:no-store" rsync -r -c -d -x "$INPUT_EXCLUDE" /github/workspace/$PATH gs://$INPUT_CLOUD_BUCKET/$INPUT_TO

        if [ $? -ne 0 ]; then
            echo "Syncing without CACHE failed"
            exit 1
        fi
        echo "Done."
    fi
fi
