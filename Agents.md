# WoWX Debug Handoff

## Purpose

This file is a continuity handoff for future work on WoWX, especially for the Runemaster / Runeshroud paging issue on Ascension PTR.

Primary goal: avoid retracing dead ends and preserve the actual discoveries from the debugging session.

## 2026-05-17 Bag Module and Per-Character Profiles

### Issues Resolved

1. **Bag module taint on UseContainerItem()**
   - Problem: Right-clicking items in WoWX bags caused taint error
   - Solution: Use Blizzard's `ContainerFrameItemButtonTemplate` (same as Bagnon)
   - This XML template has built-in secure handling for item operations
   - Result: No taint on right-click, drag, or split operations

2. **Merchant/vendor not opening WoWX bags**
   - Problem: Talking to NPCs opened Blizzard bags instead of WoWX combined bag window
   - Solution: Added `MERCHANT_SHOW` event handler to auto-open WoWX bags
   - Also added `MERCHANT_CLOSED` event to auto-close bags when merchant closes (matching Blizzard UX)
   - Implemented hooks on `ToggleBackpack()`, `OpenAllBags()`, and `CloseAllBags()` to redirect to WoWX bags when enabled
   - Result: WoWX bags now open automatically when talking to merchants/vendors

3. **Per-character button count bleeding across characters**
   - Problem: Enabling controller mode on one character (8-button layout) affected other characters even when controller mode was disabled for them
   - Root cause: `layout.buttonCount` persisted in SavedVariables and was used regardless of controller mode state
   - Solution: Modified `Bar:GetVisibleButtonCount()` to always return 12 buttons when controller mode is disabled, only respecting `layout.buttonCount` when controller is enabled
   - Result: Keyboard-mode characters now always show 12 buttons, controller-mode characters respect configured button count

### Key Code Changes

**ActionButtons.lua:**
- Item buttons use Blizzard's `ContainerFrameItemButtonTemplate` (same approach as Bagnon)
- Template provides built-in secure item handling without taint
- Buttons use dummy parent frames with bag ID, button itself has slot ID
- Removed per-bag spacer rows - bags flow continuously in 8-column grid
- Added `InstallBlizzardBagHooks()` to redirect bag opening functions
- Added `MERCHANT_SHOW` and `MERCHANT_CLOSED` event handlers
- Auto-open/close behavior when talking to vendors

**VisualBar.lua:**
- `GetVisibleButtonCount()` now returns 12 for keyboard mode unconditionally
- Controller mode still respects configured button count

### Current State

- Click transport remains the stable execution path
- Bag module now properly replaces Blizzard bags without taint
- Per-character profiles work correctly for controller vs keyboard mode
- SavedVariables are properly scoped per-character via `SavedVariablesPerCharacter`

### Important Notes for Future Work

- ContainerFrameItemButtonTemplate is the key to taint-free bag operations
- Template expects parent frame ID = bag, button ID = slot
- Dummy parent frames are created per button to satisfy this requirement
- The `_openedByMerchant` flag tracks whether bags were auto-opened to enable smart auto-close behavior
- Bag grid flows continuously without per-bag spacer rows (8-column layout)
- Hooks on ToggleBackpack/OpenAllBags/CloseAllBags redirect to WoWX bags when enabled
- Consider extracting bag module to separate addon (WoWX_Bags) for independent enable/disable

### Lesson Learned: Use Blizzard XML Templates

When implementing features that interact with protected/secure functions, always check how established addons like Bagnon solve the problem. They often use Blizzard-provided XML templates that have the necessary secure handling baked in. Don't reinvent the wheel when Blizzard already provides the solution.

## Read This First

- Always read this file before making substantive WoWX changes.
- Update this file whenever a debugging avenue, client quirk, runtime dependency, or workflow constraint becomes important enough that losing it would waste the next session.
- Treat repo code, live addon folder contents, machine-specific client settings, and per-character SavedVariables as separate layers. Do not assume a repo diff alone explains behavior.
- When a behavior works on one machine and regresses after pulling changes on another, first compare:
  - the actual addon folder being loaded
  - the current repo diff / commit state
  - the relevant character SavedVariables
  - the relevant client settings / dropdowns / conflicting addons
