# WoWX Debug Handoff

## Purpose

This file is a continuity handoff for future work on WoWX, especially for the Runemaster / Runeshroud paging issue on Ascension PTR.

Primary goal: avoid retracing dead ends and preserve the actual discoveries from the debugging session.

## 2026-11-13 Current Target: WoW Forever Client (READ BEFORE ANYTHING BELOW)

- Everything below this section was written for Ascension PTR / 3.3.5a. The working copy now lives at `d:\Games\World of Warcraft\_forever_\Interface\AddOns\WoWx` and targets the **WoW Forever** client (`.flavor.info` = `wowf`, TOC `## Interface: 16001`).
- That client is a modern-engine build (D3D12, Edit Mode, Housing/Professions logs, native gamepad UI, Questie also loads at 16001), NOT 3.3.5a. 3.3.5-era assumptions in older notes (global-function bag hooks, `ContainerFrameItemButtonTemplate` behavior, `SetBackdrop` on plain frames) must be re-verified in-game before trusting them.
- 2026-09-18 / 09-25 commits retired the WoWX bag, spellbook grid and spell ring in `WoWX.toc` because the native gamepad UI covered them. 2026-11-13: the bag (`Systems/Bags/ActionButtons.lua`) was RE-ENABLED in the TOC (the WoWX bag system already existed; dropping it was a mistake). It is still untested on this client; expect modern-engine breakage (global `ToggleBackpack`/`OpenAllBags` overrides, `ContainerFrameItemButtonTemplate`, backdrops) and verify in-game via `/wowx out window` / `WoWXRuntimeErrors`. Spellbook grid and spell ring remain retired.
- Decision (user, 2026-11-13): the native gamepad-mode bag is bad (it was good in early beta, then regressed). WoWX should either OWN the bag or force/reuse Blizzard's keyboard-mode unified (combined) bag with controller navigation. General rule: any surface that needs controller workarounds should be owned by WoWX.
- Clarification (user, 2026-11-13): the native gamepad UI otherwise works great and STAYS ENABLED. The only parts to replace are the bag (and bank) and how spells are presented (spellbook). Do NOT plan around turning native gamepad UI off or around the older "controller = plain key presses, UIMode owns navigation" model for these surfaces; the WoWX bag must coexist with native gamepad mode (open/close routing, input/focus while native gamepad UI is active). How WoWX bag navigation should work under native gamepad mode is still to be designed.
- Repo-root `ActionButtons.lua`, `Camera.lua`, `ClickTransport.lua` are stale duplicates; the TOC loads only `Systems\...` paths.

### Project Direction (user, 2026-11-13) - READ FIRST

- Two products, in order: (1) **WoWX-ABP** (Action Bar Pager): keyboard + controller cross-play action bar with modifier paging and good visual indicators; will live in its own directory/addon `WoWX-ABP` and be tracked there. (2) A greater **WoWX UI**, the long-term "final boss". This is a MAJOR REVISION and is NOT being started now.
- This repo is currently the bits and parts that make both possible. Do not restructure it for that split yet.
- Current work for the next several days (user is leveling): keep the keyboard feel of the bar right, iron out bugs, fix the minimap icon so WoWX's edit mode (Layout Edit / Button Edit) is reachable.
- Blizzard owns, in all modes: bags, bank, combined-bag option, micro menu, vehicle exit button. No feature switches for these; the WoWX bag module is not loaded.
- Native gamepad UI stays enabled.

### Gamepad Strategy (user + analysis, 2026-11-13)

- Immediate focus: WoWX-ABP (action bar pager + XP bar) with mouse + keyboard working as designed. Controller comes after.
- Leaning (user): own the controller bindings instead of living with Blizzard's. Blizzard's native gamepad mode binds buttons 5-8 to fixed game actions (auto attack, cancel, jump...) and leaves the center (PS/Xbox) button alone or to Steam; WoWX should define these itself (possible keybind/menu on the center button, different L3 use instead of auto-run).
- Working model: keep the engine gamepad layer ENABLED (stick/movement/camera, cursor, `C_GamepadTargeting`), but WoWX owns the binding table (strip `GAMEPADACTIONBUTTON*` etc. and rebind). This is what ConsolePort does ("native gamepad controls", strips native keys, hides the native gamepad bar). Do not turn native gamepad off and re-implement input.
- Muscle memory: ship a "Blizzard native layout" preset as the default so players coming from the native controller UI do not relearn; WoWX layout/custom is opt-in.
- Order: ABP kb+mouse -> ABP controller bindings (native-layout preset) -> targeting (`NativeTargeting.lua`) -> bags/bank -> spell presentation -> D-pad frame navigation (largest piece; ConsolePort_Cursor equivalent).
- ConsolePort license is Artistic-2.0 (verified on GitHub): reuse/modification is allowed with attribution, change notes and no use of the ConsolePort name. Still default to original code that follows its patterns; alternative is to coexist with ConsolePort modules rather than fork.
- Release: ship WoWX-ABP as its own addon on CurseForge (Interface 16001, Forever only), separate from the future WoWX UI.

