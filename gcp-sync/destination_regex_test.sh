# Regex to test
REGEX="[/]prod$|[/]staging$|[/]dev$|([/](branches|releases)[/][A-Za-z0-9._%+-\/]+$)"

# Valid Paths to Test
VALID=(
"test-actions/prod"
"test-actions/dev"
"test-actions/staging"
"test-actions/branches/feature"
"test-actions/branches/feature-v1.0"
"test-actions/branches/feature_branch"
"test-actions/branches/feature-branch"
"test-actions/branches/feature+branch"
"test-actions/branches/feature%20branch"
"test-actions/branches/feature/branch"
"test-actions/branches/ADIDAS-59_feature"
"test-actions/releases/v1.0"
)

# Invalid Paths to Test
INVALID=(
"/"
"test-actions"
"test-actions/"
"test-actions/prod/"
"test-actions/prod/a"
"test-actions/prod2"
"test-actions/prod2/"
"test-actions/prod2/a"
"test-actions/dev/"
"test-actions/dev/a"
"test-actions/dev2"
"test-actions/dev2/"
"test-actions/dev2/a"
"test-actions/staging/"
"test-actions/staging/a"
"test-actions/staging2"
"test-actions/staging2/"
"test-actions/staging2/a"
"test-actions/branches"
"test-actions/branches/"
"test-actions/branches2"
"test-actions/branches2/"
"test-actions/branches2/feature"
"test-actions/branches2/feature-v1.0"
"test-actions/branches2/feature_branch"
"test-actions/branches2/feature-branch"
"test-actions/branches2/feature+branch"
"test-actions/branches2/feature%20branch"
"test-actions/branches2/feature/branch"
"test-actions/branches2/ADIDAS-59_feature"
"test-actions/releases"
"test-actions/releases/"
"test-actions/releases2"
"test-actions/releases2/"
"test-actions/releases2/v1.0"
)

TEST_FAIL=0

for t in ${VALID[@]}; do
    if [[ ! $t =~ $REGEX ]]; then
        echo "SHOULD BE VALID: $t"
        TEST_FAIL=1
    fi
done

for t in ${INVALID[@]}; do
    if [[ $t =~ $REGEX ]]; then
        echo "SHOULD BE INVALID: $t"
        TEST_FAIL=1
    fi
done

if [[ $TEST_FAIL == 0 ]]; then
     echo "ALL TEST PASSED" && exit 0
fi

exit 1