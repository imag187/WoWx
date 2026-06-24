# WoWX 2.0.1 Draft Release Notes

## Summary
This release packages the stability and paging work from the PTR branch into a pull-ready update.

## Highlights
- Added class-aware CoA detection and non-CoA druid routing safeguards.
- Improved druid cat/prowl bar behavior on non-CoA paths.
- Added native-first spec-swap mode to reduce swap freezes and avoid destructive full-bar rewrites.
- Expanded diagnostics output for stance/page/transport/spec-swap state.
- Added slash command controls for spec swap behavior and settle delay tuning.
- Stabilized click transport proxy ownership for base/modifier command execution.
- Expanded WoWX bank ownership flow while preserving bank slot purchase and core bank access.
- Improved setup defaults for controller-focused layouts (9 visible main buttons) while preserving keyboard defaults.

## Controller Runtime Notes
- If only main-page casts fire, verify transport and binding diagnostics first:
  - `/wowx diag verbose`
  - Confirm `EngineCfg: transport=click`
  - Confirm keybind lines route through `WoWXBindButton_*`
- For dual-spec timing issues, use:
  - `/wowx specswap status`
  - `/wowx specswap native`
  - `/wowx specswap delay <ms>`

## Known Caveats
- External input stacks (for example DS4Windows + virtual input + keyboard mappers) can create asymmetric key delivery where base keys fire but modifier combos do not. Prefer one canonical mapper path where possible.
- Realm/client paging differences may still require per-class validation, especially for stance/aura-driven states.

## Suggested Validation Pass
1. Full client restart.
2. Run `/wowx diag verbose` once out of combat.
3. Verify base and modifier casts by key and by click.
4. Test spec swap with native mode.
5. Test bank open/close, deposit/withdraw, and slot purchase.

## Proposed Tag
- `v2.0.1`
