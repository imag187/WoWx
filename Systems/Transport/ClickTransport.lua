-- ClickTransport.lua
-- Owns ALL secure action button attribute management for WoWX click transport.
--
-- RULE: This file must never be edited for visual or layout reasons.
--       Visual code calls into this module; this module never calls visual code.
--
-- Load order: before VisualBar.lua and before GamePadX.lua resolves bindings.
-- GPX.ClickTransport is the single source of truth for proxy button creation,
-- slot resolution fallbacks, and secure attribute writes.

if not GamePadX then return end

local GPX = GamePadX
local CT = {}
GPX.ClickTransport = CT

-- ---------------------------------------------------------------------------
-- Static slot map: compile-time fallbacks when native bar button .action is nil.
-- WoWX maps modifier rows onto Blizzard main action bar pages so the same
-- placed slots remain valid across WoWX and non-WoWX sessions:
-- SHIFT     -> page 2 (slots 13-24)
-- ALT       -> page 3 (slots 25-36)
-- CTRL      -> page 4 (slots 37-48)
-- SHIFT-ALT -> page 5 (slots 49-60)
-- ---------------------------------------------------------------------------
local multibarStaticOffset = {
    ["MULTIACTIONBAR1BUTTON"] = 24,
    ["MULTIACTIONBAR2BUTTON"] = 12,
    ["MULTIACTIONBAR3BUTTON"] = 48,
    ["MULTIACTIONBAR4BUTTON"] = 36,
}

local gridRows = {
    [""] = { title = "Base", commandPrefix = "ACTIONBUTTON" },
    ["SHIFT"] = { title = "Modifier 1", commandPrefix = "MULTIACTIONBAR2BUTTON" },
    ["ALT"] = { title = "Modifier 2", commandPrefix = "MULTIACTIONBAR1BUTTON" },
    ["CTRL"] = { title = "Modifier 3", commandPrefix = "MULTIACTIONBAR4BUTTON" },
    ["SHIFT-ALT"] = { title = "Combo", commandPrefix = "MULTIACTIONBAR3BUTTON" },
}

-- Hidden parent for all proxy secure buttons.
-- Must exist before any proxy button is created.
local hiddenParent = CreateFrame("Frame", "WoWXCTHiddenParent", UIParent)
hiddenParent:Hide()

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

function CT:StaticSlotForCommand(command)
    local index = tonumber(command and command:match("(%d+)$"))
    if not index then return nil end
    for prefix, offset in pairs(multibarStaticOffset) do
        if command:find("^" .. prefix) then
            return offset + index
        end
    end
    return nil
end

function CT:GetGridRow(state)
    return gridRows[state or ""]
end

function CT:CommandForCell(state, columnIndex, useModifierPages)
    local index = tonumber(columnIndex)
    if not index then return nil end
    if state == "" or not useModifierPages then
        return "ACTIONBUTTON" .. index
    end

    local row = self:GetGridRow(state)
    if row and row.commandPrefix then
        return row.commandPrefix .. index
    end
    return nil
end

function CT:CellFor(state, columnIndex, useModifierPages)
    local command = self:CommandForCell(state, columnIndex, useModifierPages)
    if not command then return nil end

    return {
        state = state or "",
        column = tonumber(columnIndex),
        command = command,
        staticSlot = self:StaticSlotForCommand(command),
        proxyName = self:ProxyButtonName(command),
    }
end

-- Returns the base-row index (1..12) when `command` is an ACTIONBUTTONn command.
-- Only those commands page with the engine's action bar state; the modifier
-- rows are fixed slot ranges (see multibarStaticOffset).
function CT:PagedIndexForCommand(command)
    return tonumber(command and command:match("^ACTIONBUTTON(%d+)$"))
end

function CT:IsNativeUtilitySlot(slot)
    local actionSlot = tonumber(slot)
    if not actionSlot or actionSlot < 1 then
        return false
    end
    if not (GPX and GPX.SpellbookUI and GPX.SpellbookUI.IsNativeUtilityMacroAtSlot) then
        return false
    end
    return GPX.SpellbookUI:IsNativeUtilityMacroAtSlot(actionSlot) == true
end

function CT:GetNativeUtilityCommandAtSlot(slot)
    local actionSlot = tonumber(slot)
    if not actionSlot or actionSlot < 1 then
        return nil
    end
    if not (GetActionInfo and GetMacroInfo) then
        return nil
    end
    if not (GPX and GPX.SpellbookUI and GPX.SpellbookUI.GetNativeBindingCommandForUtilityMacro) then
        return nil
    end

    local actionType, actionID = GetActionInfo(actionSlot)
    if actionType ~= "macro" or not actionID then
        return nil
    end

    local macroName = GetMacroInfo(actionID)
    if not macroName or macroName == "" then
        return nil
    end

    return GPX.SpellbookUI:GetNativeBindingCommandForUtilityMacro(macroName)
