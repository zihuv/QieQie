#!/bin/bash

set -euo pipefail

APP_NAME="QieQie"
INFO_PLIST="QieQie/Support/Info.plist"
PROJECT_FILE="QieQie.xcodeproj/project.pbxproj"
CHANGELOG_FILE="docs/CHANGELOG.md"
RELEASE_TEMPLATE=".github/release_template.md"
VERSION_PATTERN='^[0-9]+\.[0-9]+\.[0-9]+$'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

fail() {
  echo "$1" >&2
  exit 1
}

ensure_required_files_exist() {
  local file

  for file in "$INFO_PLIST" "$PROJECT_FILE" "$CHANGELOG_FILE"; do
    [[ -f "$file" ]] || fail "Required file is missing: $file"
  done
}

validate_version() {
  local version="$1"

  if [[ ! "$version" =~ $VERSION_PATTERN ]]; then
    fail "Invalid version: ${version:-<empty>}. Expected semver like 1.2.3."
  fi
}

plist_value() {
  local key="$1"
  /usr/libexec/PlistBuddy -c "Print :$key" "$INFO_PLIST"
}

project_setting_value() {
  local key="$1"
  local values
  local count

  values="$(perl -ne "print qq{\$1\\n} if /${key} = ([^;]+);/" "$PROJECT_FILE" | sort -u)"

  if [[ -z "$values" ]]; then
    fail "Missing ${key} in ${PROJECT_FILE}."
  fi

  count="$(printf '%s\n' "$values" | sed '/^$/d' | wc -l | tr -d '[:space:]')"

  if [[ "$count" != "1" ]]; then
    fail "${PROJECT_FILE} contains multiple ${key} values:\n${values}"
  fi

  printf '%s' "$values"
}

render_release_body() {
  local version="$1"
  local tag="$2"
  local changelog_body

  changelog_body="$(render_changelog_release_body "$version")"

  if [[ -n "$changelog_body" ]]; then
    printf '%s\n' "$changelog_body"
    return
  fi

  if [[ -f "$RELEASE_TEMPLATE" ]]; then
    sed \
      -e "s/VERSION/${version}/g" \
      -e "s/TAG/${tag}/g" \
      "$RELEASE_TEMPLATE"
    return
  fi

  printf 'Download %s %s from the assets below.\n' "$APP_NAME" "$version"
}

render_changelog_release_body() {
  local version="$1"

  VERSION="$version" CHANGELOG_PATH="$CHANGELOG_FILE" perl <<'PERL'
use strict;
use warnings;

my $version = $ENV{VERSION};
my $path = $ENV{CHANGELOG_PATH};

open my $fh, '<', $path or die "Failed to open $path: $!";
local $/;
my $content = <$fh>;
close $fh;

if ($content =~ /^## \[\Q$version\E\] - [^\n]+\n(.*?)(?=^## \[|\z)/ms) {
    my $body = $1;
    $body =~ s/\A\s+//;
    $body =~ s/\s+\z//;

    if (length $body) {
        print "## 更新内容\n\n$body\n";
    }
}
PERL
}

write_github_output() {
  local version="$1"
  local tag="$2"
  local release_name="$3"
  local body="$4"
  local delimiter

  delimiter="EOF_$(date +%s)"

  {
    printf 'version=%s\n' "$version"
    printf 'tag=%s\n' "$tag"
    printf 'release_name=%s\n' "$release_name"
    printf 'body<<%s\n' "$delimiter"
    printf '%s\n' "$body"
    printf '%s\n' "$delimiter"
  } >> "$GITHUB_OUTPUT"
}

main() {
  local raw_input="${1:-}"
  local version
  local tag
  local release_name
  local marketing_version
  local build_version
  local plist_short_version
  local plist_bundle_version
  local body

  if [[ -z "$raw_input" ]]; then
    fail "Usage: ./scripts/prepare-release.sh <version-or-tag>"
  fi

  version="$raw_input"
  validate_version "$version"
  ensure_required_files_exist
  tag="${version}"
  release_name="${version}"

  plist_short_version="$(plist_value CFBundleShortVersionString)"
  plist_bundle_version="$(plist_value CFBundleVersion)"
  marketing_version="$(project_setting_value MARKETING_VERSION)"
  build_version="$(project_setting_value CURRENT_PROJECT_VERSION)"

  [[ "$plist_short_version" == "$version" ]] || fail "${INFO_PLIST} CFBundleShortVersionString expected ${version}, found ${plist_short_version}."
  [[ "$plist_bundle_version" == "$version" ]] || fail "${INFO_PLIST} CFBundleVersion expected ${version}, found ${plist_bundle_version}."
  [[ "$marketing_version" == "$version" ]] || fail "${PROJECT_FILE} MARKETING_VERSION expected ${version}, found ${marketing_version}."
  [[ "$build_version" == "$version" ]] || fail "${PROJECT_FILE} CURRENT_PROJECT_VERSION expected ${version}, found ${build_version}."

  body="$(render_release_body "$version" "$tag")"

  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    write_github_output "$version" "$tag" "$release_name" "$body"
    echo "Prepared release metadata for ${tag}"
    return
  fi

  echo "Validated release version ${version}"
  echo
  echo "$body"
}

main "$@"
