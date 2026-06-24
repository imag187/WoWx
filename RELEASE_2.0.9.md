# WoWX 2.0.9 Hotfix

## Summary
Controller menu-surface safety pass and docs update.

## Fixed
- Removed direct Game Menu action from WoWX Menu Navigator to avoid protected Lua errors from controller flows.
- Removed Game Menu utility macro from Gridbook/Spellbook utility action list.
- Center-button launcher no longer falls back to direct `ToggleGameMenu()`; it now stays on WoWX-owned menu navigation only.

## Docs
- README now recommends a small attachable Bluetooth keyboard for practical fully couch-driven play fallback interactions.

## Notes
- This release does not yet include the controller-tab layout shrink fix or slider nudge controls; those remain queued for the next UI pass.