### North Star (user, 2026-11-13)

Be the best lightweight controller UI that has ever existed. Old-school 3.3.5 operation was perfect and has been moved to a branch; the goal is to get that feel back on WoW Forever.

- Minimal drawing of tools: no flashy chrome, no bloated menus, no strange text, no badly drawn outlines, low RAM/CPU.
- Practical, modifier-state-driven, swappable action bars that behave exactly like Blizzard bars even in "controller" mode (placing spells etc. stays 1:1 with the native Blizzard bars/slots).
- Account for multiple input methods.
- Owning 100% of a surface (bags, bank, spell presentation, even a full UI replacement) is acceptable IF it stays minimal and slot/spell placement remains 1:1 with Blizzard's native bars. Native gamepad UI stays enabled for everything not replaced.
- Action paging: do not diverge from the method ConsolePort uses (user already had us dig into why it works and stop being "x% different" from it). Prefer ConsolePort's proven approach over novel routing. Priority is the action bar pager first, then bags/bank, then spell presentation.
- Look in the right places: ConsolePort (paging, navigation), Bartender4 (bar replacement/hiding), Bagnon-style addons (bags) for patterns, but write original code.

### Mouse + Modifier Click Requirement (user, 2026-11-13)

Why click transport exists (and why WoWX differs from ConsolePort): the user constantly CLICKS bar slots (or taps a controller trackpad) while a modifier is held, e.g. Shift held, click the slot under "-" and expect the SHIFT-row action, exactly like a macro bound to "-" with `[mod:shift]` or a Blizzard bar where hold-mod + click works. Controller/trackpad taps that were not planned for must behave the same way.
- Current mechanism: every visible `WoWXActionButtonN` gets secure attributes for ALL modifier prefixes (`ClickTransport:ApplyButtonModifiers` writes base, `shift-`, `alt-`, `ctrl-`, `shift-alt-`/`alt-shift-`), so the secure handler resolves hold-mod + click to the right slot in and out of combat. The base row is Pager-owned (pages in combat); modifier rows are static slots.
- Known gaps to verify in-game once keyboard mode works: (1) clicks register `LeftButtonUp`/`RightButtonUp` only while right-click `type2/action2` is wiped on purpose, so right-click does nothing; (2) the Forever client may cast bar keys on key DOWN (`ActionButtonUseKeyDown` cvar), so click vs key timing can feel different; (3) verify hold-Shift+click on a far-right slot casts the shift-row spell, and that drag/place (`PlaceAction`/`PickupAction`) with a modifier held targets the same slot Blizzard's bars would.
- Order of work: keyboard mode + usable diag output first, then kb+mouse together (this section), then controller trackpad taps.

### ConsolePort Paging Findings (verified against GitHub master, 2026-11-13)

ConsolePort already supports WoW Forever (its TOCs list `16001`; recent commits "Add the gamepad action storage backend for Forever", "Page the gamepad bar onto vehicle, override and temp shapeshift pages", "Hide the native gamepad bar, strip its keys"). Files: `ConsolePort/Controller/Pager.lua`, `ConsolePort_Bar/Widget/Button/Button.lua`, `ConsolePort_Bar/Widget/Page/Page.lua`.