- If a feature worked in-game before more experimentation, preserve that state immediately with a commit, diff, or explicit note here before continuing.

## Current Development Reality

- The user's real workflow is split across at least two machines:
  - office machine: keyboard / mouse development and validation
  - couch machine: controller validation in real play
- Typical failure mode:
  - work is stable upstairs
  - repo changes are pulled to couch machine
  - couch-specific fixes are made late at night until play works again
  - those changes are pulled back upstairs the next day
  - regressions appear on the original machine
- Therefore future agents must not dismiss regressions on the original machine as mere "machine drift". If the inception machine regressed after addon edits, that regression is real until disproven.
- Diagnostics and handoff notes are not optional overhead in this workflow; they are part of the actual engineering surface.

You may be reading this and thinking that click transport can't possibly be efficient, and are looking to use direct. The trouble with that on this fork is that we are bar-centric and not individual-button-centric like ConsolePort, so there are protected functions that will not only lag spike the game but also can throw fatal errors and disconnect the client entirely. DO NOT ATTEMPT TO USE IT. We have tried. Other agents have tried. Only consider direct if it is the very last or very first step in a proven chain, and only if click transport is still the system used to resolve which actual action is casting at any given time. That is hypothetical unless proven viable.

## Repo / Runtime Paths

- Live addon code worked on in this session:
  - `g:\Ascension Launcher\resources\epoch_live\Interface\AddOns\WoWX`
- PTR addon path actually used by the user during testing:
  - `g:\Ascension Launcher\resources\ascension_ptr\Interface\AddOns\WoWX`
- PTR character SavedVariables used for diagnostics:
  - `g:\Ascension Launcher\resources\ascension_ptr\WTF\Account\IMAG187\Vol'jin - CoA Beta\Glyphhoof\SavedVariables\WoWX.lua`

Important operational note:
- Code changes made under `epoch_live` do not affect PTR until copied into the PTR addon folder.
- This handoff should now treat the PTR addon folder as the primary CoA fork and source of truth for future work.
- Some behavior was ultimately controlled by the PTR SavedVariables, not just repo code.

## Current Fork Status

- `g:\Ascension Launcher\resources\ascension_ptr\Interface\AddOns\WoWX` is now the effective official CoA-focused fork.
- Future debugging notes should assume this directory is the working branch unless explicitly stated otherwise.
- Diagnostics gathered from this fork may not match older `epoch_live` behavior.

## Branch Propagation Policy

- Some changes are branch-local fixes, but architecture decisions are not automatically CoA-only just because they were first explored here.
- The emerging module / ownership split for WoWX should be treated as a base design decision that will likely need to be reflected in both:
  - `main`
  - the CoA branch / fork
- CoA-specific behavior such as multicast-bar support should remain preserved on the CoA branch unless and until there is a deliberate reason to upstream it.
- Future agents should explicitly classify changes before implementation:
  - base design / architecture change -> likely propagate to both branches
  - Ascension / CoA specific feature or compatibility layer -> keep CoA-specific unless proven generally useful
- Do not let branch-local experimentation accidentally redefine the long-term architecture without noting whether the change is intended for `main`, CoA, or both.

## User Goal

The user wanted WoWX to be reliable enough for real use and for possible repo/inclusion/demo purposes.

Specific requirements that shaped the work:
- Generic solution, not class-specific hacks if possible.
- No reload-required demo behavior.
- Avoid client/server instability.
- Preserve WoWX custom bar behavior rather than forcing a 1:1 native Blizzard bar dependency.

## Core Problem Summary

Observed bug family:
- On Ascension PTR, Runemaster / Runeshroud / stance-like transitions could leave WoWX and Blizzard action state out of sync.
- Keyboard and mouse could disagree.
- At times keyboard followed a stale stealth/bonus page.
- At times mouse clicked through to the visible main bar instead of the intended WoWX action.
- Some later experiments caused severe lag and apparent client instability/crashes, so those paths were backed out.

