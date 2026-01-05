# chinmina-git-credentials-buildkite-plugin

Combines a Git credential helper with a [`chinmina-bridge` helper
agent][chinmina-bridge] to allow Buildkite agents securely authorize Github
repository access.

The plugin contains a Git credential helper, enabled for the current step via an
`environment` hook.

The credential helper calls `chinmina-bridge` when credentials for a GitHub
repository are requested, supplying the result to Git in its expected format.

> [!IMPORTANT]
> Refer to the [Chinmina documentation][chinmina-integration] for detailed
> information about configuring and using this plugin effectively.
>
> While this plugin can be used as a regular Buildkite plugin, it must be
> enabled on every step. **This includes any steps configured in the [pipeline
> configuration](https://buildkite.com/docs/pipelines/defining-steps).** This is
> difficult to implement and maintain; hence the [strategy
> suggested][chinmina-integration].

## Example

Add the following to your `pipeline.yml`:

```yml
steps:
  - command: ls
    plugins:
      - chinmina/chinmina-git-credentials#v1.4.1:
          chinmina-url: "https://chinmina-bridge-url"
          audience: "chinmina:your-github-organization"
          profiles:
            - pipeline:default
            - org:buildkite-plugins
```

## Configuration

### `chinmina-url` (Required, string)

The URL of the [`chinmina-bridge`][chinmina-bridge] helper agent that vends a
token for a pipeline. This is a separate HTTP service that must accessible to
your Buildkite agents.

### `audience` (string)

**Default:** `chinmina:default`

The value of the `aud` claim of the OIDC JWT that will be sent to
[`chinmina-bridge`][chinmina-bridge]. This must correlate with the value
configured in the `chinmina-bridge` settings.

A recommendation: `chinmina:your-github-organization`. This is specific
to the purpose of the token, and also scoped to the GitHub organization that
tokens will be vended for. `chinmina-bridge`'s GitHub app is configured for a
particular GitHub organization/user, so if you have multiple organizations,
multiple agents will need to be running.

### `profiles` (array)

**Default:** [`pipeline:default`]

An array of profile names to use when requesting a token from
[`chinmina-bridge`][chinmina-bridge]. Organization profiles are stored outside
of `chinmina-bridge`, and must be set up in your deployment explicitly.
For more information, see the [Chinmina documentation][organization-profiles].

## Token Caching

The credential helper caches OIDC tokens for 5 minutes to reduce latency and load on successive Git operations within the same build job. This improves performance when multiple repository operations occur in a single step.

**Encryption requirement:** Caching is only enabled when `openssl` is available on the agent. If `openssl` is not found, the credential helper skips caching and requests a fresh OIDC token for each Git operation.

**Cache security:** When enabled, the cache file is encrypted using AES-256-CBC with PBKDF2 (100,000 iterations), using the `BUILDKITE_AGENT_ACCESS_TOKEN` as the encryption key. The cache file is written to `${TMPDIR}/chinmina-oidc-${BUILDKITE_JOB_ID}.cache` with 600 permissions, restricting access to the build agent process.

**Cache scope:** Each build job maintains its own cache file, identified by `BUILDKITE_JOB_ID`. The cache expires after 5 minutes or when the temporary directory is cleaned up.

## Developing

Run tests and plugin linting locally using `docker compose`:

```shell
# Buildkite plugin linter
docker compose run --rm lint

# Bash tests
docker compose run --rm tests
```

## Contributing

Contributions are welcome! Raise a PR, and include tests with your changes.

1. Fork the repo
2. Make the changes
3. Run the tests and linter
4. Commit and push your changes
5. Send a pull request

[chinmina-bridge]: https://chinmina.github.io/introduction/
[chinmina-integration]: https://chinmina.github.io/guides/buildkite-integration/
[organization-profiles]: https://chinmina.github.io/reference/organization-profile/
