-- Systems/Core/SystemRegistry.lua
-- Runtime system enable/disable registry. Defaults to enabled.

WoWXSystems = WoWXSystems or {}

local Registry = {
    defaults = {
        core = true,
        ui = true,
        transport = true,
        bags = true,
        spellgrid = true,
        cues = true,
        gamepad = true,
        keyboard = true,
        unitframes = true,
    }
}

WoWXSystems.Registry = Registry

local function lowerId(id)
    return string.lower(tostring(id or ""))
end

function Registry:IsEnabled(id)
    local key = lowerId(id)
    if key == "" then
        return true
    end

    local defaultValue = self.defaults[key]
    if defaultValue == nil then
        defaultValue = true
    end

    if not WoWX or not WoWX.db then
        return defaultValue
    end

    WoWX.db.ui = WoWX.db.ui or {}
    WoWX.db.ui.systems = WoWX.db.ui.systems or {}
    local systems = WoWX.db.ui.systems

    if systems[key] == nil then
        systems[key] = defaultValue
    end

    return systems[key] == true
end

function Registry:SetEnabled(id, enabled)
    local key = lowerId(id)
    if key == "" then
        return false
    end

    if not WoWX or not WoWX.db then
        return false
    end

    WoWX.db.ui = WoWX.db.ui or {}
    WoWX.db.ui.systems = WoWX.db.ui.systems or {}
    WoWX.db.ui.systems[key] = enabled and true or false
    return true
end
