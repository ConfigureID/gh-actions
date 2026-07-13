// Manages Github Deployments and Deployment Statuses using the Github API.
// Internal replacement for bobheadxi/deployments, run with actions/github-script (see the "deployment" action).
// Only the steps and inputs used across this repo are supported: "start", "finish" and "delete-env".
//
// Inputs are received as environment variables (set by the deployment action):
//   STEP           - One of "start", "finish" or "delete-env"
//   ENV_NAME       - The name of the deployment environment
//   REF            - Git ref for the deployment ("start" only, defaults to the workflow ref)
//   DESC           - Optional description for the deployment/status
//   DEPLOYMENT_ID  - The deployment id to update (required by "finish")
//   ENV_URL        - Environment URL, set on the status when "finish" succeeds
//   STATUS         - The deployment status (required by "finish")

const getInput = (name) => (process.env[name] ?? '').trim();
const getOptionalInput = (name) => getInput(name) || undefined;

const VALID_STATUSES = [
  'success',
  'failure',
  'cancelled',
  'error',
  'inactive',
  'in_progress',
  'queued',
  'pending',
];

module.exports = async ({ github, context, core }) => {
  const { owner, repo } = context.repo;
  const step = getInput('STEP');
  const environment = getInput('ENV_NAME');
  const description = getOptionalInput('DESC');
  const logsURL = `https://github.com/${owner}/${repo}/commit/${context.sha}/checks`;

  if (!environment) {
    core.setFailed('env input is required');
    return;
  }

  // Marks every deployment of the environment as "inactive" and returns them.
  // Deployments must be inactive before they can be deleted.
  const deactivateEnvironment = async () => {
    const deployments = await github.rest.repos.listDeployments({
      owner,
      repo,
      environment,
      per_page: 100,
    });

    for (const deployment of deployments.data) {
      // Skip deployments that are already inactive
      const statuses = await github.rest.repos.listDeploymentStatuses({
        owner,
        repo,
        deployment_id: deployment.id,
        per_page: 1,
      });
      if (statuses.data.length === 1 && statuses.data[0].state === 'inactive') {
        continue;
      }

      core.info(`${environment}.${deployment.id}: setting deployment state to "inactive"`);
      await github.rest.repos.createDeploymentStatus({
        owner,
        repo,
        deployment_id: deployment.id,
        state: 'inactive',
      });
    }
    return deployments;
  };

  try {
    switch (step) {
      case 'start': {
        const ref = getOptionalInput('REF') || context.ref;
        core.info(`initializing new deployment for ${environment} @ ${ref}`);

        const deployment = await github.rest.repos.createDeployment({
          owner,
          repo,
          ref,
          required_contexts: [],
          environment,
          description,
          auto_merge: false,
          transient_environment: true,
        });
        if (deployment.status !== 201) {
          core.setFailed(`unexpected ${deployment.status} on deployment creation`);
          return;
        }
        const deploymentID = deployment.data.id;

        await github.rest.repos.createDeploymentStatus({
          owner,
          repo,
          deployment_id: deploymentID,
          state: 'in_progress',
          log_url: logsURL,
          description,
        });
        core.info(`created deployment ${deploymentID} with status "in_progress"`);

        core.setOutput('deployment_id', deploymentID);
        core.setOutput('env', environment);
        break;
      }

      case 'finish': {
        const deploymentID = getInput('DEPLOYMENT_ID');
        const envURL = getOptionalInput('ENV_URL');
        // Cancelled jobs leave the environment inactive
        const status = getInput('STATUS').toLowerCase();
        const state = status === 'cancelled' ? 'inactive' : status;

        if (!deploymentID) {
          core.setFailed('deployment_id input is required for the finish step');
          return;
        }
        if (!VALID_STATUSES.includes(status)) {
          core.setFailed(`unexpected status ${status}`);
          return;
        }

        // Deactivate previous deployments so the environment shows only the latest one
        await deactivateEnvironment();

        await github.rest.repos.createDeploymentStatus({
          owner,
          repo,
          deployment_id: parseInt(deploymentID, 10),
          state,
          description,
          log_url: logsURL,
          // only set the environment url if the deployment succeeded
          environment_url: state === 'success' ? envURL : '',
          auto_inactive: true,
        });
        core.info(`deployment ${deploymentID} status set to ${state}`);
        break;
      }

      case 'delete-env': {
        const deployments = await deactivateEnvironment();

        for (const deployment of deployments.data) {
          core.info(`${environment}.${deployment.id}: deleting deployment`);
          await github.rest.repos.deleteDeployment({
            owner,
            repo,
            deployment_id: deployment.id,
          });
        }

        core.info(`deleting environment "${environment}"`);
        try {
          await github.rest.repos.deleteAnEnvironment({
            owner,
            repo,
            environment_name: environment,
          });
        } catch (error) {
          // The environment may not exist (eg. nothing was ever deployed to it)
          if (error.status !== 404) {
            throw error;
          }
        }
        break;
      }

      default:
        core.setFailed(`unknown step type ${step}`);
    }
  } catch (error) {
    core.setFailed(`unexpected error encountered: ${error}`);
  }
};
