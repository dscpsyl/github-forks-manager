#!/usr/bin/env bash
set -uo pipefail

: "${GH_TOKEN:?Set GH_TOKEN to a GitHub token}"
: "${SYNC_MODE:=safe}"

if [[ "$SYNC_MODE" != "safe" && "$SYNC_MODE" != "mirror" ]]; then
  echo "SYNC_MODE must be safe or mirror" >&2
  exit 2
fi

OWNER="$(gh api user --jq .login)" || exit 1
FAILED=0

while IFS= read -r line || [[ -n "$line" ]]; do

  # Remove comments and surrounding whitespace.
  upstream="${line%%#*}"
  upstream="$(printf '%s' "$upstream" | xargs)"
  [[ -z "$upstream" ]] && continue

  if [[ ! "$upstream" =~ ^[^/]+/[^/]+$ ]]; then
    echo "::error::Invalid repository: $upstream"
    FAILED=1
    continue
  fi

  name="${upstream##*/}"
  fork="$OWNER/$name-mirror"

  echo "::group::${upstream} -> ${fork}"

  # Read source metadata; this also verifies access to private sources.
  if ! metadata="$(gh api "repos/$upstream" \
      --jq '[.default_branch, .fork]' 2>/dev/null)"; then
    echo "::error::Cannot access upstream $upstream"
    FAILED=1
    echo "::endgroup::"
    continue
  fi

  branch="$(gh api "repos/$upstream" --jq .default_branch)" || {
    FAILED=1
    echo "::endgroup::"
    continue
  }

  # Check whether the destination already exists.
  if gh api "repos/$fork" --silent 2>/dev/null; then
    echo "Destination exists: $fork"
  else
    echo "Creating fork of $upstream"

    if ! gh repo fork "$upstream" \
        --fork-name "$name" --clone=false; then
      echo "::error::Could not create fork $fork"
      FAILED=1
      echo "::endgroup::"
      continue
    fi

    # Fork creation can take a short time to complete.
    ready=0
    for attempt in {1..12}; do
      if gh api "repos/$fork" --silent 2>/dev/null; then
        ready=1
        break
      fi
      sleep 10
    done

    if [[ "$ready" != 1 ]]; then
      echo "::error::Fork not available: $fork"
      FAILED=1
      echo "::endgroup::"
      continue
    fi
  fi

  # Sync only the upstream default branch.
  args=(repo sync "$fork" --source "$upstream" --branch "$branch")

  if [[ "$SYNC_MODE" == "mirror" ]]; then
    args+=(--force)
  fi

  if gh "${args[@]}"; then
    echo "Sync successful: $fork ($branch)"
  else
    echo "::error::Sync failed: $fork ($branch)"
    echo "Check permissions, branch divergence, and repository settings."
    FAILED=1
  fi

  echo "::endgroup::"
done < upstreams.txt

exit "$FAILED"
