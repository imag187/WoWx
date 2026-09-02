# WoWX 2.0.2 Hotfix

## Summary
Hotfix release focused on controller modifier-page casting reliability when using single-mapper setups (for example DS4Windows-only keyboard emulation).

## Fixes
- Normalized captured setup modifier keys to engine-safe WoW modifiers (`SHIFT`, `ALT`, `CTRL`) before binding generation.
- Applied the same effective modifier set consistently across:
  - setup-generated bindings,
  - runtime controller binding application,
  - controller utility combos.
- Added diagnostics output line to show both captured and effective modifiers:
  - `Modifiers: setup=... effective=...`

## Why this matters
Some mapper profiles emit key names that look valid during calibration but are not valid WoW modifier prefixes at bind time. This can make base-page casts work while modifier pages fail. The hotfix hardens this path and keeps controller mode aligned with keyboard-style bindings.

## Validation
1. `/wowx diag verbose`
2. Confirm `EngineCfg` is active and `Modifiers` line shows sane `effective=SHIFT,ALT,CTRL` order.
3. Test one base spell and one spell from each modifier page by key press and by click.
