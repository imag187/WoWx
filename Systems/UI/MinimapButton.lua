if not GamePadX then return end

local GPX = GamePadX
local Button = {}

GPX.MinimapButton = Button

local radius = 78

local function atan2(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    end
    if x > 0 then
        return math.atan(y / x)
    elseif x < 0 then
        return math.atan(y / x) + ((y >= 0) and math.pi or -math.pi)
    end
    return (y >= 0) and (math.pi / 2) or (-math.pi / 2)
end

local function safeCall(source, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        if WoWXLogRuntimeError then
            WoWXLogRuntimeError("MinimapButton", source, err)
        end
        GPX:Print("Minimap button error (" .. source .. "): " .. tostring(err))
    end
    return ok
end

local function ensureConfig()
    GPX.db.ui = GPX.db.ui or GPX:DeepCopy(GPX.defaults.ui)
    GPX.db.ui.minimapButton = GPX.db.ui.minimapButton or GPX:DeepCopy(GPX.defaults.ui.minimapButton)
    return GPX.db.ui.minimapButton
end

function Button:UpdateIconState()
    if not self.button or not self.button.icon then
        return
    end

    local wowxEnabled = GPX.db and GPX.db.enabled
    local controllerEnabled = GPX.IsControllerEnabled and GPX:IsControllerEnabled()

    if not wowxEnabled then
        self.button.icon:SetTexture("Interface\\Icons\\Ability_Rogue_Sprint")
        self.button.icon:SetVertexColor(0.55, 0.55, 0.55, 0.95)
        return
    end

    if controllerEnabled then
        self.button.icon:SetTexture("Interface\\Icons\\Spell_Nature_Lightning")
        self.button.icon:SetVertexColor(0.72, 0.9, 1.0, 1.0)
    else
        self.button.icon:SetTexture("Interface\\Icons\\Ability_Rogue_Sprint")
        self.button.icon:SetVertexColor(1.0, 0.9, 0.52, 1.0)
    end
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
    button:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
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
        GPX.MinimapButton:ShowTooltip(self, "ANCHOR_LEFT")
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            safeCall("menu", function() GPX.MinimapButton:ShowMenu() end)
        elseif IsShiftKeyDown() then
            safeCall("layout edit", function() GPX.MinimapButton:ToggleLayoutEdit() end)
        elseif IsControlKeyDown() then
            safeCall("button edit", function() GPX.MinimapButton:ToggleButtonEdit() end)
        else
            safeCall("settings", function()
                if GPX.ToggleSettings then
                    GPX:ToggleSettings()
                else
                    GPX:OpenSettings()
                end
            end)
        end
        if GameTooltip:IsOwned(self) then
            GPX.MinimapButton:ShowTooltip(self, "ANCHOR_LEFT")
        end
    end)

    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            x = x / scale
            y = y / scale
            local centerX, centerY = Minimap:GetCenter()
            local angle = math.deg(atan2(y - centerY, x - centerX))
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

function Button:ToggleLayoutEdit()
    local bar = GPX.VisualBar
    if bar then
        bar:Slash((bar:IsLocked() and "unlock") or "lock")
    end
end

function Button:ToggleButtonEdit()
    local bar = GPX.VisualBar
    if bar then
        bar:Slash((bar:IsButtonLockEnabled() and "buttonunlock") or "buttonlock")
    end
end

function Button:ShowTooltip(owner, anchor)
    local bar = GPX.VisualBar
    local tip = GameTooltip
    local function onOff(value)
        return value and "|cff66ff66On|r" or "|cffaaaaaaOff|r"
    end

    tip:SetOwner(owner, anchor or "ANCHOR_LEFT")
    tip:ClearLines()

    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local version = getMeta and getMeta("WoWx", "Version") or nil
    tip:AddLine((GPX.brand or "WoWX") .. (version and ("  |cff9999aav" .. version .. "|r") or ""), 1.0, 0.96, 0.7)

    local wowxEnabled = GPX.db and GPX.db.enabled
    if not wowxEnabled then
        tip:AddLine("Disabled on this character", 1.0, 0.45, 0.35)
        tip:AddLine("/wowx enable, then /reload", 0.75, 0.82, 0.9)
    else
        local controllerEnabled = GPX.IsControllerEnabled and GPX:IsControllerEnabled()
        tip:AddDoubleLine("Input mode", controllerEnabled and "Controller" or "Keyboard", 0.8, 0.85, 0.95, 1, 1, 1)
        if bar then
            local state = bar.GetCurrentState and bar:GetCurrentState() or ""
            tip:AddDoubleLine("Modifier row", (state and state ~= "") and state or "base", 0.8, 0.85, 0.95, 1, 1, 1)
            if GPX.Pager and GPX.Pager.GetCurrentPage then
                local ok, page = pcall(GPX.Pager.GetCurrentPage, GPX.Pager)
                if ok and page then
                    tip:AddDoubleLine("Base page", tostring(page), 0.8, 0.85, 0.95, 1, 1, 1)
                end
            end
            tip:AddDoubleLine("Layout Edit", onOff(not bar:IsLocked()), 0.8, 0.85, 0.95)
            tip:AddDoubleLine("Button Lock", onOff(bar:IsButtonLockEnabled()), 0.8, 0.85, 0.95)
        end
    end

    tip:AddLine(" ")
    tip:AddDoubleLine("Left-click", "Control center", 1, 0.82, 0.2, 0.9, 0.9, 0.9)
    tip:AddDoubleLine("Right-click", "Quick menu", 1, 0.82, 0.2, 0.9, 0.9, 0.9)
    tip:AddDoubleLine("Shift-click", "Toggle Layout Edit (move/size bar)", 1, 0.82, 0.2, 0.9, 0.9, 0.9)
    tip:AddDoubleLine("Ctrl-click", "Toggle Button Lock (place spells)", 1, 0.82, 0.2, 0.9, 0.9, 0.9)
    tip:AddDoubleLine("Drag", "Move this icon", 1, 0.82, 0.2, 0.9, 0.9, 0.9)
    tip:Show()
end

function Button:RegisterCompartment()
    if self.compartmentRegistered or not _G.AddonCompartmentFrame or not AddonCompartmentFrame.RegisterAddon then
        return
    end
    self.compartmentRegistered = true
    AddonCompartmentFrame:RegisterAddon({
        text = "WoWX",
        icon = "Interface\\AddOns\\WoWx\\Textures\\Icon.tga",
        notCheckable = true,
        registerForAnyClick = true,
        func = function(_, menuInputData)
            local mouseButton = menuInputData and menuInputData.buttonName
            safeCall("compartment", function()
                if mouseButton == "RightButton" then
                    GPX.MinimapButton:ShowMenu(AddonCompartmentFrame)
                else
                    GPX:ToggleSettings()
                end
            end)
        end,
        funcOnEnter = function(owner)
            GPX.MinimapButton:ShowTooltip(owner, "ANCHOR_LEFT")
        end,
        funcOnLeave = function()
            GameTooltip:Hide()
        end,
    })
end

function Button:ShowMenu(ownerOverride)
    local bar = GPX.VisualBar
    local settingsOpen = GPX.SettingsUI and GPX.SettingsUI.frame and GPX.SettingsUI.frame:IsShown()
    local layoutLabel = "Layout Edit"
    local buttonEditLabel = "Button Edit"
    local configLabel = settingsOpen and "Close Config" or "Open Config"
    if bar and bar.IsLocked and bar:IsLocked() then
        layoutLabel = "Layout Edit: Off (Enable)"
    else
        layoutLabel = "Layout Edit: On (Disable)"
    end
    if bar and bar.IsButtonLockEnabled and bar:IsButtonLockEnabled() then
        buttonEditLabel = "Button Lock: On (Unlock)"
    else
        buttonEditLabel = "Button Lock: Off (Lock)"
    end
    local entries = {
        { text = configLabel, func = function() if GPX.ToggleSettings then GPX:ToggleSettings() else GPX:OpenSettings() end end },
        { text = "Run Setup Wizard", func = function() GPX:OpenSetupWizard("init") end },
        { text = layoutLabel, func = function() if bar then bar:Slash((bar:IsLocked() and "unlock") or "lock") end end },
        { text = buttonEditLabel, func = function() if bar then bar:Slash((bar:IsButtonLockEnabled() and "buttonunlock") or "buttonlock") end end },
    }

    local owner = ownerOverride or self.button
    if _G.MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner, function(_, root)
            root:CreateTitle(GPX.brand)
            for _, entry in ipairs(entries) do
                root:CreateButton(entry.text, function() safeCall("menu action", entry.func) end)
            end
        end)
        return
    end

    if _G.EasyMenu then
        local dropdown = _G.WoWXMinimapDropdown or CreateFrame("Frame", "WoWXMinimapDropdown", UIParent, "UIDropDownMenuTemplate")
        local menu = { { text = GPX.brand, isTitle = true, notCheckable = true } }
        for _, entry in ipairs(entries) do
            menu[#menu + 1] = { text = entry.text, notCheckable = true, func = function() safeCall("menu action", entry.func) end }
        end
        EasyMenu(menu, dropdown, "cursor", 0, 0, "MENU")
        return
    end

    GPX:Print("No menu API available. Use /wowx unlock, /wowx lock, /wowx buttonunlock, /wowx buttonlock.")
end

function Button:Refresh()
    self:Create()
    self:RegisterCompartment()
    local config = ensureConfig()
    if config.enabled == false then
        self.button:Hide()
    else
        self.button:Show()
        self:UpdatePosition()
        self:UpdateIconState()
    end
end

function Button:Toggle()
    local config = ensureConfig()
    config.enabled = not config.enabled
    self:Refresh()
    GPX:Print(config.enabled and "Minimap button shown." or "Minimap button hidden.")
end

local eventFrame = CreateFrame("Frame", "WoWXMinimapButtonEvents")
WoWXMakeEventRegistrationSafe(eventFrame)
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function()
    if GPX.MinimapButton then
        GPX.MinimapButton:Refresh()
    end
end)
WoWXWrapOnEventSafe(eventFrame)
