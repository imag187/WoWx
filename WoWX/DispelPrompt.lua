if not GamePadX then return end

local GPX = GamePadX
local Prompt = {}

GPX.DispelPrompt = Prompt

local classSpells = {
    PALADIN = {
        { spellID = 4987, types = { Magic = true, Disease = true, Poison = true } },
    },
    PRIEST = {
        { spellID = 527, types = { Magic = true } },
        { spellID = 528, types = { Disease = true } },
        { spellID = 552, types = { Disease = true } },
    },
    DRUID = {
        { spellID = 2782, types = { Curse = true } },
        { spellID = 2893, types = { Poison = true } },
    },
    MAGE = {
        { spellID = 475, types = { Curse = true } },
    },
    SHAMAN = {
        { spellID = 51886, types = { Curse = true } },
    },
}

GPX.dispelClassSpells = classSpells

local unitOrder = {
    "mouseover",
    "target",
    "focus",
    "player",
    "party1",
    "party2",
    "party3",
    "party4",
}

Prompt.currentButton = nil

function Prompt:CreateFrame()
    if self.frame then return end

    local frame = CreateFrame("Frame", "GamePadXDispelPromptFrame", UIParent)
    frame:SetWidth(180)
    frame:SetHeight(42)
    frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 160)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    frame:SetBackdropBorderColor(0.95, 0.82, 0.18, 0.95)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(28)
    icon:SetHeight(28)
    icon:SetPoint("LEFT", frame, "LEFT", 8, 0)

    local keyText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    keyText:SetPoint("LEFT", icon, "RIGHT", 8, 8)
    keyText:SetJustifyH("LEFT")
    keyText:SetTextColor(1.0, 0.95, 0.5)

    local infoText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    infoText:SetPoint("TOPLEFT", keyText, "BOTTOMLEFT", 0, -2)
    infoText:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
    infoText:SetJustifyH("LEFT")

    frame.icon = icon
    frame.keyText = keyText
    frame.infoText = infoText
    frame:Hide()

    self.frame = frame
end

function Prompt:GetPlayerDispelSpells()
    if self.spells then
        return self.spells
    end

    local _, classTag = UnitClass("player")
    local entries = classSpells[classTag] or {}
    local spells = {}

    for _, entry in ipairs(entries) do
        local name, rank, icon = GetSpellInfo(entry.spellID)
        if name then
            spells[#spells + 1] = {
                spellID = entry.spellID,
                name = name,
                icon = icon,
                types = entry.types,
            }
        end
    end

    self.spells = spells
    return spells
end

function Prompt:GetProfileBindings()
    local profile = GPX:GetProfile()
    return profile and profile.bindings or nil
end

function Prompt:GetActionInfoForSlot(slot)
    if not slot then return nil end

    local actionType, actionID = GetActionInfo(slot)
    if actionType == "spell" then
        local spellName, rank, icon = GetSpellInfo(actionID)
        if spellName then
            return { kind = "spell", name = spellName, icon = icon }
        end
    elseif actionType == "macro" then
        local macroName, macroIcon, macroBody = GetMacroInfo(actionID)
        return {
            kind = "macro",
            name = macroName,
            icon = macroIcon,
            body = macroBody or "",
        }
    end

    return nil
end

function Prompt:GetCommandButtonCandidates(command)
    local index = tonumber(command and command:match("(%d+)$"))
    if not index then return nil end

    if command:find("^ACTIONBUTTON") then
        return { "ActionButton" .. index }
    end

    if command:find("^MULTIACTIONBAR1BUTTON") then
        return { "MultiBarBottomRightButton" .. index, "MultiBarBottomLeftButton" .. index }
    end

    if command:find("^MULTIACTIONBAR2BUTTON") then
        return { "MultiBarBottomLeftButton" .. index, "MultiBarBottomRightButton" .. index }
    end

    if command:find("^MULTIACTIONBAR3BUTTON") then
        return { "MultiBarRightButton" .. index, "MultiBarLeftButton" .. index }
    end

    if command:find("^MULTIACTIONBAR4BUTTON") then
        return { "MultiBarLeftButton" .. index, "MultiBarRightButton" .. index }
    end

    return nil
end

function Prompt:ResolveCommand(command)
    local candidates = self:GetCommandButtonCandidates(command)
    if not candidates then return nil end

    for _, buttonName in ipairs(candidates) do
        local button = _G[buttonName]
        if button and button.action then
            return button.action, button
        end
    end

    return nil
