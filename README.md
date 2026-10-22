# GitHub Forks Manager - GitHub Action

An easy way to manage multiple upstream forks with pure GitBub Actions. It will create individual forked repositories and automatically update them as the upstreams are updated. For those who have multiple upstream repositories to track.

> Note: This currently only works for tracking GitHub repos. Support for other upstream sources (repos, servers, etc.) will be added later.


## Prerequisites

1. A GitHub account with access to GitHub Actions
2. Permissions and tokens for this action to view/clone the upstream sources.
3. Permission to write to the forked repositories in your account through a [personal access token (PAT)](https://github.com/settings/personal-access-tokens).

## Access

### Upstream

Make sure this action has PATs or other access tokens necessary to read/fork the upstream data.

### GitHub PAT

For this action to create and manage the forked repos, it will need a PAT for the account you want the forked repos to be in with the following permissions:

| Permission | Value |
|---|---|
| Contents | Read and write |
| Repository creation | Read and write |

You will need to add this PAT to this action's secret under `FORK_SYNC_TOKEN`.

## Sync Mode (Optional)

This action allows for two types of sync mode per repository:

**mirror**: Upstream will always be mirrored to the fork. Local fork changes are not saved on the default fork branch.
**safe**: Any changes made on the local branch will cause the fork update to fail and reported.

The default is **safe**.

## Considerations & Limitations

1. For a large number of repos, make sure to monitor GitHub's API rate limit and adjust the action accordingly. It is currently set to run at 5:30 PM daily.
2. This action does not guarantee that all metadata about the upstream will be forked, nor does it guarantee that the action will run at the exact time specified. Some repos also do not allow forking. If you need to ensure metadata or a consistent update, another approach will be needed.
3. Currently, this action forks the default branch and only the default branch. If you wish to make changes on the fork, make sure to do so on a different branch to be safe.
4. Make sure to manually run it at least once to test on your setup.
