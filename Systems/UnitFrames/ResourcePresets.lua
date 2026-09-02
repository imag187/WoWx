-- Systems/UnitFrames/ResourcePresets.lua
-- Seed profiles/templates for WoWX resource bars and pips.

WoWXSystems = WoWXSystems or {}

local Presets = {}
WoWXSystems.ResourcePresets = Presets

local function deepCopy(source)
    if type(source) ~= "table" then
        return source
    end
    local copy = {}
    for key, value in pairs(source) do
        copy[deepCopy(key)] = deepCopy(value)
    end
    return setmetatable(copy, getmetatable(source))
end

local presetCatalog = {
    {
        id = "mana_bar",
        label = "Mana Bar",
        category = "engine-bar",
        definition = {
            id = "mana_bar",
            label = "Mana",
            enabled = true,
            displayType = "bar",
            unit = "player",
            engineResource = "mana",
            minValue = 0,
            startsAtZero = true,
            textureStyle = "blue_steel_bar",
            color = { r = 0.18, g = 0.48, b = 1.0 },
        },
    },
    {
        id = "rage_bar",
        label = "Rage Bar",
        category = "engine-bar",
        definition = {
            id = "rage_bar",
            label = "Rage",
            enabled = true,
            displayType = "bar",
            unit = "player",
            engineResource = "rage",
            minValue = 0,
            startsAtZero = true,
            textureStyle = "blue_steel_bar",
            color = { r = 0.88, g = 0.22, b = 0.18 },
        },
    },
    {
        id = "energy_bar",
        label = "Energy Bar",
        category = "engine-bar",
        definition = {
            id = "energy_bar",
            label = "Energy",
            enabled = true,
            displayType = "bar",
            unit = "player",
            engineResource = "energy",
            minValue = 0,
            startsAtZero = true,
            textureStyle = "blue_steel_bar",
            color = { r = 0.98, g = 0.86, b = 0.18 },
        },
    },
    {
        id = "runic_power_bar",
        label = "Runic Power Bar",
        category = "engine-bar",
        definition = {
            id = "runic_power_bar",
            label = "Runic Power",
            enabled = true,
            displayType = "bar",
            unit = "player",
            engineResource = "runic_power",
            minValue = 0,
            startsAtZero = true,
            textureStyle = "blue_steel_bar",
            color = { r = 0.32, g = 0.9, b = 1.0 },
        },
    },
    {
        id = "combo_points_pips",
        label = "Combo Point Pips",
        category = "engine-pips",
        definition = {
            id = "combo_points_pips",
            label = "Combo Points",
            enabled = true,
            displayType = "pips",
            unit = "target",
            engineResource = "combo_points",
            maxValue = 5,
            minValue = 0,
            startsAtZero = true,
            pipShape = "square_glow",
            color = { r = 1.0, g = 0.22, b = 0.4 },
        },
    },
    {
        id = "custom_bar_template",
        label = "Custom Resource Bar Template",
        category = "template",
        definition = {
            id = "custom_bar_template",
            label = "Custom Resource",
            enabled = true,
            displayType = "bar",
            unit = "player",
            engineResource = nil,
            minValue = 0,
            maxValue = 100,
            startsAtZero = true,
            auraID = nil,
            spellID = nil,
            textureStyle = "blue_steel_bar",
            color = { r = 0.2, g = 0.7, b = 1.0 },
        },
    },
    {
        id = "custom_pips_template",
        label = "Custom Pips Template",
        category = "template",
        definition = {
            id = "custom_pips_template",
            label = "Custom Pips",
            enabled = true,
            displayType = "pips",
            unit = "player",
            maxValue = 5,
            minValue = 0,
            startsAtZero = true,
            auraID = nil,
            spellID = nil,
            pipShape = "square_glow",
            color = { r = 0.96, g = 0.8, b = 0.22 },
        },
    },
    {
        id = "custom_fragments_template",
        label = "Custom Fragments Template",
        category = "template",
        definition = {
            id = "custom_fragments_template",
            label = "Custom Fragments",
            enabled = true,
            displayType = "fragments",
            unit = "player",
            maxValue = 5,
            minValue = 0,
            startsAtZero = true,
            auraID = nil,
            spellID = nil,
            fragmentSpellID = nil,
            fragmentCount = 3,
            pipShape = "square_glow",
            color = { r = 0.55, g = 0.84, b = 1.0 },
        },
    },
    {
        id = "reaper_souls_template",
        label = "Reaper Souls Template",
        category = "coa-template",
        definition = {
            id = "reaper_souls_template",
            label = "Souls",
            enabled = true,
            displayType = "fragments",
            unit = "player",
            gameType = "conquest_of_azeroth",
            maxValue = 5,
            minValue = 0,
            startsAtZero = true,
            auraID = nil,
            spellID = nil,
            fragmentSpellID = nil,
            fragmentCount = 3,
            pipShape = "square_glow",
            textureStyle = "blue_steel_glow",
            color = { r = 0.44, g = 0.76, b = 1.0 },
            notes = "Fill in the actual soul and fragment spell/aura IDs from Ascension debug tools.",
        },
    },
}

function Presets:GetCatalog()
    return presetCatalog
end

function Presets:GetPreset(presetId)
    local wanted = tostring(presetId or "")
    for _, preset in ipairs(presetCatalog) do
        if preset.id == wanted then
            return deepCopy(preset)
        end
    end
    return nil
end

function Presets:BuildDefinition(presetId, overrides)
    local preset = self:GetPreset(presetId)
    if not preset then
        return nil
    end
    local definition = deepCopy(preset.definition)
    if type(overrides) == "table" then
        for key, value in pairs(overrides) do
            definition[key] = deepCopy(value)
        end
    end
    return definition
end