Critical discovery:
- A large portion of the confusion came from the binding engine still running in `transport=direct` on the PTR character, even after repo defaults were changed to `click`.
- The PTR SavedVariables were explicitly pinned to `transport = "direct"`.
- Forcing the PTR character SavedVariables to `transport = "click"` is what finally made the user report success.

## What The Diagnostics Proved

Repeated diagnostics from `WoWX.lua` SavedVariables showed these recurring facts:

- `hasOverride=1` was often reported.
- Real override frames were missing:
  - `OverrideActionBar=missing`
  - `OverrideActionBarFrame=missing`
  - `OverrideActionBarArtFrame=missing`
  - `OverrideActionBarLeaveFrame=missing`
- `BonusActionBarFrame` was often shown.
- `ShapeshiftBarFrame` was shown.
- Blizzard defaults such as shifted mouse wheel, shifted up/down arrows, and shifted 1/2 can continue to page or scroll the underlying UI unless they are explicitly cleared in both keyboard and controller mode.
- On Runemaster / Runeshroud states, WoWX could resolve base buttons to bonus-page slots like:
  - `73`, `74`, `75`, `76`, `80`, `83`, `84`
- Meanwhile Blizzard live `ActionButton1..12.action` could still remain `1..12`.

Interpretation:
- The client can report a hidden or stale special-action state that does not line up with visible override frames.
- WoWX cannot safely assume `HasOverrideActionBar()` means a normal visible override UI exists.
- Keyboard/mouse issues were often caused by mismatches between:
  - displayed WoWX slot
  - actual secure button attribute
  - real binding command
  - Blizzard visible button action

## Most Important Discovery

The latest decisive finding was not primarily a code bug in the current repo, but a persisted state/config bug:

- The latest PTR SavedVariables still showed:
  - `EngineCfg: transport=direct`
  - `ui.bindingEngine.transport = "direct"`
- This kept keyboard on native `ACTIONBUTTON...` behavior.
- That meant keyboard could only ever follow the native underlying Blizzard bar instead of WoWX-owned click transport.

Direct consequence:
- If the underlying native bar happened to line up 1:1, keyboard looked fine.
- If it did not line up, keyboard was wrong even when mouse looked correct.

## Actual Fix That Finally Worked

The user reported success only after the PTR SavedVariables were edited directly:

- In:
  - `g:\Ascension Launcher\resources\ascension_ptr\WTF\Account\IMAG187\Vol'jin - CoA Beta\Glyphhoof\SavedVariables\WoWX.lua`
- The following values were forced:
  - `ui.bindingEngine.transport = "click"`
  - `_bindingEngineDefaultsV2 = true`

After that, the user said: `that did it`.

This strongly suggests:
- The repo code path for click transport was viable.
- The broken behavior persisted because the character still loaded legacy direct transport from SavedVariables.

## Timeline Of Major Attempts

### 1. External reference research

Looked for Ascension-specific references and comparable addons.

Most relevant external reference found:
- Ascension-Addons / Bartender4

Less useful for live behavior:
- ActionBarSaver

Conclusion:
- Bartender4 was the best comparison point because it owns state, bars, and binding routing.

### 2. Broad Bartender-like experiments

Tried making WoWX more Bartender-like.

These broader experiments did not hold up safely on PTR:
- preferring direct secure action attributes more aggressively
- broader click transport shifts

Result:
- regressions
- clicks breaking after stealth-like transitions
- later backed out

### 3. Event coverage improvements

Added more update coverage around action/stance state transitions.

Relevant events involved during the session:
- `ACTIONBAR_PAGE_CHANGED`
- `UPDATE_BONUS_ACTIONBAR`
- `UPDATE_SHAPESHIFT_FORM`
- `UPDATE_SHAPESHIFT_FORMS`
- `UPDATE_STEALTH`
- `PLAYER_AURAS_CHANGED`
- `UPDATE_VEHICLE_ACTIONBAR`
- `UPDATE_OVERRIDE_ACTIONBAR`
- `UPDATE_POSSESS_BAR`
- `PLAYER_CONTROL_GAINED`
- `PLAYER_CONTROL_LOST`

