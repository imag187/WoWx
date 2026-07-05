-- Systems/Core/RealmDetector.lua
-- Shared realm-flavor detection for WoWX subsystems and companion forks.

WoWXSystems = WoWXSystems or {}

local Detector = {}
WoWXSystems.RealmDetector = Detector

local function normalize(text)
    return string.lower(tostring(text or ""))
end

function Detector:DetectFlavor(realmName)
    local lowered = normalize(realmName)
    if lowered == "" then
        return "other"
    end

    if string.find(lowered, "conquest of azeroth", 1, true) or string.find(lowered, "coa", 1, true) then
        return "coa"
    end
    if string.find(lowered, "bronzebeard", 1, true) then
        return "bronzebeard"
    end
    if string.find(lowered, "classless", 1, true) then
        return "classless"
    end
    if string.find(lowered, "ascension", 1, true) then
        return "ascension"
    end

    return "other"
end

function Detector:GetActiveFlavor()
    local realmName = (GetRealmName and GetRealmName()) or ""
    return self:DetectFlavor(realmName)
end

function Detector:IsCoAFlavor(flavor)
    return tostring(flavor or "") == "coa"
end

function Detector:IsAscensionFlavor(flavor)
    local current = tostring(flavor or "")
    return current == "coa" or current == "bronzebeard" or current == "classless" or current == "ascension"
end

function Detector:BuildDescriptor()
    local realmName = (GetRealmName and GetRealmName()) or ""
    local flavor = self:DetectFlavor(realmName)
    return {
        realmName = realmName,
        flavor = flavor,
        isAscension = self:IsAscensionFlavor(flavor),
        isCoA = self:IsCoAFlavor(flavor),
    }
end