end

-- The canonical secure frame name for a command's proxy button.
function CT:ProxyButtonName(command)
    return command and ("WoWXBindButton_" .. command) or nil
end

-- ---------------------------------------------------------------------------
-- Core attribute writer
-- Writes secure attributes for ONE modifier prefix on a button.
-- Sets BOTH unnumbered (type/action) AND numbered (type1/action1) because
-- WoW 3.3.5a's C secure handler reads the unnumbered form for modifier+click
-- dispatch, while some code paths expect the numbered form.
-- ---------------------------------------------------------------------------
function CT:WriteAttribute(button, prefix, command, resolvedSlot)
    if not button then return end
    local p = prefix and (prefix .. "-") or ""
    local pagedIndex = self:PagedIndexForCommand(command)
    local pager = GPX.Pager
    local slot
    if pagedIndex then
        slot = (pager and pager:GetSlot(pagedIndex)) or resolvedSlot or pagedIndex
    else
        slot = resolvedSlot or self:StaticSlotForCommand(command)
    end

    -- Pager ownership: base-row buttons follow the engine page inside the secure
    -- environment (works in combat); everything else is static.
    if pager then
        if pagedIndex then
            pager:Register(button, p, pagedIndex)
        else
            pager:Unregister(button, p)
        end
    end

    -- Clear all variants so no stale state can bleed through.
    button:SetAttribute(p .. "type",        nil)
    button:SetAttribute(p .. "action",      nil)
    button:SetAttribute(p .. "type1",       nil)
    button:SetAttribute(p .. "action1",     nil)
    button:SetAttribute(p .. "macrotext",   nil)
    button:SetAttribute(p .. "macrotext1",  nil)
    button:SetAttribute(p .. "clickbutton", nil)
    button:SetAttribute(p .. "unit",        nil)
    button:SetAttribute(p .. "checkselfcast", nil)
    button:SetAttribute(p .. "checkfocuscast", nil)

    -- Native utility placeholders (Jump/Menu/Map/etc) are icon-only guide slots.
    -- Runtime execution is handled by dedicated native bindings.
    local nativeUtilityCommand = slot and self:GetNativeUtilityCommandAtSlot(slot) or nil
    if slot and nativeUtilityCommand and nativeUtilityCommand ~= "" then
        return
    end

    if slot then
        button:SetAttribute(p .. "type",    "action")
        button:SetAttribute(p .. "action",  slot)
        button:SetAttribute(p .. "type1",   "action")
        button:SetAttribute(p .. "action1", slot)
    end
end

-- ---------------------------------------------------------------------------
-- Bulk modifier attribute writer for main WoWXActionButton slots.
-- slotMap / commandMap are tables with keys: base, shift, alt, ctrl, combo.
-- Call this instead of six separate WriteAttribute calls so visual code never
-- needs to know the attribute names.
-- ---------------------------------------------------------------------------
function CT:ApplyButtonModifiers(button, slotMap, commandMap)
    if not button or InCombatLockdown() then return end

    self:WriteAttribute(button, nil,         commandMap.base,  slotMap.base)
    self:WriteAttribute(button, "shift",     commandMap.shift, slotMap.shift)
    self:WriteAttribute(button, "alt",       commandMap.alt,   slotMap.alt)
    self:WriteAttribute(button, "ctrl",      commandMap.ctrl,  slotMap.ctrl)
    self:WriteAttribute(button, "shift-alt", commandMap.combo, slotMap.combo)
    self:WriteAttribute(button, "alt-shift", commandMap.combo, slotMap.combo)

    -- Wipe all right-click (type2) slots; WoWX never uses them for action execution.
    local type2prefixes = { "", "shift-", "alt-", "ctrl-", "shift-alt-", "alt-shift-" }
    for _, pfx in ipairs(type2prefixes) do
        button:SetAttribute(pfx .. "type2",      nil)
        button:SetAttribute(pfx .. "action2",    nil)
        button:SetAttribute(pfx .. "macrotext2", nil)
    end
end

-- ---------------------------------------------------------------------------
-- Click registration (modern-engine secure templates)
-- Key bindings (SetBindingClick) deliver a DOWN click on key press and an UP click
-- on release. Secure action buttons only act on one of them, chosen by the
-- `useOnKeyDown` attribute (Blizzard bars: cvar ActionButtonUseKeyDown). A button
-- registered for LeftButtonUp only never sees the down click, so with useOnKeyDown
-- defaulting to true nothing fired. Same pattern as Blizzard / LibActionButton.
-- ---------------------------------------------------------------------------
CT.clickButtons = setmetatable({}, { __mode = "k" })

