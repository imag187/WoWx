# XPerl CoA Detector Contract

Goal: keep fork compatibility thin while WoWX owns feature development.

Use this contract in the `xperl_coa` fork:
- Shared flavors: `coa`, `bronzebeard`, `classless`, `ascension`, `other`.
- Prefer detector parity with WoWX `Systems/Core/RealmDetector.lua`.
- Avoid class-based realm overrides; realm flavor should come from realm-name detection.

Suggested port function shape (in xperl_coa):
- `DetectFlavor(realmName)` -> flavor string
- `GetActiveFlavor()` -> flavor string
- `IsCoAFlavor(flavor)` -> boolean

Behavior note:
- CoA-specific behavior should trigger only for `flavor == "coa"`.
- Shared Ascension behavior can use `coa|bronzebeard|classless|ascension`.