These helped diagnostics and refresh behavior, but were not sufficient by themselves.

### 4. Automatic diagnostics

Diagnostics were enhanced because the bug was too easy to lose between sessions.

Useful commands and behavior:
- `/wowx diag verbose`
- `WoWXDB.diagRuns`
- `WoWXDB.lastDiagRun`

Problem encountered:
- Sometimes no new diag was saved after a test, which left the session blind.

### 5. Stale override experiments

Several experiments tried to special-case hidden override state:
- detect hidden override state via missing override UI frames
- use `SetBindingClick` fallbacks in direct mode
- switch VisualBar to `clickbutton` transport in stale override state
- reapply bindings when stale override state changed

Outcome:
- sometimes aligned keyboard and mouse behavior better
- but also introduced instability, wrong routing, lag, or worse behavior
- eventually backed out as too risky

Do not reintroduce those blindly.

### 6. Mouse-specific fix that survived

One narrower fix was kept in `VisualBar.lua`:

- For base `ACTIONBUTTONn` buttons, if the resolved slot differs from the plain index, WoWX uses a direct secure `action1 = resolvedSlot` instead of `/click ActionButtonN`.

Why this mattered:
- It stopped mouse from clicking through to the visible main bar when WoWX was visually showing a resolved bonus-page slot like `74`.

This was a good local fix and was retained.

### 7. Dangerous event-driven rebind loop

A probe was added that reapplied direct bindings on many page/stealth/aura events.

This appeared to correlate with heavy lag and possible client instability during Runeshroud.

Outcome:
- removed
- do not restore without very strong reason

### 8. Final transport discovery

Even after repo defaults were changed to click transport and migration code was added, the PTR character still loaded `transport=direct`.

Only direct SavedVariables editing fixed the actual test session.

## Current Code State To Keep In Mind

### GamePadX.lua

Current intent:
- default binding engine transport is `click`
- migration exists to move old installs to click transport
- `GetBindingEngineConfig()` also tries to force the migration if `_bindingEngineDefaultsV2` is missing
- `ShouldSuspendForSpecialActionState(reason)` does not suspend click transport for a hidden fake override state

Current risk:
- despite the code, existing SavedVariables may still pin `transport=direct`
- therefore always verify runtime state with diagnostics, not code assumptions alone

### VisualBar.lua

Current important behavior:
- `GetBonusBarOffset()` remains the authoritative page signal for Runeshroud-like swaps; `hasOverride=1` is still noisy and should not drive the page by itself.
- Base `ACTIONBUTTONn` buttons now execute through conditional macro routing instead of combat-time direct action rewrites.
- Current base-button macro shape is:
  - `/click [bonusbar:5] BonusActionButtonN; [bonusbar:4] BonusActionButtonN; [bonusbar:3] BonusActionButtonN; [bonusbar:2] BonusActionButtonN; [bonusbar:1] BonusActionButtonN; ActionButtonN`
- Modifier-page proxy buttons still route through their respective Blizzard multibars.

Why this matters:
- keeps execution aligned with active bonusbar state without relying on secure attribute flips during combat
- avoids the combat-latched behavior where keys/buttons could stay stuck to the state present at combat entry

## Known Bad Paths / Dead Ends

Avoid retracing these unless there is a new reason:

- Broad stale-override routing experiments
- forcing repeated `ApplyBindings()` on many runtime events
- assuming repo default changes are enough without checking character SavedVariables
- assuming `HasOverrideActionBar()` means visible usable override UI
- assuming a successful mouse fix means keyboard is on WoWX-owned transport too

## Non-Negotiable Agent Rules (CoA Fork)

These are hard constraints for future agent work on this fork:

- DO NOT switch or migrate runtime execution back to direct transport for action execution paths.
- DO NOT replace WoWX click/proxy-owned execution with raw `SetBinding(..., "MULTIACTIONBAR...")` for modifier pages.
- DO NOT treat a visual-only improvement as proof that execution routing is correct.
- DO NOT ship changes that make bars/pages look correct while non-main-bar casts fail.

Why this is mandatory:

