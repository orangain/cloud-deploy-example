#!/usr/bin/env bash
set -euo pipefail

app_dir="${1:?app directory is required}"

if [[ ! -d "$app_dir" ]]; then
  echo "App directory not found: $app_dir" >&2
  exit 1
fi

configs=()
[[ -f "$app_dir/Dockerfile" ]] && configs+=("cloudbuild/docker.yaml")
[[ -f "$app_dir/go.mod" ]] && configs+=("cloudbuild/ko.yaml")

case "${#configs[@]}" in
  1)
    echo "${configs[0]}"
    ;;
  0)
    echo "No supported builder found in $app_dir" >&2
    exit 1
    ;;
  *)
    echo "Multiple builders found in $app_dir: ${configs[*]}" >&2
    exit 1
    ;;
esac
