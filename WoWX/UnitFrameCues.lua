if not GamePadX then return end

local GPX = GamePadX
local Cues = {}

GPX.UnitFrameCues = Cues

local watchedUnits = {
    { unit = "player", frameName = "PlayerFrame" },
    { unit = "party1", frameName = "PartyMemberFrame1" },
    { unit = "party2", frameName = "PartyMemberFrame2" },
    { unit = "party3", frameName = "PartyMemberFrame3" },
    { unit = "party4", frameName = "PartyMemberFrame4" },
}

local fallbackColor = { r = 1.0, g = 0.82, b = 0.2 }

function Cues:GetPlayerDispelTypes()
    if self.dispelTypes then
        return self.dispelTypes
    end

    local _, classTag = UnitClass("player")
    local entries = GPX.dispelClassSpells and GPX.dispelClassSpells[classTag] or {}
    local dispelTypes = {}

    for _, entry in ipairs(entries) do
        local spellName = GetSpellInfo(entry.spellID)
        if spellName then
            for debuffType in pairs(entry.types) do
                dispelTypes[debuffType] = true
            end
        end
    end

    self.dispelTypes = dispelTypes
    return dispelTypes
end

function Cues:GetDispellableAura(unit)
    local dispelTypes = self:GetPlayerDispelTypes()
    if not next(dispelTypes) then
        return nil
    end

    for index = 1, 40 do
        local name, rank, texture, count, debuffType = UnitDebuff(unit, index)
        if not name then
            break
        end

        if debuffType and dispelTypes[debuffType] then
            return {
                name = name,
                texture = texture,
                debuffType = debuffType,
            }
        end
    end

    return nil
end

function Cues:CreateIndicator(parentFrame)
    local indicator = CreateFrame("Frame", nil, parentFrame)
    indicator:SetFrameStrata(parentFrame:GetFrameStrata())
    indicator:SetFrameLevel(parentFrame:GetFrameLevel() + 6)
    indicator:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", -3, 3)
    indicator:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", 3, -3)
    indicator:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    indicator:SetBackdropBorderColor(fallbackColor.r, fallbackColor.g, fallbackColor.b, 0.95)
    indicator:Hide()

    local icon = indicator:CreateTexture(nil, "OVERLAY")
    icon:SetWidth(18)
    icon:SetHeight(18)
    icon:SetPoint("TOPRIGHT", indicator, "TOPRIGHT", -2, -2)

    local shine = indicator:CreateTexture(nil, "ARTWORK")
    shine:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    shine:SetBlendMode("ADD")
    shine:SetWidth(48)
    shine:SetHeight(48)
    shine:SetPoint("CENTER", indicator, "CENTER", 0, 0)
    shine:SetVertexColor(1.0, 0.88, 0.2, 0.6)

    indicator.icon = icon
    indicator.shine = shine
    return indicator
end

function Cues:GetIndicator(frameName)
    if not self.indicators then
        self.indicators = {}
    end

    local indicator = self.indicators[frameName]
    if indicator then
        return indicator
    end

    local parentFrame = _G[frameName]
    if not parentFrame then
        return nil
    end

    indicator = self:CreateIndicator(parentFrame)
    self.indicators[frameName] = indicator
    return indicator
end

function Cues:HideAll()
    if not self.indicators then
        return
    end

    for _, indicator in pairs(self.indicators) do
        indicator:Hide()
    end
end

function Cues:UpdateUnit(unit, frameName)
    local indicator = self:GetIndicator(frameName)
    if not indicator then
        return
    end

    if not GPX.db or not GPX.db.enabled or not UnitExists(unit) or UnitIsDeadOrGhost(unit) then
        indicator:Hide()
        return
    end

    local aura = self:GetDispellableAura(unit)
    if not aura then
        indicator:Hide()
        return
    end

    local color = DebuffTypeColor[aura.debuffType] or fallbackColor
    indicator:SetBackdropBorderColor(color.r or fallbackColor.r, color.g or fallbackColor.g, color.b or fallbackColor.b, 0.95)
    indicator.icon:SetTexture(aura.texture or "Interface\\Icons\\Spell_Holy_Renew")
    indicator:Show()
end

function Cues:UpdateAll()
    for _, entry in ipairs(watchedUnits) do
        self:UpdateUnit(entry.unit, entry.frameName)
    end
end

local eventFrame = CreateFrame("Frame", "GamePadXUnitFrameCueEvents")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "SPELLS_CHANGED" then
        Cues.dispelTypes = nil
    end

    if event == "UNIT_AURA" and unit then
        for _, entry in ipairs(watchedUnits) do
            if entry.unit == unit then
                Cues:UpdateUnit(entry.unit, entry.frameName)
                return
            end
        end
        return
    end

    Cues:UpdateAll()
end)