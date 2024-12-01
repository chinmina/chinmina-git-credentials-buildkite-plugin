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
      - chinmina/chinmina-git-credentials#v1.1.0:
          vendor-url: "https://chinmina-bridge-url"
          audience: "chinmina:your-github-organization"
```

## Configuration

### `vendor-url` (Required, string)

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

## Developing

Run tests and plugin linting locally using `docker compose`:

```shell
# Buildkite plugin linter
docker-compose run --rm lint

# Bash tests
docker-compose run --rm tests
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
