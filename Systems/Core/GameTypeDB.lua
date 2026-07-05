-- Systems/Core/GameTypeDB.lua
-- Data-driven realm/game type descriptor, manual pager rules, and resource definitions.

WoWXSystems = WoWXSystems or {}

local DB = {}
WoWXSystems.GameTypeDB = DB

local catalog = {
    classic = {
        id = "classic",
        label = "Classic 3.3.5a",
        expansionType = "wotlk_full",
        classModel = "blizzard_classes",
        ascensionFamily = false,
    },
    conquest_of_azeroth = {
        id = "conquest_of_azeroth",
        label = "Conquest of Azeroth",
        expansionType = "vanilla_progressive",
        classModel = "custom_classes",
        ascensionFamily = true,
    },
    warcraft_reborn = {
        id = "warcraft_reborn",
        label = "Warcraft Reborn",
        expansionType = "vanilla_progressive",
        classModel = "custom_specs",
        ascensionFamily = true,
    },
    classless = {
        id = "classless",
        label = "Classless",
        expansionType = "vanilla_progressive",
        classModel = "classless",
        ascensionFamily = true,
    },
    custom_classes = {
        id = "custom_classes",
        label = "Custom Classes",
        expansionType = "custom_progression",
        classModel = "custom_classes",
        ascensionFamily = true,
    },
}

local realmProfiles = {
    ["vol'jin"] = {
        realmType = "voljin",
        gameType = "conquest_of_azeroth",
        flavor = "coa",
        expansionType = "vanilla_progressive",
    },
    ["vol'jin - coa beta"] = {
        realmType = "voljin",
        gameType = "conquest_of_azeroth",
        flavor = "coa",
        expansionType = "vanilla_progressive",
    },
    ["bronzebeard"] = {
        realmType = "bronzebeard",
        gameType = "warcraft_reborn",
        flavor = "bronzebeard",
        expansionType = "vanilla_progressive",
    },
}

local customClassTokens = {
    "BARBARIAN",
    "WITCHDOCTOR",
    "DEMONHUNTER",
    "WITCHHUNTER",
    "STORMBRINGER",
    "FLESHWARDEN",
    "GUARDIAN",
    "MONK",
    "SONOFARUGAL",
    "RANGER",
    "CHRONOMANCER",
    "NECROMANCER",
    "PYROMANCER",
    "CULTIST",
    "STARCALLER",
    "SUNCLERIC",
    "TINKER",
    "PROPHET",
    "REAPER",
    "TEMPLAR",
    "WILDWALKER",
    "SPIRITMAGE",
    "RUNEMASTER",
}