- Buttons are real secure action buttons (LibActionButton), `type='action'` + `action=<slot>` attributes. No `/click` proxy macros.
- One secure Pager frame owns a state driver on `actionpage`. Its condition is only a TRIGGER list: `[possessbar] 1; [overridebar] 2; [shapeshift] 3; [bar:2..6]; [bonusbar:1..5]; <default>`. The values are meaningless.
- The `_onstate-actionpage` response (restricted env) is a replica of `ActionBarController_UpdateAll`: vehicle bar -> override bar -> temp-shapeshift bar -> `GetBonusBarOffset()+NUM_ACTIONBAR_PAGES` -> `GetActionBarPage()`. The engine APIs are the authority, not the condition values.
- The response writes `actionpage` on the pager and on every registered header (`Pager:RegisterHeader`), runs each header's `ActionPageChanged` snippet, and headers push `ChildUpdate('actionpage', page)` to buttons. Each button's secure `UpdateState` recomputes its `action` (`slot + (page-1)*12`, or Forever gamepad-storage offsets for stance pages). Page swaps therefore work IN COMBAT because they happen inside secure snippets.
- Modifier layers are a separate axis: per-state `labtype-<state>` / `labaction-<state>` attributes, state driven by a modifier driver (their `db.Layers` input controller owns `[mod:]` conditions; never call global `RegisterStateDriver` with `[mod:]` there).
- Stances/shapeshift/stealth/prowl are NOT detected by aura or spell ID. They ride the engine's bonusbar/shapeshift/override indices. `UPDATE_BONUS_ACTIONBAR` only feeds an insecure notification (`OnUpdateShapeshiftForm(spellID, bonusBarIndex, formIndex)`).
- Gap / caveat: a page swap that is driven only by an aura/spell ID with NO bonusbar/form/override change (Ascension Runeshroud-style) is not covered by the default; ConsolePort exposes `Settings/actionPageCondition` and `Settings/actionPageResponse` as the extension point. Restricted env cannot read auras directly, so the usual answer is a macro-condition trigger plus engine-index response, or an out-of-combat insecure attribute update.
- Tension to resolve: the CoA-fork "never use direct" rule below was learned on Ascension 3.3.5a. ConsolePort's secure-button approach is proven on 16001. Re-test on WoW Forever with a small isolated spike before deciding; do not assume either way.
- Not yet read: ConsolePort `db.Actionbar.Gamepad` model (Forever native gamepad slot storage: BarOffset/Width/Stance.Bar/Stance.Count) and `Controller/Layers.lua`, `Controller/GamepadActions.lua`.

### 2026-11-13 Forever Implementation Status (NOTHING BELOW HAS BEEN RUN IN-GAME)

Superseded: the "Non-Negotiable Agent Rules (CoA Fork)" and all Ascension click/macro notes do NOT apply on Forever. `BonusActionButtonN` macros do not exist here.

- `Systems/Core/Compat.lua`: install-if-missing shims for legacy globals (`GetMouseFocus`, `GetSpellInfo`, container functions, `UnitBuff`...). Loads first.
- `Systems/Transport/Pager.lua` (`GPX.Pager`): ConsolePort-style secure pager. Trigger-only `actionpage` macro-condition driver; the secure response replicates `ActionBarController_UpdateAll` (vehicle -> override -> temp shapeshift -> bonus offset -> `GetActionBarPage()`), rewrites `action` attributes inside the secure env so paging works in combat. Register out of combat only. API: `GetCurrentPage`, `GetSlot`, `Register/Unregister`, `Refresh`, `AddListener`.
- `ClickTransport.lua`: macro routing removed. `ACTIONBUTTONn` proxies are secure `type=action` buttons registered with the Pager; modifier rows stay static (SHIFT 13-24, ALT 25-36, CTRL 37-48, SHIFT-ALT 49-60). Base keys bind to visible `WoWXActionButtonN`, modifier keys to `WoWXBindButton_<command>`.
- `VisualBar.lua`: `Bar:UpdateNativeGamepadBar` hides `GamepadMainActionBarFrame` (OnShow guard) and `GamePadX` strips `GAMEPADACTIONBUTTON1..8`/`GAMEPADLEFTMOD/RIGHTMOD` bindings ONLY when controller mode is enabled. `managedBlizzardBars` now also lists the modern frames (`MainActionBar`, `StanceBar`, `PossessActionBar`, `PetActionBar`, `MicroMenu`, `BagsBar`, `MultiBar5-7`); missing names are skipped. Hide method mirrors ConsolePort/Bartender (reparent to a hidden frame, out of combat only).
- `Systems/Input/Gamepad/NativeTargeting.lua` + `Bindings.xml`: `WoWXTargetFriendly` / `WoWXTargetHostile` hold-to-target buttons over `C_GamepadTargeting` (bind `CLICK WoWXTargetHostile:LeftButton` in Key Bindings, `runOnUp`). Stripping `GAMEPADACTIONBUTTON5..8` may remove native Interact/Inspect; bind `INTERACTTARGET` (or the key-bindings UI) if missing. OPEN: confirm in-game.
- Bags (`Systems/Bags/ActionButtons.lua`): Blizzard bag opening is now handled with `hooksecurefunc` post-hooks (the old global overrides tainted the secure keybind path), debounced per frame because the wrappers call each other. `HideBlizzardContainerFrames` also hides `ContainerFrameCombinedBags`. Controller nav: `UIMode` context `"bags"` (D-pad move, Confirm = use/drop, window shoulders = pick up/put down, Cancel closes). `UIMode:GetNavigationKeys` falls back to native pad keys (`PADDUP`... `PAD1`/`PAD2`, `PADLSHOULDER`/`PADRSHOULDER`) when `C_GamePad.IsEnabled()` and no WoWX setup profile exists. Bank uses the same context. Auto-open for merchant/mail does not grab navigation.
- Spellbook grid / spell ring remain retired. Spell presentation under native gamepad UI is NOT yet designed.
- In-game test checklist: `/wowx diag verbose`, `/wowx out window`, `/wowx dump WoWXRuntimeErrors`, `/wowx dump GamePadX.Pager:GetCurrentPage()`. Verify: base keys page on stance/stealth/vehicle in AND out of combat; modifier rows static; visuals match; native gamepad bar hidden with controller mode on and untouched with it off; bag opens via B key / vendor / bank and does not taint (`ADDON_ACTION_BLOCKED`); bag D-pad navigation works with native gamepad UI enabled.

