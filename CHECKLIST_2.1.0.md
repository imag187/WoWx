# WoWX 2.1.0 Keyboard Validation Checklist (Moonlight)

Date: 2026-06-24
Focus: keyboard play stability after settings/tab/layout-editor/glow polish.

## Planned Run Order
- Tonight (cloud/Moonlight): keyboard-focused pass.
- Morning (living room/travel steam-machine equivalent): PS5 controller pass.
- Release decision after both passes.

## Test Setup
- Full client restart.
- Login on target character.
- Ensure expected mode with existing command:
  - Keyboard machine: /wowx toggle keyboard
  - Controller machine: /wowx toggle controller
- Run: /wowx reload
- Run: /wowx diag verbose
- Verify diag includes: EngineCfg: transport=click

## A. Control Center Tab Layout
1. Open: /wowx config
2. Switch tabs in this order: General -> Keybinds -> Profiles -> Keybinds -> General
3. Pass if:
- No panels render off-screen.
- No giant blank vertical space appears when switching tabs.
- Keybinds tab shows Controller Integration + Input Mapping + Current Bindings in expected order.
- Profiles tab starts near the top of the panel and does not inherit Keybinds spacing.

## B. Layout Editor Nudge Controls
1. Enable layout edit and click Edit on main bar.
2. For at least 3 sliders (Scale, Button Width, Spacing):
- Click < twice, then > once.
3. Pass if:
- Value text updates per click.
- Bar updates immediately per click.
- No jitter or slider snap-back.
- Controls hide correctly when opening bar kinds with fewer sliders.

## C. Glow Alignment / Visual Fit
1. Place at least one always-equipped or active action on main bar.
2. Trigger states:
- normal idle
- queued/current action highlight (if available)
- out-of-range target (if applicable)
3. Pass if:
- Glow halo is centered on slot border (not offset upward/downward).
- Glow does not look like a second oversized slot frame.
- Slot border and glow read as one visual layer.

## D. Keyboard Casting Integrity (Regression Guard)
1. Verify base keys 1..= cast expected actions.
2. Verify modifiers: SHIFT-1, ALT-1, CTRL-1, SHIFT-ALT-1.
3. Enter/exit combat and repeat at least one key from each set.
4. If your class has stealth/stance-like transition, test both states.
5. Pass if:
- No main-bar-only collapse.
- No stale modifier routing after combat transitions.
- Clicks and keyboard remain consistent.

## E. Utility/Settings Sanity
1. In Control Center, ensure no direct Game Menu action appears in action lists.
2. Toggle controller enable/disable once (even for keyboard session) and verify no UI break.
3. Pass if:
- No protected-action popup from settings/menu controls.

## Capture For Handoff
- Run: /wowx diag verbose after testing.
- Note any FAIL item with exact step and expected vs actual.
- Optional short format:
  - A: pass/fail
  - B: pass/fail
  - C: pass/fail
  - D: pass/fail
  - E: pass/fail
  - Notes: ...

## Copy/Paste Result Block
Use this exact block when reporting results:

Tonight - Keyboard (Moonlight)
- A Tab Layout: pass/fail
- B Slider Nudges: pass/fail
- C Glow Alignment: pass/fail
- D Keyboard Casting: pass/fail
- E Utility/Settings: pass/fail
- Notes:

Morning - Controller (PS5)
- A Tab Layout: pass/fail
- B Slider Nudges: pass/fail
- C Glow Alignment: pass/fail
- D Base + Modifier Casting: pass/fail
- E Mouselook/Controller UX: pass/fail
- Notes:

Release Gate
- Ship v2.1.0: yes/no

## Release Gate
Ship 2.1.0 if A-E all pass on Moonlight keyboard session.
If any fail, patch and retest only failed sections before release.

For final publish, require both keyboard and controller blocks above to be green.
