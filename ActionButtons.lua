if not GamePadX then return end

local GPX = GamePadX
local Buttons = {}

GPX.ActionButtons = Buttons

local defaultConfig = {
    enabled = true,
    showBags = true,
    point = { anchor = "BOTTOMRIGHT", relativeTo = "UIParent", relativePoint = "BOTTOM", x = 320, y = 64 },
    scale = 1.0,
    alpha = 1.0,
    buttonSize = 40,
    iconInset = 4,
    framePadding = 8,
    textSpacing = 1,
}

local updateFrame = CreateFrame("Frame", "WoWXActionButtonsEventFrame")
local lockTickerFrame = CreateFrame("Frame", "WoWXActionButtonsLockTicker")
local hotkeyEventFrame = CreateFrame("Frame", "WoWXActionButtonsHotkeyEvents")
local ITEM_BUTTON_SIZE = 42
local ITEM_BUTTON_GAP = 4
local ITEM_BUTTON_COLUMNS = 8
local ITEM_GRID_PADDING = 8
local SLOT_ICON_INSET = 2
local BAG_BUTTON_SIZE = 40
local BAG_ICON_INSET = 4

local BLUE_BORDER = { 0.22, 0.66, 0.98, 0.92 }
local GOLD_BORDER = { 0.96, 0.8, 0.22, 0.96 }
local DIM_BORDER = { 0.34, 0.4, 0.5, 0.85 }

local function clamp(value, minValue, maxValue)
    value = tonumber(value) or minValue
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function roundToStep(value, step)
    local s = tonumber(step) or 1
    if s <= 0 then
        return value
    end
    return math.floor((value / s) + 0.5) * s
end

local function formatScaleValue(value)
    return string.format("%.2fx", tonumber(value) or 1)
end

local function createStroke(parent, inset, thickness, layer, subLevel)
    local stroke = {}
    stroke.top = parent:CreateTexture(nil, layer, nil, subLevel)
    stroke.bottom = parent:CreateTexture(nil, layer, nil, subLevel)
    stroke.left = parent:CreateTexture(nil, layer, nil, subLevel)
    stroke.right = parent:CreateTexture(nil, layer, nil, subLevel)
    stroke.tl = parent:CreateTexture(nil, layer, nil, subLevel)
    stroke.tr = parent:CreateTexture(nil, layer, nil, subLevel)
    stroke.bl = parent:CreateTexture(nil, layer, nil, subLevel)
    stroke.br = parent:CreateTexture(nil, layer, nil, subLevel)

    stroke.top:SetTexture("Interface\\Buttons\\WHITE8x8")
    stroke.bottom:SetTexture("Interface\\Buttons\\WHITE8x8")
    stroke.left:SetTexture("Interface\\Buttons\\WHITE8x8")
    stroke.right:SetTexture("Interface\\Buttons\\WHITE8x8")
    stroke.tl:SetTexture("Interface\\Buttons\\WHITE8x8")
    stroke.tr:SetTexture("Interface\\Buttons\\WHITE8x8")
    stroke.bl:SetTexture("Interface\\Buttons\\WHITE8x8")
    stroke.br:SetTexture("Interface\\Buttons\\WHITE8x8")

    stroke.top:SetPoint("TOPLEFT", parent, "TOPLEFT", -inset + 1, inset)
    stroke.top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", inset - 1, inset)
    stroke.top:SetHeight(thickness)

    stroke.bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -inset + 1, -inset)
    stroke.bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", inset - 1, -inset)
    stroke.bottom:SetHeight(thickness)

    stroke.left:SetPoint("TOPLEFT", parent, "TOPLEFT", -inset, inset - 1)
    stroke.left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -inset, -inset + 1)
    stroke.left:SetWidth(thickness)

    stroke.right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", inset, inset - 1)
    stroke.right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", inset, -inset + 1)
    stroke.right:SetWidth(thickness)

    local cornerSize = 3
    stroke.tl:SetWidth(cornerSize)
    stroke.tl:SetHeight(cornerSize)
    stroke.tl:SetPoint("TOPLEFT", parent, "TOPLEFT", -inset, inset)

    stroke.tr:SetWidth(cornerSize)
    stroke.tr:SetHeight(cornerSize)
    stroke.tr:SetPoint("TOPRIGHT", parent, "TOPRIGHT", inset, inset)

    stroke.bl:SetWidth(cornerSize)
    stroke.bl:SetHeight(cornerSize)
    stroke.bl:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -inset, -inset)

    stroke.br:SetWidth(cornerSize)
    stroke.br:SetHeight(cornerSize)
    stroke.br:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", inset, -inset)

    return stroke
end

local function setStrokeColor(stroke, r, g, b, a)
    if not stroke then
        return
    end
    stroke.top:SetVertexColor(r, g, b, a)
    stroke.bottom:SetVertexColor(r, g, b, a)
    stroke.left:SetVertexColor(r, g, b, a)
    stroke.right:SetVertexColor(r, g, b, a)
    local cornerAlpha = (a or 1) * 0.68
    if stroke.tl then stroke.tl:SetVertexColor(r, g, b, cornerAlpha) end
    if stroke.tr then stroke.tr:SetVertexColor(r, g, b, cornerAlpha) end
    if stroke.bl then stroke.bl:SetVertexColor(r, g, b, cornerAlpha) end
    if stroke.br then stroke.br:SetVertexColor(r, g, b, cornerAlpha) end
end

local function applyBlueChromeBackdrop(frame, border)
    if not frame then
        return
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.05, 0.07, 0.12, 0.5)
    local c = border or BLUE_BORDER
    frame:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
end

