-- Shared compatibility helpers for supported WoW client families.

WoWXSystems = WoWXSystems or {}

local Compat = {}
WoWXSystems.Compat = Compat

function Compat:ApplyBackdrop(frame, backdrop)
    if frame and not frame.SetBackdrop and Mixin and BackdropTemplateMixin then
        Mixin(frame, BackdropTemplateMixin)
    end
    if frame and frame.SetBackdrop then
        frame:SetBackdrop(backdrop)
        return true
    end
    return false
end

function Compat:GetWatchedFactionInfo()
    if C_Reputation and C_Reputation.GetWatchedFactionData then
        local data = C_Reputation.GetWatchedFactionData()
        if not data then
            return nil
        end
        return data.name, data.factionID, data.reaction, data.currentReactionThreshold,
            data.nextReactionThreshold, data.currentStanding
    end
    if GetWatchedFactionInfo then
        return GetWatchedFactionInfo()
    end
    return nil
end

function Compat:GetContainerNumSlots(bagID)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bagID) or 0
    end
    if GetContainerNumSlots then
        return GetContainerNumSlots(bagID) or 0
    end
    return 0
end

function Compat:GetContainerItemInfo(bagID, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bagID, slot)
        if not info then
            return nil, 0, false, nil
        end
        return info.iconFileID, info.stackCount, info.isLocked, info.quality
    end
    if GetContainerItemInfo then
        return GetContainerItemInfo(bagID, slot)
    end
    return nil, 0, false, nil
end

function Compat:GetContainerItemLink(bagID, slot)
    if C_Container and C_Container.GetContainerItemLink then
        return C_Container.GetContainerItemLink(bagID, slot)
    end
    if GetContainerItemLink then
        return GetContainerItemLink(bagID, slot)
    end
    return nil
end

function Compat:UseContainerItem(bagID, slot)
    if C_Container and C_Container.UseContainerItem then
        return C_Container.UseContainerItem(bagID, slot)
    end
    if UseContainerItem then
        return UseContainerItem(bagID, slot)
    end
end