## 2026-11-13 In-game findings (first real run on Forever)

- Diag works. Fixed: `CooldownFrame_SetTimer` missing (Compat shim) aborted `Bar:UpdateAll` before `Show()`. After that: bar visible, 12 buttons, 60 proxies, bindings routed, pager registered, zero errors, BUT keys/clicks fired nothing.
- Suspected cause (fix applied, UNVERIFIED): modern secure action buttons act on key DOWN by default (`useOnKeyDown` attribute / cvar `ActionButtonUseKeyDown`); WoWX buttons were registered `LeftButtonUp` only so the down click was never seen. Now `ClickTransport:ConfigureClicks` registers `AnyUp`+`AnyDown` and syncs `useOnKeyDown` to the cvar (CVAR_UPDATE + post-combat). Diag "Action buttons" line prints cvar + `btn1.useOnKeyDown`. If it still does nothing, next suspects: the `type=action` secure path on Forever, tainted `action` writes, or bindings clobbered by native gamepad UI.
- Visual overlaps seen: detached stance buttons and the WoWX bag button sit on top of action slot 11/12 area.

### SECRET VALUES (critical Forever rule, found 2026-11-13)

- The client returns opaque "secret" values (cooldowns, charges, aura data, possibly range/count/usable) in combat/restricted state. Insecure (addon) code CANNOT compare, branch on, or do arithmetic with them; it throws `attempt to compare local 'duration' (a secret number value, while execution tainted by 'WoWx')`. Values may only be PASSED to widget APIs (`cooldown:SetCooldown`).
- Symptom that exposed it: bar icons stuck on the pre-combat/pre-modifier state until combat dropped (keys still fired correctly, because secure execution is unaffected). Cause: `Compat.lua` `CooldownFrame_SetTimer` compared `duration` -> error aborted `Bar:UpdateAll` mid-loop, leaving later buttons stale. 50 captured errors were all this or aura reads (`GetDebuffDataByIndex` in DispelPrompt/UnitFrameCues).
- Fix: `WoWXIsSecret()` (Compat.lua, wraps `issecretvalue`); `CooldownFrame_SetTimer` passes secrets straight to the widget; VisualBar `isSecret/anySecret/clean` guard cooldown, GCD, charges, usable, range, count, equipped, queued, overlay reads; `UpdateAll` runs each `UpdateButton` in pcall (logged via `WoWXLogRuntimeError`); `UnitBuff/UnitDebuff` shims pcall and return nil when secret.
- RULE: any new code reading cooldown/aura/charge/health-style API results must go through `WoWXIsSecret`/`clean` before comparing. Possible better path (untested): `C_ActionBar.GetActionCooldownDuration` + `Cooldown:SetCooldownFromDurationObject`.
- Diag has an "Action slot probe" INFO line (skipped in combat) for per-slot action/spell cooldown + override IDs; added to investigate "new Forever spells don't show cooldown" (unresolved, may also be this issue).

