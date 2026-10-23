
#!/usr/bin/env bash
set -uo pipefail

# Configuration
readonly MANIFEST="upstreams.txt"
readonly VALID_MODES=("safe" "mirror" "skip")

# Exit if authentication is missing.
: "${GH_TOKEN:?Set GH_TOKEN to a GitHub token}"

# Remove leading/trailing whitespace.
trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

# Log a GitHub Actions error and mark the run as failed.
fail() {
  printf '::error::%s\n' "$*" >&2
  FAILED=1
}

# Parse a manifest entry: OWNER/REPO [| MODE]
# Defaults to safe if mode is omitted or empty.
parse_entry() {
  local line="$1"
  local upstream mode

  line="$(trim "$line")"

  # Ignore blank lines and full-line comments.
  [[ -z "$line" || "$line" == \#* ]] && return 1

  # Remove inline comments.
  line="$(trim "${line%%#*}")"

  if [[ "$line" == *"|"* ]]; then
    upstream="$(trim "${line%%|*}")"
    mode="$(trim "${line#*|}")"
  else
    upstream="$line"
    mode="safe"
  fi

  # An empty mode defaults to safe.
  mode="${mode:-safe}"

  if [[ ! "$upstream" =~ ^[^/]+/[^/]+$ ]]; then
    fail "Invalid repository entry: '$upstream'"
    return 2
  fi

  case "$mode" in
    safe|mirror|skip) ;;
    *)
      fail "Invalid mode '$mode' for '$upstream'; use safe, mirror, or skip"
      return 2
      ;;
  esac

  PARSED_UPSTREAM="$upstream"
  PARSED_MODE="$mode"
}

# Check whether a repository is accessible to the authenticated account.
repository_exists() {
  gh api "repos/$1" --silent >/dev/null 2>&1
}

# Wait for a newly created fork to become accessible.
wait_for_fork() {
  local fork="$1"
  local attempt

  for attempt in {1..12}; do
    if repository_exists "$fork"; then
      return 0
    fi
    sleep 10
  done

  return 1
}

# Ensure a fork exists. The fork name is the upstream repo name.
ensure_fork() {
  local upstream="$1"
  local fork="$2"

  # If the destination already exists, reuse it.
  if repository_exists "$fork"; then
    echo "Fork already exists: $fork"
    return 0
  fi

  echo "Creating fork of $upstream as $fork"

  if ! gh repo fork "$upstream" \
      --fork-name "${fork##*/}" \
      --clone=false; then

    # Fork creation may have succeeded despite a delayed API response.
    if repository_exists "$fork"; then
      echo "Fork now exists: $fork"
      return 0
    fi

    fail "Fork creation failed: $fork"
    return 1
  fi

  if ! wait_for_fork "$fork"; then
    fail "Fork did not become accessible: $fork"
    return 1
  fi

  echo "Fork created successfully: $fork"
  return 0
}

# Sync one fork using its configured policy.
sync_fork() {
  local upstream="$1"
  local mode="$2"
  local fork="$3"
  local branch
  local -a args

  if [[ "$mode" == "skip" ]]; then
    echo "Skipping $upstream (mode: skip)"
    return 0
  fi

  # Read the upstream's current default branch.
  if ! branch="$(gh api "repos/$upstream" \
      --jq '.default_branch')"; then
    fail "Cannot read upstream or default branch: $upstream"
    return 1
  fi

  if [[ -z "$branch" || "$branch" == "null" ]]; then
    fail "Upstream has no readable default branch: $upstream"
    return 1
  fi

  if ! ensure_fork "$upstream" "$fork"; then
    return 1
  fi

  args=(repo sync "$fork" --source "$upstream" --branch "$branch")

  if [[ "$mode" == "mirror" ]]; then
    args+=(--force)
    echo "Mirror mode: upstream is authoritative for $fork ($branch)"
  else
    echo "Safe mode: syncing $fork ($branch) without force"
  fi

  if gh "${args[@]}"; then
    echo "Sync successful: $fork"
    return 0
  else
    fail "Sync failed: $fork (mode: $mode)"
    return 1
  fi
}

main() {
  local owner line
  local line_no=0
  local upstream mode fork
  local parse_status

  if [[ ! -r "$MANIFEST" ]]; then
    echo "Manifest not readable: $MANIFEST" >&2
    return 2
  fi

  if ! owner="$(gh api user --jq '.login')"; then
    echo "Unable to determine authenticated GitHub user" >&2
    return 2
  fi

  echo "Authenticated GitHub account: $owner"
  echo "Reading manifest: $MANIFEST"

  while IFS= read -r line || [[ -n "$line" ]]; do
    ((line_no += 1))

    parse_entry "$line"
    parse_status=$?

    # 1 = blank/comment; 2 = invalid entry.
    if [[ "$parse_status" -eq 1 ]]; then
      continue
    elif [[ "$parse_status" -ne 0 ]]; then
      echo "Error on manifest line $line_no"
      continue
    fi

    upstream="$PARSED_UPSTREAM"
    mode="$PARSED_MODE"

    if [[ "$mode" == "skip" ]]; then
      echo "Skipping $upstream (mode: skip)"
      continue
    fi

    # Forks are created under the authenticated user's account.
    fork="$owner/${upstream##*/}-mirror"

    echo "::group::Line $line_no: $upstream [$mode]"
    sync_fork "$upstream" "$mode" "$fork" || true
    echo "::endgroup::"
  done < "$MANIFEST"

  if [[ "$FAILED" -ne 0 ]]; then
    echo "Completed with errors; see messages above."
    return 1
  fi

  echo "All configured repositories processed successfully."
}

FAILED=0
main "$@"
