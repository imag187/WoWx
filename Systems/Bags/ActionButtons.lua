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
    bagWindowPoint = { anchor = "CENTER", relativePoint = "CENTER", x = 120, y = -20 },
    bagSlotsExpanded = false,
    selectedBagID = nil,
    includeKeyRingWithBags = false,
    selectedBankBagID = nil,
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
local UTILITY_BUTTON_GAP = 8
-- Use Blizzard constants directly, same as Bagnon
local KEYRING_BAG_ID = KEYRING_CONTAINER
local BANK_CONTAINER_ID = BANK_CONTAINER

local MOUSELOOK_ICON_OFF = "Interface\\Icons\\Ability_Stealth"
local MOUSELOOK_ICON_MOVE = "Interface\\Icons\\Ability_Rogue_Sprint"
local MOUSELOOK_ICON_ON = "Interface\\Icons\\Ability_Hunter_EagleEye"

local BLUE_BORDER = { 0.22, 0.66, 0.98, 0.92 }
local GOLD_BORDER = { 0.96, 0.8, 0.22, 0.96 }
local DIM_BORDER = { 0.34, 0.4, 0.5, 0.85 }
local KEYRING_BORDER = { 0.88, 0.68, 0.22, 0.96 }
local LOCKED_BORDER = { 0.72, 0.26, 0.26, 0.95 }
local BLIZZARD_BANK_FRAME_NAMES = {
    "BankFrame",
    "BankSlotsFrame",
}

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

local function RaiseStackSplitFrame()
    local split = StackSplitFrame
    if not split then
        return
    end

    split:SetToplevel(true)
    split:SetFrameStrata("TOOLTIP")
    local currentLevel = split:GetFrameLevel() or 0
    if currentLevel < 200 then
        split:SetFrameLevel(200)
    end
    split:Raise()
end

local function HideBlizzardContainerFrames()
    for index = 1, 13 do
        local frame = _G["ContainerFrame" .. tostring(index)]
        if frame and frame:IsShown() then
            frame:Hide()
        end
    end
end

local function safeContainerIDToInventoryID(bagID)
    local id = tonumber(bagID)
    if not id or id <= 0 then
        return nil
    end
    if ContainerIDToInventoryID then
        local ok, invSlot = pcall(ContainerIDToInventoryID, id)
        if ok then
            return invSlot
        end
    end
    return 19 + id
end

local function isBankBagID(bagID)
    local id = tonumber(bagID)
    return id and id >= 5 and id <= 11
end

local function getBankBagSlotIndex(bagID)
    local id = tonumber(bagID)
    if not id then
        return nil
    end
    return id - 4
end

local function getPurchasedBankBagSlotCount()
    if not GetNumBankSlots then
        return 0
    end
    return tonumber(GetNumBankSlots()) or 0
end

local function isBankBagSlotPurchased(bagID)
    if not isBankBagID(bagID) then
        return true
    end
    local slotIndex = getBankBagSlotIndex(bagID)
    if not slotIndex then
        return false
    end
    return slotIndex <= getPurchasedBankBagSlotCount()
end

local function getNextBankBagSlotForPurchase()
    local purchased = getPurchasedBankBagSlotCount()
    local nextIndex = purchased + 1
    if nextIndex > 7 then
        return nil
    end
    return nextIndex + 4
end

local function getBankBagSlotPurchaseCost()
    if not GetBankSlotCost then
        return nil
    end
    local cost = tonumber(GetBankSlotCost())
    if not cost or cost <= 0 then
        return nil
    end
    return cost
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

local function getControllerMouseLookUiMode()
    if GPX and GPX.GetControllerMouseLookMode then
        return GPX:GetControllerMouseLookMode()
    end

    local cfg = GPX and GPX.GetControllerConfig and GPX:GetControllerConfig() or nil
    if cfg and cfg.mouseLookMode == "platformer" then
        return "on"
    end
    return "move"
end

local function getMouseLookModeMeta(mode)
    if mode == "off" then
        return "Off", MOUSELOOK_ICON_OFF, "Mouselook disabled"
    end
    if mode == "on" then
        return "On", MOUSELOOK_ICON_ON, "Always-on mouselook"
    end
    return "Move", MOUSELOOK_ICON_MOVE, "Starts/stops with movement"
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
    if bagID == KEYRING_BAG_ID then
        return "Keyring"
    end
    if bagID == BANK_CONTAINER_ID then
        return "Bank"
    end
    if bagID == 0 then
        return "Backpack"
    end
    if type(bagID) == "number" and bagID >= 5 then
        return "Bank Bag " .. tostring(bagID - 4)
    end
    return "Bag " .. tostring(bagID)
end

local function getBagShortLabel(bagID)
    if bagID == KEYRING_BAG_ID then
        return "Key"
    end
    if bagID == BANK_CONTAINER_ID then
        return "Bank"
    end
    if bagID == 0 then
        return "BP"
    end
    if type(bagID) == "number" and bagID >= 5 then
        return "B" .. tostring(bagID - 4)
    end
    return tostring(bagID)
end

local function collectPlayerBagIDs()
    local bagIDs = { 0, 1, 2, 3, 4 }
    return bagIDs
end

local function collectBankBagIDs()
    local bagIDs = { BANK_CONTAINER_ID }
    for bagID = 5, 11 do
        bagIDs[#bagIDs + 1] = bagID
    end
    return bagIDs
end

local function bagIDExistsInList(list, bagID)
    for _, id in ipairs(list or {}) do
        if id == bagID then
            return true
        end
    end
    return false
end

local function normalizeSelectedBagID(selectedBagID, availableBagIDs)
    -- Only keep selection if bag is actually available this refresh
    -- This prevents stale selections from locking the view
    if selectedBagID == nil then
        return nil
    end
    if bagIDExistsInList(availableBagIDs, selectedBagID) then
        return selectedBagID
    end
    return nil
end

local function toggleSelectedBagID(currentSelected, clickedBagID)
    -- clicking the same bag deselects (returns to show-all), clicking another selects
    if currentSelected == clickedBagID then
        return nil
    end
    return clickedBagID
end

local function isJunkItem(itemLink)
    if not itemLink or not GetItemInfo then
        return false, 0
    end
    local _, _, quality, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemLink)
    if tonumber(quality) == 0 and (tonumber(sellPrice) or 0) > 0 then
        return true, tonumber(sellPrice) or 0
    end
    return false, 0
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

