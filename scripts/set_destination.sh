to=$([ "$DESTINATION" == "" ] && echo "$NAMESPACE/$ENVIRONMENT_NAME" || echo "$DESTINATION")
echo "Destination directory: $to"
echo "destination_dir=$to" >> $GITHUB_ENV