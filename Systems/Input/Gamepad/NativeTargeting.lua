-- NativeTargeting.lua
-- Hold-to-target buttons over WoW Forever's native gamepad targeting manager
-- (C_GamepadTargeting). Bindable from the Key Bindings UI (WoWX section) or via
-- SetBindingClick. Holding aims the reticle; releasing without a selection falls
-- back to the nearest friend/enemy when the matching game option is enabled.
-- Does nothing on clients without C_GamepadTargeting.

if not GamePadX then return end

BINDING_HEADER_WOWX = "WoWX"
_G["BINDING_NAME_CLICK WoWXTargetFriendly:LeftButton"] = "Target Friendly (Hold)"
_G["BINDING_NAME_CLICK WoWXTargetHostile:LeftButton"] = "Target Hostile (Hold)"

if not (C_GamepadTargeting and Enum and Enum.GamepadTargetingFilters) then return end

local function createTargetButton(name, filter, tabTarget, tabCvar)
    local button = CreateFrame("Button", name, UIParent)
    button:Hide()
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetScript("OnClick", function(_, _, down)
        if down then
            C_GamepadTargeting.SetFilter(filter)
            C_GamepadTargeting.Enable()
            return
        end
        local targetAlreadySelected = C_GamepadTargeting.Disable()
        if not targetAlreadySelected and tabTarget and tabCvar and GetCVarBool(tabCvar) then
            tabTarget(false)
        end
    end)
    return button
end

local filters = Enum.GamepadTargetingFilters
createTargetButton("WoWXTargetFriendly", filters.Friendly, _G.TargetNearestFriend, "GamepadTabFriendlyTargetAction")
createTargetButton("WoWXTargetHostile", filters.Hostile, _G.TargetNearestEnemy, "GamepadTabHostileTargetAction")
