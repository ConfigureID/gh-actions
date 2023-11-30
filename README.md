# Github Actions and reusable Workflows

This repository contains several actions and reusable workflows that perform common tasks.
It was created to avoid duplicating steps that are used often.


## Reusable Workflows

The directory `[.github/workflows](.github/workflows)` contains [reusable workflows](https://docs.github.com/en/actions/learn-github-actions/reusing-workflows).

This workflows are used frequently and contain multiple steps, so it is useful to extract that logic and allow other workflows to call them

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
    uses: martinmoscovich/gh-actions/.github/workflows/npm-build.yml@v2
    with:
      node_version: 14
      # Directory where this project is built (some use dist, others build, etc)
      dist_dir: dist
      # Optional. Specifies branch, tag or commit to build. Defaults to the repo's default branch
      source_ref: main
      # Optional. Name to use when uploading the resulting artifact (defaults to build-output)
      artifact_name: build-output
```

### Promote

> Promotes a release to a specified environment (eg. integration, staging, production)
> 
See contents [here](.github/workflows/promote.yml).

**Steps**
- Downloads an specified existing release zip file from the Github repo
- Uncompresses the zip file
- Deploys the file to the specified path in the repo's *Github Pages*.

**Usage**
```yaml
jobs:
  promote:
    name: Promote to Staging
    uses: martinmoscovich/gh-actions/.github/workflows/promote.yml@v2
    with:
      # Directory in GH Pages where the files must be deployed
      to: staging
      # Version to promote
      tag: v1.2.0
      # Name of the zip file associated with that release
      release_filename: 'my-app.zip'
    secrets:
      # Github Token with permission to download the release file and commit to the gh-pages branch
      github_token: ${{ secrets.GITHUB_TOKEN }}
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
        uses: martinmoscovich/gh-actions/npm-build@v2
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

### Deploy to GH Pages

> Deploys the project files to Github Pages

See contents [here](gh-deploy/action.yml).

**Steps**
- Ccreates a Github Deployment and Environment object with status "start" and the environment name
- Downloads an artifact from a previous step
- Deploys the files to the specified path (inputs.to) in Github Pages
- Marks the Github Deployment object as "finished" with the status of the workflow (success, failed)

**Usage (when deploying a branch)**
```yaml
jobs:
  deploy:
    name: Deploy
    needs: build
    runs-on: ubuntu-latest
    steps:
        # Extracts the current branch/tag name. 
        # This is shown as an example, it's not required.
      - name: Extract branch or tag name
        uses: tj-actions/branch-names@v5
        id: extract_branch

      - name: Deploy to GH Pages
        uses: martinmoscovich/gh-actions/gh-deploy@v2
        with:
          # Directory where the project must be deployed to
          to: branches/${{ steps.extract_branch.outputs.current_branch }}
          # Optional. The name of the artifact created in a previous step. If not specified, build-output is used
          artifact_name: build-output
          # Optional. Name of the environment object to create and associate with branch or PR. If not defined, env is not created
          environment_name: dev-${{ steps.extract_branch.outputs.current_branch }}
          # Github Token with permission to commit to the gh-pages of the the repository.
          github_token: ${{ secrets.GITHUB_TOKEN }}

       - name: Something after
         ...
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
        uses: martinmoscovich/gh-actions/gh-prune@v2
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
        uses: martinmoscovich/gh-actions/release@v2
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
      - name: Extract branch or tag name
        uses: tj-actions/branch-names@v6
        id: extract_branch
      
      - name: E2E Test
        uses: ConfigureID/gh-actions/cypress@v15
        with:
          # Test on the branch deployment on GCP
          base_url: ${{ format('https://{0}/{1}/branches/{2}', vars.BASE_URL, vars.NAMESPACE, steps.extract_branch.outputs.current_branch) }}
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
        uses: ConfigureID/gh-actions/cypress@v15
        with:
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}

       - name: Something after
         ...
```

### Generate and publish Test reports

> Process test reports to generate a summary and comments in the PR

See contents [here](test-report/action.yml).

It will be generated in the Action summary and as comments in the PR.

It requires that the artifacts names use the specified prefix and "-unit" or "-e2e"

Add the `if:` condition to make it run `always()`, even on failure.

**The job needs to have the permissions described in the example below or it will fail**

**Steps**
- Download the test artifacts
- Publish unit/component tests results (if available)
- Publish E2E tests results (if available)

**Usage - Remote**
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
        uses: ConfigureID/gh-actions/test-report@v15


       - name: Something after
         ...
```