- This exact regression already happened: visuals/controller/movement looked better, but spells/slots/pages/modifiers stopped executing beyond main bar.
- Keyboard and mouse/controller execution must stay on WoWX-owned click/proxy routes for this fork.
- If click/proxy paths are changed, require explicit proof (diag + live class tests) that both keyboard and click casting work on modifier pages in and out of combat.

Required verification before accepting any transport/binding refactor:

- Confirm `EngineCfg: transport=click` in diagnostics.
- Confirm modifier-page keys (SHIFT/ALT/CTRL/combo) execute correct non-main-bar actions by both key and click.
- Confirm no stale combat latching where bar state at combat entry locks later clicks/casts.

## Current Known-Good Practical State

At the end of the session, the user reported success only after the PTR SavedVariables were directly changed to click transport.

That means the effective working combination was:
- repo code including the current `VisualBar.lua` mouse fix
- repo code including the click-transport default/migration logic in `GamePadX.lua`
- PTR SavedVariables explicitly set to:
  - `ui.bindingEngine.transport = "click"`
  - `_bindingEngineDefaultsV2 = true`

## Latest Working Outcome

Current practical result from later testing:

- Runemaster / Runeshroud is the current known-good target and should be treated as the working reference solution.
- Mouse / click behavior is now considered good enough across pages.
- Base keyboard keys and modifier-page keyboard keys ended up needing different routing behavior.
- Ascension's UI dev console and event trace produced useful engine-side evidence and should be reused for future class investigations.

Current keyboard routing shape that produced the latest win:

- Base keys like `1..=` bind back to the visible `WoWXActionButtonN` buttons.
- Modifier-page keys like `SHIFT-1`, `ALT-1`, `CTRL-1`, `SHIFT-ALT-1` bind to hidden command-specific secure proxy buttons.
- This split was introduced because the visible buttons were following the live base-bar path correctly for clicks, while modifier-page keys needed direct per-command ownership to avoid collapsing back onto the base bar.

Current important VisualBar behavior from the later fixes:

- The earlier direct resolved-slot fallback experiments for base `ACTIONBUTTONn` buttons were too sensitive to combat-state latching and were replaced.
- Current behavior prefers stable macro proxy routing for base keys/buttons, with conditional `bonusbar` selection for `ActionButtonN` vs `BonusActionButtonN`.
- If future regressions reappear, do not immediately restore direct `action1 = resolvedSlot` behavior without fresh proof that combat transitions remain stable.

Current engine-level findings from `/devconsole` and Event Trace:

- For Runemaster, `GetBonusBarOffset()` was the only reliable signal of the Runeshroud page switch.
- `HasOverrideActionBar()` often remained effectively true (`override=1`) even when no visible override frames existed, so it should be treated as a noisy custom special-state flag rather than proof of a real override bar.
- `GetShapeshiftForm()` did not cleanly identify the Runeshroud transition and should not be treated as the primary driver for this class.
- Entering Runeshroud produced state changes that looked like:
  - `UPDATE_BONUS_ACTIONBAR` with `bonusOffset=1`
  - while `override=1` persisted
- The visual/action bug could still appear after the visible bar recovered, which supports the conclusion that Ascension can keep stale hidden special-action state beyond the visible transition.
- The latest successful execution fix did not come from trusting `ActionButtonN.action`; it came from making the secure macro itself branch on `bonusbar` state.
- When reviewing logs, a run is only on the newest path if diagnostics show a `BuildTag` line and `macro1` contains the conditional `BonusActionButtonN` chain.
- `PLAYER_STARTED_MOVING` / `PLAYER_STOPPED_MOVING` are not reliable on 3.3.5a for this setup; movement-based controller mouse look should be driven by `GetUnitSpeed("player")` polling instead.
- The controller mouse-look debounce that behaved best was effectively instant / ~100ms, not a long delay.
- Some spells can show a charge counter even when they do not actually have charges; treat that as a visual false positive unless diagnostics prove otherwise.
- Controller mapping can be sourced from AntiMicroX on Windows or a PS5 controller profile; the important thing is keeping the WoWX routing and transport layer stable.
- The current practical split that worked best was: mouse/kb and controller mapping stay visually clean, while actual non-main-bar execution continues to be owned by WoWX click/proxy routing.

