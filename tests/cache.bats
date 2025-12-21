#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"

#
# Tests for cache library
#

setup() {
  export TMPDIR="$(mktemp -d)"
  export BUILDKITE_JOB_ID="test-job-$$"

  # Source the cache library
  source "${PWD}/lib/cache.bash"
}

teardown() {
  rm -rf "${TMPDIR}"
  unset TMPDIR
  unset BUILDKITE_JOB_ID
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
  local test_content="test-token-abc123"

  cache_write "${BUILDKITE_JOB_ID}" "${test_content}"

  run cache_read "${BUILDKITE_JOB_ID}"

  assert_success
  assert_output "${test_content}"
}

@test "cache_read returns failure when cache does not exist" {
  run cache_read "nonexistent-job"

  assert_failure
  assert_output ""
}

@test "cache_read returns failure when cache is empty" {
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
  cache_write "${BUILDKITE_JOB_ID}" "fresh-token"

  run cache_read "${BUILDKITE_JOB_ID}"

  assert_success
  assert_output "fresh-token"
}

@test "cache_read returns failure for expired cache" {
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
