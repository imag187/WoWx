# CoA Multicast Bar Integration Guide

## Overview

This document explains how WoWX supports the Conquest of Azeroth (CoA) multicast bar, which is available to Necromancer and other CoA classes.

## What Is The Multicast Bar?

The multicast bar is CoA's equivalent to the Shaman totem bar or similar spell-switching mechanics. It typically has 4-8 active slots for class-specific abilities.

## Modifier Page Mapping

WoWX supports 5 modifier pages for accessing different action bars:

| Modifier | Bar | Command | Notes |
|----------|-----|---------|-------|
| None | Main | ACTIONBUTTON | Slots 1-12 |
| SHIFT | Bottom-Left | MULTIACTIONBAR2BUTTON | Slots 1-12 |
| ALT | Bottom-Right | MULTIACTIONBAR1BUTTON | Slots 1-12 |
| SHIFT+ALT | Right | MULTIACTIONBAR3BUTTON | Slots 1-12 - Standard WoW |
| SHIFT+CTRL | Multicast | MULTICASTBUTTON | Slots 1-12 - **CoA Exclusive** |

## Current Support

WoWX now supports binding the CoA multicast bar through a 5th modifier page:

- **Modifier Page 5**: SHIFT+CTRL combination → MULTICASTBUTTON1-12

This allows you to access up to 12 multicast abilities using your configured action keys with both SHIFT and CTRL modifiers held.

## Enabling Multicast Bar Bindings

### Step 1: Verify Multicast Bar Exists In-Game

1. Open the game menu: **Escape**
2. Navigate to: **Key Bindings → Search for "MultiCast"**
3. If you see entries like:
   - MultiCast Bar Button 1
   - MultiCast Bar Button 2
   - etc.
   
   Then the multicast bar is available for your class.

### Step 2: Run Controller Setup

```
/wowx init
```

This will guide you through calibrating your controller and will automatically include all 5 modifier pages, including the multicast bar.

### Step 3: Calibrate Your Controller

During setup, you'll be prompted for several keys/buttons:
- Jump Key
- Menu Key
- Look Key
- Action Keys (12 buttons for main bar)
- SHIFT Modifier (for Bottom-Left bar)
- ALT Modifier (for Bottom-Right bar)
- CTRL Modifier (for Right bar + Multicast bar)

The setup wizard will automatically configure SHIFT+CTRL to trigger the multicast bar bindings.

### Step 4: Test In-Game

After setup completes:

1. Open your action bar settings: **Escape → Interface Options → Action Bars**
2. Ensure "MultiCast Bar" is checked if available
3. Test multicast bindings:
   - Press SHIFT+CTRL with your action buttons
   - You should see multicast abilities execute
4. Check `/wowx diag verbose` to confirm bindings are working

## Binding Command Format

WoWX uses these binding commands for multicast:
- `MULTICASTBUTTON1` → MultiCast Bar Button 1
- `MULTICASTBUTTON2` → MultiCast Bar Button 2
- ...
- `MULTICASTBUTTON8` (or more, depending on class)

These are standard WoW binding commands that work on any Ascension PTR character with multicast bar support.

## Current Limitations

- **Button Count**: Currently supports 4-12 buttons
  - If your class uses fewer, simply don't bind all 12 slots
  - If it uses more, contact WoWX developers

- **Class Support**: Tested on Necromancer
  - Should work for Shaman/Hero and other CoA classes
  - Report issues for unsupported classes

- **Visual Display**: The multicast bar is bound but not shown in WoWX's visual HUD
  - Use the native Blizzard multicast bar for now
  - Visual integration is planned for future versions

## Troubleshooting

### Multicast buttons don't respond

1. **Verify in Key Bindings**:
   - Open Escape → Key Bindings
   - Search for "MultiCast"
   - Ensure SHIFT+CTRL+F1 (etc) bindings are not overridden

2. **Check binding transport**:
   - Run: `/wowx diag verbose`
   - Look for: `bindingEngine.transport = "click"`
   - Should be "click", not "direct"

3. **Re-run setup**:
   - Run: `/wowx init`
   - Verify SHIFT+CTRL modifiers are correctly assigned

### Multicast bar doesn't appear

1. Open interface settings: **Escape → Interface Options → Action Bars**
2. Enable the **MultiCast Bar** checkbox
3. If unavailable, your class may not support multicast

### SHIFT+CTRL conflicts

If SHIFT+CTRL combinations conflict with other bindings:

1. Open **Escape → Key Bindings**
2. Clear conflicting SHIFT+CTRL bindings
3. Re-run `/wowx init`

## Advanced: Manual Binding Configuration

To manually edit multicast bindings:

1. Open SavedVariables file:
   ```
   WTF/Account/<Account>/Vol'jin - CoA Beta/Glyphhoof/SavedVariables/WoWX.lua
   ```

2. Find the `profiles.default.bindings` section

3. Add entries like:
   ```lua
   ["SHIFT-CTRL-F1"] = "MULTICASTBUTTON1",
   ["SHIFT-CTRL-F2"] = "MULTICASTBUTTON2",
   ["SHIFT-CTRL-F3"] = "MULTICASTBUTTON3",
   ["SHIFT-CTRL-F4"] = "MULTICASTBUTTON4",
   ```

4. Save and reload: `/reload`

## For Developers

### Adding Support For Other Custom Bars

To add support for additional CoA bars:

1. Edit `GamePadX.lua` in the `getDirectClickTarget` function (line ~1780):
   ```lua
   if command:find("^CUSTOMBAR1BUTTON") then
       return "CustomBarFrame" .. index
   end
   ```

2. Add modifier page in `BuildBindingsFromSetup` (line ~1760):
   ```lua
   { modifiers = { "ALT", "CTRL" }, bar = "CUSTOMBAR1BUTTON" },
   ```

3. Choose an unused modifier combo from the mapping table above

### Finding Frame Names

To discover custom bar frame names:

1. In-game: `/script print(MultiCastActionBarFrame:GetName())`
2. List children: `/script for i=1,8 do print(MultiCastActionBarFrame:GetChild(i):GetName()) end`

## Links

- **WoWX Repository**: https://github.com/imag187/WoWx
- **Issue Tracker**: https://github.com/imag187/WoWx/issues
- **Ascension PTR**: Conquest of Azeroth server

