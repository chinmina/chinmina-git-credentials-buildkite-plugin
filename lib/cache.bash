#!/bin/bash
# Cache library for OIDC token caching

# Cache file TTL in minutes
CACHE_TTL_MINUTES=5

# Returns the full cache file path for a given Buildkite job ID
cache_get_file_path() {
  local job_id="${1:?job_id parameter required}"
  echo "${TMPDIR}/chinmina-oidc-${job_id}.cache"
}

# Reads cached content if valid (exists, non-empty, within TTL), returning
# non-zero on failure. Content is written to stdout.
cache_read() {
  local job_id="${1:?job_id parameter required}"
  local cache_file
  cache_file="$(cache_get_file_path "${job_id}")"

  if [[ -f "${cache_file}" && -s "${cache_file}" && $(find "${cache_file}" -mmin -${CACHE_TTL_MINUTES}) ]]; then
    cat "${cache_file}"
    return 0
  fi

  return 1
}

# Writes content to the cache file given the Buildkite Job ID and the token to
# cache.
cache_write() {
  local job_id="${1:?job_id parameter required}"
  local content="${2:?content parameter required}"
  local cache_file
  cache_file="$(cache_get_file_path "${job_id}")"

  echo "${content}" > "${cache_file}"
}
