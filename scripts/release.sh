#!/bin/bash

set -euo pipefail

INFO_PLIST="QieQie/Support/Info.plist"
PROJECT_FILE="QieQie.xcodeproj/project.pbxproj"
CHANGELOG_FILE="docs/CHANGELOG.md"
VERSION_PATTERN='^[0-9]+\.[0-9]+\.[0-9]+$'
VERSION_FILES=("$INFO_PLIST" "$PROJECT_FILE")
RELEASE_FILES=("$INFO_PLIST" "$PROJECT_FILE" "$CHANGELOG_FILE")

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

version_to_sort_key() {
  local version="$1"
  local major minor patch

  IFS='.' read -r major minor patch <<< "$version"
  printf '%09d%09d%09d' "$major" "$minor" "$patch"
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

ensure_version_advances() {
  local version="$1"
  local current

  current="$(current_version)"

  if [[ "$(version_to_sort_key "$version")" < "$(version_to_sort_key "$current")" ]]; then
    fail "Release version ${version} must be greater than current version ${current}."
  fi
}

update_versions() {
  local version="$1"

  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${version}" "$INFO_PLIST"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${version}" "$INFO_PLIST"

  perl -0pi -e 's/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = '"${version}"';/g; s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = '"${version}"';/g' "$PROJECT_FILE"
}

ensure_changelog_ready() {
  local version="$1"

  if ! rg -q '^## \[Unreleased\]$' "$CHANGELOG_FILE"; then
    fail "${CHANGELOG_FILE} is missing the [Unreleased] section."
  fi

  if rg -q "^## \\[${version}\\]" "$CHANGELOG_FILE"; then
    fail "${CHANGELOG_FILE} already contains version ${version}."
  fi
}

ensure_unreleased_has_entries() {
  if ! awk '
    /^## \[Unreleased\]$/ { in_section=1; next }
    /^## \[/ && in_section { exit found ? 0 : 1 }
    in_section && /^- / { found=1 }
    END { exit found ? 0 : 1 }
  ' "$CHANGELOG_FILE"; then
    fail "${CHANGELOG_FILE} has no unreleased entries to publish."
  fi
}

update_changelog() {
  local version="$1"
  local release_date="$2"
  local tmp_file

  tmp_file="$(mktemp "${TMPDIR:-/tmp}/release-changelog.XXXXXX")"

  VERSION="$version" RELEASE_DATE="$release_date" CHANGELOG_PATH="$CHANGELOG_FILE" perl <<'PERL' > "$tmp_file"
use strict;
use warnings;

my $version = $ENV{VERSION};
my $release_date = $ENV{RELEASE_DATE};
my $path = $ENV{CHANGELOG_PATH};

open my $fh, '<', $path or die "Failed to open $path: $!";
local $/;
my $content = <$fh>;
close $fh;

my $unreleased_header = "## [Unreleased]\n";
my $release_header = "## [$version] - $release_date\n";
my @category_order = qw(Added Changed Deprecated Removed Fixed Security);

$content =~ /\Q$unreleased_header\E/ or die "$path is missing the [Unreleased] section.\n";
$content =~ /^## \[\Q$version\E\]/m and die "$path already contains version $version.\n";

my $pattern = qr/(\Q$unreleased_header\E.*?)(?=^## \[|\z)/ms;
$content =~ $pattern or die "Failed to locate the [Unreleased] section body in $path.\n";

my $unreleased_block = $1;
my $unreleased_body = $unreleased_block;
$unreleased_body =~ s/^\Q$unreleased_header\E//;

my %entries_by_category;
my $current_category = '';

for my $line (split /\n/, $unreleased_body) {
    if ($line =~ /^### (.+)$/) {
        $current_category = $1;
        next;
    }

    next unless length $line;
    next unless $line =~ /^- /;

    push @{ $entries_by_category{$current_category} }, $line;
}

my $entry_count = 0;
$entry_count += scalar @{ $entries_by_category{$_} // [] } for @category_order;
$entry_count > 0 or die "$path has no unreleased entries to publish.\n";

my $release_block = $release_header . "\n";

for my $category (@category_order) {
    my $entries = $entries_by_category{$category} // [];
    next unless @$entries;
    $release_block .= "### $category\n";
    $release_block .= join("\n", @$entries) . "\n\n";
}

$content =~ s/\Q$unreleased_block\E/$unreleased_header\n### Added\n\n### Changed\n\n### Deprecated\n\n### Removed\n\n### Fixed\n\n### Security\n\n$release_block/s
    or die "Failed to update $path.\n";

print $content;
PERL

  mv "$tmp_file" "$CHANGELOG_FILE"
}

print_plan() {
  local version="$1"
  local no_push="$2"
  local tag="${version}"
  local release_date

  release_date="$(date +%F)"

  echo "Release plan:"
  echo "- update ${VERSION_FILES[*]} to ${version}"
  echo "- move docs/CHANGELOG.md [Unreleased] entries into ${version} (${release_date})"
  echo "- ./scripts/prepare-release.sh ${version}"
  echo "- git add ${RELEASE_FILES[*]}"
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
  ensure_required_files_exist

  if [[ "$(current_version)" == "$version" ]]; then
    fail "Version is already ${version}. Nothing to release."
  fi

  ensure_clean_worktree
  ensure_version_advances "$version"
  ensure_tag_does_not_exist "$version"
  ensure_changelog_ready "$version"
  ensure_unreleased_has_entries

  if [[ "$no_push" == "false" ]]; then
    ensure_upstream_exists
  fi

  if [[ "$dry_run" == "true" ]]; then
    print_plan "$version" "$no_push"
    return
  fi

  tag="${version}"

  update_versions "$version"
  update_changelog "$version" "$(date +%F)"
  ./scripts/prepare-release.sh "$version" >/dev/null

  git add -- "${RELEASE_FILES[@]}"
  git commit -m "release: ${version}"
  git tag -a "$tag" -m "$tag"

  if [[ "$no_push" == "false" ]]; then
    git push --follow-tags
  fi
}

main "$@"