local coaResourceSeeds = {
    TEMPLAR = {
        { id = "templar_oath_chain", label = "Oath Chain", displayType = "pips", maxValue = 1, sourceType = "aura", auraID = 704576, filter = "HELPFUL", color = { r = 0.95, g = 0.76, b = 0.24 } },
    },
    FLESHWARDEN = {
        { id = "fleshwarden_demonfire", label = "Demonfire", displayType = "pips", maxValue = 6, sourceType = "aura", auraID = 500906, filter = "HELPFUL", useCount = true, color = { r = 1.0, g = 0.42, b = 0.08 } },
    },
    NECROMANCER = {
        { id = "necromancer_lifeforce", label = "Life Force", displayType = "bar", maxValue = 100, sourceType = "aura", auraID = 525004, filter = "HARMFUL", useCount = true, color = { r = 0.32, g = 0.82, b = 0.36 } },
    },
    DEMONHUNTER = {
        { id = "demonhunter_felfury", label = "Felfury", displayType = "pips", maxValue = 6, sourceType = "aura", auraID = 800058, filter = "HELPFUL", useCount = true, color = { r = 0.34, g = 0.92, b = 0.46 } },
    },
    REAPER = {
        { id = "reaper_souls", label = "Souls", displayType = "fragments", maxValue = 3, sourceType = "aura", auraID = 500363, filter = "HELPFUL", useCount = true, fragmentSpellID = 805077, fragmentDivideBy = 3, infusionSpellID = 803031, color = { r = 0.30, g = 0.80, b = 1.00 } },
    },
    PYROMANCER = {
        { id = "pyromancer_embers", label = "Embers", displayType = "pips", maxValue = 5, sourceType = "aura", auraID = 807533, filter = "HARMFUL_OR_HELPFUL", useCount = true, color = { r = 1.0, g = 0.46, b = 0.12 } },
        { id = "pyromancer_heat", label = "Heat", displayType = "bar", maxValue = 100, sourceType = "aura", auraID = 807389, secondaryAuraID = 807309, filter = "HARMFUL_OR_HELPFUL", useCount = true, color = { r = 1.0, g = 0.34, b = 0.08 } },
    },
    SUNCLERIC = {
        { id = "suncleric_solar_power", label = "Solar Power", displayType = "bar", maxValue = 20, sourceType = "aura", auraID = 500149, filter = "HELPFUL", useCount = true, color = { r = 0.98, g = 0.86, b = 0.24 } },
    },
    CULTIST = {
        { id = "cultist_insanity", label = "Insanity", displayType = "bar", maxValue = 100, sourceType = "aura", auraID = 500706, filter = "HARMFUL", useCount = true, color = { r = 0.72, g = 0.34, b = 0.92 } },
    },
    STORMBRINGER = {
        { id = "stormbringer_static", label = "Static", displayType = "bar", maxValue = 100, sourceType = "aura", auraID = 803102, filter = "HARMFUL", useCount = true, color = { r = 0.50, g = 0.78, b = 1.00 } },
    },
    RANGER = {
        { id = "ranger_advantage", label = "Advantage", displayType = "pips", maxValue = 5, sourceType = "aura", auraID = 804329, filter = "HARMFUL_OR_HELPFUL", useCount = true, color = { r = 0.22, g = 0.68, b = 0.32 } },
    },
}

local function buildReactiveDefaultsByGameType(gameType)
    if gameType == "classic" or gameType == "warcraft_reborn" then
        return {
            WARRIOR = {
                { spellID = 7384, label = "Overpower" },
                { spellID = 5308, label = "Execute" },
            },
        }
    end

    return {}
end

