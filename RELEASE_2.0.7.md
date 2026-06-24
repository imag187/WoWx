# WoWX 2.0.7 Hotfix

## Summary
Controller mouse-look recapture stability fix.

## Fixed
- WoWX now syncs its internal mouse-look state with the actual game mouse-look state.
- If cursor/mouse-look state is interrupted externally, movement can re-capture mouse-look without forcing a manual mode toggle cycle.
- Applies to both movement-based and platformer/always-on controller mouse-look modes.

## Why
Previously, WoWX could keep a stale internal `controllerMouseLookActive` flag when game state changed out-of-band, which blocked automatic recapture until users toggled modes.

## Notes
- This is a behavior/stability hotfix and does not yet introduce role-specific controller modes (DPS/Tank/Healer).
