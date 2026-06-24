# WoWX 2.0.4 Hotfix

## Summary
Hotfix for stealth-bar combat regressions where base actions could stay latched to stealth-only spells after stealth broke.

## Fixed
- Rogue `ACTIONBUTTONn` execution no longer relies on generic `[bonusbar]` routing.
- Rogue base action macros now route with explicit `[stealth]` detection:
  - in stealth: `BonusActionButtonN`
  - out of stealth: `ActionButtonN`

## Why
Some stealth-bar clients can keep bonusbar state stale after stealth breaks in combat. When that happens, generic bonusbar macros continue to fire stealth-only actions and produce errors like "You must be in stealth to use that".

## Scope
- This hotfix targets rogue-style stealth bar routing.
- If a separate druid prowl-specific regression remains, that is a different page-model problem and should be handled separately from rogue stealth routing.