## 2026-11-13 Confirmed in-game (Grell, Paladin, Forever)

- CONFIRMED: keys fire (AnyUp+AnyDown, useOnKeyDown); modifier rows swap visually; combat feels "very good".
- CONFIRMED: combat cooldown swipes work after `Bar:ApplyCooldown` (VisualBar.lua): when `GetActionCooldown` returns secrets, use `C_ActionBar.GetActionCooldownDuration(slot)` + `Cooldown:SetCooldownFromDurationObject`. The old `pcall(cooldown.SetCooldown, secret...)` failed silently, so swipes only appeared after combat. Diag line "Combat cooldown path" shows `lastPath` (durationobject / settimer-secret / plain) and `lastErr`.
- Charge-based spell cooldowns in combat still use the old path (untested, likely blank in combat).
- Pager audit vs ConsolePort: trigger-only condition + engine-index secure response match ConsolePort. Differences: modifier rows are static slots (intentional), no `actionPageCondition` extension point. Untested on this character: stance/stealth/vehicle/override paging (needs druid/rogue; shaman at level 8 has no forms).

## Failure capture (added after a transient protected-action popup was lost)

- `Systems/Core/Compat.lua` now listens for `ADDON_ACTION_BLOCKED/FORBIDDEN` and `MACRO_ACTION_*` (all addons; addon name, function, combat flag, held modifiers, bounded `debugstack`), deduplicated with counts, max 40. It also chains `seterrorhandler` and records any Lua error mentioning "wowx" (also appended to `WoWXRuntimeErrors`), then calls the previous handler unchanged.
- Persisted in `WoWXDB.captures` (this session); the previous session is rotated to `WoWXDB.previousCaptures` at PLAYER_LOGIN (chat notice if non-empty). `/wowx diag dump` prints both plus a "No blocked protected actions (WoWX)" check. Memory view: `/dump WoWXBlockedActions`.
- First `[WoWX BLOCKED]` occurrence per function is also printed to chat.
- VisualBar's coalescing timer (`scheduleVisualBarUpdate`) now pcalls `UpdateAll` (timer callbacks bypass the OnEvent wrapper, a likely error-flood source).
- UNVERIFIED suspect for the protected-action popup: `Bar:UpdateVehicleLeaveButton` has no combat guard and mutates `hostFrame` (SetParent/SetPoint/SetScale/Show) on every `UpdateAll`, including in combat; the protected vehicle leave button is parented to that host. Do not guard it until the capture names the actual blocked function.

## 2026-11-13 Diagnostics, Debug Macros, Icon (NOT RUN IN-GAME YET)

- `Systems/Base/Diagnostics.lua` (`GPX.Diag`): `/wowx diag` runs a self-test suite (enabled, runtime errors, shims, system toggles, visual bar config/frame/visibility, buttons, pager, proxies, bindings, native bars, bags, targeting). Failed checks run a repair (UpdateAll, Pager:Refresh, re-bind, enable config toggle...) and are re-tested: PASS / FIXED / FAIL / INFO. `/wowx diag dump` does the same and puts the report + runtime errors + `CollectDiagnosticsLines()` into the output window. `diag verbose` was removed. Also kept: `diag stance`, `diag window`.
- Output window: `SetOutputWindowLines` PINS the window (`GPX.outputPinned`); chat mirroring is suspended so text stays selectable. `/wowx out live` (or Clear) resumes mirroring.
- The addon is opt-in per character: bar stays hidden until `/wowx enable` (+ `/reload`). Diag reports this explicitly.
- Icon: `Textures/Icon.tga` (128x128 32-bit TGA, infinity + X in a gold-stroked navy circle/square badge), referenced by `## IconTexture` in the TOC. Generated with PowerShell System.Drawing (no source file kept).
- Debug macros (create in /macro, paste body):
  - `WX_Test`: `/wowx diag`
  - `WX_Dump`: `/wowx diag dump`
  - `WX_On`: `/wowx enable`
  - `WX_Off`: `/wowx disable`
  - `WX_Redo`: `/wowx reload`
  - `WX_Errs`: `/wowx dump WoWXRuntimeErrors`
  - `WX_Page`: `/wowx dump GamePadX.Pager:GetCurrentPage()`
  - `WX_Out`: `/wowx out toggle`
  - `WX_Live`: `/wowx out live`
  - `WX_Kbd`: `/wowx toggle keyboard`
  - `WX_Pad`: `/wowx toggle controller`
  - `WX_Edit`: `/wowx unlock` / `WX_Lock`: `/wowx lock`
  - `WX_Stat`: `/wowx status`

