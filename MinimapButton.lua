if not GamePadX then return end

local GPX = GamePadX
local Button = {}
local dropdown = CreateFrame("Frame", "WoWXMinimapDropdown", UIParent, "UIDropDownMenuTemplate")

GPX.MinimapButton = Button

local radius = 78

local function ensureConfig()
    GPX.db.ui = GPX.db.ui or GPX:DeepCopy(GPX.defaults.ui)
    GPX.db.ui.minimapButton = GPX.db.ui.minimapButton or GPX:DeepCopy(GPX.defaults.ui.minimapButton)
    return GPX.db.ui.minimapButton
end

function Button:UpdatePosition()
    if not self.button then
        return
    end

    local config = ensureConfig()
    local angle = math.rad(config.angle or 210)
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius

    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function Button:Create()
    if self.button then
        return
    end

    local button = CreateFrame("Button", "WoWXMinimapButton", Minimap)
    button:SetWidth(31)
    button:SetHeight(31)
    button:SetFrameStrata("MEDIUM")
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetWidth(53)
    overlay:SetHeight(53)
    overlay:SetPoint("TOPLEFT")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\Ability_Rogue_Sprint")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetPoint("CENTER")

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    highlight:SetWidth(31)
    highlight:SetHeight(31)
    highlight:SetPoint("TOPLEFT", 0, 0)

    button.icon = icon

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(GPX.brand, 1.0, 0.96, 0.7)
        GameTooltip:AddLine("Left-click: open control center", 0.85, 0.9, 1.0)
        GameTooltip:AddLine("Right-click: quick menu", 0.85, 0.9, 1.0)
        GameTooltip:AddLine("Drag: move around the minimap", 0.75, 0.82, 0.9)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            GPX.MinimapButton:ShowMenu()
        else
            GPX:OpenSettings()
        end
    end)

    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            x = x / scale
            y = y / scale
            local centerX, centerY = Minimap:GetCenter()
            local angle = math.deg(math.atan2(y - centerY, x - centerX))
            ensureConfig().angle = angle
            GPX.MinimapButton:UpdatePosition()
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    self.button = button
    self:UpdatePosition()
end

function Button:ShowMenu()
    local bar = GPX.VisualBar
    local layoutLabel = "Layout Edit"
    if bar and bar.IsLocked and bar:IsLocked() then
        layoutLabel = "Layout Edit: Off (Enable)"
    else
        layoutLabel = "Layout Edit: On (Disable)"
    end
    local menu = {
        { text = GPX.brand, isTitle = true, notCheckable = true },
        { text = "Open Config", notCheckable = true, func = function() GPX:OpenSettings() end },
        { text = "Run Setup Wizard", notCheckable = true, func = function() GPX:OpenSetupWizard("init") end },
        { text = layoutLabel, notCheckable = true, func = function() if bar then bar:Slash((bar:IsLocked() and "unlock") or "lock") end end },
        { text = "Lock/Unlock XP Bar", notCheckable = true, func = function() if bar then bar:Slash("progresslock") end end },
        { text = "Toggle XP/Rep Bar", notCheckable = true, func = function() if bar then bar:Slash("progress") end end },
        { text = "Toggle Bag Bar", notCheckable = true, func = function() if bar then bar:Slash("bagbar") end end },
        { text = "Layout Edit uses Drag + corner grip", notCheckable = true, disabled = true },
    }
    EasyMenu(menu, dropdown, "cursor", 0, 0, "MENU")
end

function Button:Refresh()
    self:Create()
    local config = ensureConfig()
    if config.enabled == false then
        self.button:Hide()
    else
        self.button:Show()
        self:UpdatePosition()
    end
end

function Button:Toggle()
    local config = ensureConfig()
    config.enabled = not config.enabled
    self:Refresh()
    GPX:Print(config.enabled and "Minimap button shown." or "Minimap button hidden.")
end

local eventFrame = CreateFrame("Frame", "WoWXMinimapButtonEvents")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function()
    if GPX.MinimapButton then
        GPX.MinimapButton:Refresh()
    end
end)