local function addChamferAccents(frame)
    if not frame or frame._wowxChamferAccents then
        return
    end

    frame._wowxChamferAccents = {}
    local corners = {
        { "TOPLEFT", "TOPLEFT", 0, 0, { 0, 0.5, 0, 0.5 } },
        { "TOPRIGHT", "TOPRIGHT", 0, 0, { 0.5, 1, 0, 0.5 } },
        { "BOTTOMLEFT", "BOTTOMLEFT", 0, 0, { 0, 0.5, 0.5, 1 } },
        { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0, { 0.5, 1, 0.5, 1 } },
    }

    for _, info in ipairs(corners) do
        local tex = frame:CreateTexture(nil, "BORDER")
        tex:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Gold-Corner")
        tex:SetWidth(16)
        tex:SetHeight(16)
        tex:SetPoint(info[1], frame, info[2], info[3], info[4])
        tex:SetTexCoord(info[5][1], info[5][2], info[5][3], info[5][4])
        tex:SetVertexColor(1.0, 0.85, 0.24, 0.95)
        frame._wowxChamferAccents[#frame._wowxChamferAccents + 1] = tex
    end
end

local function ensureSlotChrome(button, borderColor)
    if not button then
        return
    end

    if button._border then
        return
    end

    if button.SetNormalTexture then button:SetNormalTexture(nil) end
    if button.SetPushedTexture then button:SetPushedTexture(nil) end
    if button.SetHighlightTexture then button:SetHighlightTexture(nil) end
    if button.SetDisabledTexture then button:SetDisabledTexture(nil) end

    local bg = button:CreateTexture(nil, "BORDER", nil, 0)
    bg:SetAllPoints(button)
    bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    bg:SetVertexColor(0.06, 0.08, 0.12, 0.0)

    local shadow = createStroke(button, 2, 1, "OVERLAY", 4)
    setStrokeColor(shadow, 0.0, 0.0, 0.0, 0.45)

    local edge = createStroke(button, 1, 1, "OVERLAY", 5)
    setStrokeColor(edge, borderColor[1], borderColor[2], borderColor[3], borderColor[4])

    local tint = createStroke(button, 1, 1, "OVERLAY", 6)
    setStrokeColor(tint, 0.0, 0.0, 0.0, 0.0)

    button._slotBg = bg
    button._borderShadow = shadow
    button._border = edge
    button._borderTint = tint
end

local function getBagLabel(bagID)
    if bagID == 0 then
        return "Backpack"
    end
    return "Bag " .. tostring(bagID)
end

local function formatMoneyText(copper)
    local amount = tonumber(copper) or 0
    if amount < 0 then amount = 0 end
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copperPart = amount % 100
    return string.format("%dg %ds %dc", gold, silver, copperPart)
end

local function collectWatchedCurrencies()
    local out = {}
    if not GetBackpackCurrencyInfo then
        return out
    end

    local index = 1
    while true do
        local name, count, icon = GetBackpackCurrencyInfo(index)
        if not name then
            break
        end
        out[#out + 1] = {
            name = tostring(name),
            count = tonumber(count) or 0,
            icon = icon,
        }
        index = index + 1
    end
    return out
end

local function cloneDefaults()
    if GPX.DeepCopy then
        return GPX:DeepCopy(defaultConfig)
    end

    return {
        enabled = defaultConfig.enabled,
        showBags = defaultConfig.showBags,
        point = {
            anchor = defaultConfig.point.anchor,
            relativeTo = defaultConfig.point.relativeTo,
            relativePoint = defaultConfig.point.relativePoint,
            x = defaultConfig.point.x,
            y = defaultConfig.point.y,
        },
        scale = defaultConfig.scale,
        alpha = defaultConfig.alpha,
        buttonSize = defaultConfig.buttonSize,
        iconInset = defaultConfig.iconInset,
        framePadding = defaultConfig.framePadding,
        textSpacing = defaultConfig.textSpacing,
    }
end

local function ensureConfig()
    if not GPX.db then
        return nil
    end

    GPX.db.ui = GPX.db.ui or {}
    GPX.db.ui.actionButtons = GPX.db.ui.actionButtons or cloneDefaults()

    local cfg = GPX.db.ui.actionButtons
    if cfg.enabled == nil then cfg.enabled = defaultConfig.enabled end
    if cfg.showBags == nil then cfg.showBags = defaultConfig.showBags end
    cfg.point = cfg.point or cloneDefaults().point
    if cfg.scale == nil then cfg.scale = defaultConfig.scale end
    if cfg.alpha == nil then cfg.alpha = defaultConfig.alpha end
    if cfg.buttonSize == nil then cfg.buttonSize = defaultConfig.buttonSize end
    if cfg.iconInset == nil then cfg.iconInset = defaultConfig.iconInset end
    if cfg.framePadding == nil then cfg.framePadding = defaultConfig.framePadding end
    if cfg.textSpacing == nil then cfg.textSpacing = defaultConfig.textSpacing end

    return cfg
end

local function isVisualBarLocked()
    if GPX.VisualBar and GPX.VisualBar.IsLocked then
        return GPX.VisualBar:IsLocked() == true
    end
    return true
end

local function isLayoutEditActive()
    return not isVisualBarLocked()
end

local function savePoint(frame, cfg)
    if not frame or not cfg then
        return
    end

    local anchor, _, relativePoint, x, y = frame:GetPoint(1)
    cfg.point = {
        anchor = anchor or "BOTTOMRIGHT",
        relativeTo = "UIParent",
        relativePoint = relativePoint or "BOTTOM",
        x = x or 320,
        y = y or 64,
    }
end

local function applyPoint(frame, cfg)
    frame:ClearAllPoints()

    local p = cfg.point or defaultConfig.point
    frame:SetPoint(p.anchor or "BOTTOMRIGHT", UIParent, p.relativePoint or "BOTTOM", p.x or 320, p.y or 64)
end

local function registerAsEscapeClosable(frameName)
    if not UISpecialFrames or not frameName or frameName == "" then
        return
    end

    for _, name in ipairs(UISpecialFrames) do
        if name == frameName then
            return
        end
    end
    table.insert(UISpecialFrames, frameName)
end

function Buttons:CreateFrame()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "WoWXUtilityButtonsFrame", UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetWidth(BAG_BUTTON_SIZE)
    frame:SetHeight(60)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(false)

    local button = CreateFrame("Button", "WoWXUtilityBagButton", frame)
    button:SetPoint("TOP", frame, "TOP", 0, -8)
    button:SetWidth(BAG_BUTTON_SIZE)
    button:SetHeight(BAG_BUTTON_SIZE)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    if button.SetNormalTexture then button:SetNormalTexture(nil) end
    if button.SetPushedTexture then button:SetPushedTexture(nil) end
    if button.SetHighlightTexture then button:SetHighlightTexture(nil) end
    if button.SetDisabledTexture then button:SetDisabledTexture(nil) end

    ensureSlotChrome(button, BLUE_BORDER)
    if button._slotBg then
        button._slotBg:SetVertexColor(0.06, 0.08, 0.12, 0.14)
    end

    local icon = button:CreateTexture(nil, "ARTWORK", nil, 1)
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", BAG_ICON_INSET, -BAG_ICON_INSET)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -BAG_ICON_INSET, BAG_ICON_INSET)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon:SetVertexColor(1, 1, 1, 1)

    local key = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    key:SetPoint("TOP", button, "BOTTOM", 0, -1)
    key:SetText("Bags")
    key:SetTextColor(1.0, 0.82, 0.18)

    local money = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    money:SetPoint("TOP", key, "BOTTOM", 0, -1)
    money:SetText("")
    money:SetTextColor(1.0, 0.82, 0.18)

    local currency = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    currency:SetPoint("TOP", money, "BOTTOM", 0, -1)
    currency:SetText("")
    currency:SetTextColor(0.75, 0.9, 1.0)

    local editButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    editButton:SetWidth(20)
    editButton:SetHeight(16)
    editButton:SetText("E")
    editButton:SetScript("OnClick", function()
        Buttons:ToggleLayoutEditor()
    end)

    self.moneyLabel = money
    self.currencyLabel = currency

    button:SetScript("OnDragStart", function()
        if isLayoutEditActive() then
            frame:StartMoving()
        end
    end)
    button:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        savePoint(frame, ensureConfig())
    end)

    button:SetScript("OnEnter", function(selfBtn)
        GameTooltip:SetOwner(selfBtn, "ANCHOR_TOP")
        GameTooltip:SetText("WoWX Bags", 1, 0.82, 0.2)
        GameTooltip:AddLine("Left-click toggles the WoWX combined bag window.", 0.86, 0.9, 1.0)
        GameTooltip:AddLine("Right-click opens key ring.", 0.86, 0.9, 1.0)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Money: " .. formatMoneyText(GetMoney and GetMoney() or 0), 1.0, 0.82, 0.18)
        local watched = collectWatchedCurrencies()
        if #watched > 0 then
            GameTooltip:AddLine("Watched currencies:", 0.75, 0.9, 1.0)
            for _, token in ipairs(watched) do
                GameTooltip:AddDoubleLine(token.name, tostring(token.count), 0.84, 0.92, 1.0, 1.0, 1.0, 1.0)
            end
        else
            GameTooltip:AddLine("No watched backpack currencies.", 0.66, 0.74, 0.86)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            Buttons:ToggleBagWindow()
            return
        end

        if mouseButton == "RightButton" then
            if InCombatLockdown() then
                GPX:Print("Cannot open key ring in combat.")
                return
            end
            if ToggleKeyRing then
                ToggleKeyRing()
            elseif _G.KeyRingButton and _G.KeyRingButton.Click then
                _G.KeyRingButton:Click()
            else
                GPX:Print("Key ring button unavailable on this client.")
            end
        end
    end)

    self.frame = frame
    self.editButton = editButton
    self.bagButton = button
    self.bagIcon = icon
    self.bagPanel = button._slotBg
    self.bagButtonShadow = button._borderShadow
    self.bagButtonBorder = button._border
    self.bagButtonTint = button._borderTint
    self.bagLabel = key

    self:ApplyBagButtonLayout()
    self:RefreshEconomyText()
    self:RefreshBagButtonChrome(true)
