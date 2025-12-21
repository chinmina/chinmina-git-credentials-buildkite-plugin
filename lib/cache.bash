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
# non-zero on failure. Content is decrypted and written to stdout.
cache_read() {
  local job_id="${1:?job_id parameter required}"
  local cache_file encryption_method
  cache_file="$(cache_get_file_path "${job_id}")"
  encryption_method="$(_get_encryption_method)"

  # No encryption available - can't read encrypted cache
  if [[ -z "${encryption_method}" ]]; then
    return 1
  fi

  if [[ -f "${cache_file}" && -s "${cache_file}" \
      && $(find "${cache_file}" -mmin -${CACHE_TTL_MINUTES}) ]]; then
    if "_decrypt_with_${encryption_method}" "${cache_file}"; then
      return 0
    fi
  fi

  return 1
}

# Writes encrypted content to the cache file given the Buildkite Job ID and the
# token to cache. If no encryption is available, skips caching silently.
# Always returns 0 to avoid breaking callers that use set -e.
cache_write() {
  local job_id="${1:?job_id parameter required}"
  local content="${2:?content parameter required}"
  local cache_file encryption_method
  cache_file="$(cache_get_file_path "${job_id}")"
  encryption_method="$(_get_encryption_method)"

  # No encryption available - skip caching silently
  if [[ -z "${encryption_method}" ]]; then
    return 0
  fi

  # Attempt encryption, ignore failures
  if echo "${content}" | "_encrypt_with_${encryption_method}" "${cache_file}"; then
    chmod 600 "${cache_file}"
  fi

  return 0
}

# Detects if openssl encryption is available.
# Returns "openssl" if available, empty string otherwise.
_get_encryption_method() {
  if command -v openssl > /dev/null 2>&1; then
    echo "openssl"
  fi
}

# OpenSSL encryption/decryption parameters.
#
# Choosing these is a balance between security and performance. Note that (a)
# the Buildkite access token use as the key is high-entropy, and (b) the value
# it's protecting is a short-lived high-entropy token itself.
#
# AES-256-CBC, while non-authenticated, is reasonably modern and well-tested,
# and PBKDF2 with 100,000 iterations makes brute-force attacks on the key
# extremely impractical for the time scale involved.  (Note that GCM is not
# available with `openssl enc`)
#
_openssl_enc_arguments=(-aes-256-cbc -pbkdf2 -iter 100000)

# Encrypts stdin content to the specified cache file using openssl.
# Uses BUILDKITE_AGENT_ACCESS_TOKEN as passphrase.
_encrypt_with_openssl() {
  local cache_file="${1:?cache_file required}"
  openssl enc -salt "${_openssl_enc_arguments[@]}" \
    -out "${cache_file}" \
    -pass "env:BUILDKITE_AGENT_ACCESS_TOKEN" 2>/dev/null
}

# Decrypts the specified cache file using openssl, outputs to stdout.
# Uses BUILDKITE_AGENT_ACCESS_TOKEN as passphrase.
_decrypt_with_openssl() {
  local cache_file="${1:?cache_file required}"
  openssl enc -d "${_openssl_enc_arguments[@]}" \
    -in "${cache_file}" \
    -pass "env:BUILDKITE_AGENT_ACCESS_TOKEN" 2>/dev/null
}
