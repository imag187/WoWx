# WoWX 2.0.6 Hotfix

## Summary
CoA custom-class token fix for stealth-page routing.

## Fixed
- WoWX now resolves CoA custom class tokens using the same fallback table pattern found in `XPerl_CoA`.
- Reaper is now identified as `REAPER` instead of being treated through raw Blizzard class assumptions.
- CoA stealth-page logic now keys off the resolved custom class token for Reaper rather than a raw `ROGUE` check.
- Diagnostics now print `ResolvedClassToken` to make future CoA class debugging explicit.

## Why
On CoA, gameplay classes do not map 1:1 to Blizzard classes. `XPerl_CoA` maps `REAPER` to Blizzard `WARLOCK`, so any WoWX logic gated on raw `ROGUE` would miss Reaper entirely.
