# WoWX Resource Definition Direction

This is the data model target for user-authored unit-frame resources.

## Goal

Let players describe a resource in-game without hardcoding each class or custom spec.

Examples:
- mana / rage / energy style bars
- pip resources
- fragment-based resources such as souls made of multiple shards
- aura/spell-driven resources on custom class servers

## Draft Shape

```lua
{
    id = "reaper_souls",
    label = "Souls",
    enabled = true,
    displayType = "pips", -- bar | pips | fragments
    unit = "player",
    maxValue = 5,
    minValue = 0,
    startsAtZero = true,
    resourceSpellID = 12345,
    auraID = 12345,
    fragmentSpellID = 67890,
    fragmentCount = 3,
    color = { r = 0.2, g = 0.7, b = 1.0 },
    textureStyle = "blue_steel_glow",
}
```

## Required Ideas

- built-in resources should not be redefined repeatedly
- custom resources should layer on top of the known engine model
- preview should exist in the editor UI before saving
- resource descriptors should be per machine / per character profile when needed
- unit frames should consume these definitions directly

## Immediate Code Goal

The first implementation step is storage and retrieval, followed by a simple editor UI later.
