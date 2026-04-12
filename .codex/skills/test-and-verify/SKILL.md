---
name: test-and-verify
description: Use when fixing bugs, validating behavior changes, or reviewing whether a code change actually works, including macOS menu bar apps, popovers, and Accessibility-based UI verification. This skill enforces a verification-first workflow: reproduce the issue, define the acceptance check, make the change, run the most direct available test path, and report exactly what was and was not verified.
---

# Test And Verify

Use this skill when correctness matters more than code churn. The default stance is: do not trust a fix until it has been exercised through a direct validation path.

## Core Rules

- Reproduce first when the user reports a runtime or interaction bug.
- Prefer the narrowest test that proves the claim.
- If a change affects UI or event timing, verify the transition points, not just the final steady state.
- Separate logic evidence from UI evidence. If they disagree, keep debugging.
- For menu bar, status bar, or popover UI bugs, prefer state probes and Accessibility inspection over pointer choreography.
- Never say a bug is fixed unless at least one realistic validation path was executed after the change.
- State plainly what was tested, what passed, and what remains unverified.

## Default Workflow

1. Clarify the target behavior.
   Write down the observed behavior, the expected behavior, and the exact acceptance check.
2. Reproduce the issue.
   Use the most direct available route: existing tests, a focused harness, a temporary probe, a local build, or an interactive flow.
3. Capture a baseline.
   Confirm the bug exists before editing, or state explicitly that reproduction was not possible.
4. Make the smallest change that could fix it.
   Avoid broad refactors until the failure mode is understood.
5. Re-run the direct reproduction path.
   This is the primary proof that the fix works.
6. Run adjacent regression checks.
   Test nearby states, inverse transitions, and entry/exit paths that are likely to break from the same change.
7. Report evidence.
   Distinguish clearly between executed checks and assumptions.

## Choosing a Validation Path

Prefer this order, adjusted to the task:

- Existing automated tests that directly cover the failing behavior.
- A focused test or local harness created for the bug.
- A temporary probe that inspects the exact state transition or output.
- A build plus a deterministic smoke path.
- Manual verification only when the above are unavailable or insufficient.

If a bug is timing-sensitive, focus-sensitive, or stateful, sample more than one moment:

- Immediately after the triggering action.
- Shortly after the event loop turns.
- After the next expected async or timer boundary.

When several options are available, choose the smallest layer that can prove the claim:

- Pure logic and calculations: prefer unit tests.
- View state, focus, timing, control enablement, and value overwrite behavior: prefer a focused local harness.
- Menu bar items, popovers, transient windows, and integrated UI state: prefer Accessibility-based checks.
- Whole-app wiring and packaging: use a local build and a deterministic smoke path.

## Preferred Test Methods

Choose the most direct method that proves the claim with the least ambiguity.

- Existing automated tests when they directly cover the reported behavior.
- Unit tests for pure logic, state transitions, validation rules, and math.
- A focused local harness when the full app is heavier than the bug requires.
- A temporary probe when the key question is a state transition, timing edge, or overwrite path.
- Build plus a deterministic smoke path when the behavior depends on the integrated app.
- Accessibility inspection and Accessibility actions for UI state, focus, enabled state, popovers, menus, and status items.
- Keyboard-driven or system-driven interaction when it is more deterministic than pointer interaction.

For timing or async bugs, test at more than one checkpoint:

- immediately after the trigger,
- after the next main-loop turn,
- after the next expected timer, callback, or async boundary.

## Recommended Layering

When shaping a long-lived verification strategy, prefer this layering:

1. Unit tests for deterministic logic.
2. Focused harnesses for UI timing, focus, enablement, and binding behavior.
3. Accessibility-driven checks for integrated macOS UI surfaces such as status items, menus, and popovers.
4. Local build-based smoke verification for the actual app product.
5. Manual verification only as a supplement.

## macOS Menu Bar and Popover Checks

Use this path when the bug involves a menu bar app, status item, transient window, or popover.

- Never simulate mouse movement or pointer clicks as the primary validation method.
- Do not use coordinate-based event injection when Accessibility actions or direct state probes can answer the question.
- Prefer inspecting actual Accessibility attributes such as role, title, value, enabled, focused, selected, and available actions.
- If a popover or menu must open, prefer an Accessibility press action or another deterministic system-level action over cursor automation.
- Treat screenshots as supporting evidence only after state and Accessibility checks.

Default order for this class of bug:

1. Inspect the implementation and identify the state owner and the view layer that renders it.
2. Verify the state transition without UI if possible.
3. Build the app or host the affected view in a focused local harness.
4. Verify the rendered result or control state through Accessibility or direct view inspection.
5. If logic and UI disagree, assume a presentation or sync bug until proven otherwise.

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
- Do not silently skip verification because reproduction is awkward; narrow the claim and say exactly what was not tested.

## For UI and Interaction Bugs

- Verify both the underlying state and the rendered or interactive result.
- Check whether a control is only visually changed or actually disabled, focused, selected, or updated.
- When a bug involves input, inspect whether values are being overwritten by later sync logic.
- When a bug involves transitions, test both directions, not just the one the user described.

## For Non-UI Bugs

- Prefer deterministic assertions over log reading.
- If using a probe, print only the state needed to prove the transition.
- If the failure depends on external state, reduce it to the smallest reproducible setup.

## Temporary Probes

Temporary probes are valid when they reduce guesswork. Use them to answer a specific question such as:

- Did the state change at the expected moment?
- Did the value persist after the next refresh or callback?
- Did the control actually become disabled, enabled, or focused?
- Did the popover, menu, or status item expose the expected Accessibility attributes?

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
