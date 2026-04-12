# WoWX

WoWX is a WotLK 3.3.5a addon aimed at couch play, reduced-button control surfaces, and accessibility-focused input. It treats controller mappings as ordinary WoW key presses so Linux tools like AntiMicroX or Steam Input can stay outside the addon.

## Installation

1. Download the latest release zip from the [Releases](../../releases) page.
2. Unzip the archive.
3. Inside the unzipped folder you will find a `WoWX` directory.
4. Copy or move the `WoWX` folder into your WoW addons directory:
   - **Windows:** `World of Warcraft\_classic_\Interface\AddOns\`
   - **Linux:** `~/.wine/drive_c/Program Files/World of Warcraft/_classic_/Interface/AddOns/` (or wherever your Wine prefix keeps the game)
5. Launch (or reload) the game and confirm `WoWX` appears in your AddOns list at the character select screen.
6. Enable the addon and log in, then run `/wowx init` to begin setup.

## Accessibility Policy

WoWX is an accessibility surface first.

- No aim assist.
- No rotation automation.
- No gameplay automation.
- No hidden decision systems that play for the player.

WoWX only exposes clearer, lower-friction input and UI interaction over standard WoW actions that the player still performs directly.

## Current Scope

- Visual setup wizard for input capture
- WoWX visual action bar with modifier pages
- Drag-and-drop placement onto underlying Blizzard action slots
- SpellRing support for secure cast-sequence style buttons
- Dispel prompts and player or party frame dispel cues
- Control center window and minimap launcher
- UI mode with focus navigation across WoWX windows
- WoWX spellbook window for assigning spells to the focused WoWX bar button without mouse dependence

## Core Commands

- `/wowx init` opens the visual setup wizard
- `/wowx recal` reruns calibration
- `/wowx config` opens the control center
- `/wowx bar toggle` shows or hides the visual bar
- `/wowx bar lock` locks the bar
- `/wowx bar unlock` unlocks the bar for dragging
- `/wowx bar reset` resets the bar position
- `/wowx enable` enables bindings for this session
- `/wowx disable` disables bindings for this session

## Input Model

WoWX currently assumes:

- 12 action buttons on the base page
- 3 single-modifier pages
- 1 stock combo page using `SHIFT+ALT`

Base page:

- 12 action keys -> `ACTIONBUTTON1` through `ACTIONBUTTON12`

Modifier pages:

- Modifier + action keys -> page slots 1 through 12

Current stock page mapping:

- Modifier 1 -> `MULTIACTIONBAR2BUTTON`
- Modifier 2 -> `MULTIACTIONBAR1BUTTON`
- Modifier 3 -> `MULTIACTIONBAR4BUTTON`
- Modifier 1 + Modifier 2 -> `MULTIACTIONBAR3BUTTON`

## UI Mode

When a WoWX-owned window is active, WoWX temporarily overrides the mapped inputs for UI navigation.

- Directional inputs navigate focus
- Confirm uses the captured jump button
- Cancel uses the first captured action-side key plus `ESCAPE`
- Next or previous window uses modifier 2 and modifier 3

Current focusable windows:

- Control Center
- Action Bar
- Spellbook

The UI-mode banner at the top of the screen shows the active window and the live navigation bindings.

## Suggested Linux Test Flow

1. Install the addon and reload the UI.
2. Run `/wowx init`.
3. Choose a device family that matches the labels you want on screen.
4. Capture modifiers and the 12 action buttons.
5. Click `Apply Setup`.
6. Open `/wowx config`.
7. Use `Focus Bar` to enter bar UI mode.
8. Confirm on a bar button to open the WoWX spellbook.
9. Confirm on a spell to assign it to that WoWX button.
10. Exit UI mode and test the action in the world.

## Debug Checklist

- If bindings do not fire, run `/wowx status` and confirm WoWX is enabled.
- If the bar is missing, run `/wowx bar show` or `/wowx bar toggle`.
- If the minimap icon is missing, open `/wowx config` and toggle the minimap button.
- If spell assignment fails, verify you are not in combat.
- If modifier pages look wrong, confirm your modifier buttons are mapped to real WoW modifiers: `SHIFT`, `ALT`, or `CTRL`.
- If UI mode seems stuck, close the active WoWX window with the cancel key or `ESCAPE`.

## Known Current Limits

- WoWX UI mode currently governs WoWX-owned windows, not the entire Blizzard UI.
- The spellbook flow is WoWX-owned and is not yet a full cursorless wrapper around Blizzard's default spellbook.
- Only one stock combo page is currently wired by default: `SHIFT+ALT`.
- Full controller navigation for arbitrary Blizzard windows, bags, quest panes, and other addons is not done yet.

## Practical Direction

The next major milestone is broadening the WoWX focus and window manager so more gameplay and configuration surfaces can be traversed without free mouse movement.

## Attribution And Credits

WoWX references established action-bar addon design patterns from the World of Warcraft addon community.

- Bartender4 and its authors are credited for architectural inspiration around action-bar behavior, secure interaction patterns, and configuration ergonomics.
- Any retained or adapted code must keep original copyright and license notices from the source project.
- WoWX should continue to document upstream inspiration clearly in release notes and repository documentation.