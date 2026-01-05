# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## Project Overview

A Buildkite plugin that provides Git credential helpers for GitHub HTTPS authentication via [chinmina-bridge](https://chinmina.github.io/introduction/). The plugin configures Git to obtain time-limited tokens using Buildkite OIDC tokens, enabling secure repository access without long-lived credentials.

## Development Commands

```bash
# Run the Buildkite plugin linter
docker compose run --rm lint

# Run all BATS tests
docker compose run --rm tests

# Run a specific test by name
docker compose run --rm tests bats tests/environment.bats --filter "test name pattern"

# Debug stub failures in tests (uncomment in tests/environment.bats)
# export DOCKER_STUB_DEBUG=/dev/tty
```

## Architecture

The plugin consists of two bash scripts:

**`hooks/environment`** - Buildkite hook that runs before each step:
- Reads plugin configuration from `BUILDKITE_PLUGIN_CHINMINA_GIT_CREDENTIALS_*` environment variables
- Configures Git via `GIT_CONFIG_*` environment variables to use the credential helper
- Supports multiple profiles, each getting its own credential helper registration

**`credential-helper/buildkite-connector-credential-helper`** - Git credential helper:
- Invoked by Git when HTTPS credentials are needed for github.com
- Validates profile format (`prefix:name`) and characters (alphanumeric, underscore, hyphen)
- Strips profile prefix (`pipeline:`, `repo:`, `org:`) before constructing API request
- Requests OIDC token using `buildkite-agent oidc request-token`
- Caches OIDC token for 5 minutes at `${TMPDIR}/chinmina-oidc-${BUILDKITE_JOB_ID}.cache`
- POSTs to chinmina-bridge to exchange OIDC token for GitHub credentials
  - Pipeline profiles: `POST {url}/git-credentials/{profile_name}`
  - Organization profiles: `POST {url}/organization/git-credentials/{profile_name}`
- Returns credentials in Git's expected format

**Data flow:**
```
Buildkite step → environment hook → sets GIT_CONFIG_* vars
                                          ↓
Git operation (clone/fetch) → credential helper → validate profile → buildkite-agent OIDC → chinmina-bridge → GitHub token
```

## Backward Compatibility

The plugin supports legacy configuration prefixes and parameter names:
- Old plugin prefix: `BUILDKITE_PLUGIN_GITHUB_APP_AUTH_*`
- Old parameter: `vendor-url` (now `chinmina-url`)
- Old profile: `default` (now `pipeline:default`)
- Deprecated profile prefix: `repo:` (now `pipeline:`)

## Testing

Tests use [BATS](https://github.com/bats-core/bats-core) with the Buildkite plugin tester. Tests validate:
- Required parameter enforcement
- Default value handling
- Git configuration output
- Profile iteration
- Profile format validation (colon separator, character restrictions, recognized prefixes)
- Backward compatibility with old naming

The test pattern uses `run_environment` to source the hook and capture `GIT_CONFIG_*` environment variables. Direct credential helper tests verify profile validation logic.