## 2026-11-13 Mode-dependent bag ownership + native micro menu (NOT RUN IN-GAME)

User decision: keyboard mode uses Blizzard's bags, bank, micro menu and Edit Mode positioning (Forever additions included). WoWX replaces the bag/bank ONLY when controller mode is enabled. Native gamepad UI stays enabled everywhere else.

- Single predicate: `Buttons:GetShowState()` (ActionButtons.lua) now also requires `GPX:IsControllerEnabled()`. It gates the utility bag button + mouselook button, B / SHIFT-B override bindings, `ToggleBackpack`/`OpenAllBags`/... post-hooks, MERCHANT_SHOW / MAIL_SHOW auto-open, and BANKFRAME_OPENED (WoWX bank). In keyboard mode all of these are inert.
- `Buttons:SetBlizzardBankSuppressed(false)` is a no-op unless WoWX previously suppressed (no more alpha/mouse writes on Blizzard bank frames every `UpdateAll`).
- `GPX:SetControllerEnabled` now calls `ActionButtons:UpdateAll()` and `VisualBar:UpdateBlizzardBars()` (pcall, logged). `UpdateAll` hides WoWX bag/bank windows and the button when leaving controller mode; both defer in combat (`pendingRefresh`, `pendingAttributeRefresh` now also set by `UpdateBlizzardBars` in combat).
- Micro menu: WoWX never touches it. `MicroMenu` and the legacy `*MicroButton` frames were removed from `managedBlizzardBars`; `Bar:UpdateMicroMenu` only hides the legacy `WoWXMicroMenuFrame` (never created now). The old code reparented Forever's native micro buttons out of `MicroMenu`, which broke Edit Mode and showed red question marks for entries not in the legacy list. `keepMicroMenu`, `microPoint` saved settings are ignored; `/wowx bar keepmenu` just prints a note. Reparenting was runtime-only, so `/reload` restores the native layout.
- `BagsBar`: native in keyboard mode, reparented to the hidden parent in controller mode (restored out of combat on toggle back). Legacy `CharacterBag*Slot` / `MainMenuBarBackpackButton` are skipped when `BagsBar` exists (they live inside it).
- Diag: new "Bag / micro menu ownership (mode-dependent)" check (MicroMenu/BagsBar parent+shown, WoWX bag button/window state). FAIL means native menu hidden/reparented, or WoWX bag UI visible in keyboard mode.
- Tests (all unverified):
  1. Keyboard mode, `/reload`: native micro menu complete (no red `?`), movable in Edit Mode; B / bag bar opens Blizzard bags; vendor, mail, bank are Blizzard's; no WoWX bag button or window. `/wowx diag` bag/micro line = PASS.
  2. `/wowx toggle controller` (out of combat): WoWX bag button appears, BagsBar hides, B / vendor / bank open WoWX windows, Blizzard containers hidden. D-pad nav in the bag untested.
  3. Toggle back to keyboard: WoWX windows close, BagsBar returns, B opens Blizzard bags. Repeat the toggle in combat; it must apply after combat ends with no `ADDON_ACTION_BLOCKED` (`/wowx diag dump`).

## 2026-11-13 Vehicle exit native, bag-hook crash, capture gap (NOT RUN IN-GAME)