Current debugging ergonomics:

- WoWX now has an in-game diagnostics window instead of relying on chat spam.
- Useful commands:
  - `/wowx diag window`
  - `/wowx diagwin`
- The window supports:
  - capture of a fresh snapshot
  - refresh of the last snapshot
  - select-all for manual copy/paste
- Addons still cannot write arbitrary plain text files directly into the addon directory at runtime; SavedVariables and the in-game debug window are the supported capture surfaces.

Current taint / protected-action findings:

- Event Trace showed repeated `ADDON_ACTION_BLOCKED "WoWX"` events during Runeshroud combat transitions.
- Confirmed blocked calls included:
  - `WoWXActionButtonN:SetHeight()`
  - `WoWXActionButtonN:ClearAllPoints()`
  - `WoWXActionButtonN:SetPoint()`
  - `WoWXActionButtonN:Show()`
  - `WoWXVisualBarFrame:SetWidth()`
  - `WoWXVisualBarFrame:SetScale()`
- These were not harmless noise; combat-time relayout of protected buttons/frames was part of the failure chain.
- Later fixes guarded the visible action buttons and the main visual bar frame against size/point/show/scale changes during combat lockdown.
- After those guards were added, Runemaster behavior tested cleanly enough to treat as the current working solution.

Current status of other classes:

- Reaper remains unresolved / still under investigation.
- Do not assume the Runemaster solution generalizes cleanly to Reaper without fresh diagnostics.

## If Future Work Resumes

Start from these questions in order:

1. What does the latest diag actually say for `EngineCfg: transport=`?
2. What does the PTR SavedVariables file say for `ui.bindingEngine.transport`?
3. Are keyboard and mouse both going through WoWX-owned paths, or is one still native Blizzard routing?
4. What does `GetBonusBarOffset()` do during the class transition in question?
5. Is the client still reporting hidden fake override (`hasOverride=1`, override frames missing)?
6. Is Event Trace showing `ADDON_ACTION_BLOCKED` on WoWX button/frame relayout during combat?
7. Are displayed base buttons resolved to bonus-page slots like `73..84`?

## Minimal Verification Checklist

After any future change, verify with:

1. Full PTR restart.
2. `/wowx diag verbose`
3. If the class issue is combat-state related, also use `/devconsole` Event Trace or live dumps.
4. Confirm these lines explicitly:
   - `EngineCfg: transport=click`
   - expected `BarSlot2 attr(...)`
   - expected `Keybind 1:` behavior
   - expected `displaySlot` for affected buttons
  - expected `bonusOffset` behavior for the class transition
  - absence of new `ADDON_ACTION_BLOCKED` lines on WoWX visual/button relayout during combat

## Suggested Next Safe Cleanup

If preparing for repo submission / handoff:

1. Document clearly that legacy SavedVariables can pin the binding engine to `direct`.
2. Make the migration/reporting more explicit so users can see and correct engine transport quickly.
3. Keep behavior conservative and avoid aggressive runtime rebinding logic.
4. Preserve the current base-key vs modifier-key routing split unless a more robust secure-state design replaces it.

## One-Sentence Bottom Line

The session spent many hours chasing action-state behavior, but the decisive blocker was that the PTR character continued to load legacy `transport=direct` from SavedVariables; once that was forced to `click`, the setup finally behaved as intended.

Updated practical bottom line: for Runemaster, the working solution came from click transport plus conservative combat-safe UI behavior, while treating `bonusOffset` as the real page signal and treating persistent `override=1` as a misleading Ascension-specific special-state artifact.

Latest practical bottom line: on the CoA fork, the current known-good Runemaster path is click transport plus combat-safe UI behavior plus conditional `bonusbar` macro routing for base `ACTIONBUTTONn` buttons; do not drive the bar from the always-noisy override flag.

## Architecture Direction

