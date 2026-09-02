-- Systems/UnitFrames/WoWXUnitFrames.lua
-- Foundation module for WoWX-owned unit frame surfaces.

if not GamePadX then
    return
end

local GPX = GamePadX
local UnitFrames = {}
GPX.UnitFrames = UnitFrames

function UnitFrames:GetConfig()
    GPX.db.ui = GPX.db.ui or {}
    GPX.db.ui.unitFrames = GPX.db.ui.unitFrames or {}

    local cfg = GPX.db.ui.unitFrames
    if cfg.enabled == nil then
        cfg.enabled = false
    end
    if cfg.layout == nil then
        cfg.layout = "compact"
    end

    return cfg
end

function UnitFrames:IsEnabled()
    return self:GetConfig().enabled == true
end

function UnitFrames:SetEnabled(enabled)
    self:GetConfig().enabled = enabled and true or false
end