- SUPERSEDES the mode-dependent bag section above (user, 2026-11-13): Blizzard owns bags, bank and the "Use Combined Bags" option in ALL modes, controller included; Edit Mode places them. FINAL (same day): the `WOWX_OWNS_BAGS` flag was REMOVED (user: no switch that can be messed up). `Systems\Bags\ActionButtons.lua` is simply NOT in `WoWX.toc` (parked reference file only). Also removed: `bindWoWXBagHotkeys` in GamePadX (it bound B/SHIFT-B to `WoWXUtilityBagButton` regardless of the flag, the likely source of the stray WoWX bag window), the Settings "WoWX Bags" button/status line/system toggle, and the Diagnostics bag-module checks (replaced by "Native bags / micro menu"). `keepBags` in VisualBar is always true. Note: the controller mouselook button was hosted by that parked module and is therefore also not loaded; re-home it if controller mouselook is needed.
- Minimap button (WoWX edit mode entry): previously `CreateFrame(..., "UIDropDownMenuTemplate")` at file load and `EasyMenu` (removed from modern clients) broke it. Now: no load-time template, menu via `MenuUtil.CreateContextMenu` (fallback `EasyMenu`, fallback chat hint with slash commands), `atan2` fallback, pcall + `WoWXLogRuntimeError` on click/menu actions, frame level raised above the Minimap. Gridbook entry removed (spellbook retired). Slash fallbacks: `/wowx unlock` / `lock` (Layout Edit), `/wowx buttonunlock` / `buttonlock` (Button Edit). UNVERIFIED in-game.
- Minimap button follow-up (user, 2026-11-13): the icon DID appear after a full client restart (the earlier hide was likely a stale client session, not only the EasyMenu/template bug). Forever has two UI modes (Modern / Enhanced); the user runs Enhanced. Questie (`Questie/Libs/LibDBIcon-1.0`) is the working reference: LibDBIcon button on `Minimap`, fixed frame strata/level, `GetMinimapShape`, `AddonCompartmentFrame:RegisterAddon`. WoWX now has a rich tooltip (`Button:ShowTooltip`: version, input mode, modifier row, base page, Layout/Button Edit state, click hints), Shift-click = Layout Edit toggle, Ctrl-click = Button Edit toggle, and an Addon Compartment entry (`Button:RegisterCompartment`, no-op if `AddonCompartmentFrame` is absent). UNVERIFIED: whether Forever's Game Menu exposes the compartment; Options > AddOns canvas panel (`Settings.RegisterCanvasLayoutCategory`) is the fallback idea if not.
- XP/Rep bar: user says it is fine as is (WoWX bar look and feel stays). No XP bar changes were made. Possible later: Blizzard-like rest/honor behavior and 20 "bubble" dividers, only if requested.
- Fixed: `GetUnitSpeed("player")` returns a secret value in combat; the controller mouselook poll in `GamePadX.lua` compared it (1769 captured errors in WoWx.lua). It now uses `WoWXIsSecret` and keeps the last known moving state.
- Roadmap notes (user): Bartender-style layout profiles plus size/move for the pager, but NOT button count editing. Future option: show the pager in 1, 2 or 3 rows that still swap; controller mode (8 buttons) would be 1 or 2 rows.
- CONFIG MENU DIRECTION (user, 2026-11-13, "we've gone over this over and over"): model the config like Bartender (sidebar or hamburger sections for optional bits). Action Bar 1 = the base pager bar, the only movable bar; modifier rows are not separate bars. Button counts are NOT editable. Wanted per-bar options: position and (maybe) rows. Only two distinct actions exist: (1) WoWX Layout Edit on/off (`config.locked`, moves/scales everything) and (2) Button Lock on/off (`config.buttonLocked`, slot placement; labelled "Button Lock: On" = locked in Settings and minimap menu; requires Layout Edit off). Optional features (e.g. XP/Rep bar visibility, checkbox "Show XP/Rep Bar") live ONLY in the config menu, not the minimap menu. Not built yet: sidebar layout, rows setting (needs main-bar layout metrics around `GetLayoutMetrics`/`GetVisibleButtonCount` in VisualBar.lua).
- Layout Edit is ONE mode (user: "make it like Bartender"): `/wowx unlock` / minimap Shift-click unlocks every element (bar, modifier indicator, stance, pet, vehicle, micro, XP/Rep bar) with drag, corner scale handle and an Edit panel. The XP/Rep bar now has a Scale (`progressScale`, saved in layout profiles) and corner scale handle like the rest, plus Width/Height/Opacity in its Edit panel. `/wowx bar progresslock` is just an alias of Layout Edit. The "Visible Buttons" slider was removed from the main bar Edit panel (button count is not user-editable; controller mode still uses its own 8-button count).

