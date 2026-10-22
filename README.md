# GitHub Forks Manager - GitHub Action

An easy way to manage multiple upstream forks with pure GitBub Actions. It will create individual forked repositories and automatically update them as the upstreams are updated. For those who have multiple upstream repositories to track.

> Note: This currently only works for tracking GitHub repos. Support for other upstream sources (repos, servers, etc.) will be added later.


## Prerequisites

1. A GitHub account with access to GitHub Actions
2. Permissions and tokens for this action to view/clone the upstream sources.
3. Permission to write to the forked repositories in your account through a [personal access token (PAT)](https://github.com/settings/personal-access-tokens).

## Access

### GitHub PAT

For this action to create and manage the forked repos, it will need a PAT for the account you want the forked repos to be in with the following permissions:

| Permission | Value |
|---|---|
| Contents | Read and write |
| Repository creation | Read and write |