function CT:UseKeyDown()
    return (GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")) and true or false
end

function CT:ConfigureClicks(button)
    if not button then return end
    button:RegisterForClicks("AnyUp", "AnyDown")
    self.clickButtons[button] = true
    if not InCombatLockdown() then
        button:SetAttribute("useOnKeyDown", self:UseKeyDown())
    else
        self.pendingClickSync = true
    end
end

function CT:SyncClickMode()
    if InCombatLockdown() then
        self.pendingClickSync = true
        return
    end
    self.pendingClickSync = nil
    local value = self:UseKeyDown()
    for button in pairs(self.clickButtons) do
        button:SetAttribute("useOnKeyDown", value)
    end
end

local clickSyncFrame = CreateFrame("Frame")
clickSyncFrame:RegisterEvent("CVAR_UPDATE")
clickSyncFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
clickSyncFrame:SetScript("OnEvent", function(_, event, name)
    if event == "CVAR_UPDATE" then
        if name == "ActionButtonUseKeyDown" then
            CT:SyncClickMode()
        end
    elseif CT.pendingClickSync then
        CT:SyncClickMode()
    end
end)

-- ---------------------------------------------------------------------------
-- Proxy button registry
-- One hidden SecureActionButtonTemplate per unique command string.
-- GamePadX binds keys to these frames; they are never visible.
-- ---------------------------------------------------------------------------
CT.proxyButtons = {}

function CT:GetProxyButtonCount()
    local count = 0
    for _ in pairs(self.proxyButtons) do
        count = count + 1
    end
    return count
end

function CT:EnsureProxyButton(command)
    if not command or self.proxyButtons[command] then return end
    local name = self:ProxyButtonName(command)
    if not name then return end
    local button = CreateFrame("CheckButton", name, hiddenParent, "SecureActionButtonTemplate")
    self:ConfigureClicks(button)
    button:Hide()
    button:SetAttribute("unit", nil)
    button:SetAttribute("checkselfcast", nil)
    button:SetAttribute("checkfocuscast", nil)
    -- Initialize with static slot so the button is never in an unset state
    -- before UpdateAllProxyButtons runs out of combat.
    self:WriteAttribute(button, nil, command, nil)
    button:SetAttribute("type2",   nil)
    button:SetAttribute("action2", nil)
    self.proxyButtons[command] = button
end

-- Update a single proxy button with a live-resolved slot.
function CT:UpdateProxyButton(command, resolvedSlot)
    local button = self.proxyButtons[command]
    if not button or InCombatLockdown() then return end
    self:WriteAttribute(button, nil, command, resolvedSlot)
    button:SetAttribute("type2",   nil)
    button:SetAttribute("action2", nil)
end

-- Bulk update all proxy buttons.
-- resolveFunc(command) -> slot number or nil
function CT:UpdateAllProxyButtons(resolveFunc)
    if InCombatLockdown() then return end
    for command, _ in pairs(self.proxyButtons) do
        local slot = resolveFunc and resolveFunc(command) or nil
        self:UpdateProxyButton(command, slot)
    end
end

-- ---------------------------------------------------------------------------
-- Bag item transport helpers
-- Applies a secure right-click /use macro for a specific bag/slot.
-- Left-click behavior remains owned by ContainerFrameItemButtonTemplate.
-- ---------------------------------------------------------------------------

function CT:BuildBagItemUseMacro(bagID, slot)
    local bag = tonumber(bagID)
    local idx = tonumber(slot)
    if not bag or not idx then
        return nil
    end
    return "/use " .. tostring(bag) .. " " .. tostring(idx)
end

function CT:ApplyBagItemUse(button, bagID, slot)
    if not button or InCombatLockdown() then
        return
    end

    local macro = self:BuildBagItemUseMacro(bagID, slot)
    local prefixes = { "", "shift-", "alt-", "ctrl-", "shift-alt-", "alt-shift-" }

    for _, pfx in ipairs(prefixes) do
        button:SetAttribute(pfx .. "type2", nil)
        button:SetAttribute(pfx .. "macrotext2", nil)
    end

    if not macro then
        return
    end

    for _, pfx in ipairs(prefixes) do
        button:SetAttribute(pfx .. "type2", "macro")
        button:SetAttribute(pfx .. "macrotext2", macro)
    end
end