- User decision: Blizzard owns the vehicle exit button (Forever Edit Mode positions it). `MainMenuBarVehicleLeaveButton` removed from `managedBlizzardBars`; `Bar:UpdateVehicleLeaveButton` now only hides a legacy `WoWXVehicleHostFrame` if one exists and never creates it or touches the button (the old version reparented/moved/showed the protected button every `UpdateAll`, including in combat = prime popup suspect). Diag check "Vehicle exit button is native" (parent, visible, canExit). Test: enter a vehicle/mount-with-exit, button appears, click leaves it, in and out of combat; Edit Mode moves it.
- Bug found from live diag (2 Lua errors): `hooksecurefunc("OpenStackSplitFrame")` threw because the global does not exist on Forever; it ran inside `EnsureBagWindow`, aborting bag window creation (every bag open in controller mode errored). Now hooks `StackSplitFrame` OnShow, or the global only if it is a function. RULE: guard every `hooksecurefunc` on a global with `type(_G[name])=="function"` (or `WoWXSafeHookSecureFunc`).
- Capture gap: user saw a popup but `ADDON_ACTION_BLOCKED/FORBIDDEN` handler recorded nothing (all addons: 0), so either the popup is not that event or Forever fires other names. Added: (1) `StaticPopup_Show` / `C_StaticPopup.Show` hook recording popups whose name has ADDON/BLOCK/FORBID/TAINT/PROTECT (chat `[WoWX POPUP]`); (2) `/wowx diag probe` toggles an all-events listener recording event names matching BLOCK/FORBID/TAINT/PROTECT/ADDON_ACTION/SECRET (turn OFF afterwards; costs CPU). Diag blocked check now reads `WoWXDB.captures.blocked`. Next popup: run `/wowx diag probe` first, reproduce, `/wowx diag dump`.
- Unconfirmed: the popup may also have been the Lua-error display from the bag hook crash (died while errors flooded).

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

- Profile terminology and ownership must remain separate:
  - **Layout profiles** are the Bartender-style profiles. They save WoWX UI element placement, sizing, visibility, scale, and related presentation settings. A character can select one independently of class.
  - **Class/resource profiles** save observed class mechanics: resource bars, reactive spells, class tokens, and pager/resource test definitions. They exist so a player can probe, verify, and configure any private-server class without a new addon code commit.
  - **Character state** selects the active layout profile and active class/resource profile independently. A class profile may optionally reference a layout profile, but that is a convenience mapping, not a change in profile ownership or meaning.
  - **Machine state** stores controller calibration, input setup, and machine-local runtime preferences. It is not a UI layout profile or a class profile.
- The Profiles tab should be layout-profile parity with Bartender: create, save, load, delete, and select presentation profiles. Class selection and class/resource editing belong in the Classes tab.
- The Classes system is a data/probing surface, not a server fork. It should use the raw client APIs and manually entered observations to support arbitrary custom classes and mechanics; it must not require CoA, BronzeBeard, Ascension, realm detection, or a separate addon commit.
- Current technical debt: `GamePadX.lua` still delegates class/resource APIs to the removed `WoWXSystems.GameTypeDB`. Restore that capability as a generic local class/resource service before expanding the Classes UI; do not reintroduce retired server-specific catalogs.
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

## Controller-Friendly Surface Direction

- WoWX should eventually own and style the player, target, and target-of-target frames as placeable UI surfaces. Their positions, sizes, visibility, chrome, and presentation belong to layout profiles; class/resource definitions belong to class/resource profiles.
- Unit frames should consume a shared resource-provider contract rather than contain class logic. The class system supplies observed resource definitions and reactive spell metadata; the frame surface decides how to display them.
- Controller navigation should be a shared non-secure service with surface adapters. It should provide focus order, D-pad movement, confirm/cancel, cursor centering or bobble behavior, and contextual action hints. Quest dialogue, gossip choices, loot rows, menus, spellbook entries, and similar surfaces should register their own items with that service.
- Quest dialogue and gossip need explicit support for focused choice rows, quest accept/decline/complete actions, and scroll state. Loot needs focused rows, item tooltips, loot-all, individual loot, and escape/close behavior. These surfaces must work without requiring action-bar ownership.
- The current `MenuNav.lua` is only a static launcher and `WoWXUnitFrames.lua` is only an enable/config foundation. Neither is the finished controller surface system; do not treat their existence as completed feature support.
- Initial implementation should remain in the main WoWX addon under surface-oriented modules. A future `WoWX_Gamepad` addon is appropriate only for controller-only input helpers, cursor/movement behavior, and navigation orchestration once those interfaces are narrow and tested. Core UI surfaces should remain usable without it.
- ConsolePortLK should be studied for interaction patterns, not copied wholesale: detect the active Blizzard frame, build a deterministic focus list, show the current control's WoWX/controller hint, and route confirmation through the control's native click/selection behavior.

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