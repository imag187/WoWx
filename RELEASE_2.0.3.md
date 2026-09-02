# WoWX 2.0.3 Hotfix

## Summary
Crash fix for controller binding apply path when legacy/setup data is incomplete.

## Fixed
- Resolved nil access in `ApplyBindings` -> `bindToButton` where `modifiers` could be nil.
- `effectiveModifiers` is now initialized in `ApplyBindings` scope.
- Added defensive fallback modifier table (`SHIFT`, `ALT`, `CTRL`) in binding construction.

## Impact
- Prevents runtime error:
  - `attempt to index local 'modifiers' (a nil value)`
- Restores normal binding application so modifier pages can be bound instead of crashing out.
