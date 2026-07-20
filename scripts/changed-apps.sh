#!/usr/bin/env bash
set -euo pipefail

base_sha="${1:?base SHA is required}"
head_sha="${2:-HEAD}"

all_apps() {
  find apps -mindepth 2 -maxdepth 2 -name skaffold.yaml -print \
    | sed -E 's#^apps/([^/]+)/skaffold.yaml$#\1#' \
    | sort -u
}

if [[ "$base_sha" =~ ^0+$ ]] || ! git cat-file -e "${base_sha}^{commit}" 2>/dev/null; then
  base_sha="$(git hash-object -t tree /dev/null)"
fi

changed_files="$(git diff --name-only "$base_sha" "$head_sha")"

if grep -Eq '^(\.github/workflows/release\.yml|scripts/)' <<<"$changed_files"; then
  apps="$(all_apps)"
else
  apps="$(sed -nE 's#^apps/([^/]+)/.*#\1#p' <<<"$changed_files" | sort -u)"
fi

if [[ -z "$apps" ]]; then
  echo '[]'
else
  printf '%s\n' "$apps" | jq -Rsc 'split("\n") | map(select(length > 0))'
fi
