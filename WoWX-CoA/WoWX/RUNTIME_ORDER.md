# WoWX Runtime Order (Authoritative)

This file describes the required order of operations for WoWX so behavior is deterministic and debuggable.

## 1) Load And Init

1. `GamePadX.lua` loads first (see TOC order).
2. Main frame listens for:
   - `ADDON_LOADED`
   - `PLAYER_LOGIN`
   - `PLAYER_REGEN_ENABLED`
3. `ensureInitialized()` must run before any binding work:
   - `InitDB()`
   - `RegisterSlash()`

Rule: no binding apply/clear should execute before DB init.

## 2) Login Runtime Sequence

On `PLAYER_LOGIN`:

1. Ensure init (idempotent).
2. If `db.enabled` then `ApplyBindings()` else leave bindings untouched.
3. Refresh visual modules:
   - `VisualBar:UpdateAll()`
   - `SettingsUI:Refresh()` (if present)
   - `MinimapButton:Refresh()` (if present)

Rule: module refresh happens after enable/disable decision.

## 3) Binding Apply Sequence

`ApplyBindings()` sequence:

1. Read engine config (`/wowx engine` options).
2. Clear prior session mappings if any (`ClearBindings()`).
3. If setup keys are required, validate calibration.
4. Abort during combat lockdown.
5. Ensure bar frame exists (`VisualBar:CreateFrame()` when available).
6. Rebuild bindings in deterministic order:
   - Base slot key
   - Modifier 1
   - Modifier 2
   - Modifier 3
   - Combo modifier (if enabled)
7. Optionally bind menu key (controller mode only).
8. Apply SpellRing bindings.
9. Print apply summary.

Rule: never stack new bindings over old ones in the same session.

## 4) Standard vs Controller Mode

Standard mode:

- Uses fixed number-row mapping path when engine says `useSetupKeys=false`.
- No setup calibration required in that path.
- Can still drive modifier pages if enabled.

Controller mode:

- Uses captured setup keys/modifiers.
- Menu key binding is only applied in controller mode.

Rule: controller-only requirements must not block standard mode.

## 5) Visual Page State

Visual bar state is derived from live modifier state:

- `""`, `SHIFT`, `ALT`, `CTRL`, `SHIFT-ALT`

Command resolution:

- Base page: `ACTIONBUTTONn`
- Modifier pages (when enabled): `MULTIACTIONBAR*BUTTONn`
- Same-slot mode (when disabled): modifier display may change, action command stays base slot.

Rule: action command and display state must agree for the current mode.

## 6) Blizzard Bar Replacement

Replacement logic runs through `VisualBar:UpdateBlizzardBars()`.

- Replacement should occur only when WoWX mode requires it.
- Keep flags (`keepMicroMenu`, `keepBags`, stance/pet options) are honored.
- Parent restoration uses saved original parent references.

Rule: disabling WoWX must restore original parent/visibility state.

## 7) Combat Safety

- Do not attempt forbidden secure changes in combat.
- Deferred operations use `PLAYER_REGEN_ENABLED` when needed.

Rule: when in doubt, queue and apply post-combat.

## 8) Sharing Checklist

Before publishing:

1. `/wowx disable` then `/wowx enable` once.
2. `/wowx diag` and confirm:
   - expected engine config
   - expected key ownership
   - expected modifier page mode
3. Verify in combat:
   - base key cast
   - each modifier cast/page behavior
4. Verify disable restores normal non-WoWX behavior.

This file is intended to keep future changes procedural and predictable.
