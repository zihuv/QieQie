---
name: test-and-verify
description: "Use when fixing bugs, validating behavior changes, or checking whether a code change actually works, especially for macOS menu bar apps, SwiftUI/AppKit popovers, layout regressions, and Accessibility-based UI verification. This skill enforces a verification-first workflow: define the claim, reproduce or establish a baseline, choose the narrowest proof path, run it after the change, and report exactly what was and was not verified."
---

# Test And Verify

Use this skill when correctness matters more than code churn. The default stance is: do not trust a fix until it has been exercised through a direct validation path.

This skill is about minimal sufficient evidence, not maximum ceremony. Choose the cheapest proof that can genuinely falsify the claim, and stop once the claim is proven to the degree the change warrants.

## Core Rules

- Write down the claim before editing: observed behavior, expected behavior, and the acceptance check.
- Match verification cost to the risk, scope, and reversibility of the change.
- Reproduce first when the user reports a runtime or interaction bug.
- Prefer the narrowest test that proves the claim.
- Treat validation layers as escalation options, not a mandatory checklist.
- If a change affects UI or event timing, verify the transition points, not just the final steady state.
- Separate logic evidence from UI evidence. If they disagree, keep debugging.
- For menu bar, status bar, or popover UI bugs, prefer state probes and Accessibility inspection over pointer choreography.
- For layout and spacing regressions, verify visibility, clipping, scrolling, and abnormal empty space, not just text presence.
- For low-risk declarative changes, stay at the lowest layer that can still prove the claim; do not escalate to probes or integrated automation unless ambiguity remains.
- Never say a bug is fixed unless at least one realistic validation path was executed after the change.
- Stop escalating once the acceptance check has been satisfied with realistic evidence.
- State plainly what was tested, what passed, and what remains unverified.

## Name The Claim

Capture the target behavior in three lines before making changes:

- Observed: what is happening now.
- Expected: what should happen instead.
- Acceptance check: the exact path that will prove the fix.

If reproduction is not possible, say so explicitly and narrow the claim to the highest-signal path you can validate.

## Set A Proof Budget

Before editing, decide how much evidence the change deserves. Revisit this after inspection if the risk was misjudged.

- Low-risk changes: copy edits, visual polish, spacing tweaks, color changes, boolean view flags, static layout adjustments, and other declarative edits with well-understood framework behavior. Start with code inspection plus the cheapest confirming check such as a build, focused render check, or narrow smoke path.
- Medium-risk changes: control enablement, layout interactions, navigation, state wiring, async UI refresh, or behavior that depends on more than one component. Prefer a focused harness, targeted test, or deterministic smoke path.
- High-risk changes: persistence, data loss, permissions, concurrency, security, billing, external side effects, or multi-surface workflow bugs. Reproduce if possible and use the strongest practical validation path.

Do not spend high-risk verification effort on a low-risk change just because stronger tools are available.

## Validation Layers

Prefer these layers in order when more evidence is needed, stopping at the smallest layer that can prove the claim. Do not climb the ladder automatically.

1. Unit tests for deterministic logic, state transitions, validation rules, and calculations.
2. Focused harnesses for SwiftUI/AppKit view state, layout, focus, and enablement.
3. Local build and deterministic smoke checks for wiring and product-level behavior.
4. Integrated UI checks for menu bar items, popovers, transient windows, and platform-managed surfaces using Accessibility or direct state probes when integrated behavior is actually in question.
5. Manual verification only as a supplement when the above are insufficient.

## Default Workflow

1. Define the claim.
   Record observed behavior, expected behavior, and the acceptance check.
2. Reproduce or capture a baseline.
   Use the most direct available route: existing tests, a focused harness, a temporary probe, a local build, or an interactive flow.
3. Choose the narrowest proof path.
   Pick the smallest layer that can prove or disprove the claim with minimal ambiguity.
4. Make the smallest change that could fix it.
   Avoid broad refactors until the failure mode is understood.
5. Re-run the primary proof path after the change.
   This is the main evidence.
6. Run adjacent regression checks.
   Test nearby states, inverse transitions, and likely collateral paths.
7. Report evidence and gaps.
   Distinguish executed checks, observed outcomes, and what remains unverified.

## Escalate Only For Ambiguity

Escalate to a stronger validation layer only when the current layer leaves a material question unanswered.

Good reasons to escalate:

- The framework behavior is uncertain or version-sensitive.
- The bug depends on cross-view, cross-process, or platform-managed presentation.
- The issue is timing-sensitive, focus-sensitive, or non-deterministic.
- A lower layer proved compilation but not the user-visible claim.

Bad reasons to escalate:

- Habit.
- Wanting a more impressive report.
- Avoiding a precise statement such as "build passed, interactive verification not run."
- Continuing after the acceptance check is already satisfied.

When in doubt, prefer reporting a verification gap over inventing a heavier validation path.

## Choosing a Validation Path

- Pure logic and calculations: prefer unit tests.
- Pure declarative or styling-only changes with framework-native semantics: prefer a build, focused render check, or other narrow proof; do not add runtime probes unless the rendered result is genuinely ambiguous.
- View state, focus, timing, control enablement, text visibility, and value overwrite behavior: prefer a focused local harness.
- Layout regressions in SwiftUI/AppKit views: host the view at the real production size and verify clipping, spacing, and scroll behavior.
- Menu bar items, popovers, transient windows, and integrated UI state: prefer Accessibility-based checks or direct state probes only when the integrated platform behavior matters to the claim.
- Whole-app wiring and packaging: use a local build and a deterministic smoke path.