- The user has repeatedly raised that WoWX may be outgrowing a single large addon file / single-surface coordination model.
- Future work should stay open to splitting subsystems into cleaner modules or even separate addons where that improves ownership, debugging, and controller-specific iteration.
- The relevant design goal is not abstraction for its own sake; it is making each system easier to reason about, validate, and evolve without destabilizing unrelated systems.
- Candidate separation points include UI navigation surfaces, spellbook / questbook style controller-friendly panels, controller-only helper layers, and bridge-style support addons that WoWX consumes rather than inlining everything.
- ConsolePort-style precedent matters here: if a surface can become controller-friendly as a discrete component and then plug in naturally, that may be preferable to forcing all behavior through one monolithic control path.
- Treat this as a direction for future cleanup and architecture work, not as a license to do a broad rewrite during a narrow bugfix session.

## Likely Sustainable Split

- The user specifically wants serious consideration of `WoWX_Gamepad` as its own addon with its own `.toc`, rather than continuing to thread controller and keyboard behavior through the same runtime with more `if controllerEnabled then ...` branching.
- This is a reasonable direction. "Simplicity" should be judged at the end-user level, not by minimizing the number of source files or addons for developers.
- A plausible future shape is:
  - `WoWX` core addon: shared data model, diagnostics, slash commands, binding engine contracts, visual bar ownership, and generic keyboard-safe behavior
  - `WoWX_Gamepad`: controller-only movement helpers, controller setup/calibration, controller-specific bindings, controller UI overlays, and other logic that should be absent when standard input is desired
  - optional further modules for controller-friendly surfaces such as spellbook / quest / menu wrappers if they grow independently
- The same principle applies beyond controller movement: spellbook UI, quest UI, menu wrappers, and other controller-friendly surfaces should not be crammed into action-bar runtime ownership just because they can be launched from the bar.
- Prefer surface-oriented ownership where possible: a spellbook module owns spellbook behavior, a quest/navigation module owns quest GUI behavior, and the action bar owns action-bar behavior.
- Integration between these pieces should happen through narrow bridge functions or shared services, not by letting one runtime file become the de facto owner of unrelated game systems.
- One explicit goal of such a split would be that users can disable controller-specific pieces at the login screen or keep them dormant, guaranteeing that controller code cannot interfere with standard keyboard/mouse inputs.
- Future agents should treat this not as overengineering but as a legitimate containment strategy for regression control.
- The caution is secure ownership: if a split is attempted, keep the secure action/button ownership boundaries clear so combat-safe behavior does not become harder to reason about than it is now.

## Groundwork Plan

- Do not begin with a broad rewrite.
- Start by defining ownership boundaries while preserving behavior.
- First classify current WoWX responsibilities into four buckets:
  - definitely core
  - definitely controller-only
  - definitely surface-specific
  - mixed / entangled and needs untangling first
- Treat `WoWX` core as the likely long-term owner of:
  - shared state and saved-variable contracts
  - diagnostics and slash-command entry points
  - binding-engine contracts
  - secure action-bar / button ownership
- Treat controller-specific movement, controller setup/calibration, controller-only bindings, and controller overlays as prime candidates for `WoWX_Gamepad`.
- Treat spellbook, menu navigation, quest-like UI, prompts, and frame cues as surface modules that should own their own behavior rather than being absorbed into action-bar runtime.
- Prefer narrow bridge/services between modules over direct cross-module ownership.
- Delay any secure-action split until the non-secure ownership boundaries are clean.

### Recommended First Task For Future Agents

- Produce a concrete ownership map of the current WoWX files.
- For each file or major section, identify:
  - current responsibility
  - desired long-term owner
  - whether it belongs in core, `WoWX_Gamepad`, or another future module
  - whether it is safe to extract now or blocked by secure/runtime coupling
- Extraction should follow ownership boundaries, not file size or aesthetics.
- The goal is staged migration, not a one-shot rewrite.

## 2026-05-16 Recovery Snapshot (Post-Regression Repair)

- Transport is confirmed healthy again on PTR in live diagnostics:
  - `EngineCfg: transport=click`
  - `ClickTransport: loaded`
  - `ClickTransport proxies: 60`
