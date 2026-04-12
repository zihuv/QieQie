#!/bin/bash

set -euo pipefail

INFO_PLIST="QieQie/Info.plist"
PROJECT_FILE="QieQie.xcodeproj/project.pbxproj"
VERSION_PATTERN='^[0-9]+\.[0-9]+\.[0-9]+$'
VERSION_FILES=("$INFO_PLIST" "$PROJECT_FILE")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

fail() {
  echo "$1" >&2
  exit 1
}

show_help() {
  cat <<'EOF'
Usage: ./scripts/release.sh <version> [--dry-run] [--no-push]

Examples:
  ./scripts/release.sh 1.0.1
  ./scripts/release.sh 1.0.1 --dry-run
  ./scripts/release.sh 1.0.1 --no-push
EOF
}

ensure_valid_version() {
  local version="$1"

  if [[ ! "$version" =~ $VERSION_PATTERN ]]; then
    fail "Invalid version: ${version:-<empty>}. Expected semver like 1.2.3."
  fi
}

current_version() {
  /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST"
}

ensure_clean_worktree() {
  local status
  status="$(git status --short)"

  if [[ -n "$status" ]]; then
    fail "Working tree is not clean. Commit or stash these changes first:\n${status}"
  fi
}

ensure_tag_does_not_exist() {
  local version="$1"
  local tag="${version}"

  if git rev-parse -q --verify "refs/tags/${tag}" >/dev/null 2>&1; then
    fail "Git tag already exists: ${tag}"
  fi
}

ensure_upstream_exists() {
  if ! git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    fail "Current branch has no upstream branch. Use --no-push or configure upstream first."
  fi
}

update_versions() {
  local version="$1"

  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${version}" "$INFO_PLIST"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${version}" "$INFO_PLIST"

  perl -0pi -e 's/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = '"${version}"';/g; s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = '"${version}"';/g' "$PROJECT_FILE"
}

print_plan() {
  local version="$1"
  local no_push="$2"
  local tag="${version}"

  echo "Release plan:"
  echo "- update ${VERSION_FILES[*]} to ${version}"
  echo "- ./scripts/prepare-release.sh ${version}"
  echo "- git add ${VERSION_FILES[*]}"
  echo "- git commit -m \"release: ${version}\""
  echo "- git tag -a ${tag} -m \"${tag}\""

  if [[ "$no_push" == "false" ]]; then
    echo "- git push --follow-tags"
  fi
}

main() {
  local version=""
  local dry_run="false"
  local no_push="false"
  local arg
  local tag

  for arg in "$@"; do
    case "$arg" in
      --dry-run)
        dry_run="true"
        ;;
      --no-push)
        no_push="true"
        ;;
      --help)
        show_help
        return
        ;;
      --*)
        fail "Unknown option: $arg"
        ;;
      *)
        if [[ -n "$version" ]]; then
          fail "Unexpected extra argument: $arg"
        fi
        version="$arg"
        ;;
    esac
  done

  ensure_valid_version "$version"

  if [[ "$(current_version)" == "$version" ]]; then
    fail "Version is already ${version}. Nothing to release."
  fi

  ensure_clean_worktree
  ensure_tag_does_not_exist "$version"

  if [[ "$no_push" == "false" ]]; then
    ensure_upstream_exists
  fi

  if [[ "$dry_run" == "true" ]]; then
    print_plan "$version" "$no_push"
    return
  fi

  tag="${version}"

  update_versions "$version"
  ./scripts/prepare-release.sh "$version" >/dev/null

  git add -- "${VERSION_FILES[@]}"
  git commit -m release: ${version}"
  git tag -a "$tag" -m "$tag"

  if [[ "$no_push" == "false" ]]; then
    git push --follow-tags
  fi
}

main "$@"