If a bug is timing-sensitive, focus-sensitive, or stateful, sample more than one checkpoint:

- Immediately after the trigger.
- After the next main-loop turn.
- After the next expected timer, callback, or async boundary.

## macOS Menu Bar and Popover Checks

Use this path when the bug genuinely involves menu bar app integration, a status item, a transient window, or a popover. Do not use this path for every change made inside a menu bar app.

Default order for this class of bug:

1. Inspect the implementation and identify the state owner and the view layer that renders it.
2. Verify the state transition without UI if possible.
3. Host the affected SwiftUI/AppKit view in a focused harness at the production size.
4. Verify the rendered result or control state through direct view inspection, OCR, or Accessibility as appropriate.
5. If needed, build the app and verify integrated behavior through Accessibility-based inspection and actions.
6. If logic and UI disagree, assume a presentation or sync bug until proven otherwise.

Practical tactics for SwiftUI/AppKit UI:

- Use `NSHostingController` plus `NSWindow` when verifying SwiftUI popover content, and size the harness to the real popover dimensions.
- If production popover size changes, update the harness size in tests at the same time.
- For text presence or absence in rendered output, OCR is acceptable when view-tree assertions are weaker.
- For layout fixes, explicitly check header visibility, back-button visibility, scroll reachability, and absence of oversized bottom whitespace.
- For status bar visuals driven by deterministic mappings, unit-test the mapping helper and only add integrated render checks if ambiguity remains.
- For isolated SwiftUI/AppKit property tweaks inside these apps, stay at the view or build layer unless the claim depends on system-managed presentation.

Prefer these commands when relevant:

```bash
xcodebuild -project QieQie.xcodeproj -scheme QieQie -configuration Debug -derivedDataPath build test
```

## How To Trigger UI Actions

Use deterministic control-level or system-level actions instead of pointer simulation.

- In a focused local harness, prefer the control's own action interface.
- For buttons, use the native click or action path rather than simulating a cursor.
- For text input, use direct selection, insertion, and keyboard-oriented editing paths.
- If the issue can be proven by driving the view model or action owner directly, that is valid for logic evidence.
- In a running macOS app, prefer Accessibility actions such as press on the discovered element.
- For status items, menus, and popovers, prefer Accessibility inspection plus Accessibility actions over pointer-driven interaction.

## Avoided Test Methods

Do not default to fragile or indirect validation when a more direct path exists.

- Do not control the mouse as the primary test method.
- Do not use coordinate-based clicks, pointer movement, or image-matching automation when Accessibility, keyboard, or direct state inspection can answer the question.
- Do not use low-level pointer event synthesis when a control action, keyboard path, or Accessibility action can do the same job more deterministically.
- Do not rely on screenshots alone to prove behavior.
- Do not treat a successful build as proof that a runtime bug is fixed.
- Do not stop at a single end-state check when the bug involves transitions, focus, or timing.
- Do not claim a fix based only on code inspection or reasoning.
- Do not broaden to a full end-to-end flow when a focused probe can prove or disprove the bug faster and more reliably.
- Do not add launch hooks, temporary instrumentation, or custom probes when a lower-cost validation path already proves the claim.
- Do not silently skip verification because reproduction is awkward; narrow the claim and say exactly what was not tested.

## Layout And Visual Regression Checks

When the bug is about spacing, clipping, or “looks wrong,” verify more than text:

- Check that critical controls are visible inside the intended frame.
- Check that headers and back buttons remain reachable after height reductions.
- Check that content scrolls when it exceeds the fixed container height.
- Check that negative space is intentional; large unexplained blank regions count as a regression.
- Treat screenshots or PNG renders as supporting evidence, not the only proof.

## Temporary Probes

Temporary probes are valid when they reduce guesswork. Use them to answer a specific question such as:

- Did the state change at the expected moment?
- Did the value persist after the next refresh or callback?
- Did the control actually become disabled, enabled, or focused?
- Did the popover, menu, or status item expose the expected Accessibility attributes?

One-off render scripts are acceptable for UI smoke checks when a test would be too heavy. Keep them targeted, use the production size, and delete temporary artifacts unless the user asked to keep them.

Do not create probes just to increase confidence on an already-proven low-risk change.

Remove or isolate probes once they have served their purpose unless they are worth keeping as a real regression test.

## Evidence Standard

A good verification note answers these questions:

- What exact path was executed after the change?
- What specific outcome was observed?
- What nearby cases were checked for regressions?
- What was not tested?

Bad verification language:

- "Should work now"
- "Looks fine"
- "Probably fixed"

Good verification language:

- "Reproduced before the change with X, then re-ran the same path after the change and observed Y."
- "Validated the primary bug path and one adjacent regression path."
- "Build passed, but interactive verification was not run."

Use this close-out template when reporting:

- Claim:
- Primary validation path:
- Observed result:
- Adjacent regression checks:
- Not verified:

## If Reproduction Fails

- Say so explicitly.
- Do not invent certainty.
- Validate the highest-signal path still available.
- Narrow the claim: say the code path was improved or the suspected race was addressed, not that the bug is definitively fixed.

## Completion Bar

Do not stop at code changes alone. A task is only complete when you have:

- a concrete claim,
- a matching validation path,
- and a concise report of what evidence supports the claim.
