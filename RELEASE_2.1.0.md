# WoWX 2.1.0 Release Draft

## Summary
Settings and bar editor polish release focused on keyboard/controller usability and visual clarity.

## Included
- Startup performance simplification:
  - Removed eager 72-slot spec snapshot capture from PLAYER_LOGIN.
  - Removed duplicate login-time UI refresh/auto-diagnostic passes; startup now leans on entering-world + single binding apply path.
- Automatic mode-consistency normalization (local safety for multi-machine workflows):
  - On login, WoWX normalizes controller/setupkey state to prevent keyboard sessions from inheriting controller setup-key paths.
  - Existing `/wowx toggle keyboard` and `/wowx toggle controller` flows remain the mode switch surface.
- Binding count reporting fix:
  - Startup/status configured-count now reflects active mode logic instead of stale profile table size.
  - Reduces false "48 bindings" confusion on keyboard sessions.
- Control Center tab layout fix:
  - Keybinds tab now uses tab-specific panel anchoring (bindings under input mapping, not under hidden General action stack).
  - Profiles tab now anchors from top content region.
  - Tab-specific frame heights reduce blank-space shell behavior.
- Layout editor precision controls:
  - Added step nudge buttons (< and >) for each slider row.
  - Nudge updates apply immediately and respect each slider step value.
- Action glow alignment cleanup:
  - Glow anchor moved to slot panel center.
  - Reduced glow sizing/padding to remove oversized double-slot halo look.

## Files Changed
- SettingsUI.lua
- VisualBar.lua
- WoWX.toc (version set to 2.1.0)

## Validation Gate (Before Final Publish)
Run CHECKLIST_2.1.0.md and confirm pass for sections A-E.
- If all pass: publish as v2.1.0.
- If any fail: patch failing section(s), retest, then publish.

## Notes
- Transport/binding ownership remains on click/proxy model; this release is a UI polish pass, not a transport architecture change.
