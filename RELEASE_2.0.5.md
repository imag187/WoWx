# WoWX 2.0.5 Hotfix

## Summary
Follow-up CoA stealth-bar fix for rogue main-bar display and slot resolution.

## Fixed
- On CoA rogues, main-page visual/slot resolution no longer trusts stale `bonusOffset` by itself.
- CoA rogue main-page resolution now uses real stealth state:
  - stealthed -> stealth page
  - not stealthed -> base page
- This complements 2.0.4, which already changed rogue base-button execution to use `[stealth]` instead of generic `[bonusbar]`.

## Why
On CoA realms, hidden special-action state can stay effectively latched even after usable stealth has broken. That causes the bar to keep resolving to stealth-only actions unless routing is keyed to real stealth state instead of stale bonus-page state.
