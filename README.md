# Github Actions and reusable Workflows

This repository contains several actions and reusable workflows that perform common tasks.
It was created to avoid duplicating steps that are used often.


## Reusable Workflows

The directory `[.github/workflows](.github/workflows)` contains [reusable workflows](https://docs.github.com/en/actions/learn-github-actions/reusing-workflows).

This workflows are used frequently and contain multiple steps, so it is useful to extract that logic and allow other workflows to call them.
It also allows to reuse matrix execution strategy for parallelism

### NPM Build

> Tests and builds an NPM Project and then uploads the resulting artifact so other jobs may use them

See contents [here](.github/workflows/npm-build.yml).

**Steps**
- Checkouts the code
- Installs the specified Node.js version and restores the node_modules cache if it exists
- Installs dependencies (npm ci)
- Runs Tests
- Builds transpiled/minified output
- Uploads the artifact so the next steps can use it

**Usage**
```yaml
jobs:
  build:
    uses: ConfigureID/gh-actions/.github/workflows/npm-build.yml@v21
    with:
      node_version: 14
      # Directory where this project is built (some use dist, others build, etc)
      dist_dir: dist
      # Optional. Specifies branch, tag or commit to build. Defaults to the repo's default branch
      source_ref: main
      # Optional. Name to use when uploading the resulting artifact (defaults to build-output)
      artifact_name: build-output
```

### Playwright E2E Testing - Simple

> Runs E2E tests using Playwright sequentially on a single VM

See contents [here](.github/workflows/playwright.yml).

This is the same as simply calling the [action](playwright/action.yml). It is created as a reusable workflow to make the call 
more similar to the shared version (where using a reusable workflow is actually useful). 
Just add/remove the "-sharded" suffix and add/remove the number of shards

**Steps**
- Install the dependencies (node_modules and Playwright browsers)
- Run tests on a single VM
- Generate the JSON/XML results and HTML report
- Upload them as artifacts

**Usage**
```yaml
jobs:
  e2e:
    name: E2E Tests
    needs: deploy
    uses: ./.github/workflows/playwright.yml
    with:
      trace: true
      browser: chromium
      base_url: ${{ format('https://{0}/{1}/branches/{2}', vars.BASE_URL, vars.NAMESPACE, github.event.pull_request.head.ref) }}
    secrets:
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```

### Playwright E2E Testing - Sharded

> Runs E2E tests using Playwright in parallel on multiple VMs (matrix execution strategy)

See contents [here](.github/workflows/playwright-shareded.yml).

 It uses 3 jobs, because:
- The first one run on a single VM and prepares the execution by installing/caching dependencies and setting up the matrix parameters
- The second one actually runs the tests on multiple VMs in parallel
- The third one runs on a single VM after the testing has finished and merges the results to generate the JSON/XML/HTML output

The number of shards is configurable. Defaults to 3.

**Steps**
- Install the dependencies (node_modules and Playwright browsers)
- Run tests on a single VM
- Generate the JSON/XML results and HTML report
- Upload them as artifacts

**Usage**
```yaml
jobs:
  e2e:
    name: E2E Tests
    needs: deploy
    uses: ./.github/workflows/playwright-sharded.yml
    with:
      shards: 4
      trace: true
      browser: chromium
      base_url: ${{ format('https://{0}/{1}/branches/{2}', vars.BASE_URL, vars.NAMESPACE, github.event.pull_request.head.ref) }}
    secrets:
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```

## Actions

This repository also contain actions.

There are two types of actions:
- Simple actions: Perform a single step (but it may be complex)
- [Composite actions](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action): Performs multiple steps, similar to reusable workflows. 

### Composite actions vs reusable workflows

- Composite Actions run in the context of its job, so the `runs-on` parameter is left for the caller to define. Reusable workflows define their own context (but input parameters and environment variables can be specified).
- Composite Actions may be use in a job combined with other steps (before and after). Reusable workflows can't.
- Composite Actions may call other composite actions, reusable workflows can't call other reusable workflows (but they can call Composite actions).
- Reusable workflows may contains multiple jobs.
- Reusable workflows support both `inputs` and `secrets`, Composite actions only suppport `inputs`.
- The UI shown for workflows is better, as all the differents steps performed are shown clearly. With actions, only one step is shown.

Since the UI is better for reusable workflows, I prefer to use them when possible.
For example `npm-build` is provided as both an action and a workflow. But unless you need to perform steps (**NOT jobs**) before or after building, I'd recommend using the workflow.


### NPM Build

Works exactly as the reusable workflow with the same name.

See contents [here](npm-build/action.yml).

**Usage**
```yaml
jobs:
  build:
    name: Build
    runs-on: ubuntu-latest
    steps:
      - name: Something before
        ...

      - name: Build project
        uses: ConfigureID/gh-actions/npm-build@v21
        with:
          node_version: 14
          # Directory where this project is built (some use dist, others build, etc)
          dist_dir: dist
          # Optional. Specifies branch, tag or commit to build. Defaults to the repo's default branch
          source_ref: main
          # Optional. Name to use when uploading the resulting artifact (defaults to build-output)
          artifact_name: build-output

       - name: Something after
         ...
```

### Deploy build or Promote release to Cloud Service

> Deploy the project to a Cloud Service (supports Github Pages and GCS)

It can **DEPLOY a build** created on a previous step or **PROMOTE an existing release** to an specified environment (eg. integration, staging, production).

See contents [here](gh-deploy/action.yml).

**Steps**
- Creates a Github Deployment object with status "start" and the name
- Downloads an artifact from a previous step OR an asset from an existing release.
- Deploy the files to the specified path ("namespace/environment_name" or "to") in Github Pages or GCS
- Marks the Github Deployment object as "finished" with the status of the workflow (success, failed)

**Usage (when deploying a branch)**
```yaml
jobs:
  deploy:
    name: Deploy
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Deploy branch
        uses:  ConfigureID/gh-actions/deploy@v21
        with:
          # Base URL where the app is deployed
          base_url: ${{ vars.BASE_URL }}
          # Namespace inside the URL. Usually the client/project name (eg. adidas, moncler)
          namespace: ${{ vars.NAMESPACE }}
          # Directory inside the namespace where the app should be deployed
          environment_name: branches/${{ github.event.pull_request.head.ref }}

          # Cloud service settings
          cloud_service: gcp
          cloud_bucket: ${{ secrets.CLOUD_BUCKET_DEV }}
          cloud_credentials: ${{ secrets.GCP_CREDENTIALS }}

          # Indicates if the assets must be cached, useful for release, staging and production
          # Only works with GCP
          cache: false

          # Optional. The name of the artifact created in a previous step. If not specified, build-output is used
          artifact_name: build-output

       - name: Something after
         ...

        - name: Promote to Staging
          uses: ConfigureID/gh-actions/deploy@FETI-87_release_workflow
          with:
            # By specifying a release, this action PROMOTES the release instead of deploying the current build
            release: ${{ github.event.inputs.release-version }}
            
            # Base URL where the app is deployed
            base_url: ${{ vars.BASE_URL }}
            # Namespace inside the URL. Usually the client/project name (eg. adidas, moncler)
            namespace: ${{ vars.NAMESPACE }}
            # Directory inside the namespace where the app should be deployed
            environment_name: staging

            # Cloud service settings
            cloud_service: gcp
            cloud_bucket: ${{ secrets.CLOUD_BUCKET }}
            cloud_credentials: ${{ secrets.GCP_CREDENTIALS }}
            cloud_lb: ${{ secrets.CLOUD_LB }}

            # Indicates if the assets must be cached, useful for release, staging and production
            # Only works with GCP
            cache: true
```

### Remove deployment

> Removes the deployment from Github Pages and disbles the environment

Useful for example when a PR is closed and the associated deployment is not required anymore.

See contents [here](gh-prune/action.yml).

**Steps**
- Disables the Github Environment object
- Removes the directory in Github Pages

**Usage (when deploying a branch)**
```yaml
jobs:
  prune:
    name: Prune
    runs-on: ubuntu-latest

    steps:
        # Extracts the current branch/tag name. 
        # This is shown as an example, it's not required.
      - name: Extract branch or tag name
        uses: tj-actions/branch-names@v5
        id: extract_branch
        
      - name: Prunes enviroment and files
        uses: ConfigureID/gh-actions/gh-prune@v21
        with:
          # Directory where the project must be deployed to
          to: branches/${{ steps.extract_branch.outputs.current_branch }}
           # Optional. Name of the environment object to create and associate with branch or PR. If not defined, env is not created
          environment_name: branch-${{ steps.extract_branch.outputs.current_branch }}
          # Github Token with permission to commit to the gh-pages of the the repository.
          github_token: ${{ secrets.GITHUB_TOKEN }}
   
   - name: Something after
      ...
```

### Create Release

> Creates a release in the Github repository, uploading the assets

> **DEPRECATED**. Replaced by Release Please Action

See contents [here](release/action.yml).

**Steps**
- Downloads artifact from previous step
- Compresses the files
- Creates a release in the Github repo using the tag name and the artifact

**Usage**
```yaml
jobs:
  release:
    name: Release
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Something before
        ...

      - name: Create release
        uses: ConfigureID/gh-actions/release@v21
        with:
          # Optional. Commit reference, only used when the tag does not exist to create it
          source_ref: main
          # Pptional. Tag for the release. If this is omitted the git ref will be used (if it is a tag)
          tag: v1.2.0
          # Name of the release file
          release_filename: 'my-app.zip'
          # Optional. Body for the release
          description: This is a great release!
          # Optional. The name of the artifact created in a previous step. If not specified, build-output is used
          artifact_name: build-output
          # Github Token with permission to create a release in the repository.
          github_token: ${{ secrets.GITHUB_TOKEN }}

       - name: Something after
         ...
```

### Run E2E Tests using Cypress

> Runs local/remote end to end test using Cypress and uploads the results as artifacts

See contents [here](cypress/action.yml).

If a `base_url` is defined, it will be tested remotely. If not, the built artifact will be downloaded and a local server will be started.

- For the remote version, ensure to mark `deploy` as a job dependency
- For the local version, ensure to mark `build` as a job dependency and use the right artifact. 
  Also, the right `serve_command` must be configured on the project (defaults to `npm run cypress:serve`)

**Steps**
- Checkout the repo
- Install the specified Node.js version and restores the node_modules cache if it exists
- Install dependencies (npm ci), in order to setup Cypress
- If local run, download the bundle artifact
- Run Cypress tests (either with the local server or remote)
- Upload videos if available
- Upload snapshots on failure if available
- Upload tests results (junit xml format)

**Usage - Remote**
```yaml
jobs:
  e2e-remote:
    name: E2E Tests - Remote (GCP)
    runs-on: ubuntu-latest
    needs: deploy

    steps:
      - name: E2E Test
        uses: ConfigureID/gh-actions/cypress@v21
        with:
          # Test on the branch deployment on GCP
          base_url: ${{ format('https://{0}/{1}/branches/{2}', vars.BASE_URL, vars.NAMESPACE, github.event.pull_request.head.ref) }}
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}

       - name: Something after
         ...
```

**Usage - Local**
```yaml
jobs:
  e2e-local:
    name: E2E Tests - Local
    runs-on: ubuntu-latest
    needs: build

    steps:
      - name: E2E Test
        uses: ConfigureID/gh-actions/cypress@v21
        with:
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}

       - name: Something after
         ...
```

### Run E2E Tests using Playwright

> Runs local/remote end to end test using Playwright and uploads the results as artifacts

See contents [here](playwright/action.yml).

It can run the full E2E Test suite or a single shard, if the `shard` parameter is provided.
Also it can generate a simple HTML report or a full trace (slower and larger) by setting the `trace` flag.

If a `base_url` is defined, it will be tested remotely. If not, the built artifact will be downloaded and a local server will be started.

- For the remote version, ensure to mark `deploy` as a job dependency
- For the local version, ensure to mark `build` as a job dependency and use the right artifact. 
  **TBD**: Also, the right `serve_command` must be configured on the project (defaults to `??`)

**Steps**
- Checkout the repo
- Install the specified Node.js version
- Install node modules dependencies and cache
- Install Playwright browsers and cache
- If local run, download the bundle artifact
- Run Playwright tests (either with the local server or remote)
- Generate results
- If sharded: Merge results once it has finished
- Upload tests results (junit xml format)
- Upload HTML report

**Usage - Remote**
```yaml
jobs:
  e2e-remote:
    name: E2E Tests - Remote (GCP)
    runs-on: ubuntu-latest
    needs: deploy

    steps:
      - name: E2E Test
        uses: ConfigureID/gh-actions/playwright@v21
        with:
          # Test on the branch deployment on GCP
          base_url: ${{ format('https://{0}/{1}/branches/{2}', vars.BASE_URL, vars.NAMESPACE, github.event.pull_request.head.ref) }}
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
          browser: chromium

       - name: Something after
         ...
```

**Usage - Local**
```yaml
jobs:
  e2e-local:
    name: E2E Tests - Local
    runs-on: ubuntu-latest
    needs: build

    steps:
      - name: E2E Test
        uses: ConfigureID/gh-actions/playwright@v21
        with:
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
          browser: chromium

       - name: Something after
         ...
```

### Generate and publish Test reports

> Process test reports to generate a summary and comments in the PR

See contents [here](test-report-pr/action.yml).

It will be generated in the Action summary and as comments in the PR.

It requires that the artifacts names use the specified prefix and "-unit" or "-e2e"

Add the `if:` condition to make it run `always()`, even on failure.

**The job needs to have the permissions described in the example below or it will fail**

**Steps**
- Download the test artifacts
- Publish unit/component tests results (if available)
- Publish E2E tests results (if available)

**Usage**
```yaml
jobs:
   test-reports:
    name: Create test reports
    needs: [build, e2e-remote]
    if: always() && !cancelled()
    runs-on: ubuntu-latest
    # Required to generate reports in the PR
    permissions:
      contents: read
      issues: read
      checks: write
      pull-requests: write

    steps:
      - name: Create reports
        uses: ConfigureID/gh-actions/test-report-pr@v21


       - name: Something after
         ...
```

### Upload the E2E Test HTML Report to the Cloud

> Retrieve the E2E Tests HTML Report and upload it to the Cloud (eg. GCP).

See contents [here](test-report-cloud/action.yml).

It requires the HTML report artifact name (defaults to `e2e-html-report`) and a subpath (defaults to `tests`) and uploads
the report to the same environment tests inside the subpath

**Steps**
- Download the HTML Report artifact
- Upload it to the Cloud (eg. GCP)
- Publish E2E tests results (if available)

**Usage**
```yaml
jobs:
   test-reports:
    name: Upload HTML report
    needs: [e2e-remote]
    if: always() && !cancelled()
    runs-on: ubuntu-latest

    steps:
      - name: Upload E2E Test HTML reports
        uses: ConfigureID/gh-actions/test-report-cloud@v21


       - name: Something after
         ...
```

### Get remote JSON property value

> Reads a property from a remote JSON file

See contents [here](get-remote-json-property/action.yml).

The property can be a simple name of a path to a nested property, separated by "."

**Steps**
- Download the remote JSON file
- Read the specified property value
- Return the value as an action output named "value".

**Usage**
```yaml
jobs:
   read-version:
    name: Read deployment version
    runs-on: ubuntu-latest
    

    steps:
      - name: Get JSON "version" property value
        uses: ConfigureID/gh-actions/get-remote-json-property@v21
        id: get-version
        with: 
          url: https://someurl.com/build.json
          property: version
```

### Get version deployed in environment

> Reads the version field of the build json file from the provided environment

See contents [here](get-version/action.yml).

This action receives the base URL, the namespace and the environment and returns the version of the app deployed in that environment.

- The JSON path defaults to `build.json` but can be modified using the parameter `json_path`
- The property path where the version is stored defaults to `version` but can be modified using the parameter `version_prop`

**Steps**
- Download the remote JSON file for the deployment
- Read the version property
- Return the deployed version in two output variables: 
  - `version`: Version string with "v" (eg v1.4.3)
  - `version_number`: version number without "v" (eg 1.4.3)

**Usage**
```yaml
jobs:
   read-version:
    name: Read staging version
    runs-on: ubuntu-latest
    
    steps:
      - name: Get deployed version
        uses: ConfigureID/gh-actions/get-version@v21
        id: deployed-version
        with: 
          base_url: somedomain.com/apps
          namespace: adidas
          environment_name: staging
```

### Compare specified version with the one deployed in a certain environment

> Given a version and an environment, determines if the provided version is greater, lower or equal to the one deployed in the environment

See contents [here](compare-version/action.yml).

This action receives a version and the base URL, namespace and environment of an app. It compares the version to determine if the one provided is greater, lower or equal

- The JSON path defaults to `build.json` but can be modified using the parameter `json_path`
- The property path where the version is stored defaults to `version` but can be modified using the parameter `version_prop`

**Steps**
- Download the remote JSON file for the deployment
- Read the version property from the JSON file
- Compares both versions and return
  - `deployed_version`: The deployed version
  - `greater`: Boolean flag indicating whether the provided version is greater than the one deployed
  - `lower`: Boolean flag indicating whether the provided version is lower than the one deployed
  - `equal`: Boolean flag indicating whether the provided version is equal to the one deployed

**Usage**
```yaml
jobs:
   read-version:
    name: Run different actions depending on the version
    runs-on: ubuntu-latest
    
    steps:
      - name: Get current version in staging
        uses: ConfigureID/gh-actions/compare-version@v21
        id: compare-version
        with: 
          version: v1.4.3
          base_url: somedomain.com/apps
          namespace: adidas
          environment_name: staging

      - name: Step to run if the provided version (v1.4.3) is greater
        if: ${{ steps.compare-version.outputs.greater == 'true' }}
        ...

      - name: Step to run if the provided version (v1.4.3) is lower
        if: ${{ steps.compare-version.outputs.lower == 'true' }}
        ...
```

### Attach build artifact to release

> Given an artifact (defaults to `build-output`), a release name (tag) and filename, uploads and attaches the artifact as a zip file to the release. 

See contents [here](attach-release-artifact/action.yml).

**Steps**
- Download the build artifact by name (defaults to `build-output`) to a temp directory
- Creates a zip file from the temp directory using the provided `filename`
- Uploads and attaches the zip file to the list of release assets

**Usage**
```yaml
jobs:
   read-version:
    name: Upload artifact as release asset
    runs-on: ubuntu-latest
    
    steps:
      - name: Create build artifact
        ...

      - name: Upload artifact as release asset
        uses: ConfigureID/gh-actions/attach-release-artifact@v21
        with:
          release_name: v1.4.3
          filename: imp-adidas-v1.4.3
```