end

function Buttons:ApplyBagButtonLayout()
    local cfg = ensureConfig()
    if not cfg or not self.frame or not self.bagButton then
        return
    end

    local buttonSize = math.floor(clamp(cfg.buttonSize, 24, 72) + 0.5)
    local iconInset = math.floor(clamp(cfg.iconInset, 1, 12) + 0.5)
    local framePadding = math.floor(clamp(cfg.framePadding, 2, 18) + 0.5)
    local textSpacing = math.floor(clamp(cfg.textSpacing, 0, 8) + 0.5)
    local labelHeight = 12
    local currencyShown = self.currencyLabel and self.currencyLabel:GetText() and self.currencyLabel:GetText() ~= ""
    local textRows = currencyShown and 3 or 2
    local frameWidth = buttonSize + (framePadding * 2)
    local frameHeight = buttonSize + (framePadding * 2) + (textRows * labelHeight) + (math.max(0, textRows - 1) * textSpacing)

    self.frame:SetWidth(frameWidth)
    self.frame:SetHeight(frameHeight)

    self.bagButton:SetWidth(buttonSize)
    self.bagButton:SetHeight(buttonSize)
    self.bagButton:ClearAllPoints()
    self.bagButton:SetPoint("TOP", self.frame, "TOP", 0, -framePadding)

    if self.editButton then
        self.editButton:ClearAllPoints()
        self.editButton:SetPoint("BOTTOMLEFT", self.bagButton, "TOPRIGHT", 2, -6)
    end

    if self.bagIcon then
        self.bagIcon:ClearAllPoints()
        self.bagIcon:SetPoint("TOPLEFT", self.bagButton, "TOPLEFT", iconInset, -iconInset)
        self.bagIcon:SetPoint("BOTTOMRIGHT", self.bagButton, "BOTTOMRIGHT", -iconInset, iconInset)
    end

    if self.bagLabel then
        self.bagLabel:ClearAllPoints()
        self.bagLabel:SetPoint("TOP", self.bagButton, "BOTTOM", 0, -textSpacing)
    end

    if self.moneyLabel and self.bagLabel then
        self.moneyLabel:ClearAllPoints()
        self.moneyLabel:SetPoint("TOP", self.bagLabel, "BOTTOM", 0, -textSpacing)
    end

    if self.currencyLabel and self.moneyLabel then
        self.currencyLabel:ClearAllPoints()
        self.currencyLabel:SetPoint("TOP", self.moneyLabel, "BOTTOM", 0, -textSpacing)
    end
