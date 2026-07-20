#!/usr/bin/env bash
set -euo pipefail

root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT

assert_config() {
  local expected="$1"
  local app_dir="$2"
  local actual

  actual="$(scripts/select-build-config.sh "$app_dir")"
  [[ "$actual" == "$expected" ]] || {
    echo "Expected $expected, got $actual" >&2
    exit 1
  }
}

mkdir -p "$root/docker" "$root/ko" "$root/missing" "$root/ambiguous"
touch "$root/docker/Dockerfile"
touch "$root/ko/go.mod"
touch "$root/ambiguous/Dockerfile" "$root/ambiguous/go.mod"

assert_config "cloudbuild/docker.yaml" "$root/docker"
assert_config "cloudbuild/ko.yaml" "$root/ko"

if scripts/select-build-config.sh "$root/missing" >/dev/null 2>&1; then
  echo "Expected an unsupported app to fail" >&2
  exit 1
fi

if scripts/select-build-config.sh "$root/ambiguous" >/dev/null 2>&1; then
  echo "Expected an ambiguous app to fail" >&2
  exit 1
fi
