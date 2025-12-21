#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"

#
# Tests for cache library
#

# Helper: Create a stub bin directory and prepend to PATH
_setup_stub_bin() {
  export STUB_BIN_DIR="${TMPDIR}/stub-bin"
  mkdir -p "${STUB_BIN_DIR}"
  export PATH="${STUB_BIN_DIR}:${PATH}"
}

# Helper: Add openssl stub that passes version checks and can encrypt/decrypt
_add_openssl_stub() {
  local stub_script="${STUB_BIN_DIR}/openssl"

  cat > "${stub_script}" << 'STUB'
#!/bin/bash
# openssl stub for testing
if [[ "$1" == "version" ]]; then
  echo "OpenSSL 1.1.1 (stub)"
  exit 0
fi
# Encryption: openssl enc ... -out <file> -pass ...
# Find -out argument and write base64 encoded data there
if [[ "$1" == "enc" && "$2" != "-d" ]]; then
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "-out" ]]; then
      shift
      base64 > "$1"
      exit 0
    fi
    shift
  done
fi
# Decryption: openssl enc -d ... -in <file> -pass ...
if [[ "$1" == "enc" && "$2" == "-d" ]]; then
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "-in" ]]; then
      shift
      base64 -d < "$1"
      exit 0
    fi
    shift
  done
fi
exit 1
STUB
  chmod +x "${stub_script}"
}

setup() {
  export TMPDIR="$(mktemp -d)"
  export BUILDKITE_JOB_ID="test-job-$$"
  export BUILDKITE_AGENT_ACCESS_TOKEN="test-agent-token-for-encryption"

  # Set up stub bin directory for controlling tool availability
  _setup_stub_bin

  # Source the cache library
  source "${PWD}/lib/cache.bash"
}

teardown() {
  rm -rf "${TMPDIR}"
  unset TMPDIR
  unset BUILDKITE_JOB_ID
  unset BUILDKITE_AGENT_ACCESS_TOKEN
  unset STUB_BIN_DIR
}

#
# cache_get_file_path tests
#

@test "cache_get_file_path returns path with job ID" {
  local result
  result="$(cache_get_file_path "my-job-123")"

  assert_equal "${result}" "${TMPDIR}/chinmina-oidc-my-job-123.cache"
}

@test "cache_get_file_path uses TMPDIR" {
  export TMPDIR="/custom/tmp/dir"
  local result
  result="$(cache_get_file_path "job-456")"

  assert_equal "${result}" "/custom/tmp/dir/chinmina-oidc-job-456.cache"
}

@test "cache_get_file_path fails without job_id" {
  run cache_get_file_path

  assert_failure
  assert_output --partial "job_id parameter required"
}

#
# cache_write and cache_read tests
#

@test "cache_write and cache_read round-trip" {
  _add_openssl_stub
  local test_content="test-token-abc123"

  cache_write "${BUILDKITE_JOB_ID}" "${test_content}"

  run cache_read "${BUILDKITE_JOB_ID}"

  assert_success
  assert_output "${test_content}"
}

@test "cache_read returns failure when cache does not exist" {
  _add_openssl_stub
  run cache_read "nonexistent-job"

  assert_failure
  assert_output ""
}

@test "cache_read returns failure when cache is empty" {
  _add_openssl_stub
  local cache_file
  cache_file="$(cache_get_file_path "${BUILDKITE_JOB_ID}")"
  touch "${cache_file}"

  run cache_read "${BUILDKITE_JOB_ID}"

  assert_failure
}

@test "cache_write fails without job_id" {
  run cache_write

  assert_failure
  assert_output --partial "job_id parameter required"
}

@test "cache_write fails without content" {
  run cache_write "${BUILDKITE_JOB_ID}"

  assert_failure
  assert_output --partial "content parameter required"
}

@test "cache_read fails without job_id" {
  run cache_read

  assert_failure
  assert_output --partial "job_id parameter required"
}

#
# cache TTL tests
#

@test "cache_read returns success for fresh cache" {
  _add_openssl_stub
  cache_write "${BUILDKITE_JOB_ID}" "fresh-token"

  run cache_read "${BUILDKITE_JOB_ID}"

  assert_success
  assert_output "fresh-token"
}

@test "cache_read returns failure for expired cache" {
  _add_openssl_stub
  local cache_file
  cache_file="$(cache_get_file_path "${BUILDKITE_JOB_ID}")"

  # Write the cache
  cache_write "${BUILDKITE_JOB_ID}" "old-token"

  # Set modification time to 6 minutes ago using portable timestamp arithmetic
  local now_ts six_min_ago_ts six_min_ago
  now_ts="$(date +%s)"
  six_min_ago_ts=$((now_ts - 360))
  six_min_ago="$(date -d "@${six_min_ago_ts}" +%Y%m%d%H%M.%S 2>/dev/null || date -r "${six_min_ago_ts}" +%Y%m%d%H%M.%S)"
  touch -t "${six_min_ago}" "${cache_file}"

  run cache_read "${BUILDKITE_JOB_ID}"

  assert_failure
}

@test "cache_read returns success for cache just under TTL" {
  _add_openssl_stub
  local cache_file
  cache_file="$(cache_get_file_path "${BUILDKITE_JOB_ID}")"

  # Write the cache
  cache_write "${BUILDKITE_JOB_ID}" "valid-token"

  # Set modification time to 4 minutes ago (within TTL)
  local now_ts four_min_ago_ts four_min_ago
  now_ts="$(date +%s)"
  four_min_ago_ts=$((now_ts - 240))
  four_min_ago="$(date -d "@${four_min_ago_ts}" +%Y%m%d%H%M.%S 2>/dev/null || date -r "${four_min_ago_ts}" +%Y%m%d%H%M.%S)"
  touch -t "${four_min_ago}" "${cache_file}"

  run cache_read "${BUILDKITE_JOB_ID}"

  assert_success
  assert_output "valid-token"
}

#
# Encryption tests
#

@test "_get_encryption_method returns openssl when available" {
  _add_openssl_stub

  run _get_encryption_method

  assert_success
  assert_output "openssl"
}

@test "_get_encryption_method returns empty when openssl unavailable" {
  # No stub added, so openssl version will fail

  run _get_encryption_method

  assert_success
  assert_output ""
}

@test "cache_write succeeds when no encryption available" {
  # No stub added, so encryption is unavailable

  run cache_write "${BUILDKITE_JOB_ID}" "test-content"

  assert_success

  # Cache file should not exist
  local cache_file
  cache_file="$(cache_get_file_path "${BUILDKITE_JOB_ID}")"
  [[ ! -f "${cache_file}" ]]
}

@test "cache_read fails when no encryption available" {
  # No stub added, so decryption is unavailable

  run cache_read "${BUILDKITE_JOB_ID}"

  assert_failure
}

@test "encrypted cache file has 600 permissions" {
  _add_openssl_stub
  cache_write "${BUILDKITE_JOB_ID}" "test-token"

  local cache_file permissions
  cache_file="$(cache_get_file_path "${BUILDKITE_JOB_ID}")"
  permissions="$(stat -c '%a' "${cache_file}")"

  assert_equal "${permissions}" "600"
}

@test "cache file is encrypted (not plaintext)" {
  _add_openssl_stub
  local test_content="plaintext-secret-token"
  cache_write "${BUILDKITE_JOB_ID}" "${test_content}"

  local cache_file
  cache_file="$(cache_get_file_path "${BUILDKITE_JOB_ID}")"

  # The cache file should exist but NOT contain the plaintext
  [[ -f "${cache_file}" ]]
  ! grep -q "${test_content}" "${cache_file}"
}