end

function Buttons:CreateLayoutEditor()
    if self.layoutEditor then
        return self.layoutEditor
    end

    local frame = CreateFrame("Frame", "WoWXUtilityBagLayoutEditor", UIParent)
    frame:SetWidth(300)
    frame:SetHeight(276)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    applyBlueChromeBackdrop(frame, GOLD_BORDER)
    addChamferAccents(frame)
    frame:Hide()

    frame:SetScript("OnDragStart", function(selfFrame)
        selfFrame:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
    end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -12)
    title:SetText("Bag Button Edit Mode")
    title:SetTextColor(0.96, 0.98, 1.0)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)

    local resetButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetButton:SetWidth(82)
    resetButton:SetHeight(22)
    resetButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 12)
    resetButton:SetText("Defaults")
    resetButton:SetScript("OnClick", function()
        local cfg = ensureConfig()
        if not cfg then
            return
        end
        cfg.point = cloneDefaults().point
        cfg.scale = defaultConfig.scale
        cfg.alpha = defaultConfig.alpha
        cfg.buttonSize = defaultConfig.buttonSize
        cfg.iconInset = defaultConfig.iconInset
        cfg.framePadding = defaultConfig.framePadding
        cfg.textSpacing = defaultConfig.textSpacing
        Buttons:UpdateAll()
        Buttons:OpenLayoutEditor()
    end)

    local doneButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    doneButton:SetWidth(82)
    doneButton:SetHeight(22)
    doneButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
    doneButton:SetText("Close")
    doneButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame.controls = {}
    local controls = {
        { key = "scale", label = "Scale", min = 0.5, max = 2.0, step = 0.01, format = formatScaleValue },
        { key = "buttonSize", label = "Button Size", min = 24, max = 72, step = 1 },
        { key = "iconInset", label = "Icon Padding", min = 1, max = 12, step = 1 },
        { key = "framePadding", label = "Frame Padding", min = 2, max = 18, step = 1 },
        { key = "textSpacing", label = "Text Spacing", min = 0, max = 8, step = 1 },
        { key = "alpha", label = "Opacity", min = 0.35, max = 1.0, step = 0.01 },
    }

    for index, control in ipairs(controls) do
        local slider = CreateFrame("Slider", nil, frame)
        slider:SetOrientation("HORIZONTAL")
        slider:SetWidth(240)
        slider:SetHeight(18)
        slider:SetPoint("TOPLEFT", frame, "TOPLEFT", 26, -48 - ((index - 1) * 38))
        slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        slider:SetBackdrop({
            bgFile = "Interface\\TargetingFrame\\UI-StatusBar",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false,
            edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        slider:SetBackdropColor(0.12, 0.16, 0.22, 0.95)
        slider:SetBackdropBorderColor(0.22, 0.3, 0.4, 0.75)
        slider:SetMinMaxValues(control.min, control.max)
        slider:SetValueStep(control.step)

        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 4)
        label:SetText(control.label)
        label:SetTextColor(0.92, 0.95, 1.0)

        local valueText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        valueText:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 4)
        valueText:SetTextColor(1.0, 0.92, 0.58)

        slider.control = control
        slider.valueText = valueText
        slider:SetScript("OnValueChanged", function(selfSlider, value)
            if selfSlider._suspend then
                return
            end
            local cfg = ensureConfig()
            if not cfg then
                return
            end
            local stepped = roundToStep(value, control.step)
            cfg[control.key] = stepped
            valueText:SetText(control.format and control.format(stepped) or tostring(stepped))
            Buttons:UpdateAll()
        end)

        frame.controls[index] = slider
    end

    self.layoutEditor = frame
    return frame
end