local function buildDefaultClassProfiles(descriptor)
    local gameType = descriptor and descriptor.gameType or "classic"
    local profiles = {}

    profiles.WARRIOR = {
        id = "WARRIOR",
        classToken = "WARRIOR",
        displayName = "Warrior",
        lockedResourceIDs = false,
        resources = {
            { id = "warrior_rage", label = "Rage", displayType = "bar", sourceType = "engine", engineResource = "rage", color = { r = 0.88, g = 0.22, b = 0.18 } },
        },
        reactiveSpells = {},
    }
    profiles.PALADIN = {
        id = "PALADIN",
        classToken = "PALADIN",
        displayName = "Paladin",
        lockedResourceIDs = false,
        resources = {
            { id = "paladin_mana", label = "Mana", displayType = "bar", sourceType = "engine", engineResource = "mana", color = { r = 0.18, g = 0.48, b = 1.0 } },
        },
        reactiveSpells = {},
    }
    profiles.HUNTER = {
        id = "HUNTER",
        classToken = "HUNTER",
        displayName = "Hunter",
        lockedResourceIDs = false,
        resources = {
            { id = "hunter_mana", label = "Mana", displayType = "bar", sourceType = "engine", engineResource = "mana", color = { r = 0.18, g = 0.48, b = 1.0 } },
        },
        reactiveSpells = {},
    }
    profiles.ROGUE = {
        id = "ROGUE",
        classToken = "ROGUE",
        displayName = "Rogue",
        lockedResourceIDs = false,
        resources = {
            { id = "rogue_energy", label = "Energy", displayType = "bar", sourceType = "engine", engineResource = "energy", color = { r = 0.98, g = 0.86, b = 0.18 } },
            { id = "rogue_combo", label = "Combo Points", displayType = "pips", sourceType = "engine", engineResource = "combo_points", maxValue = 5, color = { r = 1.0, g = 0.22, b = 0.4 } },
        },
        reactiveSpells = {},
    }
    profiles.PRIEST = {
        id = "PRIEST",
        classToken = "PRIEST",
        displayName = "Priest",
        lockedResourceIDs = false,
        resources = {
            { id = "priest_mana", label = "Mana", displayType = "bar", sourceType = "engine", engineResource = "mana", color = { r = 0.18, g = 0.48, b = 1.0 } },
        },
        reactiveSpells = {},
    }
    profiles.DEATHKNIGHT = {
        id = "DEATHKNIGHT",
        classToken = "DEATHKNIGHT",
        displayName = "Death Knight",
        lockedResourceIDs = false,
        resources = {
            { id = "dk_runic", label = "Runic Power", displayType = "bar", sourceType = "engine", engineResource = "runic_power", color = { r = 0.32, g = 0.9, b = 1.0 } },
        },
        reactiveSpells = {},
    }
    profiles.SHAMAN = {
        id = "SHAMAN",
        classToken = "SHAMAN",
        displayName = "Shaman",
        lockedResourceIDs = false,
        resources = {
            { id = "shaman_mana", label = "Mana", displayType = "bar", sourceType = "engine", engineResource = "mana", color = { r = 0.18, g = 0.48, b = 1.0 } },
        },
        reactiveSpells = {},
    }
    profiles.MAGE = {
        id = "MAGE",
        classToken = "MAGE",
        displayName = "Mage",
        lockedResourceIDs = false,
        resources = {
            { id = "mage_mana", label = "Mana", displayType = "bar", sourceType = "engine", engineResource = "mana", color = { r = 0.18, g = 0.48, b = 1.0 } },
        },
        reactiveSpells = {},
    }
    profiles.WARLOCK = {
        id = "WARLOCK",
        classToken = "WARLOCK",
        displayName = "Warlock",
        lockedResourceIDs = false,
        resources = {
            { id = "warlock_mana", label = "Mana", displayType = "bar", sourceType = "engine", engineResource = "mana", color = { r = 0.18, g = 0.48, b = 1.0 } },
        },
        reactiveSpells = {},
    }
    profiles.DRUID = {
        id = "DRUID",
        classToken = "DRUID",
        displayName = "Druid",
        lockedResourceIDs = false,
        resources = {
            { id = "druid_mana", label = "Mana", displayType = "bar", sourceType = "engine", engineResource = "mana", color = { r = 0.18, g = 0.48, b = 1.0 } },
        },
        reactiveSpells = {},
    }

    local reactiveDefaults = buildReactiveDefaultsByGameType(gameType)
    for token, list in pairs(reactiveDefaults) do
        profiles[token] = profiles[token] or {
            id = token,
            classToken = token,
            displayName = token,
            lockedResourceIDs = false,
            resources = {},
            reactiveSpells = {},
        }
        profiles[token].reactiveSpells = deepCopy(list)
    end

    if descriptor and descriptor.isCoA then
        for _, token in ipairs(customClassTokens) do
            profiles[token] = profiles[token] or {
                id = token,
                classToken = token,
                displayName = token,
                lockedResourceIDs = true,
                resources = {},
                reactiveSpells = {},
            }
            if coaResourceSeeds[token] then
                profiles[token].resources = deepCopy(coaResourceSeeds[token])
            end
            profiles[token].lockedResourceIDs = true
        end
    end

    return profiles
end

local function normalize(text)
    return string.lower(tostring(text or ""))
end

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

local SPELLDB_SHARE_HEADER = "WOWX_SPELLDB_V1"