- Base and modifier key matrix now routes through proxy buttons:
  - `CLICK WoWXBindButton_ACTIONBUTTONN:LeftButton`
  - `CLICK WoWXBindButton_MULTIACTIONBARxBUTTONN:LeftButton`
- `SHIFT-1` / `SHIFT-2` regression was fixed by binding-order correction:
  - clear Blizzard page/direct keys first
  - then apply WoWX bindings
- Visual click transport no longer depends on live `.action` drift for modifier bars.
  Canonical command->slot ownership is now enforced.

### Canonical Slot Contract (Current Rule)

- `ACTIONBUTTONN`: base action button behavior with conditional bonusbar macro.
- `MULTIACTIONBAR2BUTTONN` (SHIFT page): slots `49-60`.
- `MULTIACTIONBAR1BUTTONN` (ALT page): slots `61-72`.
- `MULTIACTIONBAR4BUTTONN` (CTRL page): slots `37-48`.
- `MULTIACTIONBAR3BUTTONN` (SHIFT-ALT page): slots `25-36`.

Interpretation rule:
- whatever action is on that command's canonical slot is what fires.
- no re-drag should be required after reload if slot contents are already present.

## Quick Navigation Index (Use This First)

Use heading search in this file to jump quickly:

1. `2026-05-16 Recovery Snapshot (Post-Regression Repair)`
2. `Canonical Slot Contract (Current Rule)`
3. `Current TOC Load Order (PTR Fork)`
4. `File Ownership Map (PTR Fork)`
5. `Controller Bring-Up Safety Sequence`
6. `Minimal Verification Checklist`
7. `Known Bad Paths / Dead Ends`

## Current TOC Load Order (PTR Fork)

Load order currently expected in `WoWX.toc`:

1. `GamePadX.lua`
2. `ClickTransport.lua`
3. `UIMode.lua`
4. `SetupWizard.lua`
5. `VisualBar.lua`
6. `ActionButtons.lua`
7. `SettingsUI.lua`
8. `MenuNav.lua`
9. `MinimapButton.lua`
10. `SpellbookUI.lua`
11. `SpellRing.lua`
12. `DispelPrompt.lua`
13. `UnitFrameCues.lua`

Why this matters:
- `ClickTransport.lua` must load before `VisualBar.lua` uses `GPX.ClickTransport`.

## File Ownership Map (PTR Fork)

- `GamePadX.lua`
  - slash command router
  - binding engine application/clear lifecycle
  - diagnostics capture/output windows
  - engine config and migration behavior
- `ClickTransport.lua`
  - single owner of secure attribute writes for click transport
  - proxy button creation and update
  - canonical static slot fallback map
  - must not absorb visual/layout logic
- `VisualBar.lua`
  - visual/action bar frame creation
  - display and tooltip state
  - placement interactions (`PlaceAction`, `PickupAction`)
  - delegates secure writes to `GPX.ClickTransport`
- `ActionButtons.lua`
  - WoWX bag utility button and combined bag window
  - bag/item slot chrome and grid behavior
- `UIMode.lua`
  - focus/navigation context and controller-oriented selection flow
- `SetupWizard.lua`
  - first-run / re-calibration flow and input setup capture
- `SettingsUI.lua`
  - user-facing config surface
- `MenuNav.lua`
  - in-game menu navigation helpers
- `SpellbookUI.lua`
  - spellbook surface integration
- `SpellRing.lua`
  - ring binding/application surface
- `MinimapButton.lua`, `DispelPrompt.lua`, `UnitFrameCues.lua`
  - auxiliary UX modules; should not own core binding transport

## Controller Bring-Up Safety Sequence

Before controller-specific troubleshooting on another machine:

1. full client restart
2. `/wowx reload`
3. `/wowx diag verbose`
4. verify transport/proxy lines (`transport=click`, `ClickTransport loaded`, proxy count)
5. verify base/mod key matrix lines route to `WoWXBindButton_*`
6. only then run controller init/setup
7. re-test one base, one modifier, one click path

If this order fails, do not change transport mode first; inspect load order, SavedVariables transport pinning, and diag lines.