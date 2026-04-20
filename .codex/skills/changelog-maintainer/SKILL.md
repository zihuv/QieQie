---
name: changelog-maintainer
description: Update docs/CHANGELOG.md whenever work introduces a user-visible feature, behavior change, fix, deprecation, removal, or security improvement in this repository. Follow Keep a Changelog, write concise user-facing Chinese entries, and keep unreleased notes ready for the next release.
---

# Changelog Maintainer

Use this skill whenever a completed task changes what users can do, see, configure, or rely on in this repository.

Update `docs/CHANGELOG.md` before handing work back to the user when the task includes any of these:

- Added: new user-facing capability, preference, view, workflow, or shortcut
- Changed: behavior change, default change, UI adjustment, or compatibility change that users will notice
- Deprecated: functionality that is still present but should no longer be used
- Removed: deleted functionality, settings, or flows
- Fixed: bug fixes that affect user experience, data correctness, timing, persistence, or reliability
- Security: security or privacy related fixes that matter to users

Skip the changelog only when the work is purely internal and has no user-facing effect, such as:

- refactors with unchanged behavior
- formatting, comments, or test-only updates
- dependency or tooling churn with no user-visible impact

## Workflow

1. Review the task outcome and decide whether users would notice the change.
2. Open `docs/CHANGELOG.md`.
3. If the task is not an explicit release:
   - add bullets under `## [Unreleased]`
   - use only the categories that are needed
4. If the task is an explicit release or version bump:
   - move relevant bullets from `Unreleased` into a new version section
   - format the heading as `## [x.y.z] - YYYY-MM-DD`
   - keep versions in reverse chronological order
5. Keep every bullet short, concrete, and written for humans.

## Writing Rules

- Default to Chinese unless the user asks for another language.
- Describe outcomes, not implementation details.
- Good: `修复暂停后剩余时间偶发跳变的问题。`
- Bad: `修改 FocusTimerManager.swift 的 pause() 逻辑。`
- Merge similar bullets instead of repeating the same change across categories.
- Do not add noise such as documentation edits, code cleanup, or version bumps unless they change user experience.
- Preserve old entries; do not rewrite history unless the existing text is incorrect.

## Preferred Category Order

When multiple sections are needed, keep this order:

1. Added
2. Changed
3. Deprecated
4. Removed
5. Fixed
6. Security

## Final Check

Before finishing, confirm one of these is true:

- `docs/CHANGELOG.md` was updated to reflect the completed user-facing change.
- You intentionally skipped the changelog because the task was internal-only, and you say that explicitly in the final response.