end

function Prompt:FindBindingForSpellType(dispelType)
    local bindings = self:GetProfileBindings()
    if not bindings then return nil end

    local spells = self:GetPlayerDispelSpells()
    if #spells == 0 then return nil end

    for _, spell in ipairs(spells) do
        if spell.types[dispelType] then
            for key, command in pairs(bindings) do
                local slot, button = self:ResolveCommand(command)
                local action = self:GetActionInfoForSlot(slot)
                if action then
                    if action.kind == "spell" and action.name == spell.name then
                        return {
                            key = key,
                            command = command,
                            slot = slot,
                            button = button,
                            spell = spell,
                            icon = action.icon or spell.icon,
                        }
                    end

                    if action.kind == "macro" and action.body ~= "" then
                        local macroBody = string.lower(action.body)
                        local spellName = string.lower(spell.name)
                        if string.find(macroBody, spellName, 1, true) then
                            return {
                                key = key,
                                command = command,
                                slot = slot,
                                button = button,
                                spell = spell,
                                icon = action.icon or spell.icon,
                            }
                        end
                    end
                end
            end
        end
    end

    return nil
end

function Prompt:FindUnitNeedingDispel()
    for _, unit in ipairs(unitOrder) do
        if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and (unit == "player" or UnitCanAssist("player", unit)) then
            for index = 1, 40 do
                local name, rank, texture, count, debuffType = UnitDebuff(unit, index)
                if not name then break end

                if debuffType and debuffType ~= "" then
                    local binding = self:FindBindingForSpellType(debuffType)
                    if binding then
                        return {
                            unit = unit,
                            unitName = UnitName(unit) or unit,
                            debuffName = name,
                            debuffType = debuffType,
                            texture = texture,
                            binding = binding,
                        }
                    end
                end
            end
        end
    end

    return nil
end

function Prompt:GetVisibleButtonForSlot(slot)
    if not slot then return nil end

    local candidates = {
        "ActionButton",
        "MultiBarBottomLeftButton",
        "MultiBarBottomRightButton",
        "MultiBarRightButton",
        "MultiBarLeftButton",
    }

    for _, prefix in ipairs(candidates) do
        for index = 1, 12 do
            local button = _G[prefix .. index]
            if button and button.action == slot and button:IsShown() then
                return button
            end
        end
    end

    return nil
end

function Prompt:EnsureGlow(button)
    if button.GPXDispelGlow then return button.GPXDispelGlow end

    local glow = button:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetWidth(70)
    glow:SetHeight(70)
    glow:SetPoint("CENTER", button, "CENTER", 0, 0)
    glow:SetVertexColor(1.0, 0.88, 0.2, 0.95)
    glow:Hide()

    button.GPXDispelGlow = glow
    return glow
end

function Prompt:ClearHighlight()
    if self.currentButton and self.currentButton.GPXDispelGlow then
        self.currentButton.GPXDispelGlow:Hide()
    end
    self.currentButton = nil
end

function Prompt:ShowPrompt(state)
    self:CreateFrame()

    local frame = self.frame
    local icon = state.binding.icon or state.texture or "Interface\\Icons\\Spell_Holy_Renew"
    frame.icon:SetTexture(icon)
    frame.keyText:SetText(state.binding.key)
    frame.infoText:SetText(string.format("%s on %s", state.debuffType, state.unitName))
    frame:Show()

    self:ClearHighlight()
    local button = self:GetVisibleButtonForSlot(state.binding.slot)
    if button then
        self:EnsureGlow(button):Show()
        self.currentButton = button
    end
end

function Prompt:HidePrompt()
    if self.frame then
        self.frame:Hide()
    end
    self:ClearHighlight()
end

function Prompt:Update()
    if not GPX.db or not GPX.db.enabled then
        self:HidePrompt()
        return
    end

    local state = self:FindUnitNeedingDispel()
    if state then
        self:ShowPrompt(state)
    else
        self:HidePrompt()
    end
end

local eventFrame = CreateFrame("Frame", "GamePadXDispelPromptEvents")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
eventFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("UPDATE_BINDINGS")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "UNIT_AURA" and unit then
        local watched = {
            player = true,
            target = true,
            focus = true,
            mouseover = true,
            party1 = true,
            party2 = true,
            party3 = true,
            party4 = true,
        }
        if not watched[unit] then
            return
        end
    end

    if event == "SPELLS_CHANGED" then
        Prompt.spells = nil
    end

    Prompt:Update()
end)