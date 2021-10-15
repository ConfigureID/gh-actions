### Replace environment variables in files ####

# Search for files in REPLACE_PATH using the $REPLACE_FILE_PATTERN
for file in $(find ${REPLACE_PATH:-'./'} -name ${REPLACE_FILE_PATTERN:-'*'} -type f)
do
    # Call replacer and save to a tmp file
    envsub -g -p ${REPLACE_PREFIX:-'${'} -s ${REPLACE_SUFFIX:-'}'} < $file > $file-tmp

    # Replace original file
    mv $file-tmp $file
done