function Buttons:OpenLayoutEditor()
    local frame = self:CreateLayoutEditor()
    frame:ClearAllPoints()
    if self.bagButton and self.bagButton:IsShown() then
        frame:SetPoint("LEFT", self.bagButton, "RIGHT", 16, 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    local cfg = ensureConfig()
    for _, slider in ipairs(frame.controls or {}) do
        local control = slider.control
        local value = cfg and cfg[control.key] or defaultConfig[control.key]
        slider._suspend = true
        slider:SetValue(value)
        slider.valueText:SetText(control.format and control.format(value) or tostring(value))
        slider._suspend = false
    end

    frame:Show()
    frame:Raise()
end

function Buttons:ToggleLayoutEditor()
    local frame = self:CreateLayoutEditor()
    if frame:IsShown() then
        frame:Hide()
    else
        self:OpenLayoutEditor()
    end
end

function Buttons:RefreshBagButtonChrome(force)
    if not self.bagPanel or not self.bagButtonBorder then
        return
    end

    local locked = isVisualBarLocked()
    if not force and self._lastBagVisualLockState == locked then
        return
    end
    self._lastBagVisualLockState = locked

    local c = locked and BLUE_BORDER or GOLD_BORDER
    setStrokeColor(self.bagButtonBorder, c[1], c[2], c[3], 1.0)
    if self.bagButtonTint then
        setStrokeColor(self.bagButtonTint, c[1], c[2], c[3], 0.18)
    end

    if self.editButton then
        self.editButton:SetShown(not locked)
    end

    if self.bagLabel then
        if locked then
            self.bagLabel:SetTextColor(0.66, 0.86, 1.0)
        else
            self.bagLabel:SetTextColor(1.0, 0.82, 0.18)
        end
    end
end

function Buttons:SetBagHighlight(activeBagID)
    if not self.itemButtons then
        return
    end

    for _, button in ipairs(self.itemButtons) do
        if button:IsShown() and button._bagID ~= nil and activeBagID ~= nil then
            local isActive = button._bagID == activeBagID
            if isActive then
                setStrokeColor(button._border, button._baseBorderColor[1], button._baseBorderColor[2], button._baseBorderColor[3], button._baseBorderColor[4])
                if button._borderTint then
                    setStrokeColor(button._borderTint, 0.22, 0.9, 0.36, 0.45)
                end
            elseif button._baseBorderColor then
                setStrokeColor(button._border, button._baseBorderColor[1], button._baseBorderColor[2], button._baseBorderColor[3], button._baseBorderColor[4])
                if button._borderTint then
                    setStrokeColor(button._borderTint, 0.0, 0.0, 0.0, 0.0)
                end
            else
                setStrokeColor(button._border, 0.8, 0.8, 0.8, 1.0)
                if button._borderTint then
                    setStrokeColor(button._borderTint, 0.0, 0.0, 0.0, 0.0)
                end
            end
        else
            button:SetAlpha(1.0)
            if button._baseBorderColor then
                setStrokeColor(button._border, button._baseBorderColor[1], button._baseBorderColor[2], button._baseBorderColor[3], button._baseBorderColor[4])
                if button._borderTint then
                    setStrokeColor(button._borderTint, 0.0, 0.0, 0.0, 0.0)
                end
            else
                setStrokeColor(button._border, 0.8, 0.8, 0.8, 1.0)
                if button._borderTint then
                    setStrokeColor(button._borderTint, 0.0, 0.0, 0.0, 0.0)
                end
            end
        end
    end
end

function Buttons:CreateBagSlotButton(parent, bagID)
    local invSlot = bagID == 0 and 16 or ((ContainerIDToInventoryID and ContainerIDToInventoryID(bagID)) or (19 + bagID))
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(38)
    button:SetHeight(38)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton", "RightButton")
    if button.SetNormalTexture then button:SetNormalTexture(nil) end
    if button.SetPushedTexture then button:SetPushedTexture(nil) end
    if button.SetHighlightTexture then button:SetHighlightTexture(nil) end
    if button.SetDisabledTexture then button:SetDisabledTexture(nil) end

    ensureSlotChrome(button, GOLD_BORDER)

    local icon = button:CreateTexture(nil, "ARTWORK", nil, 1)
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", SLOT_ICON_INSET, -SLOT_ICON_INSET)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -SLOT_ICON_INSET, SLOT_ICON_INSET)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetVertexColor(1, 1, 1, 1)

    button._bagID = bagID
    button._invSlot = invSlot
    button._icon = icon

    button:SetScript("OnClick", function(selfBtn)
        if CursorHasItem() then
            if PutItemInBag then
                PutItemInBag(selfBtn._invSlot)
            end
        else
            if PickupInventoryItem then
                PickupInventoryItem(selfBtn._invSlot)
            end
        end
    end)
    button:SetScript("OnReceiveDrag", function(selfBtn)
        if PutItemInBag then
            PutItemInBag(selfBtn._invSlot)
        end
    end)
    button:SetScript("OnEnter", function(selfBtn)
        if GameTooltip then
            GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
            if GameTooltip.SetInventoryItem then
                GameTooltip:SetInventoryItem("player", selfBtn._invSlot)
            end
            local slotCount = GetContainerNumSlots and (GetContainerNumSlots(selfBtn._bagID) or 0) or 0
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(getBagLabel(selfBtn._bagID) .. " slots: " .. tostring(slotCount), 0.86, 0.9, 1.0)
            GameTooltip:Show()
        end
        Buttons:SetBagHighlight(selfBtn._bagID)
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
        Buttons:SetBagHighlight(nil)
    end)

    return button
end

function Buttons:CreateItemButton(parent)
    -- Use Blizzard's ContainerFrameItemButtonTemplate like Bagnon does
    -- This template has built-in secure handling for UseContainerItem
    local buttonID = (self._nextItemButtonID or 0) + 1
    self._nextItemButtonID = buttonID
    
    local button = CreateFrame("Button", "WoWXBagItem" .. buttonID, parent, "ContainerFrameItemButtonTemplate")
    button:SetWidth(ITEM_BUTTON_SIZE)
    button:SetHeight(ITEM_BUTTON_SIZE)
    
    -- ContainerFrameItemButtonTemplate creates: icon, Count, Stock, etc.
    button._icon = _G[button:GetName() .. "IconTexture"] or button.icon
    button._count = _G[button:GetName() .. "Count"] or button.Count

    -- Fallback if template did not create icon as expected
    if not button._icon and button.icon then
        button._icon = button.icon
    end
    
    -- Keep template's default click/drag handling, just override tooltip
    button:SetScript("OnEnter", function(selfBtn)
        local bagID = selfBtn:GetParent():GetID()
        local slot = selfBtn:GetID()
        if bagID and slot and GameTooltip and GameTooltip.SetBagItem then
            GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
            GameTooltip:SetBagItem(bagID, slot)
            GameTooltip:Show()
        end
    end)
    
    button:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    return button
end

function Buttons:EnsureBagWindow()
    if self.bagWindow then
        return self.bagWindow
    end

    local contentWidth = ITEM_BUTTON_COLUMNS * ITEM_BUTTON_SIZE + (ITEM_BUTTON_COLUMNS - 1) * ITEM_BUTTON_GAP
    local bagWindowWidth = 16 + ITEM_GRID_PADDING * 2 + contentWidth + 20
    local frame = CreateFrame("Frame", "WoWXCombinedBagWindow", UIParent)
    frame:SetWidth(bagWindowWidth)
    frame:SetHeight(520)
    frame:SetPoint("CENTER", UIParent, "CENTER", 120, -20)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(selfFrame)
        selfFrame:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
    end)
    applyBlueChromeBackdrop(frame, BLUE_BORDER)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
    title:SetText("WoWX Bags")

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    subtitle:SetText("Single-window inventory. Drag items to top bag slots to change equipped bags.")
    subtitle:SetTextColor(1.0, 0.82, 0.2)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

    local summary = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -48)
    summary:SetText("")
    summary:SetTextColor(1.0, 0.82, 0.18)

    local bagSlotHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bagSlotHeader:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -8)
    bagSlotHeader:SetText("Bag slots")
    bagSlotHeader:SetTextColor(0.66, 0.86, 1.0)

    local bagSlotRow = CreateFrame("Frame", nil, frame)
    bagSlotRow:SetPoint("TOPLEFT", bagSlotHeader, "BOTTOMLEFT", 0, -4)
    bagSlotRow:SetWidth(420)
    bagSlotRow:SetHeight(38)

    self.bagSlotButtons = {}
    for bagID = 0, 4 do
        local slotButton = self:CreateBagSlotButton(bagSlotRow, bagID)
        slotButton:SetPoint("LEFT", bagSlotRow, "LEFT", bagID * 46, 0)
        self.bagSlotButtons[#self.bagSlotButtons + 1] = slotButton

        local label = bagSlotRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOP", slotButton, "BOTTOM", 0, -1)
        label:SetText(bagID == 0 and "BP" or tostring(bagID))
    end

    local grid = CreateFrame("Frame", nil, frame)
    grid:SetPoint("TOPLEFT", bagSlotRow, "BOTTOMLEFT", 0, -22)
    grid:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 20)
    applyBlueChromeBackdrop(grid, DIM_BORDER)

    self.itemButtons = self.itemButtons or {}

    frame._wowxSummary = summary
    frame._wowxGrid = grid

    self.bagWindow = frame
    registerAsEscapeClosable("WoWXCombinedBagWindow")
    return frame
