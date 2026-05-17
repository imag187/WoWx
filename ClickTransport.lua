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
-- WotLK 3.3.5a canonical command slots:
-- MULTIACTIONBAR1 = BottomLeft  (slots 61-72)
-- MULTIACTIONBAR2 = BottomRight (slots 49-60)
-- MULTIACTIONBAR3 = Right       (slots 25-36)
-- MULTIACTIONBAR4 = Left        (slots 37-48)
-- ---------------------------------------------------------------------------
local multibarStaticOffset = {
    ["MULTIACTIONBAR1BUTTON"] = 60,
    ["MULTIACTIONBAR2BUTTON"] = 48,
    ["MULTIACTIONBAR3BUTTON"] = 24,
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

-- Returns the bonusbar-conditional macro text for ACTIONBUTTON commands so
-- Runeshroud / bonus-bar page swaps execute the correct slot without needing
-- combat-time attribute rewrites.
-- Returns nil for all multibar commands (those use direct slot action).
function CT:ConditionalMacroForCommand(command)
    if not command then return nil end
    local actionIndex = tonumber(command:match("^ACTIONBUTTON(%d+)$"))
    if actionIndex then
        return "/click [bonusbar:5] BonusActionButton" .. actionIndex
            .. "; [bonusbar:4] BonusActionButton" .. actionIndex
            .. "; [bonusbar:3] BonusActionButton" .. actionIndex
            .. "; [bonusbar:2] BonusActionButton" .. actionIndex
            .. "; [bonusbar:1] BonusActionButton" .. actionIndex
            .. "; ActionButton" .. actionIndex
    end
    -- Multibar buttons must NOT route through native Blizzard bar frames;
    -- UpdateBlizzardBars() reparents those to a hidden frame so "/click" silently
    -- fails. Direct action slot execution is used instead.
    return nil
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
    local proxyMacro = self:ConditionalMacroForCommand(command)
    local slot = resolvedSlot or self:StaticSlotForCommand(command)

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

    if proxyMacro then
        button:SetAttribute(p .. "type",       "macro")
        button:SetAttribute(p .. "macrotext",  proxyMacro)
        button:SetAttribute(p .. "type1",      "macro")
        button:SetAttribute(p .. "macrotext1", proxyMacro)
    elseif slot then
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
-- Proxy button registry
-- One hidden SecureActionButtonTemplate per unique command string.
-- GamePadX binds keys to these frames; they are never visible.
-- ---------------------------------------------------------------------------
CT.proxyButtons = {}

function CT:EnsureProxyButton(command)
    if not command or self.proxyButtons[command] then return end
    local name = self:ProxyButtonName(command)
    if not name then return end
    local button = CreateFrame("CheckButton", name, hiddenParent, "SecureActionButtonTemplate")
    button:RegisterForClicks("LeftButtonUp")
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
