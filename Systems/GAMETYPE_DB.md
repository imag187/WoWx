# WoWX GameType DB Direction

This is the design target for keeping WoWX broader than a single server family while still supporting deep Ascension-specific behavior.

## Why This Exists

WoWX is no longer just a generic WoW addon, but it should also not collapse into an Ascension-only addon.

The correct model is:
- WoWX supports multiple game types and realm types.
- Detection can auto-fill sensible defaults.
- Players can override those choices per machine / character profile.
- System behavior can branch from a shared data model instead of ad hoc checks.

## Core Terms

### Game Type
Defines the gameplay ruleset that most strongly affects classes, resources, action paging, and UI behavior.

Examples:
- `classic`
- `classless`
- `conquest_of_azeroth`
- `warcraft_reborn`
- `custom_classes`

### Realm Type
Defines the specific realm under the login server.

Examples:
- `voljin`
- `bronzebeard`
- future custom realms

### Expansion Type
Defines content/progression structure rather than class system.

Examples:
- `vanilla_progressive`
- `wotlk_full`
- `custom_progression`

## Desired Descriptor Shape

A full descriptor should eventually look like this:

```lua
{
    realmName = "Vol'jin",
    realmType = "voljin",
    gameType = "conquest_of_azeroth",
    expansionType = "vanilla_progressive",
    classModel = "custom_classes",
    flavor = "coa",
    isAscension = true,
}
```

## Why This Matters

This descriptor will drive:
- action pager rules
- stance / stealth / shapeshift logic
- resource bar behavior
- unit frame resource rendering
- spell range and dispel behavior
- game-specific system defaults
- what system checkboxes should default on/off

## Profile and Override Rules

The intended layering is:

1. auto-detect runtime realm info
2. map that to default GameType DB values
3. allow per-machine override
4. allow per-character / per-profile override

That keeps WoWX flexible for:
- server families that can be detected
- custom realms that cannot be detected yet
- private server drift where realm and gameplay rules do not line up cleanly

## Unit Frame Relevance

Unit frames should eventually read from the same GameType DB.

This matters because:
- class resources differ by game type
- custom class servers may need resource definitions not present in base 3.3.5a
- classless/custom-class players may need user-authored aura/spell driven resource bars

Long-term target:
- player-first layout
- party second
- raid third
- hide party frames in raid
- retain useful xperl-style status cues
- own the styling in WoWX visual language

## Immediate Build Goal

Short-term implementation should provide:
- a shared detector module
- a GameType DB module
- settings UI for override selection
- persistence through existing machine/character state

This makes WoWX reviewable, expandable, and less dependent on fork-specific logic.