local function sortKeys(source)
    local keys = {}
    for key in pairs(source or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local function escapeField(value)
    local text = tostring(value or "")
    text = string.gsub(text, "\\", "\\\\")
    text = string.gsub(text, "\t", "\\t")
    text = string.gsub(text, "\r", "\\r")
    text = string.gsub(text, "\n", "\\n")
    return text
end

local function unescapeField(value)
    local text = tostring(value or "")
    local out = {}
    local i = 1
    while i <= string.len(text) do
        local char = string.sub(text, i, i)
        if char == "\\" and i < string.len(text) then
            local nxt = string.sub(text, i + 1, i + 1)
            if nxt == "t" then
                out[#out + 1] = "\t"
            elseif nxt == "r" then
                out[#out + 1] = "\r"
            elseif nxt == "n" then
                out[#out + 1] = "\n"
            else
                out[#out + 1] = nxt
            end
            i = i + 2
        else
            out[#out + 1] = char
            i = i + 1
        end
    end
    return table.concat(out, "")
end

local function splitTabFields(line)
    local parts = {}
    local startPos = 1
    while true do
        local tabPos = string.find(line, "\t", startPos, true)
        if not tabPos then
            parts[#parts + 1] = string.sub(line, startPos)
            break
        end
        parts[#parts + 1] = string.sub(line, startPos, tabPos - 1)
        startPos = tabPos + 1
    end
    for i = 1, #parts do
        parts[i] = unescapeField(parts[i])
    end
    return parts
end

local function maybeNumber(value)
    local text = tostring(value or "")
    if text == "" then
        return nil
    end
    return tonumber(text)
end

local function getDB()
    if not GamePadX or not GamePadX.db then
        return nil
    end
    GamePadX.db.ui = GamePadX.db.ui or {}
    GamePadX.db.ui.gameTypeDB = GamePadX.db.ui.gameTypeDB or {
        mode = "auto",
        manualDescriptor = nil,
        pagerRules = {},
        resourceDefinitions = {},
        classProfiles = nil,
        activeProfileId = nil,
    }
    return GamePadX.db.ui.gameTypeDB
end

local function ensureClassProfileStore(self)
    local config = getDB()
    if not config then
        return nil
    end

    if type(config.classProfiles) ~= "table" then
        local descriptor = self:DetectDescriptor((GetRealmName and GetRealmName()) or "")
        config.classProfiles = buildDefaultClassProfiles(descriptor)
    end

    if not config.activeProfileId or config.activeProfileId == "" then
        if GamePadX and GamePadX.GetResolvedClassToken then
            config.activeProfileId = tostring(GamePadX:GetResolvedClassToken("player") or "WARRIOR")
        else
            config.activeProfileId = "WARRIOR"
        end
    end

    return config
end

function DB:GetCatalog()
    return catalog
end

function DB:DetectDescriptor(realmName)
    local lowered = normalize(realmName)
    local descriptor = {
        realmName = tostring(realmName or ""),
        realmType = "unknown",
        gameType = "classic",
        expansionType = "wotlk_full",
        classModel = "blizzard_classes",
        flavor = "other",
        isAscension = false,
        isCoA = false,
    }

    if lowered == "" then
        return descriptor
    end

    local exact = realmProfiles[lowered]
    if exact then
        descriptor.realmType = exact.realmType
        descriptor.gameType = exact.gameType
        descriptor.expansionType = exact.expansionType
        descriptor.flavor = exact.flavor
    elseif string.find(lowered, "conquest of azeroth", 1, true) or string.find(lowered, "coa", 1, true) then
        descriptor.realmType = "coa"
        descriptor.gameType = "conquest_of_azeroth"
        descriptor.expansionType = "vanilla_progressive"
        descriptor.flavor = "coa"
    elseif string.find(lowered, "bronzebeard", 1, true) then
        descriptor.realmType = "bronzebeard"
        descriptor.gameType = "warcraft_reborn"
        descriptor.expansionType = "vanilla_progressive"
        descriptor.flavor = "bronzebeard"
    elseif string.find(lowered, "classless", 1, true) then
        descriptor.realmType = "classless"
        descriptor.gameType = "classless"
        descriptor.expansionType = "vanilla_progressive"
        descriptor.flavor = "classless"
    elseif string.find(lowered, "ascension", 1, true) then
        descriptor.realmType = "ascension"
        descriptor.gameType = "custom_classes"
        descriptor.expansionType = "custom_progression"
        descriptor.flavor = "ascension"
    end

    local profile = catalog[descriptor.gameType] or catalog.classic
    descriptor.classModel = profile.classModel
    descriptor.isAscension = profile.ascensionFamily == true
    descriptor.isCoA = descriptor.gameType == "conquest_of_azeroth"
    return descriptor
end

function DB:GetConfig()
    return getDB()
end

function DB:GetDescriptor()
    local config = getDB()
    local auto = self:DetectDescriptor((GetRealmName and GetRealmName()) or "")
    if not config then
        return auto
    end

    if config.mode == "manual" and type(config.manualDescriptor) == "table" then
        local merged = deepCopy(auto)
        for key, value in pairs(config.manualDescriptor) do
            merged[key] = value
        end
        local profile = catalog[merged.gameType] or catalog.classic
        merged.classModel = merged.classModel or profile.classModel
        merged.expansionType = merged.expansionType or profile.expansionType
        merged.isAscension = profile.ascensionFamily == true
        merged.isCoA = merged.gameType == "conquest_of_azeroth"
        return merged
    end

    return auto
end

function DB:SetMode(mode)
    local config = getDB()
    if not config then
        return false
    end
    if mode ~= "auto" and mode ~= "manual" then
        mode = "auto"
    end
    config.mode = mode
    return true
end

function DB:SetManualDescriptor(descriptor)
    local config = getDB()
    if not config then
        return false
    end
    config.manualDescriptor = deepCopy(descriptor or {})
    return true
end

function DB:GetPagerRules()
    local config = getDB()
    if not config then
        return {}
    end
    config.pagerRules = config.pagerRules or {}
    return config.pagerRules
end

function DB:SetPagerRules(rules)
    local config = getDB()
    if not config then
        return false
    end
    config.pagerRules = deepCopy(rules or {})
    return true
end

local function hasPlayerAuraBySpellID(spellID)
    if not UnitAura then
        return false
    end
    local wanted = tonumber(spellID)
    if not wanted then
        return false
    end
    for index = 1, 40 do
        local _, _, _, _, _, _, _, _, _, auraSpellID = UnitAura("player", index, "HELPFUL")
        if not auraSpellID then
            break
        end
        if tonumber(auraSpellID) == wanted then
            return true
        end
    end
    for index = 1, 40 do
        local _, _, _, _, _, _, _, _, _, auraSpellID = UnitAura("player", index, "HARMFUL")
        if not auraSpellID then
            break
        end
        if tonumber(auraSpellID) == wanted then
            return true
        end
    end
    return false
end

function DB:EvaluatePagerRules(context)
    local rules = self:GetPagerRules()
    local winner = nil
    for _, rule in ipairs(rules) do
        if type(rule) == "table" and rule.enabled ~= false and tonumber(rule.page) then
            local matched = false
            if rule.triggerType == "stealth" then
                matched = context.stealthed == true
            elseif rule.triggerType == "bonusOffset" then
                matched = tonumber(rule.value) == tonumber(context.bonusOffset)
            elseif rule.triggerType == "aura" then
                matched = hasPlayerAuraBySpellID(rule.spellID or rule.auraID)
            elseif rule.triggerType == "class" then
                matched = tostring(rule.classFile or "") == tostring(context.classFile or "")
            end

            if matched then
                local priority = tonumber(rule.priority) or 0
                if not winner or priority > winner.priority then
                    winner = {
                        page = math.max(1, math.min(10, math.floor(tonumber(rule.page) or 1))),
                        priority = priority,
                        reason = rule.reason or rule.id or ("rule:" .. tostring(rule.triggerType)),
                    }
                end
            end
        end
    end
    if winner then
        return winner.page, winner.reason
    end
    return nil
end

function DB:GetResourceDefinitions()
    local config = getDB()
    if not config then
        return {}
    end
    config.resourceDefinitions = config.resourceDefinitions or {}
    return config.resourceDefinitions
end

function DB:SetResourceDefinitions(definitions)
    local config = getDB()
    if not config then
        return false
    end
    config.resourceDefinitions = deepCopy(definitions or {})
    return true
end

function DB:AddResourceDefinition(definition)
    local definitions = self:GetResourceDefinitions()
    definitions[#definitions + 1] = deepCopy(definition or {})
    return #definitions
end

function DB:GetResourcePresetCatalog()
    if WoWXSystems and WoWXSystems.ResourcePresets and WoWXSystems.ResourcePresets.GetCatalog then
        return WoWXSystems.ResourcePresets:GetCatalog()
    end
    return {}
end

function DB:BuildResourceDefinitionFromPreset(presetId, overrides)
    if WoWXSystems and WoWXSystems.ResourcePresets and WoWXSystems.ResourcePresets.BuildDefinition then
        return WoWXSystems.ResourcePresets:BuildDefinition(presetId, overrides)
    end
    return nil
end

function DB:ImportResourcePreset(presetId, overrides)
    local definition = self:BuildResourceDefinitionFromPreset(presetId, overrides)
    if not definition then
        return nil
    end
    self:AddResourceDefinition(definition)
    return definition
end

function DB:GetClassProfiles()
    local config = ensureClassProfileStore(self)
    if not config then
        return {}
    end
    return config.classProfiles
end

function DB:GetClassProfile(profileId)
    local profiles = self:GetClassProfiles()
    return profiles[tostring(profileId or "")]
end

function DB:SetClassProfile(profileId, profile)
    local config = ensureClassProfileStore(self)
    if not config then
        return false
    end
    local key = tostring(profileId or "")
    if key == "" then
        return false
    end
    config.classProfiles[key] = deepCopy(profile or {})
    config.classProfiles[key].id = key
    config.classProfiles[key].classToken = config.classProfiles[key].classToken or key
    config.classProfiles[key].displayName = config.classProfiles[key].displayName or key
    config.classProfiles[key].resources = config.classProfiles[key].resources or {}
    config.classProfiles[key].reactiveSpells = config.classProfiles[key].reactiveSpells or {}
    return true
end

function DB:EnsureClassProfile(profileId, displayName, classToken)
    local key = string.upper(tostring(profileId or ""))
    if key == "" then
        return false
    end

    local profile = self:GetClassProfile(key)
    if profile then
        return true
    end

    profile = {
        id = key,
        classToken = string.upper(tostring(classToken or key)),
        displayName = tostring(displayName or key),
        lockedResourceIDs = false,
        resources = {},
        reactiveSpells = {},
    }
    return self:SetClassProfile(key, profile)
end

function DB:GetActiveClassProfileId()
    local config = ensureClassProfileStore(self)
    if not config then
        return nil
    end
    return config.activeProfileId
end

function DB:SetActiveClassProfileId(profileId)
    local config = ensureClassProfileStore(self)
    if not config then
        return false
    end
    local key = tostring(profileId or "")
    if key == "" then
        return false
    end
    config.activeProfileId = key
    return true
end

function DB:GetActiveClassProfile()
    local config = ensureClassProfileStore(self)
    if not config then
        return nil
    end
    return config.classProfiles[config.activeProfileId]
end

function DB:SetClassProfileDisplayName(profileId, displayName)
    local profile = self:GetClassProfile(profileId)
    if not profile then
        profile = {
            id = tostring(profileId or ""),
            classToken = tostring(profileId or ""),
            resources = {},
            reactiveSpells = {},
        }
        self:SetClassProfile(profileId, profile)
        profile = self:GetClassProfile(profileId)
    end
    profile.displayName = tostring(displayName or profile.displayName or profile.classToken or profile.id or "Class")
    return true
end

function DB:AddClassProfileReactiveSpell(profileId, spellID)
    local profile = self:GetClassProfile(profileId)
    if not profile then
        return false
    end
    profile.reactiveSpells = profile.reactiveSpells or {}
    local id = tonumber(spellID)
    if not id then
        return false
    end
    for _, entry in ipairs(profile.reactiveSpells) do
        if tonumber(entry.spellID) == id then
            return true
        end
    end
    profile.reactiveSpells[#profile.reactiveSpells + 1] = { spellID = id }
    return true
end

function DB:UpdateClassProfileReactiveSpell(profileId, index, spellID)
    local profile = self:GetClassProfile(profileId)
    if not profile then
        return false
    end
    profile.reactiveSpells = profile.reactiveSpells or {}
    local row = tonumber(index)
    local id = tonumber(spellID)
    if not row or row < 1 or row > #profile.reactiveSpells or not id then
        return false
    end
    profile.reactiveSpells[row].spellID = id
    return true
end

function DB:RemoveClassProfileReactiveSpell(profileId, index)
    local profile = self:GetClassProfile(profileId)
    if not profile then
        return false
    end
    profile.reactiveSpells = profile.reactiveSpells or {}
    local row = tonumber(index)
    if not row or row < 1 or row > #profile.reactiveSpells then
        return false
    end
    table.remove(profile.reactiveSpells, row)
    return true
end

function DB:AddClassProfileResource(profileId, definition)
    local profile = self:GetClassProfile(profileId)
    if not profile then
        return false
    end
    profile.resources = profile.resources or {}
    profile.resources[#profile.resources + 1] = deepCopy(definition or {})
    return true
end

function DB:RemoveClassProfileResource(profileId, index)
    local profile = self:GetClassProfile(profileId)
    if not profile then
        return false
    end
    profile.resources = profile.resources or {}
    local row = tonumber(index)
    if not row or row < 1 or row > #profile.resources then
        return false
    end
    table.remove(profile.resources, row)
    return true
end

function DB:UpdateClassProfileResource(profileId, index, definition)
    local profile = self:GetClassProfile(profileId)
    if not profile then
        return false
    end

    profile.resources = profile.resources or {}
    local row = tonumber(index)
    if not row or row < 1 or row > #profile.resources then
        return false
    end

    local nextValue = deepCopy(definition or {})
    if type(nextValue) ~= "table" then
        return false
    end

    local nextId = tostring(nextValue.id or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if nextId == "" then
        nextValue.id = profile.resources[row].id or (tostring(profile.id or "class") .. "_resource_" .. tostring(row))
    else
        nextValue.id = nextId
    end
    nextValue.label = tostring(nextValue.label or nextValue.id or "Resource"):gsub("^%s+", ""):gsub("%s+$", "")
    nextValue.displayType = tostring(nextValue.displayType or "bar"):gsub("^%s+", ""):gsub("%s+$", "")
    nextValue.sourceType = tostring(nextValue.sourceType or "custom"):gsub("^%s+", ""):gsub("%s+$", "")

    profile.resources[row] = nextValue
    return true
end

function DB:IsSpellReactiveForActiveProfile(spellID)
    local id = tonumber(spellID)
    if not id then
        return false
    end
    local profile = self:GetActiveClassProfile()
    if not profile or type(profile.reactiveSpells) ~= "table" then
        return false
    end
    for _, entry in ipairs(profile.reactiveSpells) do
        if tonumber(entry.spellID) == id then
            return true
        end
    end
    return false
end

function DB:ExportSpellDBText()
    local profiles = self:GetClassProfiles() or {}
    local lines = { SPELLDB_SHARE_HEADER }

    for _, profileId in ipairs(sortKeys(profiles)) do
        local profile = profiles[profileId] or {}
        lines[#lines + 1] = table.concat({
            "profile",
            escapeField(profileId),
            escapeField(profile.classToken or profileId),
            escapeField(profile.displayName or profileId),
            escapeField(profile.icon or ""),
            escapeField(profile.lockedResourceIDs and "1" or "0"),
        }, "\t")

        for _, resource in ipairs(profile.resources or {}) do
            local color = resource.color or {}
            lines[#lines + 1] = table.concat({
                "resource",
                escapeField(profileId),
                escapeField(resource.id or ""),
                escapeField(resource.label or ""),
                escapeField(resource.displayType or ""),
                escapeField(resource.sourceType or ""),
                escapeField(resource.engineResource or ""),
                escapeField(resource.auraID or ""),
                escapeField(resource.secondaryAuraID or ""),
                escapeField(resource.filter or ""),
                escapeField(resource.maxValue or ""),
                escapeField(resource.useCount and "1" or "0"),
                escapeField(resource.fragmentSpellID or ""),
                escapeField(resource.fragmentDivideBy or ""),
                escapeField(resource.infusionSpellID or ""),
                escapeField(color.r or ""),
                escapeField(color.g or ""),
                escapeField(color.b or ""),
            }, "\t")
        end

        for _, reactive in ipairs(profile.reactiveSpells or {}) do
            lines[#lines + 1] = table.concat({
                "reactive",
                escapeField(profileId),
                escapeField(reactive.spellID or ""),
                escapeField(reactive.label or ""),
            }, "\t")
        end
    end

    local activeId = self:GetActiveClassProfileId()
    if activeId and activeId ~= "" then
        lines[#lines + 1] = table.concat({ "active", escapeField(activeId) }, "\t")
    end

    return table.concat(lines, "\n")
end

function DB:ImportSpellDBText(text, mode)
    local raw = tostring(text or "")
    if raw == "" then
        return false, "No SpellDB text provided."
    end

    local parsedProfiles = {}
    local parsedActiveId = nil
    local started = false

    for line in string.gmatch(raw, "[^\r\n]+") do
        local trimmed = tostring(line or "")
        if not started then
            if trimmed == SPELLDB_SHARE_HEADER then
                started = true
            end
        else
            if trimmed ~= "" then
                local fields = splitTabFields(trimmed)
                local tag = fields[1]

                if tag == "profile" then
                    local profileId = tostring(fields[2] or "")
                    if profileId ~= "" then
                        parsedProfiles[profileId] = parsedProfiles[profileId] or {
                            id = profileId,
                            classToken = profileId,
                            displayName = profileId,
                            lockedResourceIDs = false,
                            resources = {},
                            reactiveSpells = {},
                        }
                        local profile = parsedProfiles[profileId]
                        profile.classToken = tostring(fields[3] or profile.classToken or profileId)
                        profile.displayName = tostring(fields[4] or profile.displayName or profileId)
                        profile.icon = tostring(fields[5] or "")
                        profile.lockedResourceIDs = tostring(fields[6] or "0") == "1"
                    end

                elseif tag == "resource" then
                    local profileId = tostring(fields[2] or "")
                    if profileId ~= "" then
                        parsedProfiles[profileId] = parsedProfiles[profileId] or {
                            id = profileId,
                            classToken = profileId,
                            displayName = profileId,
                            lockedResourceIDs = false,
                            resources = {},
                            reactiveSpells = {},
                        }
                        local resource = {
                            id = tostring(fields[3] or ""),
                            label = tostring(fields[4] or ""),
                            displayType = tostring(fields[5] or ""),
                            sourceType = tostring(fields[6] or ""),
                            engineResource = tostring(fields[7] or ""),
                            auraID = maybeNumber(fields[8]),
                            secondaryAuraID = maybeNumber(fields[9]),
                            filter = tostring(fields[10] or ""),
                            maxValue = maybeNumber(fields[11]),
                            useCount = tostring(fields[12] or "0") == "1",
                            fragmentSpellID = maybeNumber(fields[13]),
                            fragmentDivideBy = maybeNumber(fields[14]),
                            infusionSpellID = maybeNumber(fields[15]),
                        }
                        local r = maybeNumber(fields[16])
                        local g = maybeNumber(fields[17])
                        local b = maybeNumber(fields[18])
                        if r or g or b then
                            resource.color = {
                                r = r or 1,
                                g = g or 1,
                                b = b or 1,
                            }
                        end
                        parsedProfiles[profileId].resources[#parsedProfiles[profileId].resources + 1] = resource
                    end

                elseif tag == "reactive" then
                    local profileId = tostring(fields[2] or "")
                    local spellID = maybeNumber(fields[3])
                    if profileId ~= "" and spellID then
                        parsedProfiles[profileId] = parsedProfiles[profileId] or {
                            id = profileId,
                            classToken = profileId,
                            displayName = profileId,
                            lockedResourceIDs = false,
                            resources = {},
                            reactiveSpells = {},
                        }
                        parsedProfiles[profileId].reactiveSpells[#parsedProfiles[profileId].reactiveSpells + 1] = {
                            spellID = spellID,
                            label = tostring(fields[4] or ""),
                        }
                    end

                elseif tag == "active" then
                    parsedActiveId = tostring(fields[2] or "")
                end
            end
        end
    end

    if not started then
        return false, "SpellDB header not found."
    end

    local importedCount = 0
    for _ in pairs(parsedProfiles) do
        importedCount = importedCount + 1
    end
    if importedCount == 0 then
        return false, "No profiles found in SpellDB text."
    end

    local config = ensureClassProfileStore(self)
    if not config then
        return false, "GameTypeDB store unavailable."
    end

    local normalizedMode = tostring(mode or "merge")
    if normalizedMode ~= "replace" then
        normalizedMode = "merge"
    end

    if normalizedMode == "replace" then
        config.classProfiles = {}
    end

    config.classProfiles = config.classProfiles or {}
    for profileId, profile in pairs(parsedProfiles) do
        config.classProfiles[profileId] = deepCopy(profile)
    end

    if parsedActiveId ~= "" and config.classProfiles[parsedActiveId] then
        config.activeProfileId = parsedActiveId
    elseif not config.activeProfileId or not config.classProfiles[config.activeProfileId] then
        for profileId in pairs(config.classProfiles) do
            config.activeProfileId = profileId
            break
        end
    end

    return true, {
        mode = normalizedMode,
        importedProfiles = importedCount,
        activeProfileId = config.activeProfileId,
    }
end
