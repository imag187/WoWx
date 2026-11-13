-- Pager.lua
-- Secure action pager for the WoWX base row, modelled on ConsolePort's Pager.
--
-- A SecureHandlerStateTemplate frame owns one state driver. The macro
-- condition is only a TRIGGER list: its values are meaningless and merely cause
-- the handler to re-evaluate. The response is a secure replica of
-- ActionBarController_UpdateAll, so the engine's own bar indices (vehicle,
-- override, temp shapeshift, bonus bar, bar page) stay the single authority.
-- The response then rewrites the `action` attributes of every registered
-- button, entirely inside the secure environment. That is why page swaps
-- (stances, stealth, vehicles, bar paging) also work in combat.
--
-- Load order: before ClickTransport.lua.

if not GamePadX then return end

local GPX = GamePadX
local Pager = CreateFrame("Frame", "WoWXPager", UIParent, "SecureHandlerStateTemplate")
GPX.Pager = Pager

local NUM_PAGES = NUM_ACTIONBAR_PAGES or 6
local NUM_BUTTONS = NUM_ACTIONBAR_BUTTONS or 12

Pager.registered = {}
Pager.listeners = {}

Pager:Execute("refs = newtable(); idxs = newtable(); pfxs = newtable()")

-- Replica of ActionBarController_UpdateAll. Every call is guarded because the
-- restricted environment only exposes what the client provides.
local PAGE_SNIPPET = ([[
    local page
    if HasVehicleActionBar and HasVehicleActionBar() and GetVehicleBarIndex then
        page = GetVehicleBarIndex()
    elseif HasOverrideActionBar and HasOverrideActionBar() and GetOverrideBarIndex then
        page = GetOverrideBarIndex()
    elseif HasTempShapeshiftActionBar and HasTempShapeshiftActionBar() and GetTempShapeshiftBarIndex then
        page = GetTempShapeshiftBarIndex()
    elseif GetBonusBarOffset and GetBonusBarOffset() > 0 then
        page = GetBonusBarOffset() + %d
    else
        page = GetActionBarPage and GetActionBarPage() or 1
    end
    return page or 1
]]):format(NUM_PAGES)

local APPLY_SNIPPET = ([[
    local page = ...
    local base = (page - 1) * %d
    for key, button in pairs(refs) do
        local slot = base + idxs[key]
        local prefix = pfxs[key]
        button:SetAttribute(prefix .. "action", slot)
        button:SetAttribute(prefix .. "action1", slot)
    end
]]):format(NUM_BUTTONS)

local REFRESH_SNIPPET = [[
    local page = self:RunAttribute("ComputePage")
    local old = self:GetAttribute("wxpage")
    self:SetAttribute("wxpage", page)
    self:RunAttribute("ApplyPage", page)
    if old ~= page then
        self:CallMethod("OnActionPageChanged", page)
    end
]]

Pager:SetAttribute("ComputePage", PAGE_SNIPPET)
Pager:SetAttribute("ApplyPage", APPLY_SNIPPET)
Pager:SetAttribute("Refresh", REFRESH_SNIPPET)
Pager:SetAttribute("_onstate-wxpage", [[ self:RunAttribute("Refresh") ]])

-- Trigger list only; see header comment.
local function buildCondition()
    local conditions = {
        "possessbar", "overridebar", "shapeshift",
        "bar:2", "bar:3", "bar:4", "bar:5", "bar:6",
        "bonusbar:1", "bonusbar:2", "bonusbar:3", "bonusbar:4", "bonusbar:5",
    }
    local cond = ""
    for i, macroCondition in ipairs(conditions) do
        cond = cond .. ("[%s] %d; "):format(macroCondition, i)
    end
    return cond .. (#conditions + 1)
end

-- Insecure replica for display / resolution. Uses the same engine authorities.
function Pager:GetCurrentPage()
    if HasVehicleActionBar and HasVehicleActionBar() and GetVehicleBarIndex then
        return GetVehicleBarIndex()
    elseif HasOverrideActionBar and HasOverrideActionBar() and GetOverrideBarIndex then
        return GetOverrideBarIndex()
    elseif HasTempShapeshiftActionBar and HasTempShapeshiftActionBar() and GetTempShapeshiftBarIndex then
        return GetTempShapeshiftBarIndex()
    elseif GetBonusBarOffset and (GetBonusBarOffset() or 0) > 0 then
        return GetBonusBarOffset() + NUM_PAGES
    end
    return GetActionBarPage and GetActionBarPage() or 1
end

-- Action slot the base-row button `index` (1..12) currently addresses.
function Pager:GetSlot(index)
    local idx = tonumber(index)
    if not idx then return nil end
    return ((self:GetCurrentPage() or 1) - 1) * NUM_BUTTONS + idx
end

-- Registers (or re-registers) a secure button so the pager keeps its action
-- attributes on the current page. `prefix` is the modifier prefix including the
-- trailing dash ("", "shift-", ...). Out of combat only.
function Pager:Register(button, prefix, index)
    if not button or InCombatLockdown() then return false end
    local name = button.GetName and button:GetName()
    local idx = tonumber(index)
    if not name or not idx then return false end
    prefix = prefix or ""

    local key = name .. "|" .. prefix
    local entry = self.registered[key]
    if entry and entry.index == idx and entry.button == button then
        return true
    end

    self.registered[key] = { button = button, index = idx }
    self:SetFrameRef("wxbtn", button)
    self:Execute(("local k = %q; refs[k] = self:GetFrameRef('wxbtn'); idxs[k] = %d; pfxs[k] = %q")
        :format(key, idx, prefix))
    return true
end

function Pager:Unregister(button, prefix)
    if not button or InCombatLockdown() then return false end
    local name = button.GetName and button:GetName()
    if not name then return false end

    local key = name .. "|" .. (prefix or "")
    if not self.registered[key] then return true end

    self.registered[key] = nil
    self:Execute(("local k = %q; refs[k] = nil; idxs[k] = nil; pfxs[k] = nil"):format(key))
    return true
end

-- Re-evaluates the page inside the secure environment (out of combat only).
function Pager:Refresh()
    if InCombatLockdown() then return false end
    self:Execute([[ self:RunAttribute("Refresh") ]])
    return true
end

function Pager:AddListener(callback)
    if type(callback) == "function" then
        self.listeners[#self.listeners + 1] = callback
    end
end

-- Called from the secure environment via CallMethod.
function Pager:OnActionPageChanged(page)
    for _, callback in ipairs(self.listeners) do
        pcall(callback, page)
    end
end

RegisterStateDriver(Pager, "wxpage", buildCondition())

-- Engine events that can move the page without the macro condition changing
-- (checked out of combat only; in combat the state driver alone is trusted).
local events = CreateFrame("Frame")
if WoWXMakeEventRegistrationSafe then WoWXMakeEventRegistrationSafe(events) end
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
events:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
events:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
events:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
    Pager:Refresh()
end)
if WoWXWrapOnEventSafe then WoWXWrapOnEventSafe(events) end