end

function Buttons:GetShowState()
    local cfg = ensureConfig()
    if not cfg then
        return false
    end
    local enabled = GPX.db and GPX.db.enabled
    return enabled and cfg.enabled and cfg.showBags
end

function Buttons:ApplyHotkeys()
    self.hotkeyOwner = self.hotkeyOwner or CreateFrame("Frame", "WoWXActionButtonsHotkeyOwner", UIParent)

    if InCombatLockdown() then
        self.pendingHotkeyRefresh = true
        return
    end

    if ClearOverrideBindings then
        ClearOverrideBindings(self.hotkeyOwner)
    end

    if not self:GetShowState() then
        self.pendingHotkeyRefresh = nil
        return
    end

    if SetOverrideBindingClick then
        SetOverrideBindingClick(self.hotkeyOwner, true, "B", "WoWXUtilityBagButton", "LeftButton")
        SetOverrideBindingClick(self.hotkeyOwner, true, "SHIFT-B", "WoWXUtilityBagButton", "RightButton")
    end

    self.pendingHotkeyRefresh = nil
end

function Buttons:RefreshBagWindow()
    local frame = self:EnsureBagWindow()
    if not frame then
        return
    end

    local totalSlots = 0
    local usedSlots = 0
    local entries = {}

    for bagID = 0, 4 do
        local slotCount = GetContainerNumSlots and (GetContainerNumSlots(bagID) or 0) or 0
        totalSlots = totalSlots + slotCount

        for slot = 1, slotCount do
            local texture, itemCount, locked, quality = GetContainerItemInfo(bagID, slot)
            if texture then
                usedSlots = usedSlots + 1
            end
            local entry = {
                bagID = bagID,
                slot = slot,
                texture = texture,
                count = tonumber(itemCount) or 0,
                locked = locked,
                quality = tonumber(quality) or 1,
            }

            entries[#entries + 1] = entry
        end
    end

    if frame._wowxSummary then
        frame._wowxSummary:SetText(string.format("Slots: %d / %d", usedSlots, totalSlots))
    end

    local rows = math.ceil((#entries > 0 and #entries or 1) / ITEM_BUTTON_COLUMNS)
    local minRows = 4
    if rows < minRows then
        rows = minRows
    end
    local gridHeight = ITEM_GRID_PADDING * 2 + (rows * ITEM_BUTTON_SIZE) + ((rows - 1) * ITEM_BUTTON_GAP)
    if frame._wowxGrid then
        frame._wowxGrid:SetHeight(gridHeight)
    end
    local windowHeight = 176 + gridHeight
    if windowHeight < 360 then
        windowHeight = 360
    elseif windowHeight > 620 then
        windowHeight = 620
    end
    frame:SetHeight(windowHeight)

    for index, slotButton in ipairs(self.bagSlotButtons or {}) do
        local bagID = index - 1
        local invSlot = bagID == 0 and 16 or ((ContainerIDToInventoryID and ContainerIDToInventoryID(bagID)) or (19 + bagID))
        local texture = GetInventoryItemTexture("player", invSlot)
        if slotButton and slotButton._icon then
            slotButton._icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_Bag_08")
        end
    end

    for i = 1, #entries do
        local info = entries[i]
        local button = self.itemButtons[i]
        if not button then
            button = self:CreateItemButton(frame._wowxGrid)
            self.itemButtons[i] = button
        end

        local col = (i - 1) % ITEM_BUTTON_COLUMNS
        local row = math.floor((i - 1) / ITEM_BUTTON_COLUMNS)
        local x = ITEM_GRID_PADDING + col * (ITEM_BUTTON_SIZE + ITEM_BUTTON_GAP)
        local y = -(ITEM_GRID_PADDING + row * (ITEM_BUTTON_SIZE + ITEM_BUTTON_GAP))
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", frame._wowxGrid, "TOPLEFT", x, y)

        -- Set bag/slot for ContainerFrameItemButtonTemplate
        -- Template needs parent's ID = bag, button's ID = slot
        if info.bagID and info.slot then
            if not button._dummyParent then
                button._dummyParent = CreateFrame("Frame", nil, frame._wowxGrid)
                button:SetParent(button._dummyParent)
            end
            button._dummyParent:SetID(info.bagID)
            button:SetID(info.slot)
        end
        
        if info.spacer then
            button:Hide()
        else
            -- Explicitly drive icon/count so visual state stays stable on load.
            if info.texture then
                if button._icon then
                    button._icon:SetTexture(info.texture)
                    button._icon:SetVertexColor(1, 1, 1, 1)
                end
                if button._count then
                    if info.count and info.count > 1 then
                        button._count:SetText(tostring(info.count))
                        button._count:Show()
                    else
                        button._count:Hide()
                    end
                end
                button:Show()
            else
                if button._icon then
                    button._icon:SetTexture(nil)
                end
                if button._count then
                    button._count:Hide()
                end
                button:Show()
            end
        end
    end

    for i = #entries + 1, #self.itemButtons do
        self.itemButtons[i]:Hide()
    end

    self:SetBagHighlight(nil)
end

function Buttons:ToggleBagWindow()
    local frame = self:EnsureBagWindow()
    if not frame then
        return
    end

    if frame:IsShown() then
        frame:Hide()
        self._openedByMerchant = nil
        if CloseAllBags then
            CloseAllBags()
        end
        return
    end

    if CloseAllBags then
        CloseAllBags()
    end
    self:RefreshBagWindow()
    frame:Show()
    frame:Raise()
end

function Buttons:RefreshEconomyText()
    if not self.frame then
        return
    end

    if self.moneyLabel then
        self.moneyLabel:SetText(formatMoneyText(GetMoney and GetMoney() or 0))
    end

    if self.currencyLabel then
        local watched = collectWatchedCurrencies()
        if #watched > 0 then
            local first = watched[1]
            self.currencyLabel:SetText(first.name .. ": " .. tostring(first.count))
        else
            self.currencyLabel:SetText("")
        end
    end
end

function Buttons:UpdateAll()
    local cfg = ensureConfig()
    if not cfg then
        return
    end

    self:CreateFrame()

    if InCombatLockdown() then
        self.pendingRefresh = true
        return
    end

    local show = self:GetShowState()

    if show then
        self.frame:SetScale(cfg.scale or 1.0)
        self.frame:SetAlpha(cfg.alpha or 1.0)
        applyPoint(self.frame, cfg)
        self:RefreshEconomyText()
        self:ApplyBagButtonLayout()
        self:RefreshBagButtonChrome()
        self.frame:Show()
    else
        self.frame:Hide()
        if self.bagWindow then
            self.bagWindow:Hide()
        end
    end

    self:ApplyHotkeys()

    self.pendingRefresh = nil
    
    -- Hook Blizzard bag opening functions to redirect to WoWX bags
    self:InstallBlizzardBagHooks()
end

function Buttons:InstallBlizzardBagHooks()
    if self._hooksInstalled then
        return
    end
    self._hooksInstalled = true

    local cfg = ensureConfig()
    if not cfg then
        return
    end

    -- Hook ToggleBackpack to open WoWX bags instead
    if ToggleBackpack and not self._originalToggleBackpack then
        self._originalToggleBackpack = ToggleBackpack
        ToggleBackpack = function()
            if Buttons:GetShowState() then
                Buttons:ToggleBagWindow()
            else
                Buttons._originalToggleBackpack()
            end
        end
    end

    -- Hook OpenAllBags to open WoWX bags instead
    if OpenAllBags and not self._originalOpenAllBags then
        self._originalOpenAllBags = OpenAllBags
        OpenAllBags = function()
            if Buttons:GetShowState() then
                local frame = Buttons:EnsureBagWindow()
                if frame and not frame:IsShown() then
                    Buttons:RefreshBagWindow()
                    frame:Show()
                    frame:Raise()
                end
            else
                Buttons._originalOpenAllBags()
            end
        end
    end

    -- Hook CloseAllBags to close WoWX bags
    if CloseAllBags and not self._originalCloseAllBags then
        self._originalCloseAllBags = CloseAllBags
        CloseAllBags = function()
            if Buttons:GetShowState() and Buttons.bagWindow and Buttons.bagWindow:IsShown() then
                Buttons.bagWindow:Hide()
                Buttons._openedByMerchant = nil
            end
            Buttons._originalCloseAllBags()
        end
    end
end

function Buttons:Slash(msg)
    local arg = string.lower((msg or ""):match("^%s*(.-)%s*$"))
    local cfg = ensureConfig()
    if not cfg then
        GPX:Print("ActionButtons unavailable (database not ready).")
        return
    end

    if arg == "" or arg == "status" then
        GPX:Print("Bags action button: " .. ((cfg.enabled and cfg.showBags) and "ON" or "OFF"))
        return
    end

    if arg == "on" or arg == "enable" or arg == "1" then
        cfg.enabled = true
        cfg.showBags = true
    elseif arg == "off" or arg == "disable" or arg == "0" then
        cfg.showBags = false
    elseif arg == "toggle" then
        cfg.showBags = not (cfg.showBags == true)
    elseif arg == "reset" then
        cfg.point = cloneDefaults().point
        cfg.scale = defaultConfig.scale
        cfg.alpha = defaultConfig.alpha
        cfg.buttonSize = defaultConfig.buttonSize
        cfg.iconInset = defaultConfig.iconInset
        cfg.framePadding = defaultConfig.framePadding
        cfg.textSpacing = defaultConfig.textSpacing
    else
        GPX:Print("Usage: /wowx bags [on|off|toggle|status|reset]")
        return
    end

    self:UpdateAll()
    GPX:Print("Bags action button: " .. ((cfg.enabled and cfg.showBags) and "ON" or "OFF"))
end

updateFrame:RegisterEvent("PLAYER_LOGIN")
updateFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
updateFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
updateFrame:RegisterEvent("PLAYER_MONEY")
updateFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
updateFrame:RegisterEvent("BAG_UPDATE")
updateFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
updateFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
updateFrame:RegisterEvent("MERCHANT_SHOW")
updateFrame:RegisterEvent("MERCHANT_CLOSED")
updateFrame:SetScript("OnEvent", function(_, event)
    if not GPX.ActionButtons then
        return
    end

    if event == "MERCHANT_SHOW" then
        -- Auto-open WoWX bags when talking to a merchant/vendor
        local cfg = ensureConfig()
        if cfg and cfg.enabled and cfg.showBags and GPX.db and GPX.db.enabled then
            local frame = GPX.ActionButtons:EnsureBagWindow()
            if frame and not frame:IsShown() then
                GPX.ActionButtons:RefreshBagWindow()
                frame:Show()
                frame:Raise()
                GPX.ActionButtons._openedByMerchant = true
            end
        end
        return
    end

    if event == "MERCHANT_CLOSED" then
        -- Optionally close WoWX bags when merchant closes (matching Blizzard behavior)
        if GPX.ActionButtons.bagWindow and GPX.ActionButtons.bagWindow:IsShown() then
            -- Don't auto-close if user manually opened bags - only if opened by merchant
            if GPX.ActionButtons._openedByMerchant then
                GPX.ActionButtons.bagWindow:Hide()
                GPX.ActionButtons._openedByMerchant = nil
            end
        end
        return
    end

    if event == "PLAYER_MONEY" or event == "CURRENCY_DISPLAY_UPDATE" then
        GPX.ActionButtons:RefreshEconomyText()
        return
    end

    if event == "BAG_UPDATE" or event == "BAG_UPDATE_COOLDOWN" or event == "UNIT_INVENTORY_CHANGED" then
        GPX.ActionButtons:RefreshEconomyText()
        if GPX.ActionButtons.bagWindow and GPX.ActionButtons.bagWindow:IsShown() then
            GPX.ActionButtons:RefreshBagWindow()
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" and not GPX.ActionButtons.pendingRefresh then
        return
    end

    GPX.ActionButtons:UpdateAll()
end)

hotkeyEventFrame:RegisterEvent("PLAYER_LOGIN")
hotkeyEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
hotkeyEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
hotkeyEventFrame:RegisterEvent("UPDATE_BINDINGS")
hotkeyEventFrame:SetScript("OnEvent", function(_, event)
    if not GPX.ActionButtons then
        return
    end

    if event == "PLAYER_REGEN_ENABLED" and not GPX.ActionButtons.pendingHotkeyRefresh then
        return
    end

    GPX.ActionButtons:ApplyHotkeys()
end)

lockTickerFrame:SetScript("OnUpdate", function(_, elapsed)
    if not GPX.ActionButtons then
        return
    end

    GPX.ActionButtons._lockRefreshAccum = (GPX.ActionButtons._lockRefreshAccum or 0) + (elapsed or 0)
    if GPX.ActionButtons._lockRefreshAccum < 0.25 then
        return
    end
    GPX.ActionButtons._lockRefreshAccum = 0

    if GPX.ActionButtons.frame and GPX.ActionButtons.frame:IsShown() then
        GPX.ActionButtons:RefreshBagButtonChrome()
    end
end)