local function formatWatchedCurrenciesText(watched, maxEntries, separator)
    if not watched or #watched == 0 then
        return ""
    end

    local sep = separator or "  "
    local limit = tonumber(maxEntries) or #watched
    if limit < 1 then
        limit = 1
    end
    if limit > #watched then
        limit = #watched
    end

    local parts = {}
    for index = 1, limit do
        local entry = watched[index]
        parts[#parts + 1] = tostring(entry.name or "Currency") .. ": " .. tostring(tonumber(entry.count) or 0)
    end

    local extra = #watched - limit
    if extra > 0 then
        parts[#parts + 1] = "+" .. tostring(extra) .. " more"
    end

    return table.concat(parts, sep)
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
        bagWindowPoint = {
            anchor = defaultConfig.bagWindowPoint.anchor,
            relativePoint = defaultConfig.bagWindowPoint.relativePoint,
            x = defaultConfig.bagWindowPoint.x,
            y = defaultConfig.bagWindowPoint.y,
        },
        bagSlotsExpanded = defaultConfig.bagSlotsExpanded,
        selectedBagID = defaultConfig.selectedBagID,
        includeKeyRingWithBags = defaultConfig.includeKeyRingWithBags,
        selectedBankBagID = defaultConfig.selectedBankBagID,
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
    cfg.bagWindowPoint = cfg.bagWindowPoint or cloneDefaults().bagWindowPoint
    if cfg.bagSlotsExpanded == nil then cfg.bagSlotsExpanded = defaultConfig.bagSlotsExpanded end
    if cfg.selectedBagID == nil then cfg.selectedBagID = defaultConfig.selectedBagID end
    if cfg.includeKeyRingWithBags == nil then cfg.includeKeyRingWithBags = defaultConfig.includeKeyRingWithBags end
    if cfg.selectedBankBagID == nil then cfg.selectedBankBagID = defaultConfig.selectedBankBagID end

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

    local mouseLookButton = CreateFrame("Button", "WoWXUtilityMouseLookButton", frame)
    mouseLookButton:SetWidth(BAG_BUTTON_SIZE)
    mouseLookButton:SetHeight(BAG_BUTTON_SIZE)
    mouseLookButton:RegisterForClicks("LeftButtonUp")
    if mouseLookButton.SetNormalTexture then mouseLookButton:SetNormalTexture(nil) end
    if mouseLookButton.SetPushedTexture then mouseLookButton:SetPushedTexture(nil) end
    if mouseLookButton.SetHighlightTexture then mouseLookButton:SetHighlightTexture(nil) end
    if mouseLookButton.SetDisabledTexture then mouseLookButton:SetDisabledTexture(nil) end

    ensureSlotChrome(mouseLookButton, BLUE_BORDER)
    if mouseLookButton._slotBg then
        mouseLookButton._slotBg:SetVertexColor(0.06, 0.08, 0.12, 0.14)
    end

    local mouseLookIcon = mouseLookButton:CreateTexture(nil, "ARTWORK", nil, 1)
    mouseLookIcon:SetPoint("TOPLEFT", mouseLookButton, "TOPLEFT", BAG_ICON_INSET, -BAG_ICON_INSET)
    mouseLookIcon:SetPoint("BOTTOMRIGHT", mouseLookButton, "BOTTOMRIGHT", -BAG_ICON_INSET, BAG_ICON_INSET)
    mouseLookIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    mouseLookIcon:SetTexture(MOUSELOOK_ICON_MOVE)

    local mouseLookLabel = mouseLookButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mouseLookLabel:SetPoint("TOP", mouseLookButton, "BOTTOM", 0, -1)
    mouseLookLabel:SetText("Look")
    mouseLookLabel:SetTextColor(0.72, 0.9, 1.0)

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
        GameTooltip:AddLine("Keyring is available as a bag selector inside WoWX Bags.", 0.86, 0.9, 1.0)
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
        Buttons:ToggleBagWindow()
    end)

    mouseLookButton:SetScript("OnEnter", function(selfBtn)
        GameTooltip:SetOwner(selfBtn, "ANCHOR_TOP")
        local mode = getControllerMouseLookUiMode()
        local label, _, detail = getMouseLookModeMeta(mode)
        GameTooltip:SetText("Controller Mouselook", 0.75, 0.9, 1.0)
        GameTooltip:AddLine("Current: " .. label, 1.0, 0.92, 0.58)
        GameTooltip:AddLine(detail, 0.86, 0.9, 1.0)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click to cycle: Off -> Move -> On", 0.82, 0.9, 1.0)
        GameTooltip:Show()
    end)
    mouseLookButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    mouseLookButton:SetScript("OnClick", function()
        if not (GPX and GPX.IsControllerEnabled and GPX:IsControllerEnabled()) then
            GPX:Print("Controller mode is disabled.")
            return
        end

        local mode = nil
        if GPX and GPX.CycleControllerMouseLookMode then
            mode = GPX:CycleControllerMouseLookMode()
        else
            local cfg = GPX:GetControllerConfig()
            if cfg.mouseLookMode == "platformer" then
                GPX:SetControllerMouseLookMode("move")
                mode = "move"
            else
                GPX:SetControllerMouseLookMode("platformer")
                mode = "on"
            end
        end

        Buttons:RefreshMouseLookButton()
        if GPX.SettingsUI and GPX.SettingsUI.frame and GPX.SettingsUI.frame:IsShown() then
            GPX.SettingsUI:Refresh()
        end

        local modeLabel = getMouseLookModeMeta(mode)
        GPX:Print("Controller mouselook: " .. tostring(modeLabel))
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
    self.mouseLookButton = mouseLookButton
    self.mouseLookIcon = mouseLookIcon
    self.mouseLookLabel = mouseLookLabel

    self:ApplyBagButtonLayout()
    self:RefreshEconomyText()
    self:RefreshBagButtonChrome(true)
    self:RefreshMouseLookButton()
end

function Buttons:RefreshMouseLookButton()
    if not self.mouseLookButton then
        return
    end

    local show = GPX and GPX.IsControllerEnabled and GPX:IsControllerEnabled()
    self.mouseLookButton:SetShown(show)

    if not show then
        return
    end

    local mode = getControllerMouseLookUiMode()
    local label, icon, _ = getMouseLookModeMeta(mode)
    if self.mouseLookIcon then
        self.mouseLookIcon:SetTexture(icon)
        self.mouseLookIcon:SetDesaturated(mode == "off")
    end
    if self.mouseLookLabel then
        self.mouseLookLabel:SetText(label)
        if mode == "off" then
            self.mouseLookLabel:SetTextColor(0.88, 0.68, 0.68)
        elseif mode == "on" then
            self.mouseLookLabel:SetTextColor(0.72, 1.0, 0.72)
        else
            self.mouseLookLabel:SetTextColor(0.72, 0.9, 1.0)
        end
    end
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
    local showMouseLook = self.mouseLookButton and self.mouseLookButton:IsShown()
    local frameWidth = (buttonSize + (framePadding * 2))
    if showMouseLook then
        frameWidth = (buttonSize * 2) + UTILITY_BUTTON_GAP + (framePadding * 2)
    end
    local frameHeight = buttonSize + (framePadding * 2) + (textRows * labelHeight) + (math.max(0, textRows - 1) * textSpacing)

    self.frame:SetWidth(frameWidth)
    self.frame:SetHeight(frameHeight)

    self.bagButton:SetWidth(buttonSize)
    self.bagButton:SetHeight(buttonSize)
    self.bagButton:ClearAllPoints()
    if showMouseLook then
        self.bagButton:SetPoint("TOPLEFT", self.frame, "TOPLEFT", framePadding, -framePadding)
    else
        self.bagButton:SetPoint("TOP", self.frame, "TOP", 0, -framePadding)
    end

    if self.mouseLookButton then
        self.mouseLookButton:SetWidth(buttonSize)
        self.mouseLookButton:SetHeight(buttonSize)
        self.mouseLookButton:ClearAllPoints()
        if showMouseLook then
            self.mouseLookButton:SetPoint("TOPLEFT", self.bagButton, "TOPRIGHT", UTILITY_BUTTON_GAP, 0)
            self.mouseLookButton:Show()
        else
            self.mouseLookButton:Hide()
        end
    end

    if self.editButton then
        self.editButton:ClearAllPoints()
        if showMouseLook and self.mouseLookButton then
            self.editButton:SetPoint("BOTTOMLEFT", self.mouseLookButton, "TOPRIGHT", 2, -6)
        else
            self.editButton:SetPoint("BOTTOMLEFT", self.bagButton, "TOPRIGHT", 2, -6)
        end
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

    if self.mouseLookLabel and self.mouseLookButton then
        self.mouseLookLabel:ClearAllPoints()
        self.mouseLookLabel:SetPoint("TOP", self.mouseLookButton, "BOTTOM", 0, -textSpacing)
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
    if self.mouseLookButton and self.mouseLookButton._border then
        setStrokeColor(self.mouseLookButton._border, c[1], c[2], c[3], 1.0)
    end
    if self.mouseLookButton and self.mouseLookButton._borderTint then
        setStrokeColor(self.mouseLookButton._borderTint, c[1], c[2], c[3], 0.18)
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
    if self.mouseLookLabel then
        if locked then
            self.mouseLookLabel:SetTextColor(0.72, 0.9, 1.0)
        else
            self:RefreshMouseLookButton()
        end
    end
end

function Buttons:SetBlizzardBankSuppressed(suppressed)
    self._bankSuppressedState = self._bankSuppressedState or {}
    for _, frameName in ipairs(BLIZZARD_BANK_FRAME_NAMES) do
        local frame = _G[frameName]
        if frame then
            local state = self._bankSuppressedState[frameName] or {}
            self._bankSuppressedState[frameName] = state
            if suppressed then
                if state.alpha == nil and frame.GetAlpha then
                    state.alpha = frame:GetAlpha()
                end
                if state.mouseEnabled == nil and frame.IsMouseEnabled then
                    state.mouseEnabled = frame:IsMouseEnabled()
                end
                if frame.SetAlpha then
                    frame:SetAlpha(0)
                end
                if frame.EnableMouse then
                    frame:EnableMouse(false)
                end
            else
                if frame.SetAlpha then
                    frame:SetAlpha(state.alpha or 1)
                end
                if frame.EnableMouse then
                    frame:EnableMouse(state.mouseEnabled ~= false)
                end
            end
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
    local invSlot = safeContainerIDToInventoryID(bagID)
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
        local cfg = ensureConfig()
        if not cfg then
            return
        end
        if selfBtn._isBankSelector then
            if isBankBagID(selfBtn._bagID) and not isBankBagSlotPurchased(selfBtn._bagID) then
                if not Buttons._bankIsOpen then
                    GPX:Print("Open the bank before buying slots.")
                    return
                end
                local nextBagID = getNextBankBagSlotForPurchase()
                if nextBagID ~= selfBtn._bagID then
                    GPX:Print("Unlock bank slots in order.")
                    return
                end
                if BuyBankSlot then
                    local ok, err = pcall(BuyBankSlot)
                    if not ok then
                        GPX:Print("Unable to buy bank slot: " .. tostring(err))
                    end
                end
                Buttons:RefreshBankWindow()
                return
            end
            cfg.selectedBankBagID = toggleSelectedBagID(cfg.selectedBankBagID, selfBtn._bagID)
            Buttons:RefreshBankWindow()
        elseif selfBtn._bagID == KEYRING_BAG_ID then
            cfg.includeKeyRingWithBags = not (cfg.includeKeyRingWithBags == true)
            Buttons:RefreshBagWindow()
        else
            cfg.selectedBagID = toggleSelectedBagID(cfg.selectedBagID, selfBtn._bagID)
            Buttons:RefreshBagWindow()
        end
    end)
    button:SetScript("OnReceiveDrag", function()
        return
    end)
    button:SetScript("OnEnter", function(selfBtn)
        if GameTooltip then
            GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
            if selfBtn._bagID == 0 then
                GameTooltip:SetText("Backpack", 1, 0.82, 0.2)
            elseif selfBtn._bagID == KEYRING_BAG_ID then
                GameTooltip:SetText("Keyring", 1, 0.82, 0.2)
            elseif GameTooltip.SetInventoryItem and selfBtn._invSlot then
                GameTooltip:SetInventoryItem("player", selfBtn._invSlot)
            end
            local slotCount = GetContainerNumSlots and (GetContainerNumSlots(selfBtn._bagID) or 0) or 0
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(getBagLabel(selfBtn._bagID) .. " slots: " .. tostring(slotCount), 0.86, 0.9, 1.0)
            if selfBtn._isBankSelector and isBankBagID(selfBtn._bagID) and not isBankBagSlotPurchased(selfBtn._bagID) then
                local nextBagID = getNextBankBagSlotForPurchase()
                if nextBagID == selfBtn._bagID then
                    local cost = getBankBagSlotPurchaseCost()
                    if cost then
                        GameTooltip:AddLine("Left-click to unlock for " .. formatMoneyText(cost) .. ".", 1.0, 0.82, 0.18)
                    else
                        GameTooltip:AddLine("Left-click to unlock this slot.", 1.0, 0.82, 0.18)
                    end
                else
                    GameTooltip:AddLine("Unlock previous bank slots first.", 0.95, 0.48, 0.48)
                end
            end
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
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    ensureSlotChrome(button, DIM_BORDER)
    
    -- ContainerFrameItemButtonTemplate creates: icon, Count, Stock, etc.
    button._icon = _G[button:GetName() .. "IconTexture"] or button.icon
    button._count = _G[button:GetName() .. "Count"] or button.Count

    -- Fallback if template did not create icon as expected
    if not button._icon and button.icon then
        button._icon = button.icon
    end

    local keyRingGlow = button:CreateTexture(nil, "OVERLAY")
    keyRingGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    keyRingGlow:SetBlendMode("ADD")
    keyRingGlow:SetPoint("CENTER", button, "CENTER", 0, 1)
    keyRingGlow:SetWidth(58)
    keyRingGlow:SetHeight(58)
    keyRingGlow:SetVertexColor(1.0, 0.82, 0.22, 0.0)
    keyRingGlow:Hide()
    button._keyRingGlow = keyRingGlow
    
    -- Keep template's default click/drag handling, just override tooltip
    button:SetScript("OnEnter", function(selfBtn)
        local bagID = selfBtn:GetParent():GetID()
        local slot = selfBtn:GetID()
        if bagID and slot and GameTooltip and GameTooltip.SetBagItem then
            GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
            GameTooltip:SetBagItem(bagID, slot)
            GameTooltip:Show()
        end
        Buttons:SetBagHighlight(bagID)
    end)
    
    button:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
        Buttons:SetBagHighlight(nil)
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
    frame:SetHeight(460)
    local cfg = ensureConfig()
    local bagPoint = (cfg and cfg.bagWindowPoint) or defaultConfig.bagWindowPoint
    frame:SetPoint(
        bagPoint.anchor or "CENTER",
        UIParent,
        bagPoint.relativePoint or "CENTER",
        tonumber(bagPoint.x) or 120,
        tonumber(bagPoint.y) or -20
    )
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(selfFrame)
        selfFrame:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
        local cfgInner = ensureConfig()
        if cfgInner then
            local anchor, _, relativePoint, x, y = selfFrame:GetPoint(1)
            cfgInner.bagWindowPoint = {
                anchor = anchor or "CENTER",
                relativePoint = relativePoint or "CENTER",
                x = x or 120,
                y = y or -20,
            }
        end
    end)
    applyBlueChromeBackdrop(frame, BLUE_BORDER)
    frame:Hide()

    if not self._stackSplitHookInstalled and hooksecurefunc then
        hooksecurefunc("OpenStackSplitFrame", function()
            RaiseStackSplitFrame()
        end)
        self._stackSplitHookInstalled = true
    end

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
    title:SetText("WoWX Bags")

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

    local controls = CreateFrame("Frame", nil, frame)
    controls:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -40)
    controls:SetWidth(420)
    controls:SetHeight(62)

    local bagSlotsToggle = CreateFrame("Button", nil, controls, "UIPanelButtonTemplate")
    bagSlotsToggle:SetPoint("LEFT", controls, "LEFT", 0, 0)
    bagSlotsToggle:SetWidth(120)
    bagSlotsToggle:SetHeight(22)

    local sellJunkButton = CreateFrame("Button", nil, controls, "UIPanelButtonTemplate")
    sellJunkButton:SetPoint("LEFT", bagSlotsToggle, "RIGHT", 8, 0)
    sellJunkButton:SetWidth(120)
    sellJunkButton:SetHeight(22)
    sellJunkButton:SetText("Sell Junk")

    local bagMoney = controls:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bagMoney:SetPoint("TOPLEFT", controls, "TOPLEFT", 2, -26)
    bagMoney:SetText("")
    bagMoney:SetTextColor(1.0, 0.82, 0.18)

    local bagCurrency = controls:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bagCurrency:SetPoint("TOPLEFT", bagMoney, "BOTTOMLEFT", 0, -2)
    bagCurrency:SetWidth(400)
    bagCurrency:SetJustifyH("LEFT")
    bagCurrency:SetJustifyV("TOP")
    bagCurrency:SetText("")
    bagCurrency:SetTextColor(0.75, 0.9, 1.0)

    bagSlotsToggle:SetScript("OnClick", function()
        local cfg = ensureConfig()
        if not cfg then
            return
        end
        cfg.bagSlotsExpanded = not (cfg.bagSlotsExpanded == true)
        Buttons:RefreshBagWindow()
    end)

    sellJunkButton:SetScript("OnClick", function()
        Buttons:SellAllJunkToMerchant()
    end)

    local bagSlotRow = CreateFrame("Frame", nil, frame)
    bagSlotRow:SetPoint("TOPLEFT", controls, "BOTTOMLEFT", 0, -4)
    bagSlotRow:SetWidth(420)
    bagSlotRow:SetHeight(38)

    self.bagSlotButtons = {}
    for _, bagID in ipairs(collectPlayerBagIDs()) do
        local slotButton = self:CreateBagSlotButton(bagSlotRow, bagID)
        slotButton:SetPoint("LEFT", bagSlotRow, "LEFT", (#self.bagSlotButtons) * 46, 0)
        self.bagSlotButtons[#self.bagSlotButtons + 1] = slotButton

        local label = bagSlotRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOP", slotButton, "BOTTOM", 0, -1)
        label:SetText(getBagShortLabel(bagID))
    end

    if KEYRING_BAG_ID then
        local keyButton = self:CreateBagSlotButton(bagSlotRow, KEYRING_BAG_ID)
        keyButton:SetPoint("LEFT", bagSlotRow, "LEFT", (#self.bagSlotButtons) * 46, 0)
        self.keyRingSlotButton = keyButton

        local keyLabel = bagSlotRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        keyLabel:SetPoint("TOP", keyButton, "BOTTOM", 0, -1)
        keyLabel:SetText(getBagShortLabel(KEYRING_BAG_ID))
    end

    local grid = CreateFrame("Frame", nil, frame)
    grid:SetPoint("TOPLEFT", controls, "BOTTOMLEFT", 0, -8)
    grid:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 20)
    applyBlueChromeBackdrop(grid, DIM_BORDER)

    self.itemButtons = self.itemButtons or {}

    frame._wowxControls = controls
    frame._wowxMoney = bagMoney
    frame._wowxCurrency = bagCurrency
    frame._wowxBagSlotsToggle = bagSlotsToggle
    frame._wowxSellJunkButton = sellJunkButton
    frame._wowxBagSlotRow = bagSlotRow
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

    local entries = {}
    local cfg = ensureConfig()
    local bagSlotsExpanded = cfg and cfg.bagSlotsExpanded == true
    local includeKeyRingWithBags = cfg and cfg.includeKeyRingWithBags == true
    local bagIDs = collectPlayerBagIDs()
    -- Don't write-back normalize into cfg; only validate for display
    local selectedBagID = normalizeSelectedBagID(cfg and cfg.selectedBagID or nil, bagIDs)

    if frame._wowxMoney then
        frame._wowxMoney:SetText("Money: " .. formatMoneyText(GetMoney and GetMoney() or 0))
    end
    if frame._wowxCurrency then
        local watched = collectWatchedCurrencies()
        frame._wowxCurrency:SetText(formatWatchedCurrenciesText(watched, 6, "   "))
    end

    for _, bagID in ipairs(bagIDs) do
        local slotCount = GetContainerNumSlots and (GetContainerNumSlots(bagID) or 0) or 0
        if selectedBagID == nil or selectedBagID == bagID then
            for slot = 1, slotCount do
                local texture, itemCount, locked, quality = GetContainerItemInfo(bagID, slot)
                entries[#entries + 1] = {
                    bagID = bagID,
                    slot = slot,
                    texture = texture,
                    count = tonumber(itemCount) or 0,
                    locked = locked,
                    quality = tonumber(quality) or 1,
                    isKeyRing = false,
                }
            end
        end
    end

    if includeKeyRingWithBags and KEYRING_BAG_ID then
        local keySlotCount = GetContainerNumSlots and (GetContainerNumSlots(KEYRING_BAG_ID) or 0) or 0
        for slot = 1, keySlotCount do
            local texture, itemCount, locked, quality = GetContainerItemInfo(KEYRING_BAG_ID, slot)
            -- Append only occupied keyring slots so keyring grows the grid without empty placeholders.
            if texture then
                entries[#entries + 1] = {
                    bagID = KEYRING_BAG_ID,
                    slot = slot,
                    texture = texture,
                    count = tonumber(itemCount) or 0,
                    locked = locked,
                    quality = tonumber(quality) or 1,
                    isKeyRing = true,
                }
            end
        end
    end

    if frame._wowxBagSlotRow then
        frame._wowxBagSlotRow:SetShown(bagSlotsExpanded)
    end
    if frame._wowxBagSlotsToggle then
        frame._wowxBagSlotsToggle:SetText(bagSlotsExpanded and "Bags: Hide" or "Bags: Show")
    end
    if frame._wowxSellJunkButton then
        frame._wowxSellJunkButton:SetEnabled(MerchantFrame and MerchantFrame:IsShown())
    end

    if frame._wowxGrid then
        frame._wowxGrid:ClearAllPoints()
        if bagSlotsExpanded and frame._wowxBagSlotRow then
            frame._wowxGrid:SetPoint("TOPLEFT", frame._wowxBagSlotRow, "BOTTOMLEFT", 0, -22)
        elseif frame._wowxControls then
            frame._wowxGrid:SetPoint("TOPLEFT", frame._wowxControls, "BOTTOMLEFT", 0, -8)
        else
            frame._wowxGrid:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -66)
        end
        frame._wowxGrid:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 20)
    end

    local rows = math.ceil((#entries > 0 and #entries or 1) / ITEM_BUTTON_COLUMNS)
    local minRows = 4
    if rows < minRows then
        rows = minRows
    end
    local gridHeight = ITEM_GRID_PADDING * 2 + (rows * ITEM_BUTTON_SIZE) + ((rows - 1) * ITEM_BUTTON_GAP)
    -- topInset must match actual anchored offsets used by controls/grid points.
    -- Collapsed: grid top at -110 and bottom inset is 20 => 130.
    -- Expanded:  grid top at -166 and bottom inset is 20 => 186.
    local topInset = bagSlotsExpanded and 186 or 130
    local minWindowHeight = 320
    local parentHeight = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 900
    local maxWindowHeight = math.floor(parentHeight - 120)
    if maxWindowHeight < minWindowHeight then
        maxWindowHeight = minWindowHeight
    end
    local windowHeight = clamp(topInset + gridHeight, minWindowHeight, maxWindowHeight)
    -- Clamp grid to actual available space so it never escapes the window
    local availableGridHeight = windowHeight - topInset
    if gridHeight > availableGridHeight then
        gridHeight = availableGridHeight
    end
    if frame._wowxGrid then
        frame._wowxGrid:SetHeight(gridHeight)
    end
    frame:SetHeight(windowHeight)

    for index, slotButton in ipairs(self.bagSlotButtons or {}) do
        local bagID = bagIDs[index]
        local invSlot = safeContainerIDToInventoryID(bagID)
        local texture = nil
        if bagID == 0 then
            texture = "Interface\\Icons\\INV_Misc_Bag_08"
        elseif bagID == KEYRING_BAG_ID then
            texture = "Interface\\Icons\\INV_Misc_Key_14"
        else
            texture = invSlot and GetInventoryItemTexture("player", invSlot)
        end
        if slotButton and slotButton._icon then
            slotButton._icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_Bag_08")
        end
        if slotButton then
            slotButton._invSlot = invSlot
            local active = selectedBagID ~= nil and bagID == selectedBagID
            if slotButton._borderTint then
                if active then
                    setStrokeColor(slotButton._borderTint, 0.22, 0.9, 0.36, 0.5)
                else
                    setStrokeColor(slotButton._borderTint, 0.0, 0.0, 0.0, 0.0)
                end
            end
        end
    end

    if self.keyRingSlotButton and self.keyRingSlotButton._icon then
        self.keyRingSlotButton._icon:SetTexture("Interface\\Icons\\INV_Misc_Key_14")
    end
    if self.keyRingSlotButton and self.keyRingSlotButton._borderTint then
        if includeKeyRingWithBags then
            setStrokeColor(self.keyRingSlotButton._borderTint, 0.98, 0.82, 0.24, 0.55)
        else
            setStrokeColor(self.keyRingSlotButton._borderTint, 0.0, 0.0, 0.0, 0.0)
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
            if GPX.ClickTransport and GPX.ClickTransport.ApplyBagItemUse then
                GPX.ClickTransport:ApplyBagItemUse(button, info.bagID, info.slot)
            end
        end
        button._bagID = info.bagID
        
        if info.spacer then
            button:Hide()
        else
            local qualityColor = nil
            if info.quality and info.quality > 1 and GetItemQualityColor then
                local r, g, b = GetItemQualityColor(info.quality)
                if r and g and b then
                    qualityColor = { r, g, b, 0.95 }
                end
            end
            if info.isKeyRing then
                button._baseBorderColor = KEYRING_BORDER
            else
                button._baseBorderColor = qualityColor or { 0.38, 0.44, 0.54, 0.85 }
            end
            if button._border then
                setStrokeColor(button._border, button._baseBorderColor[1], button._baseBorderColor[2], button._baseBorderColor[3], button._baseBorderColor[4])
            end
            if button._borderTint then
                setStrokeColor(button._borderTint, 0.0, 0.0, 0.0, 0.0)
            end

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

            if button._keyRingGlow then
                button._keyRingGlow:Hide()
            end
        end
    end

    for i = #entries + 1, #self.itemButtons do
        if self.itemButtons[i]._keyRingGlow then
            self.itemButtons[i]._keyRingGlow:Hide()
        end
        self.itemButtons[i]:Hide()
    end

    self:SetBagHighlight(nil)
end

function Buttons:SellAllJunkToMerchant()
    if InCombatLockdown() then
        GPX:Print("Cannot sell junk in combat.")
        return
    end
    if not (MerchantFrame and MerchantFrame:IsShown()) then
        GPX:Print("Open a merchant before selling junk.")
        return
    end

    local soldCount = 0
    local soldValue = 0
    for bagID = 0, 4 do
        local slots = GetContainerNumSlots and (GetContainerNumSlots(bagID) or 0) or 0
        for slot = 1, slots do
            local texture, itemCount, locked = GetContainerItemInfo(bagID, slot)
            if texture and not locked and GetContainerItemLink then
                local link = GetContainerItemLink(bagID, slot)
                local junk, sellPrice = isJunkItem(link)
                if junk and UseContainerItem then
                    local count = tonumber(itemCount) or 1
                    pcall(UseContainerItem, bagID, slot)
                    soldCount = soldCount + count
                    soldValue = soldValue + (sellPrice * count)
                end
            end
        end
    end

    if soldCount > 0 then
        GPX:Print("Sold junk: " .. tostring(soldCount) .. " item(s) for " .. formatMoneyText(soldValue) .. ".")
    else
        GPX:Print("No junk items to sell.")
    end

    if self.bagWindow and self.bagWindow:IsShown() then
        self:RefreshBagWindow()
    end
end

function Buttons:EnsureBankWindow()
    if self.bankWindow then
        return self.bankWindow
    end

    local contentWidth = ITEM_BUTTON_COLUMNS * ITEM_BUTTON_SIZE + (ITEM_BUTTON_COLUMNS - 1) * ITEM_BUTTON_GAP
    local bankWindowWidth = 16 + ITEM_GRID_PADDING * 2 + contentWidth + 20
    local frame = CreateFrame("Frame", "WoWXBankWindow", UIParent)
    frame:SetWidth(bankWindowWidth)
    frame:SetHeight(460)
    frame:SetPoint("CENTER", UIParent, "CENTER", -120, -20)
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
    title:SetText("WoWX Bank")

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

    local controls = CreateFrame("Frame", nil, frame)
    controls:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -40)
    controls:SetWidth(420)
    controls:SetHeight(62)

    local bankSlotsToggle = CreateFrame("Button", nil, controls, "UIPanelButtonTemplate")
    bankSlotsToggle:SetPoint("LEFT", controls, "LEFT", 0, 0)
    bankSlotsToggle:SetWidth(120)
    bankSlotsToggle:SetHeight(22)
    bankSlotsToggle:SetText("Bags: Show")
    bankSlotsToggle:SetScript("OnClick", function()
        local cfg = ensureConfig()
        if not cfg then
            return
        end
        cfg.bagSlotsExpanded = not (cfg.bagSlotsExpanded == true)
        Buttons:RefreshBankWindow()
    end)

    local buySlotButton = CreateFrame("Button", nil, controls, "UIPanelButtonTemplate")
    buySlotButton:SetPoint("LEFT", bankSlotsToggle, "RIGHT", 8, 0)
    buySlotButton:SetWidth(120)
    buySlotButton:SetHeight(22)
    buySlotButton:SetText("Buy Slot")
    buySlotButton:SetScript("OnClick", function()
        local nextBagID = getNextBankBagSlotForPurchase()
        if not Buttons._bankIsOpen then
            GPX:Print("Open the bank before buying slots.")
            return
        end
        if not nextBagID then
            GPX:Print("All bank bag slots are already unlocked.")
            return
        end
        if not BuyBankSlot then
            GPX:Print("This client does not support bank slot purchase API.")
            return
        end
        local ok, err = pcall(BuyBankSlot)
        if not ok then
            GPX:Print("Unable to buy bank slot: " .. tostring(err))
        end
        Buttons:RefreshBankWindow()
    end)

    local buySlotCost = controls:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    buySlotCost:SetPoint("TOPLEFT", controls, "TOPLEFT", 2, -26)
    buySlotCost:SetText("")
    buySlotCost:SetTextColor(1.0, 0.82, 0.18)

    local bagSlotRow = CreateFrame("Frame", nil, frame)
    bagSlotRow:SetPoint("TOPLEFT", controls, "BOTTOMLEFT", 0, -4)
    bagSlotRow:SetWidth(420)
    bagSlotRow:SetHeight(38)

    self.bankBagSlotButtons = {}
    for _, bagID in ipairs(collectBankBagIDs()) do
        local slotButton = self:CreateBagSlotButton(bagSlotRow, bagID)
        slotButton._isBankSelector = true
        slotButton:SetPoint("LEFT", bagSlotRow, "LEFT", (#self.bankBagSlotButtons) * 46, 0)
        self.bankBagSlotButtons[#self.bankBagSlotButtons + 1] = slotButton

        local label = bagSlotRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOP", slotButton, "BOTTOM", 0, -1)
        label:SetText(getBagShortLabel(bagID))
    end

    local grid = CreateFrame("Frame", nil, frame)
    grid:SetPoint("TOPLEFT", controls, "BOTTOMLEFT", 0, -8)
    grid:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 20)
    applyBlueChromeBackdrop(grid, DIM_BORDER)

    self.bankItemButtons = self.bankItemButtons or {}

    frame._wowxControls = controls
    frame._wowxBagSlotsToggle = bankSlotsToggle
    frame._wowxBuySlotButton = buySlotButton
    frame._wowxBuySlotCost = buySlotCost
    frame._wowxBagSlotRow = bagSlotRow
    frame._wowxGrid = grid

    self.bankWindow = frame
    registerAsEscapeClosable("WoWXBankWindow")
    return frame
end

function Buttons:RefreshBankWindow()
    local frame = self:EnsureBankWindow()
    if not frame then
        return
    end

    local cfg = ensureConfig()
    local bagSlotsExpanded = cfg and cfg.bagSlotsExpanded == true
    local bagIDs = collectBankBagIDs()
    local selectedBagID = normalizeSelectedBagID(cfg and cfg.selectedBankBagID or nil, bagIDs)

    local entries = {}
    for _, bagID in ipairs(bagIDs) do
        local slotCount = GetContainerNumSlots and (GetContainerNumSlots(bagID) or 0) or 0
        if selectedBagID == nil or selectedBagID == bagID then
            for slot = 1, slotCount do
                local texture, itemCount, locked, quality = GetContainerItemInfo(bagID, slot)
                entries[#entries + 1] = {
                    bagID = bagID,
                    slot = slot,
                    texture = texture,
                    count = tonumber(itemCount) or 0,
                    locked = locked,
                    quality = tonumber(quality) or 1,
                }
            end
        end
    end

    if frame._wowxBagSlotRow then
        frame._wowxBagSlotRow:SetShown(bagSlotsExpanded)
    end
    if frame._wowxBagSlotsToggle then
        frame._wowxBagSlotsToggle:SetText(bagSlotsExpanded and "Bags: Hide" or "Bags: Show")
    end
    if frame._wowxBuySlotButton then
        local nextBagID = getNextBankBagSlotForPurchase()
        frame._wowxBuySlotButton:SetEnabled(self._bankIsOpen and nextBagID ~= nil)
        if nextBagID then
            frame._wowxBuySlotButton:SetText("Buy Slot " .. tostring(nextBagID - 4))
        else
            frame._wowxBuySlotButton:SetText("Slots Maxed")
        end
    end
    if frame._wowxBuySlotCost then
        local nextBagID = getNextBankBagSlotForPurchase()
        local cost = getBankBagSlotPurchaseCost()
        if nextBagID and cost then
            frame._wowxBuySlotCost:SetText("Next slot cost: " .. formatMoneyText(cost))
        elseif nextBagID then
            frame._wowxBuySlotCost:SetText("Next slot cost: unknown")
        else
            frame._wowxBuySlotCost:SetText("All bank bag slots unlocked.")
        end
    end

    if frame._wowxGrid then
        frame._wowxGrid:ClearAllPoints()
        if bagSlotsExpanded and frame._wowxBagSlotRow then
            frame._wowxGrid:SetPoint("TOPLEFT", frame._wowxBagSlotRow, "BOTTOMLEFT", 0, -22)
        elseif frame._wowxControls then
            frame._wowxGrid:SetPoint("TOPLEFT", frame._wowxControls, "BOTTOMLEFT", 0, -8)
        else
            frame._wowxGrid:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -66)
        end
        frame._wowxGrid:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 20)
    end

    local rows = math.ceil((#entries > 0 and #entries or 1) / ITEM_BUTTON_COLUMNS)
    local minRows = 4
    if rows < minRows then
        rows = minRows
    end
    local gridHeight = ITEM_GRID_PADDING * 2 + (rows * ITEM_BUTTON_SIZE) + ((rows - 1) * ITEM_BUTTON_GAP)
    -- Keep bank window sizing in sync with bag window anchor math.
    local topInset = bagSlotsExpanded and 186 or 130
    local minWindowHeight = 320
    local parentHeight = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 900
    local maxWindowHeight = math.floor(parentHeight - 120)
    if maxWindowHeight < minWindowHeight then
        maxWindowHeight = minWindowHeight
    end
    local windowHeight = clamp(topInset + gridHeight, minWindowHeight, maxWindowHeight)
    local availableGridHeight = windowHeight - topInset
    if gridHeight > availableGridHeight then
        gridHeight = availableGridHeight
    end
    if frame._wowxGrid then
        frame._wowxGrid:SetHeight(gridHeight)
    end
    frame:SetHeight(windowHeight)

    for index, slotButton in ipairs(self.bankBagSlotButtons or {}) do
        local bagID = bagIDs[index]
        local invSlot = safeContainerIDToInventoryID(bagID)
        local isPurchased = isBankBagSlotPurchased(bagID)
        local texture = nil
        if bagID == BANK_CONTAINER_ID then
            texture = "Interface\\Icons\\INV_Misc_Bag_10_Blue"
        elseif not isPurchased then
            texture = "Interface\\Icons\\INV_Misc_QuestionMark"
        else
            texture = invSlot and GetInventoryItemTexture("player", invSlot)
        end
        if slotButton and slotButton._icon then
            slotButton._icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_Bag_10_Blue")
            if not isPurchased then
                slotButton._icon:SetVertexColor(0.65, 0.65, 0.65, 1.0)
            else
                slotButton._icon:SetVertexColor(1, 1, 1, 1)
            end
        end
        if slotButton then
            slotButton._invSlot = invSlot
            local active = selectedBagID ~= nil and bagID == selectedBagID
            local nextBagID = getNextBankBagSlotForPurchase()
            if slotButton._border then
                local border = (not isPurchased and bagID == nextBagID) and GOLD_BORDER or ((not isPurchased) and LOCKED_BORDER or GOLD_BORDER)
                setStrokeColor(slotButton._border, border[1], border[2], border[3], border[4])
            end
            if slotButton._borderTint then
                if active then
                    setStrokeColor(slotButton._borderTint, 0.22, 0.9, 0.36, 0.5)
                elseif not isPurchased and bagID == nextBagID then
                    setStrokeColor(slotButton._borderTint, 0.96, 0.8, 0.22, 0.35)
                elseif not isPurchased then
                    setStrokeColor(slotButton._borderTint, 0.72, 0.26, 0.26, 0.24)
                else
                    setStrokeColor(slotButton._borderTint, 0.0, 0.0, 0.0, 0.0)
                end
            end
        end
    end

    for i = 1, #entries do
        local info = entries[i]
        local button = self.bankItemButtons[i]
        if not button then
            button = self:CreateItemButton(frame._wowxGrid)
            self.bankItemButtons[i] = button
        end

        local col = (i - 1) % ITEM_BUTTON_COLUMNS
        local row = math.floor((i - 1) / ITEM_BUTTON_COLUMNS)
        local x = ITEM_GRID_PADDING + col * (ITEM_BUTTON_SIZE + ITEM_BUTTON_GAP)
        local y = -(ITEM_GRID_PADDING + row * (ITEM_BUTTON_SIZE + ITEM_BUTTON_GAP))
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", frame._wowxGrid, "TOPLEFT", x, y)

        if info.bagID and info.slot then
            if not button._dummyParent then
                button._dummyParent = CreateFrame("Frame", nil, frame._wowxGrid)
                button:SetParent(button._dummyParent)
            end
            button._dummyParent:SetID(info.bagID)
            button:SetID(info.slot)
            if GPX.ClickTransport and GPX.ClickTransport.ApplyBagItemUse then
                GPX.ClickTransport:ApplyBagItemUse(button, info.bagID, info.slot)
            end
        end
        button._bagID = info.bagID

        local qualityColor = nil
        if info.quality and info.quality > 1 and GetItemQualityColor then
            local r, g, b = GetItemQualityColor(info.quality)
            if r and g and b then
                qualityColor = { r, g, b, 0.95 }
            end
        end
        button._baseBorderColor = qualityColor or { 0.38, 0.44, 0.54, 0.85 }
        if button._border then
            setStrokeColor(button._border, button._baseBorderColor[1], button._baseBorderColor[2], button._baseBorderColor[3], button._baseBorderColor[4])
        end
        if button._borderTint then
            setStrokeColor(button._borderTint, 0.0, 0.0, 0.0, 0.0)
        end

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
        else
            if button._icon then
                button._icon:SetTexture(nil)
            end
            if button._count then
                button._count:Hide()
            end
        end
        if button._keyRingGlow then
            button._keyRingGlow:Hide()
        end
        button:Show()
    end

    for i = #entries + 1, #self.bankItemButtons do
        if self.bankItemButtons[i]._keyRingGlow then
            self.bankItemButtons[i]._keyRingGlow:Hide()
        end
        self.bankItemButtons[i]:Hide()
    end
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
    HideBlizzardContainerFrames()
end

function Buttons:ToggleBankWindow(forceShow)
    local frame = self:EnsureBankWindow()
    if not frame then
        return
    end

    if forceShow == false then
        frame:Hide()
        self:SetBlizzardBankSuppressed(false)
        return
    end

    if forceShow ~= true and frame:IsShown() then
        frame:Hide()
        self:SetBlizzardBankSuppressed(false)
        return
    end

    self:RefreshBankWindow()
    frame:Show()
    frame:Raise()
    self:SetBlizzardBankSuppressed(true)
    HideBlizzardContainerFrames()
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
        self.currencyLabel:SetText(formatWatchedCurrenciesText(watched, 2, "  "))
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
        self:RefreshMouseLookButton()
        self:RefreshEconomyText()
        self:ApplyBagButtonLayout()
        self:RefreshBagButtonChrome()
        self.frame:Show()
    else
        self.frame:Hide()
        if self.bagWindow then
            self.bagWindow:Hide()
        end
        if self.bankWindow then
            self.bankWindow:Hide()
        end
        self:SetBlizzardBankSuppressed(false)
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
                if Buttons._bankIsOpen then
                    return
                end
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
                if Buttons._bankIsOpen then
                    return
                end
                local frame = Buttons:EnsureBagWindow()
                if frame and not frame:IsShown() then
                    Buttons:RefreshBagWindow()
                    frame:Show()
                    frame:Raise()
                    HideBlizzardContainerFrames()
                end
            else
                Buttons._originalOpenAllBags()
            end
        end
    end

    -- Some interactions (altars, special objects) call OpenBackpack/OpenBag directly.
    -- Redirect those paths too so Blizzard container windows do not open under WoWX.
    if OpenBackpack and not self._originalOpenBackpack then
        self._originalOpenBackpack = OpenBackpack
        OpenBackpack = function()
            if Buttons:GetShowState() then
                if Buttons._bankIsOpen then
                    return
                end
                local frame = Buttons:EnsureBagWindow()
                if frame and not frame:IsShown() then
                    Buttons:RefreshBagWindow()
                    frame:Show()
                    frame:Raise()
                    HideBlizzardContainerFrames()
                end
            else
                Buttons._originalOpenBackpack()
            end
        end
    end

    if OpenBag and not self._originalOpenBag then
        self._originalOpenBag = OpenBag
        OpenBag = function(_)
            if Buttons:GetShowState() then
                if Buttons._bankIsOpen then
                    return
                end
                local frame = Buttons:EnsureBagWindow()
                if frame and not frame:IsShown() then
                    Buttons:RefreshBagWindow()
                    frame:Show()
                    frame:Raise()
                    HideBlizzardContainerFrames()
                end
            else
                Buttons._originalOpenBag(_)
            end
        end
    end

    if ToggleBag and not self._originalToggleBag then
        self._originalToggleBag = ToggleBag
        ToggleBag = function(_)
            if Buttons:GetShowState() then
                Buttons:ToggleBagWindow()
            else
                Buttons._originalToggleBag(_)
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

    if CloseBackpack and not self._originalCloseBackpack then
        self._originalCloseBackpack = CloseBackpack
        CloseBackpack = function()
            if Buttons:GetShowState() and Buttons.bagWindow and Buttons.bagWindow:IsShown() then
                Buttons.bagWindow:Hide()
                Buttons._openedByMerchant = nil
            end
            Buttons._originalCloseBackpack()
        end
    end

    if CloseBag and not self._originalCloseBag then
        self._originalCloseBag = CloseBag
        CloseBag = function(bag)
            if Buttons:GetShowState() and Buttons.bagWindow and Buttons.bagWindow:IsShown() then
                Buttons.bagWindow:Hide()
                Buttons._openedByMerchant = nil
            end
            Buttons._originalCloseBag(bag)
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
        cfg.bagWindowPoint = cloneDefaults().bagWindowPoint
        cfg.scale = defaultConfig.scale
        cfg.alpha = defaultConfig.alpha
        cfg.buttonSize = defaultConfig.buttonSize
        cfg.iconInset = defaultConfig.iconInset
        cfg.framePadding = defaultConfig.framePadding
        cfg.textSpacing = defaultConfig.textSpacing
        if self.bagWindow then
            self.bagWindow:ClearAllPoints()
            self.bagWindow:SetPoint("CENTER", UIParent, "CENTER", 120, -20)
        end
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
updateFrame:RegisterEvent("MAIL_SHOW")
updateFrame:RegisterEvent("MAIL_CLOSED")
updateFrame:RegisterEvent("BANKFRAME_OPENED")
updateFrame:RegisterEvent("BANKFRAME_CLOSED")
updateFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
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

    if event == "MAIL_SHOW" then
        local cfg = ensureConfig()
        if cfg and cfg.enabled and cfg.showBags and GPX.db and GPX.db.enabled then
            local frame = GPX.ActionButtons:EnsureBagWindow()
            if frame and not frame:IsShown() then
                GPX.ActionButtons:RefreshBagWindow()
                frame:Show()
                frame:Raise()
                HideBlizzardContainerFrames()
                GPX.ActionButtons._openedByMail = true
            else
                HideBlizzardContainerFrames()
            end
        end
        return
    end

    if event == "MAIL_CLOSED" then
        if GPX.ActionButtons.bagWindow and GPX.ActionButtons.bagWindow:IsShown() and GPX.ActionButtons._openedByMail then
            GPX.ActionButtons.bagWindow:Hide()
            GPX.ActionButtons._openedByMail = nil
        end
        return
    end

    if event == "BANKFRAME_OPENED" then
        GPX.ActionButtons._bankIsOpen = true
        GPX.ActionButtons._reopenBagAfterBank = GPX.ActionButtons.bagWindow and GPX.ActionButtons.bagWindow:IsShown() or false
        if GPX.ActionButtons.bagWindow and GPX.ActionButtons.bagWindow:IsShown() then
            GPX.ActionButtons.bagWindow:Hide()
        end
        GPX.ActionButtons:ToggleBankWindow(true)
        return
    end

    if event == "BANKFRAME_CLOSED" then
        GPX.ActionButtons._bankIsOpen = nil
        GPX.ActionButtons:ToggleBankWindow(false)
        if GPX.ActionButtons._reopenBagAfterBank and GPX.ActionButtons:GetShowState() then
            local frame = GPX.ActionButtons:EnsureBagWindow()
            if frame then
                GPX.ActionButtons:RefreshBagWindow()
                frame:Show()
                frame:Raise()
                HideBlizzardContainerFrames()
            end
        end
        GPX.ActionButtons._reopenBagAfterBank = nil
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
        if GPX.ActionButtons.bankWindow and GPX.ActionButtons.bankWindow:IsShown() then
            GPX.ActionButtons:RefreshBankWindow()
        end
        return
    end

    if event == "PLAYERBANKSLOTS_CHANGED" then
        if GPX.ActionButtons.bankWindow and GPX.ActionButtons.bankWindow:IsShown() then
            GPX.ActionButtons:RefreshBankWindow()
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
