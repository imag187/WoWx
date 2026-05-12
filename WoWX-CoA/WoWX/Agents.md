# WoWX Debug Handoff

## Purpose

This file is a continuity handoff for future work on WoWX, especially for the Runemaster / Runeshroud paging issue on Ascension PTR.

Primary goal: avoid retracing dead ends and preserve the actual discoveries from the debugging session.

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