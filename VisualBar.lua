if not GamePadX then return end

local GPX = GamePadX
local Bar = {}

GPX.VisualBar = Bar

local BAR_BUTTON_COUNT = 12
local PET_ACTION_BUTTON_COUNT = 10
local defaultKeyHints = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" }

local modifierStates = {
    [""] = { title = "Base", bar = nil },
    ["SHIFT"] = { title = "Modifier 1", bar = "MULTIACTIONBAR2BUTTON" },
    ["ALT"] = { title = "Modifier 2", bar = "MULTIACTIONBAR1BUTTON" },
    ["CTRL"] = { title = "Modifier 3", bar = "MULTIACTIONBAR4BUTTON" },
    ["SHIFT-ALT"] = { title = "Combo", bar = "MULTIACTIONBAR3BUTTON" },
}

local placementRows = {
    { state = "", label = "Base" },
    { state = "SHIFT", label = "Shift" },
    { state = "ALT", label = "Alt" },
    { state = "CTRL", label = "Ctrl" },
    { state = "SHIFT-ALT", label = "Combo" },
}

local layoutDefaults = {
    main = {
        buttonCount = 12,
        buttonWidth = 56,
        buttonHeight = 90,
        buttonSpacing = 6,
        padding = 16,
        alpha = 1.0,
        chromeAlpha = 0.12,
    },
    bag = {
        buttonSize = 22,
        buttonSpacing = 8,
        padding = 6,
        alpha = 1.0,
        chromeAlpha = 0.32,
    },
    progress = {
        width = 520,
        height = 24,
        alpha = 1.0,
    },
    micro = {
        alpha = 1.0,
    },
    modifier = {
        alpha = 1.0,
        chromeAlpha = 0.2,
    },
    stance = {
        alpha = 1.0,
    },
    pet = {
        alpha = 1.0,
    },
    vehicle = {
        alpha = 1.0,
    },
}

local layoutTitles = {
    main = "Action Bar",
    bag = "Bag Bar",
    progress = "XP / Rep Bar",
    micro = "Micro Menu",
    modifier = "Modifier Indicator",
    stance = "Stance Bar",
    pet = "Pet Bar",
    vehicle = "Vehicle Exit",
}

local RANGE_UPDATE_INTERVAL = 0.08
local GLOBAL_COOLDOWN_SPELL_ID = 61304

local function createBackdrop(frame, borderR, borderG, borderB, borderA)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.04, 0.06, 0.1, 0.9)
    frame:SetBackdropBorderColor(borderR or 0.2, borderG or 0.62, borderB or 0.96, borderA or 0.85)
end

local function ensureFrameChrome(frame)
    if not frame or frame._wowxChromeApplied then
        return
    end
    frame._wowxChromeApplied = true
    createBackdrop(frame, 0.2, 0.28, 0.38, 0.8)
    frame:SetBackdropColor(0.05, 0.07, 0.12, 0.45)
end

local function ensureVisualBarConfig()
    GPX.db.ui = GPX.db.ui or GPX:DeepCopy(GPX.defaults.ui)
    GPX.db.ui.visualBar = GPX.db.ui.visualBar or GPX:DeepCopy(GPX.defaults.ui.visualBar)
    return GPX.db.ui.visualBar
end

function Bar:UseModifierPages()
    local cfg = ensureVisualBarConfig()
    return cfg.modifierPages == true
end

local hiddenParent = CreateFrame("Frame", "WoWXHiddenBarParent", UIParent)
hiddenParent:Hide()

local managedBlizzardBars = {
    "MainMenuBar",
    "MainMenuBarArtFrame",
    "MainMenuExpBar",
    "MainMenuBarMaxLevelBar",
    "MainMenuBarTexture0",
    "MainMenuBarTexture1",
    "MainMenuBarTexture2",
    "MainMenuBarTexture3",
    "MainMenuBarLeftEndCap",
    "MainMenuBarRightEndCap",
    "ActionBarUpButton",
    "ActionBarDownButton",
    "MainMenuBarPageNumber",
    "MainMenuBarPerformanceBarFrame",
    "MainMenuBarVehicleLeaveButton",
    "MainMenuBarBackpackButton",
    "CharacterBag0Slot",
    "CharacterBag1Slot",
    "CharacterBag2Slot",
    "CharacterBag3Slot",
    "CharacterMicroButton",
    "SpellbookMicroButton",
    "TalentMicroButton",
    "QuestLogMicroButton",
    "SocialsMicroButton",
    "WorldMapMicroButton",
    "MainMenuMicroButton",
    "HelpMicroButton",
    "AchievementMicroButton",
    "CompanionsMicroButton",
    "EJMicroButton",
    "MultiBarBottomLeft",
    "MultiBarBottomRight",
    "MultiBarRight",
    "MultiBarLeft",
    "StanceBarFrame",
    "ShapeshiftBarFrame",
    "PossessBarFrame",
    "PetActionBarFrame",
}

local microMenuFrames = {
    CharacterMicroButton = true,
    SpellbookMicroButton = true,
    TalentMicroButton = true,
    QuestLogMicroButton = true,
    SocialsMicroButton = true,
    WorldMapMicroButton = true,
    MainMenuMicroButton = true,
    HelpMicroButton = true,
    AchievementMicroButton = true,
    LFGMicroButton = true,
    CompanionsMicroButton = true,
    EJMicroButton = true,
}

local bagFrames = {
    MainMenuBarBackpackButton = true,
    CharacterBag0Slot = true,
    CharacterBag1Slot = true,
    CharacterBag2Slot = true,
    CharacterBag3Slot = true,
}

local stanceFrames = {
    StanceBarFrame = true,
    ShapeshiftBarFrame = true,
    PossessBarFrame = true,
}

local petFrames = {
    PetActionBarFrame = true,
}

local orderedMicroButtons = {
    "CharacterMicroButton",
    "SpellbookMicroButton",
    "TalentMicroButton",
    "AchievementMicroButton",
    "QuestLogMicroButton",
    "SocialsMicroButton",
    "LFGMicroButton",
    "CompanionsMicroButton",
    "EJMicroButton",
    "MainMenuMicroButton",
    "HelpMicroButton",
}

local vehicleLeaveButtonCandidates = {
    "MainMenuBarVehicleLeaveButton",
    "VehicleMenuBarLeaveButton",
    "OverrideActionBarLeaveFrameLeaveButton",
}

local function getPointFromConfig(config, key, fallback)
    return config[key] or fallback
end

local function clamp(value, minV, maxV)
    if value < minV then return minV end
    if value > maxV then return maxV end
    return value
end

local function roundToStep(value, step)
    if not step or step <= 0 then
        return value
    end
    return math.floor((value / step) + 0.5) * step
end

local function formatSliderValue(value, step)
    if step and step >= 1 then
        return tostring(math.floor(value + 0.5))
    end
    return string.format("%.2f", value)
end

local function getEffectiveFrameWidth(frame)
    if not frame then
        return 0
    end
    return (frame.GetWidth and frame:GetWidth()) or 0
end

local function formatScaleValue(value)
    return string.format("%.2fx", value)
end

local function ensureSlotWrapper(frame)
    if not frame or frame._wowxSlotWrapper then
        return
    end

    local panel = frame:CreateTexture(nil, "BACKGROUND")
    panel:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    panel:SetVertexColor(0.07, 0.09, 0.12, 0.96)

    local border = frame:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    border:SetVertexColor(0.92, 0.93, 0.9, 0.92)

    frame.slotPanel = panel
    frame.slotBorder = border
    frame._wowxSlotWrapper = true
end

local function layoutSlotWrapper(frame, leftInset, topInset, rightInset, bottomInset)
    ensureSlotWrapper(frame)
    frame.slotPanel:ClearAllPoints()
    frame.slotPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", leftInset, -topInset)
    frame.slotPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -rightInset, bottomInset)

    frame.slotBorder:ClearAllPoints()
    frame.slotBorder:SetPoint("TOPLEFT", frame.slotPanel, "TOPLEFT", -6, 6)
    frame.slotBorder:SetPoint("BOTTOMRIGHT", frame.slotPanel, "BOTTOMRIGHT", 6, -6)
end

local function layoutSquareSlotWrapper(frame, leftInset, topInset, rightInset, bottomInset)
    ensureSlotWrapper(frame)

    local width = (frame.GetWidth and frame:GetWidth()) or 0
    local height = (frame.GetHeight and frame:GetHeight()) or 0
    local availableWidth = math.max(0, width - leftInset - rightInset)
    local availableHeight = math.max(0, height - topInset - bottomInset)
    local size = math.max(18, math.min(availableWidth, availableHeight))
    local left = leftInset + math.floor((availableWidth - size) * 0.5)
    local top = topInset + math.floor((availableHeight - size) * 0.5)

    frame.slotPanel:ClearAllPoints()
    frame.slotPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -top)
    frame.slotPanel:SetWidth(size)
    frame.slotPanel:SetHeight(size)

    frame.slotBorder:ClearAllPoints()
    frame.slotBorder:SetPoint("TOPLEFT", frame.slotPanel, "TOPLEFT", -6, 6)
    frame.slotBorder:SetPoint("BOTTOMRIGHT", frame.slotPanel, "BOTTOMRIGHT", 6, -6)
end

local function layoutIconPriorityWrapper(frame, icon, iconSize, bottomReserve)
    ensureSlotWrapper(frame)

    local width = (frame.GetWidth and frame:GetWidth()) or iconSize
    local height = (frame.GetHeight and frame:GetHeight()) or iconSize
    local reserve = bottomReserve or 6
    local topInset = 2
    local x = math.max(4, math.floor((width - iconSize) * 0.5))
    local y = topInset + math.max(0, math.floor((height - reserve - topInset - iconSize) * 0.5))

    icon:ClearAllPoints()
    icon:SetWidth(iconSize)
    icon:SetHeight(iconSize)
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)

    frame.slotPanel:ClearAllPoints()
    frame.slotPanel:SetPoint("TOPLEFT", icon, "TOPLEFT", -3, 3)
    frame.slotPanel:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 3, -3)

    frame.slotBorder:ClearAllPoints()
    frame.slotBorder:SetPoint("TOPLEFT", frame.slotPanel, "TOPLEFT", -6, 6)
    frame.slotBorder:SetPoint("BOTTOMRIGHT", frame.slotPanel, "BOTTOMRIGHT", 6, -6)
end

local function stripFrameTextures(frame)
    if not frame or frame._wowxArtStripped then
        return
    end

    local regions = { frame:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then
            region:SetTexture(nil)
            region:SetAlpha(0)
            region:Hide()
        end
    end

    frame._wowxArtStripped = true
end

local function updateShellAroundButtons(ownerFrame, buttonList, insetX, insetY)
    if not ownerFrame then
        return
    end

    local firstButton
    local lastButton
    local firstAnchor
    local lastAnchor
    for _, button in ipairs(buttonList or {}) do
        if button and button.IsShown and button:IsShown() then
            firstButton = firstButton or button
            lastButton = button
            firstAnchor = firstAnchor or button._wowxShellAnchorTarget or button
            lastAnchor = button._wowxShellAnchorTarget or button
        end
    end

    if not firstButton or not lastButton then
        if ownerFrame._wowxShell then
            ownerFrame._wowxShell:Hide()
        end
        return
    end

    if not ownerFrame._wowxShell then
        local shell = CreateFrame("Frame", nil, UIParent)
        shell:SetFrameStrata("LOW")
        createBackdrop(shell, 0.18, 0.24, 0.3, 0.7)
        shell:EnableMouse(true)
        shell:SetMovable(true)
        shell:RegisterForDrag("LeftButton")
        shell:SetScript("OnDragStart", function(self)
            if not GPX.VisualBar or GPX.VisualBar:IsLayoutEditLocked() then
                return
            end
            if not self._wowxOwnerFrame then
                return
            end
            self._wowxOwnerFrame:StartMoving()
            self._wowxDragStarted = true
        end)
        shell:SetScript("OnDragStop", function(self)
            if not self._wowxDragStarted or not self._wowxOwnerFrame then
                return
            end
            self._wowxDragStarted = nil
            self._wowxOwnerFrame:StopMovingOrSizing()
            if GPX.VisualBar and self._wowxOwnerKind then
                GPX.VisualBar:SavePositionForKind(self._wowxOwnerFrame, self._wowxOwnerKind)
            end
        end)
        ownerFrame._wowxShell = shell
    end

    ownerFrame._wowxShell._wowxOwnerFrame = ownerFrame
    ownerFrame._wowxShell._wowxOwnerKind = ownerFrame._wowxFrameDragKind
    ownerFrame._wowxShell:SetFrameStrata(ownerFrame:GetFrameStrata() or "MEDIUM")
    ownerFrame._wowxShell:SetFrameLevel((ownerFrame:GetFrameLevel() or 1) + 24)
    ownerFrame._wowxShell:EnableMouse(GPX.VisualBar and not GPX.VisualBar:IsLayoutEditLocked())
    ownerFrame._wowxShell:ClearAllPoints()
    ownerFrame._wowxShell:SetPoint("TOPLEFT", firstAnchor or firstButton, "TOPLEFT", -(insetX or 6), insetY or 6)
    ownerFrame._wowxShell:SetPoint("BOTTOMRIGHT", lastAnchor or lastButton, "BOTTOMRIGHT", insetX or 6, -(insetY or 6))
    ownerFrame._wowxShell:SetAlpha(ownerFrame:GetAlpha() or 1.0)
    ownerFrame._wowxShell:Show()
end

local function getVisibleButtons(buttonList)
    local visibleButtons = {}
    for _, button in ipairs(buttonList or {}) do
        if button and button.IsShown and button:IsShown() and ((button.GetAlpha and button:GetAlpha() > 0) or not button.GetAlpha) then
            visibleButtons[#visibleButtons + 1] = button
        end
    end
    return visibleButtons
end

local function getShapeshiftFormCount()
    if GetNumShapeshiftForms then
        return GetNumShapeshiftForms() or 0
    end
    return 0
end

local function getFormBackedButtons(buttonList, formCount)
    local usableButtons = {}
    local count = math.min(formCount or 0, #(buttonList or {}))
    for index = 1, count do
        local button = buttonList[index]
        if button then
            usableButtons[#usableButtons + 1] = button
        end
    end
    return usableButtons
end

local function layoutAuxButtons(frame, buttonList, padding, spacing)
    if not frame then
        return
    end

    local inset = padding or 8
    local gap = spacing or 6
    local prev
    local maxHeight = 0
    local totalWidth = inset * 2

    for _, button in ipairs(buttonList or {}) do
        if button then
            local width = (button.GetWidth and button:GetWidth()) or 36
            local height = (button.GetHeight and button:GetHeight()) or 36
            button:ClearAllPoints()
            if not prev then
                button:SetPoint("LEFT", frame, "LEFT", inset, 0)
            else
                button:SetPoint("LEFT", prev, "RIGHT", gap, 0)
                totalWidth = totalWidth + gap
            end
            totalWidth = totalWidth + width
            if height > maxHeight then
                maxHeight = height
            end
            prev = button
        end
    end

    frame:SetWidth(math.max(64, totalWidth))
    frame:SetHeight(math.max(28, maxHeight + (inset * 2)))
end

local function ensurePlaceholderLabel(frame)
    if not frame or frame._wowxPlaceholderLabel then
        return frame and frame._wowxPlaceholderLabel or nil
    end

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", frame, "CENTER", 0, 0)
    label:SetTextColor(1.0, 0.92, 0.58)
    frame._wowxPlaceholderLabel = label
    return label
end

local function ensureAuxPlaceholderButtons(frame, key, count, buttonSize)
    if not frame then
        return {}
    end

    frame._wowxPlaceholderButtons = frame._wowxPlaceholderButtons or {}
    frame._wowxPlaceholderButtons[key] = frame._wowxPlaceholderButtons[key] or {}
    local buttons = frame._wowxPlaceholderButtons[key]
    local finalSize = math.max(20, buttonSize or 28)

    for index = 1, count do
        local button = buttons[index]
        if not button then
            button = CreateFrame("Frame", nil, frame)
            createBackdrop(button, 0.22, 0.66, 0.98, 0.28)
            button:SetBackdropColor(0.05, 0.07, 0.12, 0.08)
            layoutSquareSlotWrapper(button, 2, 2, 2, 2)

            local icon = button:CreateTexture(nil, "ARTWORK")
            icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            icon:SetVertexColor(0.45, 0.5, 0.58, 0.65)
            button.icon = icon

            buttons[index] = button
        end

        button:SetWidth(finalSize)
        button:SetHeight(finalSize)
        layoutSquareSlotWrapper(button, 2, 2, 2, 2)
        if button.icon then
            button.icon:ClearAllPoints()
            button.icon:SetPoint("TOPLEFT", button.slotPanel, "TOPLEFT", 2, -2)
            button.icon:SetPoint("BOTTOMRIGHT", button.slotPanel, "BOTTOMRIGHT", -2, 2)
        end
        button:Show()
    end

    for index = count + 1, #buttons do
        if buttons[index] then
            buttons[index]:Hide()
        end
    end

    return buttons
end

local function hideAuxPlaceholderButtons(frame, key)
    if not frame or not frame._wowxPlaceholderButtons or not frame._wowxPlaceholderButtons[key] then
        return
    end
    for _, button in ipairs(frame._wowxPlaceholderButtons[key]) do
        if button then
            button:Hide()
        end
    end
end

local function isCursorCarryingActionPayload()
    local cursorType = GetCursorInfo and select(1, GetCursorInfo()) or nil
    return cursorType or CursorHasItem() or CursorHasSpell() or CursorHasMacro() or CursorHasMoney()
end

local function getFrameMouseFocus(frame)
    if not frame or not frame.IsMouseOver or not frame:IsMouseOver() then
        return nil
    end

    local focus = GetMouseFocus and GetMouseFocus() or nil
    while focus do
        if focus == frame then
            return frame
        end
        focus = focus.GetParent and focus:GetParent() or nil
    end

    return nil
end

local function shouldStartFrameDrag(frame)
    local focus = getFrameMouseFocus(frame)
    if not focus then
        return false
    end

    if focus == frame then
        return true
    end

    if focus._wowxDisableFrameDrag then
        return false
    end

    return not (focus.GetObjectType and focus:GetObjectType() == "Button")
end

local function getActiveStanceFrames()
    local frames = {}
    local candidates = { _G.StanceBarFrame, _G.ShapeshiftBarFrame, _G.PossessBarFrame }
    for _, frame in ipairs(candidates) do
        if frame and not frame._wowxListed then
            frame._wowxListed = true
            frames[#frames + 1] = frame
        end
    end
    for _, frame in ipairs(frames) do
        frame._wowxListed = nil
    end
    return frames
end

local function getFrameBounds(frame)
    if not frame or not frame.IsShown or not frame:IsShown() then
        return nil
    end

    local left = frame.GetLeft and frame:GetLeft() or nil
    local right = frame.GetRight and frame:GetRight() or nil
    local top = frame.GetTop and frame:GetTop() or nil
    local bottom = frame.GetBottom and frame:GetBottom() or nil
    if not left or not right or not top or not bottom then
        return nil
    end

    return left, right, top, bottom
end

local function framesOverlap(firstFrame, secondFrame)
    local firstLeft, firstRight, firstTop, firstBottom = getFrameBounds(firstFrame)
    local secondLeft, secondRight, secondTop, secondBottom = getFrameBounds(secondFrame)
    if not firstLeft or not secondLeft then
        return false
    end

    return not (
        firstRight <= secondLeft
        or firstLeft >= secondRight
        or firstTop <= secondBottom
        or firstBottom >= secondTop
    )
end

local function getProxyButtonNameForCommand(command)
    local index = tonumber(command and command:match("(%d+)$"))
    if not index then
        return nil
    end

    if command:find("^ACTIONBUTTON") then
        return "ActionButton" .. index
    end
    if command:find("^MULTIACTIONBAR1BUTTON") then
        return "MultiBarBottomLeftButton" .. index
    end
    if command:find("^MULTIACTIONBAR2BUTTON") then
        return "MultiBarBottomRightButton" .. index
    end
    if command:find("^MULTIACTIONBAR3BUTTON") then
        return "MultiBarRightButton" .. index
    end
    if command:find("^MULTIACTIONBAR4BUTTON") then
        return "MultiBarLeftButton" .. index
    end

    return nil
end

local function getBindingProxyFrameName(command)
    return command and ("WoWXBindButton_" .. command) or nil
end

-- Static slot offsets for known multibar commands.
-- These are compile-time fallbacks used when the native bar button's .action
-- attribute is nil (e.g. hidden bars, first-init before UpdateBindingProxyButtons).
-- MULTIACTIONBAR1=BottomLeft(49-60), MULTIACTIONBAR2=BottomRight(61-72),
-- MULTIACTIONBAR3=Right(73-84), MULTIACTIONBAR4=Left(85-96).
local multibarStaticOffset = {
    ["MULTIACTIONBAR1BUTTON"] = 48,
    ["MULTIACTIONBAR2BUTTON"] = 60,
    ["MULTIACTIONBAR3BUTTON"] = 72,
    ["MULTIACTIONBAR4BUTTON"] = 84,
}

local function getStaticSlotForCommand(command)
    local index = tonumber(command and command:match("(%d+)$"))
    if not index then return nil end
    for prefix, offset in pairs(multibarStaticOffset) do
        if command:find("^" .. prefix) then
            return offset + index
        end
    end
    return nil
end

local function getConditionalProxyMacro(command)
    if not command then
        return nil
    end

    local actionIndex = tonumber(command:match("^ACTIONBUTTON(%d+)$"))
    if actionIndex then
        -- Keep ACTIONBUTTON execution aligned with aura/bonus bars without
        -- requiring combat-time secure attribute rewrites.
        return "/click [bonusbar:5] BonusActionButton" .. actionIndex
            .. "; [bonusbar:4] BonusActionButton" .. actionIndex
            .. "; [bonusbar:3] BonusActionButton" .. actionIndex
            .. "; [bonusbar:2] BonusActionButton" .. actionIndex
            .. "; [bonusbar:1] BonusActionButton" .. actionIndex
            .. "; ActionButton" .. actionIndex
    end

    -- Do NOT route multibar or other commands through native Blizzard bar buttons.
    -- UpdateBlizzardBars() reparents those frames to hiddenParent, so
    -- "/click MultiBarXXXButtonN" silently fails (hidden frame, no click received).
    -- Direct action slot execution (via fallbackSlot) is used instead.
    return nil
end

local function setProxyOrActionAttribute(button, prefix, command, fallbackSlot)
    local attrPrefix = prefix and (prefix .. "-") or ""
    local proxyMacro = getConditionalProxyMacro(command)
    -- Prefer the live-resolved slot from the caller; if the native button had no
    -- .action attribute yet (hidden or first-init), use the static offset table.
    local resolvedSlot = fallbackSlot or getStaticSlotForCommand(command)

    button:SetAttribute(attrPrefix .. "type", nil)
    button:SetAttribute(attrPrefix .. "action", nil)

    if proxyMacro then
        button:SetAttribute(attrPrefix .. "type1", "macro")
        button:SetAttribute(attrPrefix .. "macrotext1", proxyMacro)
        button:SetAttribute(attrPrefix .. "clickbutton", nil)
        button:SetAttribute(attrPrefix .. "action1", nil)
    elseif resolvedSlot then
        button:SetAttribute(attrPrefix .. "type1", "action")
        button:SetAttribute(attrPrefix .. "action1", resolvedSlot)
        button:SetAttribute(attrPrefix .. "clickbutton", nil)
        button:SetAttribute(attrPrefix .. "macrotext1", nil)
    else
        button:SetAttribute(attrPrefix .. "type1", nil)
        button:SetAttribute(attrPrefix .. "action1", nil)
        button:SetAttribute(attrPrefix .. "clickbutton", nil)
        button:SetAttribute(attrPrefix .. "macrotext1", nil)
    end
end

function Bar:GetBindingProxyButtonName(command)
    return getBindingProxyFrameName(command)
end

function Bar:EnsureBindingProxyButtons()
    if self.bindingButtons then
        return
    end

    self.bindingButtons = {}
    for _, row in ipairs(placementRows) do
        for index = 1, BAR_BUTTON_COUNT do
            local command = self:GetCommandForButton(index, row.state)
            if command and not self.bindingButtons[command] then
                local buttonName = getBindingProxyFrameName(command)
                local button = CreateFrame("CheckButton", buttonName, hiddenParent, "SecureActionButtonTemplate")
                button:RegisterForClicks("LeftButtonUp")
                button:Hide()
                -- Initialize immediately with at least the static slot so the button
                -- is never in an unset state before UpdateBindingProxyButtons runs.
                -- A live-resolved slot will overwrite this when combat is not active.
                setProxyOrActionAttribute(button, nil, command, nil)
                button:SetAttribute("type2", nil)
                button:SetAttribute("action2", nil)
                self.bindingButtons[command] = button
            end
        end
    end
end

function Bar:UpdateBindingProxyButtons()
    self:EnsureBindingProxyButtons()
    if InCombatLockdown() then
        self.pendingAttributeRefresh = true
        return
    end

    for command, button in pairs(self.bindingButtons) do
        local slot = self:ResolveCommand(command)
        setProxyOrActionAttribute(button, nil, command, slot)
        button:SetAttribute("type2", nil)
        button:SetAttribute("action2", nil)
        button:SetAttribute("clickbutton", button:GetAttribute("clickbutton"))
    end
end

function Bar:GetCurrentState()
    local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() or nil
    if focus and focus.IsObjectType and focus:IsObjectType("EditBox") then
        return ""
    end
    if ChatFrameEditBox and ChatFrameEditBox:IsShown() then
        return ""
    end

    local shift = IsShiftKeyDown()
    local alt = IsAltKeyDown()
    local ctrl = IsControlKeyDown()

    if shift and alt and not ctrl then
        return "SHIFT-ALT"
    end
    if shift and not alt and not ctrl then
        return "SHIFT"
    end
    if alt and not shift and not ctrl then
        return "ALT"
    end
    if ctrl and not shift and not alt then
        return "CTRL"
    end
    return ""
end

function Bar:GetProfile()
    return GPX:GetProfile()
end

function Bar:GetLayoutConfig(kind)
    local config = ensureVisualBarConfig()
    config.layout = config.layout or {}
    config.layout[kind] = config.layout[kind] or {}

    local defaults = layoutDefaults[kind] or {}
    local layout = config.layout[kind]
    for key, value in pairs(defaults) do
        if layout[key] == nil then
            layout[key] = value
        end
    end
    return layout
end

function Bar:ResetLayoutForKind(kind)
    local config = ensureVisualBarConfig()
    config.layout = config.layout or {}
    config.layout[kind] = GPX:DeepCopy(layoutDefaults[kind] or {})

    if kind == "main" then
        config.scale = GPX.defaults.ui.visualBar.scale or 1.0
    elseif kind == "bag" then
        config.bagScale = nil
    elseif kind == "micro" then
        config.microScale = GPX.defaults.ui.visualBar.microScale or 1.0
    elseif kind == "modifier" then
        config.modifierScale = GPX.defaults.ui.visualBar.modifierScale or 1.0
    elseif kind == "stance" then
        config.stanceScale = GPX.defaults.ui.visualBar.stanceScale or 1.0
    elseif kind == "pet" then
        config.petScale = GPX.defaults.ui.visualBar.petScale or 1.0
    elseif kind == "vehicle" then
        config.vehicleScale = GPX.defaults.ui.visualBar.vehicleScale or 1.0
    end

    self:UpdateAll()
end

function Bar:GetVisibleButtonCount()
    local layout = self:GetLayoutConfig("main")
    local visibleCount = clamp(math.floor((tonumber(layout.buttonCount) or BAR_BUTTON_COUNT) + 0.5), 1, BAR_BUTTON_COUNT)
    if GPX:IsControllerEnabled() then
        local setup = self:GetSetup()
        visibleCount = math.min(visibleCount, GPX:GetConfiguredActionButtonCount(setup))
    end
    return visibleCount
end

function Bar:GetMainLayoutMetrics()
    local layout = self:GetLayoutConfig("main")
    return {
        layout = layout,
        visibleCount = clamp(math.floor((tonumber(layout.buttonCount) or BAR_BUTTON_COUNT) + 0.5), 1, BAR_BUTTON_COUNT),
        buttonWidth = math.floor(tonumber(layout.buttonWidth) or layoutDefaults.main.buttonWidth),
        buttonHeight = math.floor(tonumber(layout.buttonHeight) or layoutDefaults.main.buttonHeight),
        spacing = math.floor(tonumber(layout.buttonSpacing) or layoutDefaults.main.buttonSpacing),
        padding = math.floor(tonumber(layout.padding) or layoutDefaults.main.padding),
        alpha = tonumber(layout.alpha) or layoutDefaults.main.alpha,
        chromeAlpha = tonumber(layout.chromeAlpha) or layoutDefaults.main.chromeAlpha or 0.12,
    }
end

function Bar:GetSetup()
    local profile = self:GetProfile()
    return profile and profile.setup or nil
end

function Bar:GetStyle()
    local setup = self:GetSetup()
    local styleId = setup and setup.deviceId or "keyboard"
    return GPX:GetInputStyle(styleId)
end

function Bar:ShouldReplaceBlizzardBars()
    local config = ensureVisualBarConfig()
    return GPX.db and GPX.db.enabled and config.enabled ~= false and config.replaceBlizzard ~= false
end

function Bar:UpdateBlizzardBars()
    if InCombatLockdown() then
        return
    end

    self.originalParents = self.originalParents or {}
    local hideBars = self:ShouldReplaceBlizzardBars()
    local config = ensureVisualBarConfig()
    local controllerEnabled = GPX:IsControllerEnabled()
    local keepMicro = not controllerEnabled
    local keepBags = false
    local keepStance = true
    local keepPet = true
    for _, frameName in ipairs(managedBlizzardBars) do
        local frame = _G[frameName]
        if frame then
            local keepFrame = (keepMicro and microMenuFrames[frameName])
                or (keepBags and bagFrames[frameName])
                or (keepStance and stanceFrames[frameName])
                or (keepPet and petFrames[frameName])
            if hideBars then
                if keepFrame then
                    if self.originalParents[frameName] then
                        frame:SetParent(self.originalParents[frameName])
                        frame:Show()
                    end
                else
                    if not self.originalParents[frameName] then
                        self.originalParents[frameName] = frame:GetParent() or UIParent
                    end
                    frame:SetParent(hiddenParent)
                end
            elseif self.originalParents[frameName] then
                frame:SetParent(self.originalParents[frameName])
                frame:Show()
            end
        end
    end
end

function Bar:GetStoredBagPosition()
    local config = ensureVisualBarConfig()
    return getPointFromConfig(config, "bagPoint", GPX:DeepCopy(GPX.defaults.ui.visualBar.bagPoint))
end

function Bar:ApplyStoredBagPosition()
    if not self.frame or not self.frame.bagBar then
        return
    end
    local point = self:GetStoredBagPosition()
    self.frame.bagBar:ClearAllPoints()
    self.frame.bagBar:SetPoint(point.anchor, UIParent, point.relativePoint, point.x, point.y)
end

function Bar:SaveBagPosition()
    if not self.frame or not self.frame.bagBar then
        return
    end
    local config = ensureVisualBarConfig()
    local anchor, _, relativePoint, x, y = self.frame.bagBar:GetPoint(1)
    config.bagPoint = {
        anchor = anchor or "BOTTOMRIGHT",
        relativeTo = "UIParent",
        relativePoint = relativePoint or "BOTTOM",
        x = x or -220,
        y = y or 64,
    }
end

function Bar:GetStoredMicroPosition()
    local config = ensureVisualBarConfig()
    return getPointFromConfig(config, "microPoint", GPX:DeepCopy(GPX.defaults.ui.visualBar.microPoint))
end

function Bar:GetStoredModifierPosition()
    local config = ensureVisualBarConfig()
    return getPointFromConfig(config, "modifierPoint", GPX:DeepCopy(GPX.defaults.ui.visualBar.modifierPoint))
end

function Bar:SaveModifierPosition()
    if not self.modifierFrame then
        return
    end
    local config = ensureVisualBarConfig()
    local anchor, _, relativePoint, x, y = self.modifierFrame:GetPoint(1)
    config.modifierPoint = {
        anchor = anchor or "BOTTOM",
        relativeTo = "UIParent",
        relativePoint = relativePoint or "BOTTOM",
        x = x or 0,
        y = y or 150,
    }
end

function Bar:SaveMicroPosition()
    if not self.microMenuFrame then
        return
    end
    local config = ensureVisualBarConfig()
    local anchor, _, relativePoint, x, y = self.microMenuFrame:GetPoint(1)
    config.microPoint = {
        anchor = anchor or "BOTTOM",
        relativeTo = "UIParent",
        relativePoint = relativePoint or "BOTTOM",
        x = x or 0,
        y = y or 26,
    }
end

function Bar:GetStoredStancePosition()
    local config = ensureVisualBarConfig()
    return getPointFromConfig(config, "stancePoint", GPX:DeepCopy(GPX.defaults.ui.visualBar.stancePoint))
end

function Bar:GetStoredPetPosition()
    local config = ensureVisualBarConfig()
    return getPointFromConfig(config, "petPoint", GPX:DeepCopy(GPX.defaults.ui.visualBar.petPoint))
end

function Bar:GetStoredVehiclePosition()
    local config = ensureVisualBarConfig()
    return getPointFromConfig(config, "vehiclePoint", GPX:DeepCopy(GPX.defaults.ui.visualBar.vehiclePoint))
end

function Bar:SaveAuxFramePosition(frame, key, anchorDefault, relativeDefault)
    if not frame then
        return
    end
    local config = ensureVisualBarConfig()
    local anchor, _, relativePoint, x, y = frame:GetPoint(1)
    config[key] = {
        anchor = anchor or anchorDefault,
        relativeTo = "UIParent",
        relativePoint = relativePoint or relativeDefault,
        x = x or 0,
        y = y or 0,
    }
end

function Bar:EnsureAuxMovable(frame, saveFn)
    if not frame or frame._wowxMovableHooked then
        return
    end
    frame._wowxMovableHooked = true
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if GPX.VisualBar and not GPX.VisualBar:IsLayoutEditLocked() then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if saveFn then
            saveFn(self)
        end
    end)
end

function Bar:EnableFrameDrag(frame, kind)
    if not frame or frame._wowxFrameDragKind == kind then
        return
    end

    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame._wowxFrameDragKind = kind

    frame:HookScript("OnDragStart", function(self)
        if not GPX.VisualBar or GPX.VisualBar:IsLayoutEditLocked() then
            return
        end
        if not shouldStartFrameDrag(self) then
            return
        end
        self:StartMoving()
        self._wowxDragStarted = true
    end)

    frame:HookScript("OnDragStop", function(self)
        if not self._wowxDragStarted then
            return
        end
        self._wowxDragStarted = nil
        self:StopMovingOrSizing()
        if GPX.VisualBar then
            GPX.VisualBar:SavePositionForKind(self, kind)
        end
    end)
end

function Bar:SyncStanceFramePositions(sourceFrame)
    local frames = {}
    if self.stanceHostFrame then
        frames[#frames + 1] = self.stanceHostFrame
    end
    for _, frame in ipairs(getActiveStanceFrames()) do
        frames[#frames + 1] = frame
    end
    if #frames == 0 then
        return
    end

    local anchor, _, relativePoint, x, y
    if sourceFrame and sourceFrame.GetPoint then
        anchor, _, relativePoint, x, y = sourceFrame:GetPoint(1)
    else
        local point = self:GetStoredStancePosition()
        anchor = point.anchor
        relativePoint = point.relativePoint
        x = point.x
        y = point.y
    end

    for _, frame in ipairs(frames) do
        frame:SetParent(UIParent)
        frame:ClearAllPoints()
        frame:SetPoint(anchor or "BOTTOM", UIParent, relativePoint or "BOTTOM", x or 0, y or 0)
    end
end

function Bar:SavePositionForKind(frame, kind)
    if kind == "main" then
        self:SavePosition()
    elseif kind == "bag" then
        self:SaveBagPosition()
    elseif kind == "micro" then
        self:SaveMicroPosition()
    elseif kind == "modifier" then
        self:SaveModifierPosition()
    elseif kind == "stance" then
        self:SaveAuxFramePosition(frame, "stancePoint", "BOTTOM", "BOTTOM")
    elseif kind == "pet" then
        self:SaveAuxFramePosition(frame, "petPoint", "BOTTOM", "BOTTOM")
    elseif kind == "vehicle" then
        self:SaveAuxFramePosition(frame, "vehiclePoint", "BOTTOM", "BOTTOM")
    end
end

function Bar:AttachMoveHandle(frame, kind)
    if not frame or frame._wowxMoveKind == kind then
        return
    end

    local handle = CreateFrame("Button", nil, frame)
    if kind == "modifier" then
        handle:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        handle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    else
        handle:SetWidth(120)
        handle:SetHeight(20)
        handle:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    end
    handle:RegisterForDrag("LeftButton")
    handle:EnableMouse(true)
    handle:SetFrameStrata("HIGH")
    if kind == "modifier" then
        handle:SetFrameLevel((frame:GetFrameLevel() or 1) + 11)
        createBackdrop(handle, 0.96, 0.8, 0.22, 0.0)
        handle:SetBackdropColor(0.0, 0.0, 0.0, 0.0)
    else
        handle:SetFrameLevel((frame:GetFrameLevel() or 1) + 12)
        createBackdrop(handle, 0.96, 0.8, 0.22, 0.85)
        handle:SetBackdropColor(0.1, 0.08, 0.03, 0.75)
    end

    local text = handle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER", handle, "CENTER", 0, 0)
    if kind == "modifier" then
        text:SetText("")
        text:Hide()
    else
        text:SetText("Drag")
        text:SetTextColor(1.0, 0.92, 0.58)
    end
    handle.text = text

    handle:SetScript("OnDragStart", function(self)
        if not GPX.VisualBar or GPX.VisualBar:IsLayoutEditLocked() then
            return
        end
        frame:StartMoving()
    end)
    handle:SetScript("OnDragStop", function(self)
        frame:StopMovingOrSizing()
        if GPX.VisualBar then
            GPX.VisualBar:SavePositionForKind(frame, kind)
        end
    end)

    frame._wowxMoveHandle = handle
    frame._wowxMoveKind = kind
end

function Bar:AttachEditButton(frame, kind)
    if not frame then
        return
    end

    if frame._wowxEditButton and frame._wowxEditKind == kind then
        return
    end

    local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetWidth(46)
    button:SetHeight(18)
    button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -4)
    button:SetFrameStrata("HIGH")
    button:SetFrameLevel((frame:GetFrameLevel() or 1) + 14)
    button:SetText("Edit")
    button:SetScript("OnClick", function()
        if GPX.VisualBar then
            GPX.VisualBar:OpenLayoutEditor(kind, frame)
        end
    end)

    frame._wowxEditButton = button
    frame._wowxEditKind = kind
end

function Bar:GetScaleForKind(kind)
    local config = ensureVisualBarConfig()
    if kind == "main" then
        return self:GetBarScale(), 0.5, 2.0, "scale"
    end
    if kind == "bag" then
        local scale = tonumber(config.bagScale) or self:GetBarScale()
        return clamp(scale, 0.5, 2.0), 0.5, 2.0, "bagScale"
    end
    if kind == "micro" then
        local scale = tonumber(config.microScale) or 1.0
        return clamp(scale, 0.5, 2.0), 0.5, 2.0, "microScale"
    end
    if kind == "modifier" then
        local scale = tonumber(config.modifierScale) or 1.0
        return clamp(scale, 0.5, 2.0), 0.5, 2.0, "modifierScale"
    end
    if kind == "stance" then
        local scale = tonumber(config.stanceScale) or 1.0
        return clamp(scale, 0.5, 2.0), 0.5, 2.0, "stanceScale"
    end
    if kind == "pet" then
        local scale = tonumber(config.petScale) or 1.0
        return clamp(scale, 0.5, 2.0), 0.5, 2.0, "petScale"
    end
    if kind == "vehicle" then
        local scale = tonumber(config.vehicleScale) or 1.0
        return clamp(scale, 0.5, 2.0), 0.5, 2.0, "vehicleScale"
    end
    return 1.0, 0.5, 2.0, nil
end

function Bar:SetScaleForKind(kind, newScale)
    local _, minV, maxV, key = self:GetScaleForKind(kind)
    if not key then
        return
    end
    local config = ensureVisualBarConfig()
    local finalScale = clamp(newScale or 1.0, minV, maxV)
    config[key] = finalScale

    if kind == "main" and self.frame then
        self.frame:SetScale(finalScale)
    elseif kind == "bag" and self.frame and self.frame.bagBar then
        self.frame.bagBar:SetScale(finalScale)
    elseif kind == "micro" and self.microMenuFrame then
        self.microMenuFrame:SetScale(finalScale)
    elseif kind == "modifier" and self.modifierFrame then
        self.modifierFrame:SetScale(finalScale)
    elseif kind == "stance" then
        local stanceFrame = self.stanceHostFrame
        if stanceFrame then
            stanceFrame:SetScale(finalScale)
        end
        for _, frame in ipairs(getActiveStanceFrames()) do
            frame:SetScale(finalScale)
        end
    elseif kind == "pet" then
        local petFrame = self.petHostFrame or _G.PetActionBarFrame
        if petFrame then
            petFrame:SetScale(finalScale)
        end
    elseif kind == "vehicle" and self.vehicleFrame then
        self.vehicleFrame:SetScale(finalScale)
    end
end

function Bar:AttachResizeHandle(frame, kind)
    if not frame or frame._wowxResizeKind == kind then
        return
    end

    local handle = CreateFrame("Button", nil, frame)
    handle:SetWidth(14)
    handle:SetHeight(14)
    if kind == "bag" or kind == "micro" then
        handle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 8, -8)
    else
        handle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    end
    handle:RegisterForDrag("LeftButton")
    handle:EnableMouse(true)
    handle:SetFrameStrata("HIGH")
    handle:SetFrameLevel((frame:GetFrameLevel() or 1) + 12)

    local grip = handle:CreateTexture(nil, "ARTWORK")
    grip:SetAllPoints(handle)
    grip:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetVertexColor(1.0, 0.92, 0.58, 0.9)
    handle.grip = grip

    handle:SetScript("OnEnter", function(self)
        self.grip:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    end)
    handle:SetScript("OnLeave", function(self)
        self.grip:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    end)
    handle:SetScript("OnDragStart", function(self)
        if not GPX.VisualBar or GPX.VisualBar:IsLayoutEditLocked() then
            return
        end
        local uiScale = UIParent:GetEffectiveScale()
        self._startX = GetCursorPosition() / uiScale
        self._startScale = select(1, GPX.VisualBar:GetScaleForKind(kind))
        self:SetScript("OnUpdate", function(btn)
            local nowX = GetCursorPosition() / uiScale
            local delta = (nowX - btn._startX) / 120
            GPX.VisualBar:SetScaleForKind(kind, btn._startScale + delta)
        end)
    end)
    handle:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    frame._wowxResizeHandle = handle
    frame._wowxResizeKind = kind
end

function Bar:UpdateResizeHandles()
    local unlocked = not self:IsLayoutEditLocked()
    local function showHandle(frame)
        if frame and frame._wowxResizeHandle then
            frame._wowxResizeHandle:SetShown(unlocked)
        end
        if frame and frame._wowxMoveHandle then
            frame._wowxMoveHandle:SetShown(unlocked and frame == self.modifierFrame)
        end
        if frame and frame._wowxEditButton then
            frame._wowxEditButton:SetShown(unlocked)
        end
    end
    showHandle(self.frame)
    showHandle(self.frame and self.frame.bagBar or nil)
    showHandle(self.microMenuFrame)
    showHandle(self.modifierFrame)
    showHandle(self.stanceHostFrame)
    showHandle(self.petHostFrame or _G.PetActionBarFrame)
    showHandle(self.vehicleFrame)
    showHandle(self.progressFrame)
end

function Bar:GetDetachedStanceFrame()
    if self.stanceHostFrame then
        return self.stanceHostFrame
    end

    local frame = CreateFrame("Frame", "WoWXDetachedStanceFrame", UIParent)
    frame:SetWidth(132)
    frame:SetHeight(30)
    frame:SetFrameStrata("MEDIUM")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    ensureFrameChrome(frame)
    self.stanceHostFrame = frame
    return frame
end

function Bar:AvoidSingleStanceOverlap(stanceFrame, visibleStanceButtons)
    if not stanceFrame or not self.frame or not self:IsLayoutEditLocked() then
        return
    end
    if not visibleStanceButtons or #visibleStanceButtons ~= 1 then
        return
    end

    local stanceBoundsFrame = stanceFrame._wowxShell or stanceFrame
    local mainBoundsFrame = (self.frame and self.frame._wowxShell) or self.frame
    if not framesOverlap(stanceBoundsFrame, mainBoundsFrame) then
        return
    end

    stanceFrame:ClearAllPoints()
    stanceFrame:SetPoint("BOTTOMLEFT", self.frame, "TOPLEFT", 0, 14)
end

function Bar:GetDetachedPetFrame()
    if self.petHostFrame then
        return self.petHostFrame
    end

    local frame = CreateFrame("Frame", "WoWXDetachedPetFrame", UIParent)
    frame:SetWidth(360)
    frame:SetHeight(40)
    frame:SetFrameStrata("MEDIUM")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    ensureFrameChrome(frame)
    self.petHostFrame = frame
    return frame
end

function Bar:GetVehicleHostFrame()
    if self.vehicleFrame then
        return self.vehicleFrame
    end

    local frame = CreateFrame("Frame", "WoWXVehicleHostFrame", UIParent)
    frame:SetWidth(56)
    frame:SetHeight(56)
    frame:SetFrameStrata("MEDIUM")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    ensureFrameChrome(frame)
    self.vehicleFrame = frame
    return frame
end

function Bar:CreateLayoutEditor()
    if self.layoutEditor then
        return
    end

    local frame = CreateFrame("Frame", "WoWXLayoutEditorFrame", UIParent)
    frame:SetWidth(296)
    frame:SetHeight(352)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    createBackdrop(frame, 0.96, 0.8, 0.22, 0.9)
    frame:SetBackdropColor(0.05, 0.07, 0.12, 0.92)
    frame:Hide()

    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -12)
    title:SetTextColor(0.96, 0.98, 1.0)

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    subtitle:SetWidth(252)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetTextColor(0.78, 0.84, 0.95)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)

    local resetButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetButton:SetWidth(82)
    resetButton:SetHeight(22)
    resetButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 12)
    resetButton:SetText("Defaults")

    local doneButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    doneButton:SetWidth(82)
    doneButton:SetHeight(22)
    doneButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
    doneButton:SetText("Close")
    doneButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame.title = title
    frame.subtitle = subtitle
    frame.resetButton = resetButton
    frame.controls = {}

    for index = 1, 7 do
        local slider = CreateFrame("Slider", nil, frame)
        slider:SetOrientation("HORIZONTAL")
        slider:SetWidth(240)
        slider:SetHeight(18)
        slider:SetPoint("TOPLEFT", frame, "TOPLEFT", 26, -72 - ((index - 1) * 36))
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

        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 4)
        label:SetTextColor(0.92, 0.95, 1.0)

        local valueText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        valueText:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 4)
        valueText:SetTextColor(1.0, 0.92, 0.58)

        slider.label = label
        slider.valueText = valueText
        slider:Hide()
        slider:SetScript("OnValueChanged", function(self, value)
            if self._suspend or not self.control then
                return
            end
            local control = self.control
            local stepped = roundToStep(value, control.step)
            if math.abs(stepped - value) > 0.0001 then
                self._suspend = true
                self:SetValue(stepped)
                self._suspend = false
                return
            end
            self.valueText:SetText((control.format and control.format(stepped)) or formatSliderValue(stepped, control.step))
            control.set(stepped)
            if GPX.VisualBar then
                GPX.VisualBar:UpdateAll()
            end
        end)

        frame.controls[index] = slider
    end

    self.layoutEditor = frame
end

function Bar:GetEditorControls(kind)
    local controls = {}
    local layout = self:GetLayoutConfig(kind)

    local function add(label, minV, maxV, step, getter, setter, formatter)
        controls[#controls + 1] = {
            label = label,
            min = minV,
            max = maxV,
            step = step,
            get = getter,
            set = setter,
            format = formatter,
        }
    end

    if kind == "main" then
        add("Scale", 0.5, 2.0, 0.01,
            function() return select(1, self:GetScaleForKind("main")) end,
            function(value) self:SetScaleForKind("main", value) end,
            formatScaleValue)
        add("Visible Buttons", 1, 12, 1,
            function() return self:GetVisibleButtonCount() end,
            function(value) layout.buttonCount = clamp(math.floor(value + 0.5), 1, BAR_BUTTON_COUNT) end)
        add("Button Width", 42, 120, 1,
            function() return tonumber(layout.buttonWidth) or layoutDefaults.main.buttonWidth end,
            function(value) layout.buttonWidth = math.floor(value + 0.5) end)
        add("Button Height", 68, 156, 1,
            function() return tonumber(layout.buttonHeight) or layoutDefaults.main.buttonHeight end,
            function(value) layout.buttonHeight = math.floor(value + 0.5) end)
        add("Spacing", 0, 28, 1,
            function() return tonumber(layout.buttonSpacing) or layoutDefaults.main.buttonSpacing end,
            function(value) layout.buttonSpacing = math.floor(value + 0.5) end)
        add("Padding", 4, 36, 1,
            function() return tonumber(layout.padding) or layoutDefaults.main.padding end,
            function(value) layout.padding = math.floor(value + 0.5) end)
        add("Opacity", 0.35, 1.0, 0.01,
            function() return tonumber(layout.alpha) or layoutDefaults.main.alpha end,
            function(value) layout.alpha = clamp(value, 0.35, 1.0) end)
    elseif kind == "bag" then
        add("Scale", 0.5, 2.0, 0.01,
            function() return select(1, self:GetScaleForKind("bag")) end,
            function(value) self:SetScaleForKind("bag", value) end,
            formatScaleValue)
        add("Button Size", 18, 48, 1,
            function() return tonumber(layout.buttonSize) or layoutDefaults.bag.buttonSize end,
            function(value) layout.buttonSize = math.floor(value + 0.5) end)
        add("Spacing", 0, 20, 1,
            function() return tonumber(layout.buttonSpacing) or layoutDefaults.bag.buttonSpacing end,
            function(value) layout.buttonSpacing = math.floor(value + 0.5) end)
        add("Padding", 2, 20, 1,
            function() return tonumber(layout.padding) or layoutDefaults.bag.padding end,
            function(value) layout.padding = math.floor(value + 0.5) end)
        add("Opacity", 0.35, 1.0, 0.01,
            function() return tonumber(layout.alpha) or layoutDefaults.bag.alpha end,
            function(value) layout.alpha = clamp(value, 0.35, 1.0) end)
    elseif kind == "progress" then
        add("Width", 260, 960, 2,
            function() return tonumber(layout.width) or layoutDefaults.progress.width end,
            function(value) layout.width = math.floor(value + 0.5) end)
        add("Height", 18, 42, 1,
            function() return tonumber(layout.height) or layoutDefaults.progress.height end,
            function(value) layout.height = math.floor(value + 0.5) end)
        add("Opacity", 0.35, 1.0, 0.01,
            function() return tonumber(layout.alpha) or layoutDefaults.progress.alpha end,
            function(value) layout.alpha = clamp(value, 0.35, 1.0) end)
    elseif kind == "micro" or kind == "modifier" or kind == "stance" or kind == "pet" or kind == "vehicle" then
        add("Scale", 0.5, 2.0, 0.01,
            function() return select(1, self:GetScaleForKind(kind)) end,
            function(value) self:SetScaleForKind(kind, value) end,
            formatScaleValue)
        add("Opacity", 0.35, 1.0, 0.01,
            function() return tonumber(layout.alpha) or 1.0 end,
            function(value) layout.alpha = clamp(value, 0.35, 1.0) end)
    end

    return controls
end

function Bar:OpenLayoutEditor(kind, anchorFrame)
    self:CreateLayoutEditor()

    local editor = self.layoutEditor
    local controls = self:GetEditorControls(kind)
    editor.kind = kind
    editor.title:SetText((layoutTitles[kind] or "Bar") .. " Edit Mode")
    editor.subtitle:SetText("Adjust this bar in place. Changes save immediately to the current WoWX profile.")
    editor:ClearAllPoints()

    if anchorFrame and anchorFrame.IsShown and anchorFrame:IsShown() and anchorFrame.GetCenter then
        local anchorX, anchorY = anchorFrame:GetCenter()
        local parentMidX = UIParent:GetWidth() / 2
        local parentMidY = UIParent:GetHeight() / 2
        local onRightSide = anchorX and anchorX > parentMidX
        local nearBottom = anchorY and anchorY < parentMidY

        if nearBottom then
            if onRightSide then
                editor:SetPoint("BOTTOMRIGHT", anchorFrame, "TOPRIGHT", 0, 12)
            else
                editor:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", 0, 12)
            end
        else
            if onRightSide then
                editor:SetPoint("TOPRIGHT", anchorFrame, "BOTTOMRIGHT", 0, -12)
            else
                editor:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -12)
            end
        end
    else
        editor:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    for index, slider in ipairs(editor.controls) do
        local control = controls[index]
        if control then
            local value = control.get()
            slider.control = control
            slider.label:SetText(control.label)
            slider:SetMinMaxValues(control.min, control.max)
            slider:SetValueStep(control.step)
            slider._suspend = true
            slider:SetValue(value)
            slider.valueText:SetText((control.format and control.format(value)) or formatSliderValue(value, control.step))
            slider._suspend = false
            slider:Show()
        else
            slider.control = nil
            slider:Hide()
        end
    end

    editor.resetButton:SetScript("OnClick", function()
        if GPX.VisualBar then
            GPX.VisualBar:ResetLayoutForKind(kind)
            GPX.VisualBar:OpenLayoutEditor(kind, anchorFrame)
        end
    end)

    editor:Show()
end

function Bar:CreateMicroMenuFrame()
    if self.microMenuFrame then
        return
    end

    local frame = CreateFrame("Frame", "WoWXMicroMenuFrame", UIParent)
    frame:SetWidth(420)
    frame:SetHeight(28)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    createBackdrop(frame, 0.18, 0.24, 0.3, 0.7)
    self.microMenuFrame = frame
    self:EnableFrameDrag(frame, "micro")
    self:AttachMoveHandle(frame, "micro")
    self:AttachResizeHandle(frame, "micro")
    self:AttachEditButton(frame, "micro")
end

function Bar:CreateModifierFrame()
    if self.modifierFrame then
        return
    end

    local frame = CreateFrame("Frame", "WoWXModifierIndicatorFrame", UIParent)
    frame:SetWidth(320)
    frame:SetHeight(30)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    createBackdrop(frame, 0.18, 0.24, 0.3, 0.7)

    local chipContainer = CreateFrame("Frame", nil, frame)
    chipContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -4)
    chipContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 4)

    frame.chips = {}
    local chipLabels = { "SHIFT", "ALT", "CTRL", "SHIFT+ALT" }
    local xOffset = 0
    for index = #chipLabels, 1, -1 do
        local text = chipLabels[index]
        local chip = CreateFrame("Frame", nil, chipContainer)
        chip:SetWidth(index == 4 and 86 or 66)
        chip:SetHeight(22)
        chip:SetPoint("RIGHT", chipContainer, "RIGHT", -xOffset, 0)
        createBackdrop(chip, 0.25, 0.32, 0.42, 0.8)

        local label = chip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("CENTER", chip, "CENTER", 0, 0)
        label:SetText(text)
        chip.label = label
        frame.chips[index] = chip
        xOffset = xOffset + chip:GetWidth() + 8
    end

    self.modifierFrame = frame
    self:EnableFrameDrag(frame, "modifier")
    self:AttachMoveHandle(frame, "modifier")
    self:AttachResizeHandle(frame, "modifier")
    self:AttachEditButton(frame, "modifier")
end

function Bar:UpdateModifierIndicator(state)
    self:CreateModifierFrame()

    local layout = self:GetLayoutConfig("modifier")
    local point = self:GetStoredModifierPosition()
    local chromeAlpha = tonumber(layout.chromeAlpha) or layoutDefaults.modifier.chromeAlpha or 0.2
    local show = self:ShouldReplaceBlizzardBars() and self.frame and self.frame:IsShown()

    if not show then
        self.modifierFrame:Hide()
        return
    end

    self.modifierFrame:ClearAllPoints()
    self.modifierFrame:SetPoint(point.anchor, UIParent, point.relativePoint, point.x, point.y)
    self.modifierFrame:SetScale(select(1, self:GetScaleForKind("modifier")))
    self.modifierFrame:SetAlpha(tonumber(layout.alpha) or 1.0)
    self:ApplyChromeBackdrop(self.modifierFrame, chromeAlpha)
    self.modifierFrame:Show()

    local active = {
        SHIFT = state == "SHIFT" or state == "SHIFT-ALT",
        ALT = state == "ALT" or state == "SHIFT-ALT",
        CTRL = state == "CTRL",
        ["SHIFT+ALT"] = state == "SHIFT-ALT",
    }

    local totalWidth = 16
    local order = { "SHIFT", "ALT", "CTRL", "SHIFT+ALT" }
    for index, key in ipairs(order) do
        local chip = self.modifierFrame.chips[index]
        totalWidth = totalWidth + chip:GetWidth()
        if index > 1 then
            totalWidth = totalWidth + 8
        end
        if active[key] then
            chip:SetBackdropBorderColor(0.96, 0.8, 0.22, 0.95)
            chip:SetBackdropColor(0.18, 0.14, 0.05, 0.95)
            chip:SetAlpha(1.0)
        else
            chip:SetBackdropBorderColor(0.25, 0.32, 0.42, 0.8)
            chip:SetBackdropColor(0.05, 0.07, 0.12, 0.86)
            chip:SetAlpha(0.42)
        end
        chip:Show()
    end

    self.modifierFrame:SetWidth(totalWidth)
    self.modifierFrame:SetHeight(30)
end

function Bar:UpdateMicroMenu()
    self:CreateMicroMenuFrame()
    if InCombatLockdown() then
        self.pendingAttributeRefresh = true
        return
    end
    local layout = self:GetLayoutConfig("micro")
    local show = self:ShouldReplaceBlizzardBars() and (not GPX:IsControllerEnabled())
    if not show then
        self.microMenuFrame:Hide()
        return
    end

    local point = self:GetStoredMicroPosition()
    self.microMenuFrame:ClearAllPoints()
    self.microMenuFrame:SetPoint(point.anchor, UIParent, point.relativePoint, point.x, point.y)
    self.microMenuFrame:SetScale(select(1, self:GetScaleForKind("micro")))
    self.microMenuFrame:SetAlpha(tonumber(layout.alpha) or 1.0)

    local prev
    local visibleButtons = {}
    local buttonCount = 0
    local contentWidth = 16
    for _, name in ipairs(orderedMicroButtons) do
        local btn = _G[name]
        if btn then
            btn:SetParent(self.microMenuFrame)
            btn:ClearAllPoints()
            if not prev then
                btn:SetPoint("LEFT", self.microMenuFrame, "LEFT", 8, 0)
            else
                btn:SetPoint("LEFT", prev, "RIGHT", -2, 0)
            end
            btn._wowxShellAnchorTarget = (btn.GetNormalTexture and btn:GetNormalTexture()) or btn
            btn:Show()
            visibleButtons[#visibleButtons + 1] = btn
            prev = btn
            buttonCount = buttonCount + 1
            contentWidth = contentWidth + getEffectiveFrameWidth(btn)
            if buttonCount > 1 then
                contentWidth = contentWidth - 2
            end
        end
    end

    if buttonCount == 0 then
        self.microMenuFrame:Hide()
        return
    end

    self.microMenuFrame:SetWidth(math.max(36, contentWidth + 8))
    self.microMenuFrame:SetHeight(26)
    self:ApplyChromeBackdrop(self.microMenuFrame, 0.12)
    updateShellAroundButtons(self.microMenuFrame, visibleButtons, 4, 4)
    if self.microMenuFrame._wowxShell then
        self.microMenuFrame._wowxShell:SetBackdropColor(0.0, 0.0, 0.0, 0.0)
        self.microMenuFrame._wowxShell:SetBackdropBorderColor(0.0, 0.0, 0.0, 0.0)
    end

    self.microMenuFrame:Show()
end

function Bar:UpdateDetachedClassBars()
    local stanceLayout = self:GetLayoutConfig("stance")
    local petLayout = self:GetLayoutConfig("pet")
    local show = self:ShouldReplaceBlizzardBars()
    local inCombat = InCombatLockdown()

    -- Detached stance/pet hosts can become protected when secure buttons are parented to them.
    -- Never mutate their visibility/layout during combat; refresh after lockdown ends.
    if inCombat then
        self.pendingAttributeRefresh = true
        return
    end

    local stanceFrame = self:GetDetachedStanceFrame()
    if show then
        local stanceButtons = {}
        for index = 1, 12 do
            local button = _G["ShapeshiftButton" .. index] or _G["StanceButton" .. index] or _G["PossessButton" .. index]
            if button then
                stanceButtons[#stanceButtons + 1] = button
            end
        end
        local formCount = getShapeshiftFormCount()
        local visibleStanceButtons = getVisibleButtons(stanceButtons)
        if #visibleStanceButtons == 0 and formCount > 0 then
            visibleStanceButtons = getFormBackedButtons(stanceButtons, formCount)
        end
        if #visibleStanceButtons == 0 then
            if not self:IsLayoutEditLocked() and stanceFrame then
                ensureFrameChrome(stanceFrame)
                self:SyncStanceFramePositions()
                stanceFrame:SetScale(select(1, self:GetScaleForKind("stance")))
                stanceFrame:SetAlpha(tonumber(stanceLayout.alpha) or 1.0)
                self:ApplyChromeBackdrop(stanceFrame, 0.12)
                stanceFrame:SetWidth(132)
                stanceFrame:SetHeight(30)
                stanceFrame:Show()
                local placeholder = ensurePlaceholderLabel(stanceFrame)
                if placeholder then
                    placeholder:SetText("Aura / Stance")
                    placeholder:Show()
                end
                self:EnsureAuxMovable(stanceFrame, function(selfFrame)
                    GPX.VisualBar:SaveAuxFramePosition(selfFrame, "stancePoint", "BOTTOM", "BOTTOM")
                    GPX.VisualBar:SyncStanceFramePositions(selfFrame)
                end)
                self:AttachMoveHandle(stanceFrame, "stance")
                self:AttachResizeHandle(stanceFrame, "stance")
                self:AttachEditButton(stanceFrame, "stance")
                self:EnableFrameDrag(stanceFrame, "stance")
            elseif stanceFrame then
                stanceFrame:Hide()
            end
            if stanceFrame and stanceFrame._wowxShell then
                stanceFrame._wowxShell:Hide()
            end
        else
        ensureFrameChrome(stanceFrame)
        self:SyncStanceFramePositions()
        stanceFrame:SetScale(select(1, self:GetScaleForKind("stance")))
        stanceFrame:SetAlpha(tonumber(stanceLayout.alpha) or 1.0)
        for _, button in ipairs(visibleStanceButtons) do
            button:SetParent(stanceFrame)
            button:Show()
            button:SetAlpha(1.0)
        end
        layoutAuxButtons(stanceFrame, visibleStanceButtons, 8, 6)
        stanceFrame:Show()
        if stanceFrame._wowxPlaceholderLabel then
            stanceFrame._wowxPlaceholderLabel:Hide()
        end
        updateShellAroundButtons(stanceFrame, visibleStanceButtons, 8, 8)
        if stanceFrame._wowxShell then
            stanceFrame:SetBackdropBorderColor(0.22, 0.66, 0.98, 0.0)
            stanceFrame:SetBackdropColor(0.05, 0.07, 0.12, 0.0)
            self:ApplyChromeBackdrop(stanceFrame._wowxShell, 0.12)
        end
        self:AvoidSingleStanceOverlap(stanceFrame, visibleStanceButtons)
        self:EnsureAuxMovable(stanceFrame, function(selfFrame)
            GPX.VisualBar:SaveAuxFramePosition(selfFrame, "stancePoint", "BOTTOM", "BOTTOM")
            GPX.VisualBar:SyncStanceFramePositions(selfFrame)
        end)
        self:AttachMoveHandle(stanceFrame, "stance")
        self:AttachResizeHandle(stanceFrame, "stance")
        self:AttachEditButton(stanceFrame, "stance")
        self:EnableFrameDrag(stanceFrame, "stance")
        end
    elseif self.stanceHostFrame then
        self.stanceHostFrame:Hide()
        if self.stanceHostFrame._wowxShell then
            self.stanceHostFrame._wowxShell:Hide()
        end
    end

    local petFrame = self:GetDetachedPetFrame()
    if petFrame and show then
        local petButtons = {}
        for index = 1, 12 do
            local button = _G["PetActionButton" .. index]
            if button then
                petButtons[#petButtons + 1] = button
            end
        end
        local visiblePetButtons = getVisibleButtons(petButtons)
        if #visiblePetButtons == 0 then
            if not self:IsLayoutEditLocked() then
                ensureFrameChrome(petFrame)
                local point = self:GetStoredPetPosition()
                petFrame:SetParent(UIParent)
                petFrame:ClearAllPoints()
                petFrame:SetPoint(point.anchor, UIParent, point.relativePoint, point.x, point.y)
                petFrame:SetScale(select(1, self:GetScaleForKind("pet")))
                petFrame:SetAlpha(tonumber(petLayout.alpha) or 1.0)
                self:ApplyChromeBackdrop(petFrame, 0.12)
                petFrame:SetBackdropBorderColor(0.22, 0.66, 0.98, 0.9)
                local placeholderButtons = ensureAuxPlaceholderButtons(petFrame, "pet", PET_ACTION_BUTTON_COUNT, 28)
                layoutAuxButtons(petFrame, placeholderButtons, 8, 6)
                updateShellAroundButtons(petFrame, placeholderButtons, 8, 8)
                if petFrame._wowxShell then
                    petFrame:SetBackdropBorderColor(0.22, 0.66, 0.98, 0.0)
                    self:ApplyChromeBackdrop(petFrame._wowxShell, 0.12)
                end
                petFrame:Show()
                local placeholder = ensurePlaceholderLabel(petFrame)
                if placeholder then
                    placeholder:SetText("Pet")
                    placeholder:Show()
                end
                self:EnsureAuxMovable(petFrame, function(selfFrame)
                    GPX.VisualBar:SaveAuxFramePosition(selfFrame, "petPoint", "BOTTOM", "BOTTOM")
                end)
                self:AttachMoveHandle(petFrame, "pet")
                self:AttachResizeHandle(petFrame, "pet")
                self:AttachEditButton(petFrame, "pet")
                self:EnableFrameDrag(petFrame, "pet")
            else
                petFrame:Hide()
                hideAuxPlaceholderButtons(petFrame, "pet")
                if petFrame._wowxPlaceholderLabel then
                    petFrame._wowxPlaceholderLabel:Hide()
                end
            end
            if petFrame._wowxShell then
                if self:IsLayoutEditLocked() then
                    petFrame._wowxShell:Hide()
                end
            end
        else
            ensureFrameChrome(petFrame)
            hideAuxPlaceholderButtons(petFrame, "pet")
            local point = self:GetStoredPetPosition()
            petFrame:SetParent(UIParent)
            petFrame:ClearAllPoints()
            petFrame:SetPoint(point.anchor, UIParent, point.relativePoint, point.x, point.y)
            petFrame:SetScale(select(1, self:GetScaleForKind("pet")))
            petFrame:SetAlpha(tonumber(petLayout.alpha) or 1.0)
            for _, button in ipairs(visiblePetButtons) do
                button:SetParent(petFrame)
                button:Show()
                button:SetAlpha(1.0)
            end
            layoutAuxButtons(petFrame, visiblePetButtons, 8, 6)
            petFrame:Show()
            if petFrame._wowxPlaceholderLabel then
                petFrame._wowxPlaceholderLabel:Hide()
            end
            updateShellAroundButtons(petFrame, visiblePetButtons, 8, 8)
            if petFrame._wowxShell then
                petFrame:SetBackdropBorderColor(0.22, 0.66, 0.98, 0.0)
                petFrame:SetBackdropColor(0.05, 0.07, 0.12, 0.0)
                self:ApplyChromeBackdrop(petFrame._wowxShell, 0.12)
            end
            self:EnsureAuxMovable(petFrame, function(selfFrame)
                GPX.VisualBar:SaveAuxFramePosition(selfFrame, "petPoint", "BOTTOM", "BOTTOM")
            end)
            self:AttachMoveHandle(petFrame, "pet")
            self:AttachResizeHandle(petFrame, "pet")
            self:AttachEditButton(petFrame, "pet")
            self:EnableFrameDrag(petFrame, "pet")
        end
    elseif self.petHostFrame then
        self.petHostFrame:Hide()
        if self.petHostFrame._wowxShell then
            self.petHostFrame._wowxShell:Hide()
        end
    end
end

function Bar:GetVehicleLeaveButton()
    for _, name in ipairs(vehicleLeaveButtonCandidates) do
        local button = _G[name]
        if button then
            return button
        end
    end
    return nil
end

function Bar:UpdateVehicleLeaveButton()
    local hostFrame = self:GetVehicleHostFrame()
    local layout = self:GetLayoutConfig("vehicle")
    local point = self:GetStoredVehiclePosition()
    local button = self:GetVehicleLeaveButton()
    local active = (CanExitVehicle and CanExitVehicle())
        or (UnitHasVehicleUI and UnitHasVehicleUI("player"))
        or (HasVehicleActionBar and HasVehicleActionBar())

    hostFrame:SetParent(UIParent)
    hostFrame:ClearAllPoints()
    hostFrame:SetPoint(point.anchor, UIParent, point.relativePoint, point.x, point.y)
    hostFrame:SetScale(select(1, self:GetScaleForKind("vehicle")))
    hostFrame:SetAlpha(tonumber(layout.alpha) or 1.0)

    if active and button then
        hideAuxPlaceholderButtons(hostFrame, "vehicle")
        if hostFrame._wowxPlaceholderLabel then
            hostFrame._wowxPlaceholderLabel:Hide()
        end

        ensureFrameChrome(hostFrame)
        self:ApplyChromeBackdrop(hostFrame, 0.12)
        button:SetParent(hostFrame)
        button:ClearAllPoints()
        button:SetPoint("CENTER", hostFrame, "CENTER", 0, 0)
        hostFrame:SetWidth(math.max(40, getEffectiveFrameWidth(button) + 12))
        hostFrame:SetHeight(math.max(40, (button.GetHeight and button:GetHeight() or 24) + 12))
        updateShellAroundButtons(hostFrame, { button }, 6, 6)
        if hostFrame._wowxShell then
            hostFrame:SetBackdropBorderColor(0.22, 0.66, 0.98, 0.0)
            self:ApplyChromeBackdrop(hostFrame._wowxShell, 0.12)
        end
        hostFrame:Show()
        button:SetFrameStrata("HIGH")
        button:Show()
        self:EnsureAuxMovable(hostFrame, function(selfFrame)
            GPX.VisualBar:SaveAuxFramePosition(selfFrame, "vehiclePoint", "BOTTOM", "BOTTOM")
        end)
        self:AttachMoveHandle(hostFrame, "vehicle")
        self:AttachResizeHandle(hostFrame, "vehicle")
        self:AttachEditButton(hostFrame, "vehicle")
        self:EnableFrameDrag(hostFrame, "vehicle")
        return
    end

    if not self:IsLayoutEditLocked() then
        ensureFrameChrome(hostFrame)
        self:ApplyChromeBackdrop(hostFrame, 0.12)
        local placeholderButtons = ensureAuxPlaceholderButtons(hostFrame, "vehicle", 1, 30)
        layoutAuxButtons(hostFrame, placeholderButtons, 8, 0)
        updateShellAroundButtons(hostFrame, placeholderButtons, 8, 8)
        if hostFrame._wowxShell then
            hostFrame:SetBackdropBorderColor(0.22, 0.66, 0.98, 0.0)
            self:ApplyChromeBackdrop(hostFrame._wowxShell, 0.12)
        end
        hostFrame:Show()
        local placeholder = ensurePlaceholderLabel(hostFrame)
        if placeholder then
            placeholder:SetText("Vehicle Exit")
            placeholder:Show()
        end
        self:EnsureAuxMovable(hostFrame, function(selfFrame)
            GPX.VisualBar:SaveAuxFramePosition(selfFrame, "vehiclePoint", "BOTTOM", "BOTTOM")
        end)
        self:AttachMoveHandle(hostFrame, "vehicle")
        self:AttachResizeHandle(hostFrame, "vehicle")
        self:AttachEditButton(hostFrame, "vehicle")
        self:EnableFrameDrag(hostFrame, "vehicle")
    else
        hostFrame:Hide()
        hideAuxPlaceholderButtons(hostFrame, "vehicle")
        if hostFrame._wowxPlaceholderLabel then
            hostFrame._wowxPlaceholderLabel:Hide()
        end
        if hostFrame._wowxShell then
            hostFrame._wowxShell:Hide()
        end
    end
end

function Bar:GetBarScale()
    local config = ensureVisualBarConfig()
    local scale = tonumber(config.scale) or 1.0
    if scale < 0.5 then scale = 0.5 end
    if scale > 2.0 then scale = 2.0 end
    return scale
end

function Bar:AdjustScale(delta)
    if self:IsLayoutEditLocked() then
        GPX:Print("Visual bar is locked. Unlock it to resize.")
        return
    end

    local config = ensureVisualBarConfig()
    local scale = self:GetBarScale() + delta
    if scale < 0.5 then scale = 0.5 end
    if scale > 2.0 then scale = 2.0 end
    config.scale = scale
    self:UpdateAll()
    GPX:Print(string.format("Visual bar scale: %.2f", scale))
end

function Bar:ToggleKeepBags()
    GPX:Print("Blizzard bag buttons are auto-hidden while WoWX bar replacement is active.")
end

function Bar:ToggleKeepMicroMenu()
    GPX:Print("Micro menu visibility is automatic: shown in keyboard mode, hidden in controller mode.")
end

function Bar:ToggleKeepStanceBar()
    GPX:Print("Stance/possess bars are kept active and detached automatically.")
end

function Bar:ToggleKeepPetBar()
    GPX:Print("Pet bar is kept active and detached automatically.")
end

function Bar:AdjustAuxScale(kind, delta)
    local current = select(1, self:GetScaleForKind(kind))
    local nextScale = current + delta
    self:SetScaleForKind(kind, nextScale)
    self:UpdateResizeHandles()
    GPX:Print(string.format("%s scale: %.2f", kind, select(1, self:GetScaleForKind(kind))))
end

function Bar:ResetAuxPosition(kind)
    local config = ensureVisualBarConfig()
    if kind == "stance" then
        config.stancePoint = GPX:DeepCopy(GPX.defaults.ui.visualBar.stancePoint)
        self:SyncStanceFramePositions()
        self:UpdateAll()
        GPX:Print("Aura / stance bar position reset.")
    elseif kind == "pet" then
        config.petPoint = GPX:DeepCopy(GPX.defaults.ui.visualBar.petPoint)
        self:UpdateAll()
        GPX:Print("Pet bar position reset.")
    end
end

function Bar:ToggleBagBar()
    local config = ensureVisualBarConfig()
    config.showBagBar = not config.showBagBar
    self:UpdateAll()
    GPX:Print(config.showBagBar and "WoWX bag bar shown." or "WoWX bag bar hidden.")
end

function Bar:ToggleProgressBar()
    local config = ensureVisualBarConfig()
    config.showProgress = not config.showProgress
    self:UpdateAll()
    GPX:Print(config.showProgress and "WoWX XP/Rep bar shown." or "WoWX XP/Rep bar hidden.")
end

function Bar:IsAtMaxLevel()
    local maxPlayerLevel = MAX_PLAYER_LEVEL_TABLE and MAX_PLAYER_LEVEL_TABLE[GetExpansionLevel()] or MAX_PLAYER_LEVEL
    return UnitLevel("player") >= (maxPlayerLevel or 80)
end

function Bar:UpdateProgressBar()
    if not self.progressFrame or not self.progressFrame.progressBar then
        return
    end

    local config = ensureVisualBarConfig()
    local layout = self:GetLayoutConfig("progress")
    if config.showProgress == false then
        self.progressFrame:Hide()
        return
    end

    self.progressFrame:SetWidth(tonumber(layout.width) or layoutDefaults.progress.width)
    self.progressFrame:SetHeight(tonumber(layout.height) or layoutDefaults.progress.height)
    self.progressFrame:SetAlpha(tonumber(layout.alpha) or layoutDefaults.progress.alpha)

    local progressBar = self.progressFrame.progressBar
    local progressText = self.progressFrame.progressText
    progressBar:ClearAllPoints()
    progressBar:SetPoint("TOPLEFT", self.progressFrame, "TOPLEFT", 6, -6)
    progressBar:SetPoint("BOTTOMRIGHT", self.progressFrame, "BOTTOMRIGHT", -6, 6)

    local name, _, standingID, min, max, value = GetWatchedFactionInfo()
    if name and min and max and max > min and value then
        local current = value - min
        local total = max - min
        local pct = total > 0 and (current / total) or 0
        local color = FACTION_BAR_COLORS and FACTION_BAR_COLORS[standingID or 1] or { r = 0.0, g = 0.6, b = 1.0 }
        progressBar:SetMinMaxValues(0, total)
        progressBar:SetValue(current)
        progressBar:SetStatusBarColor(color.r, color.g, color.b)
        progressText:SetText(string.format("%s  %d%%", name, math.floor(pct * 100 + 0.5)))
        self.progressFrame:Show()
        return
    end

    local xpMax = UnitXPMax("player") or 0
    if xpMax > 0 and not self:IsAtMaxLevel() then
        local xp = UnitXP("player") or 0
        local pct = xpMax > 0 and (xp / xpMax) or 0
        local rested = GetXPExhaustion and (GetXPExhaustion() or 0) or 0
        local restedPct = xpMax > 0 and math.floor((rested / xpMax) * 100 + 0.5) or 0
        progressBar:SetMinMaxValues(0, xpMax)
        progressBar:SetValue(xp)
        progressBar:SetStatusBarColor(0.35, 0.2, 0.8)
        if rested > 0 then
            progressText:SetText(string.format("XP %d%%  Rested +%d%%", math.floor(pct * 100 + 0.5), restedPct))
        else
            progressText:SetText(string.format("XP %d%%", math.floor(pct * 100 + 0.5)))
        end
        self.progressFrame:Show()
        return
    end

    if self:IsLocked() then
        self.progressFrame:Hide()
        return
    end

    progressBar:SetMinMaxValues(0, 1)
    progressBar:SetValue(1)
    progressBar:SetStatusBarColor(0.2, 0.28, 0.34)
    progressText:SetText("XP / Rep")
    self.progressFrame:Show()
end

function Bar:ToggleBagSlot(bagID)
    if bagID == 0 then
        if ToggleBackpack then ToggleBackpack() end
        return
    end
    if ToggleBag then
        ToggleBag(bagID)
    end
end

function Bar:UpdateBagBar()
    if not self.frame or not self.frame.bagBar or not self.frame.bagButtons then
        return
    end

    local config = ensureVisualBarConfig()
    local layout = self:GetLayoutConfig("bag")
    local controllerEnabled = GPX.IsControllerEnabled and GPX:IsControllerEnabled()
    local show = (config.showBagBar ~= false) and not controllerEnabled
    self.frame.bagBar:SetShown(show)
    if not show then
        return
    end

    local buttonSize = math.floor(tonumber(layout.buttonSize) or layoutDefaults.bag.buttonSize)
    local spacing = math.floor(tonumber(layout.buttonSpacing) or layoutDefaults.bag.buttonSpacing)
    local padding = math.floor(tonumber(layout.padding) or layoutDefaults.bag.padding)
    local chromeAlpha = tonumber(layout.chromeAlpha) or layoutDefaults.bag.chromeAlpha or 0.32
    local width = (padding * 2) + (buttonSize * 5) + (spacing * 4)
    local height = buttonSize + (padding * 2)

    self.frame.bagBar:SetWidth(width)
    self.frame.bagBar:SetHeight(height)
    self.frame.bagBar:SetAlpha(tonumber(layout.alpha) or layoutDefaults.bag.alpha)
    self:ApplyChromeBackdrop(self.frame.bagBar, chromeAlpha * 0.8)
    self.frame.bagBar:SetScale(select(1, self:GetScaleForKind("bag")))
    self:ApplyStoredBagPosition()

    local buttonBorderR, buttonBorderG, buttonBorderB = 0.22, 0.66, 0.98
    if self:IsEditChromeActive() then
        buttonBorderR, buttonBorderG, buttonBorderB = 0.96, 0.8, 0.22
    end

    local bagButtons = {}

    for bagID = 0, 4 do
        local button = self.frame.bagButtons[bagID]
        local invSlot = bagID == 0 and 16 or ((ContainerIDToInventoryID and ContainerIDToInventoryID(bagID)) or (19 + bagID))
        local texture = GetInventoryItemTexture("player", invSlot)
        button:ClearAllPoints()
        button:SetWidth(buttonSize)
        button:SetHeight(buttonSize)
        button:SetPoint("LEFT", self.frame.bagBar, "LEFT", padding + ((4 - bagID) * (buttonSize + spacing)), 0)
        layoutSlotWrapper(button, 1, 1, 1, 1)
        button.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_Bag_08")
        button.icon:ClearAllPoints()
        button.icon:SetPoint("TOPLEFT", button.slotPanel, "TOPLEFT", 2, -2)
        button.icon:SetPoint("BOTTOMRIGHT", button.slotPanel, "BOTTOMRIGHT", -2, 2)
        button.slotBorder:SetVertexColor(buttonBorderR, buttonBorderG, buttonBorderB, 0.95)
        button:SetBackdropColor(0.05, 0.07, 0.12, 0.08)
        button:SetBackdropBorderColor(buttonBorderR, buttonBorderG, buttonBorderB, 0.28)
        bagButtons[#bagButtons + 1] = button
    end

    updateShellAroundButtons(self.frame.bagBar, bagButtons, 4, 4)
    if self.frame.bagBar._wowxShell then
        self.frame.bagBar._wowxShell:SetBackdropColor(0.0, 0.0, 0.0, 0.0)
        self.frame.bagBar._wowxShell:SetBackdropBorderColor(0.0, 0.0, 0.0, 0.0)
    end
end

function Bar:GetStoredPosition()
    local config = ensureVisualBarConfig()
    return config.point or GPX:DeepCopy(GPX.defaults.ui.visualBar.point)
end

function Bar:ApplyStoredPosition()
    local point = self:GetStoredPosition()
    self.frame:ClearAllPoints()
    self.frame:SetPoint(point.anchor, UIParent, point.relativePoint, point.x, point.y)
end

function Bar:SavePosition()
    local config = ensureVisualBarConfig()
    local anchor, _, relativePoint, x, y = self.frame:GetPoint(1)
    config.point = {
        anchor = anchor or "BOTTOM",
        relativeTo = "UIParent",
        relativePoint = relativePoint or "BOTTOM",
        x = x or 0,
        y = y or 48,
    }
end

function Bar:IsLocked()
    return ensureVisualBarConfig().locked ~= false
end

function Bar:IsButtonLockEnabled()
    return ensureVisualBarConfig().buttonLocked ~= false
end

function Bar:IsLayoutEditLocked()
    return self:IsLocked() or InCombatLockdown()
end

function Bar:GetButtonEditBlockReason()
    if InCombatLockdown() then
        return "combat"
    end
    if not self:IsLayoutEditLocked() then
        return "layout"
    end
    if self:IsButtonLockEnabled() then
        return "buttonlock"
    end
    return nil
end

function Bar:IsEditChromeActive()
    return (not self:IsLayoutEditLocked()) or (GPX.UIMode and GPX.UIMode.activeContext == "bar")
end

function Bar:ApplyChromeBackdrop(frame, alpha, isActive)
    if not frame or not frame.SetBackdropBorderColor or not frame.SetBackdropColor then
        return
    end

    local active = isActive
    if active == nil then
        active = self:IsEditChromeActive()
    end

    if active then
        frame:SetBackdropBorderColor(0.96, 0.8, 0.22, 0.96)
        frame:SetBackdropColor(0.12, 0.09, 0.03, math.max(alpha or 0.12, 0.16))
    else
        frame:SetBackdropBorderColor(0.22, 0.66, 0.98, 0.9)
        frame:SetBackdropColor(0.05, 0.07, 0.12, alpha or 0.12)
    end
end

function Bar:IsButtonEditLocked()
    return self:GetButtonEditBlockReason() ~= nil
end

function Bar:NotifyButtonEditBlocked(reason, actionText)
    if reason == "combat" then
        return
    end
    if reason == "layout" then
        GPX:Print("Layout edit is active. Lock layout edit before changing buttons.")
        return
    end
    GPX:Print("Button lock is enabled. Unlock bar buttons to " .. (actionText or "edit slots") .. ".")
end

function Bar:IsProgressLocked()
    return self:IsLayoutEditLocked()
end

function Bar:GetStoredProgressPosition()
    local config = ensureVisualBarConfig()
    return config.progressPoint or GPX:DeepCopy(GPX.defaults.ui.visualBar.progressPoint)
end

function Bar:ApplyStoredProgressPosition()
    if not self.progressFrame then
        return
    end
    local point = self:GetStoredProgressPosition()
    self.progressFrame:ClearAllPoints()
    self.progressFrame:SetPoint(point.anchor, UIParent, point.relativePoint, point.x, point.y)
end

function Bar:SaveProgressPosition()
    if not self.progressFrame then
        return
    end
    local config = ensureVisualBarConfig()
    local anchor, _, relativePoint, x, y = self.progressFrame:GetPoint(1)
    config.progressPoint = {
        anchor = anchor or "BOTTOM",
        relativeTo = "UIParent",
        relativePoint = relativePoint or "BOTTOM",
        x = x or 0,
        y = y or 170,
    }
end

function Bar:ToggleProgressLock()
    self:Slash((self:IsLocked() and "unlock") or "lock")
end

function Bar:GetPhysicalKeyForButton(index)
    local setup = self:GetSetup()
    if not setup then
        return defaultKeyHints[index]
    end

    if GPX:IsControllerEnabled() then
        return GPX:GetSetupActionKey(setup, index) or defaultKeyHints[index]
    end

    if index == 1 then
        return setup.jumpKey or defaultKeyHints[index]
    end
    return GPX:GetSetupActionKey(setup, index) or defaultKeyHints[index]
end

function Bar:GetCommandForButton(index, state)
    local page = modifierStates[state]
    if state == "" or not self:UseModifierPages() then
        return "ACTIONBUTTON" .. index
    end
    if page and page.bar then
        return page.bar .. index
    end
    return nil
end

function Bar:GetSlotForButtonState(index, state)
    local command = self:GetCommandForButton(index, state)
    if not command then
        return nil
    end
    return self:ResolveCommand(command)
end

function Bar:GetButtonCandidates(command)
    local index = tonumber(command and command:match("(%d+)$"))
    if not index then return nil end

    if command:find("^ACTIONBUTTON") then
        return { "ActionButton" .. index }
    end
    if command:find("^MULTIACTIONBAR1BUTTON") then
        return { "MultiBarBottomLeftButton" .. index }
    end
    if command:find("^MULTIACTIONBAR2BUTTON") then
        return { "MultiBarBottomRightButton" .. index }
    end
    if command:find("^MULTIACTIONBAR3BUTTON") then
        return { "MultiBarRightButton" .. index }
    end
    if command:find("^MULTIACTIONBAR4BUTTON") then
        return { "MultiBarLeftButton" .. index }
    end

    return nil
end

local function getCurrentMainActionPage()
    if GetBonusBarOffset then
        local bonusOffset = tonumber(GetBonusBarOffset()) or 0
        if bonusOffset > 0 then
            return 6 + bonusOffset
        end
    end

    -- Ascension PTR can report stale/non-visual page values after aura-driven swaps;
    -- treat base page as authoritative whenever bonus offset is zero.
    return 1
end

function Bar:ResolveCommand(command)
    local mainIndex = tonumber(command and command:match("^ACTIONBUTTON(%d+)$"))
    if mainIndex then
        local liveButton = _G["ActionButton" .. mainIndex]
        local liveAction = liveButton and liveButton.action or nil
        local bonusOffset = GetBonusBarOffset and (tonumber(GetBonusBarOffset()) or 0) or 0
        local page = getCurrentMainActionPage()
        local slot = ((page - 1) * 12) + mainIndex

        -- On Ascension PTR, hasOverride can remain noisy while bonusOffset is the
        -- reliable signal for Runeshroud page routing. Treat bonusOffset as
        -- authoritative for ACTIONBUTTON slot resolution.
        if bonusOffset > 0 then
            return slot
        end

        if page > 1 then
            if liveAction then
                return liveAction
            end
            if HasAction and HasAction(slot) then
                return slot
            end
            return slot
        end

        if liveAction and liveAction ~= mainIndex then
            return liveAction
        end

        if HasAction and HasAction(slot) then
            return slot
        end

        if liveButton and liveButton.action then
            return liveButton.action
        end
        return slot
    end

    local candidates = self:GetButtonCandidates(command)
    if not candidates then
        return nil
    end

    for _, buttonName in ipairs(candidates) do
        local button = _G[buttonName]
        if button and button.action then
            return button.action
        end
    end

    return nil
end

function Bar:GetActionName(slot)
    local actionType, actionID = GetActionInfo(slot)
    if actionType == "spell" then
        local name = GetSpellInfo(actionID)
        return name
    elseif actionType == "macro" then
        local name = GetMacroInfo(actionID)
        return name
    elseif actionType == "item" then
        local name = GetItemInfo(actionID)
        return name
    end

    return nil
end

function Bar:GetDisplayForButton(index, state)
    local style = self:GetStyle()
    local slotLabel = "Action " .. index
    if GPX:IsControllerEnabled() then
        local setup = self:GetSetup()
        local labels = GPX:GetCombatDisplayLabels(setup and setup.deviceId)
        if labels[index] then
            slotLabel = labels[index]
        end
    elseif style and style.slotLabels and style.slotLabels[index] then
        slotLabel = style.slotLabels[index]
    end

    local command = self:GetCommandForButton(index, state)

    if not command then
        return {
            icon = nil,
            title = slotLabel,
            subtitle = state == "" and "Empty" or "No page",
            hint = "No mapped page",
        }
    end

    local slot = self:ResolveCommand(command)
    local texture = slot and GetActionTexture(slot) or nil
    return {
        icon = texture,
        title = slotLabel,
        subtitle = "",
        slot = slot,
        command = command,
        hint = command,
    }
end

function Bar:UpdateButtonTooltip(button)
    if not button.display then
        return
    end

    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    if button.display.slot then
        GameTooltip:SetAction(button.display.slot)
    else
        GameTooltip:AddLine(button.display.title or "WoWX", 1.0, 0.96, 0.7)
        GameTooltip:AddLine(button.display.subtitle or "", 0.85, 0.9, 1.0)
    end

    if button.physicalKey and button.physicalKey ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("WoWX Key", button.physicalKey, 0.7, 0.82, 0.95, 1.0, 0.92, 0.58)
    end

    if button.display and button.display.hint then
        GameTooltip:AddDoubleLine("Page", button.display.hint, 0.7, 0.82, 0.95, 0.82, 0.9, 0.98)
    end

    if button.display and button.display.slot then
        GameTooltip:AddLine("Drag spells, items, or macros here to place them on this WoWX page.", 0.75, 0.82, 0.9, true)
    end
    GameTooltip:Show()
end

function Bar:PlaceCursorIntoButton(button)
    if not button.display or not button.display.slot or button.display.utilityId then
        return
    end
    local blockReason = self:GetButtonEditBlockReason()
    if blockReason then
        if not isCursorCarryingActionPayload() then
            self:NotifyButtonEditBlocked(blockReason, "edit slots")
        end
        return
    end
    if isCursorCarryingActionPayload() then
        PlaceAction(button.display.slot)
        self:UpdateAll()
    end
end

function Bar:HandleRightClickEdit(button)
    if not button or not button.display or not button.display.slot or button.display.utilityId then
        return
    end
    local blockReason = self:GetButtonEditBlockReason()
    if blockReason then
        if not isCursorCarryingActionPayload() then
            self:NotifyButtonEditBlocked(blockReason, "edit slots")
        end
        return
    end

    if isCursorCarryingActionPayload() then
        PlaceAction(button.display.slot)
        self:UpdateAll()
    else
        PickupAction(button.display.slot)
    end
end

function Bar:PickupFromButton(button)
    if not button.display or not button.display.slot or button.display.utilityId then
        return
    end
    local blockReason = self:GetButtonEditBlockReason()
    if blockReason then
        self:NotifyButtonEditBlocked(blockReason, "edit slots")
        return
    end
    PickupAction(button.display.slot)
end

function Bar:IsPlacementModeEnabled()
    local config = ensureVisualBarConfig()
    return config.placementMode == true
end

function Bar:TogglePlacementMode()
    local config = ensureVisualBarConfig()
    config.placementMode = not (config.placementMode == true)
    self:UpdateAll()
    GPX:Print(config.placementMode and "Placement mode: ON (all pages visible)." or "Placement mode: OFF.")
end

function Bar:UpdatePlacementButtonTooltip(button)
    if not button then
        return
    end

    local slot = self:GetSlotForButtonState(button.slotIndex, button.state)
    local command = self:GetCommandForButton(button.slotIndex, button.state)
    local physicalKey = self:GetPhysicalKeyForButton(button.slotIndex)

    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    if slot then
        GameTooltip:SetAction(slot)
    else
        GameTooltip:AddLine("Empty slot", 0.95, 0.95, 1.0)
    end
    GameTooltip:AddDoubleLine("Page", command or "(none)", 0.7, 0.82, 0.95, 0.9, 0.95, 1.0)
    GameTooltip:AddDoubleLine("Key", physicalKey or "", 0.7, 0.82, 0.95, 1.0, 0.92, 0.58)
    GameTooltip:AddLine("Drag or right-click to place/pick actions on this page slot.", 0.75, 0.82, 0.9, true)
    GameTooltip:Show()
end

function Bar:HandlePlacementButtonEdit(button)
    if not button then
        return
    end
    local blockReason = self:GetButtonEditBlockReason()
    if blockReason then
        if not isCursorCarryingActionPayload() then
            self:NotifyButtonEditBlocked(blockReason, "edit slots")
        end
        return
    end

    local slot = self:GetSlotForButtonState(button.slotIndex, button.state)
    if not slot then
        return
    end

    if isCursorCarryingActionPayload() then
        PlaceAction(slot)
        self:UpdateAll()
    else
        PickupAction(slot)
    end
end

function Bar:CreatePlacementFrame()
    if self.placementFrame then
        return
    end

    local frame = CreateFrame("Frame", "WoWXPlacementFrame", UIParent)
    frame:SetWidth(780)
    frame:SetHeight(214)
    frame:SetFrameStrata("MEDIUM")
    createBackdrop(frame, 0.18, 0.24, 0.3, 0.85)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
    title:SetText("Placement: drag, drop, or click to assign spells, items, and macros")
    title:SetTextColor(0.92, 0.96, 1.0)

    frame.rows = {}
    for rowIndex, rowInfo in ipairs(placementRows) do
        local rowLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rowLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -14 - (rowIndex * 36))
        rowLabel:SetText(rowInfo.label)
        rowLabel:SetTextColor(0.85, 0.9, 0.98)

        local rowButtons = {}
        for slotIndex = 1, BAR_BUTTON_COUNT do
            local btn = CreateFrame("Button", nil, frame)
            btn:SetWidth(28)
            btn:SetHeight(28)
            btn:SetPoint("TOPLEFT", frame, "TOPLEFT", 78 + ((slotIndex - 1) * 56), -10 - (rowIndex * 36))
            createBackdrop(btn, 0.2, 0.28, 0.38, 0.78)
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            btn:RegisterForDrag("LeftButton")

            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
            icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            local keyText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            keyText:SetPoint("TOP", btn, "BOTTOM", 0, -1)
            keyText:SetTextColor(1.0, 0.92, 0.58)

            btn.icon = icon
            btn.keyText = keyText
            btn.rowLabel = rowInfo.label
            btn.state = rowInfo.state
            btn.slotIndex = slotIndex

            btn:SetScript("OnEnter", function(self)
                GPX.VisualBar:UpdatePlacementButtonTooltip(self)
            end)
            btn:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            btn:SetScript("OnReceiveDrag", function(self)
                GPX.VisualBar:HandlePlacementButtonEdit(self)
            end)
            btn:SetScript("OnDragStart", function(self)
                GPX.VisualBar:HandlePlacementButtonEdit(self)
            end)
            btn:SetScript("OnClick", function(self, mouseButton)
                if mouseButton == "LeftButton" or mouseButton == "RightButton" then
                    GPX.VisualBar:HandlePlacementButtonEdit(self)
                end
            end)

            rowButtons[slotIndex] = btn
        end
        frame.rows[rowIndex] = rowButtons
    end

    self.placementFrame = frame
    self.placementFrame.title = title
end

function Bar:UpdatePlacementFrame()
    self:CreatePlacementFrame()

    if not self.frame or not self:IsPlacementModeEnabled() or not GPX.db or not GPX.db.enabled or InCombatLockdown() then
        self.placementFrame:Hide()
        return
    end

    local frame = self.placementFrame
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", self.frame, "BOTTOMLEFT", 0, -8)

    for rowIndex, rowInfo in ipairs(placementRows) do
        local rowButtons = frame.rows[rowIndex]
        for slotIndex = 1, BAR_BUTTON_COUNT do
            local btn = rowButtons[slotIndex]
            local display = self:GetDisplayForButton(slotIndex, rowInfo.state)
            local slot = display and display.slot or nil
            local icon = display and display.icon or nil
            local keyText = self:GetPhysicalKeyForButton(slotIndex)

            btn.keyText:SetText(keyText or "")
            if icon then
                btn.icon:SetTexture(icon)
                btn.icon:SetVertexColor(1.0, 1.0, 1.0)
            else
                btn.icon:SetTexture("Interface\\Buttons\\UI-Quickslot2")
                btn.icon:SetVertexColor(0.35, 0.4, 0.46)
            end

            if slot then
                btn:SetBackdropBorderColor(0.24, 0.76, 0.98, 0.9)
            else
                btn:SetBackdropBorderColor(0.2, 0.28, 0.38, 0.78)
            end
        end
    end

    frame:Show()
end

function Bar:AssignFromSpellbook(button)
    if not button.display or not button.display.slot or button.display.utilityId then
        GPX:Print("This WoWX button is not assignable on the current page.")
        return
    end

    local blockReason = self:GetButtonEditBlockReason()
    if blockReason then
        self:NotifyButtonEditBlocked(blockReason, "assign spells")
        return
    end

    if GPX.SpellbookUI then
        GPX.SpellbookUI:Open(button.display.slot, "bar")
    end
end

function Bar:CreateFrame()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "WoWXVisualBarFrame", UIParent)
    frame:SetWidth(780)
    frame:SetHeight(152)
    frame:SetFrameStrata("MEDIUM")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    createBackdrop(frame, 0.22, 0.66, 0.98, 0.9)
    frame:Hide()

    frame:SetScript("OnDragStart", function(self)
        if GPX.VisualBar and not GPX.VisualBar:IsLayoutEditLocked() then
            self:StartMoving()
        end
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if GPX.VisualBar then
            GPX.VisualBar:SavePosition()
        end
    end)
    frame:SetScript("OnUpdate", function(_, elapsed)
        if GPX.VisualBar then
            GPX.VisualBar:OnVisualUpdate(elapsed)
        end
    end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -10)
    title:SetTextColor(0.92, 0.96, 1.0)

    local pageText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pageText:SetPoint("LEFT", title, "RIGHT", 8, 0)
    pageText:SetTextColor(0.85, 0.88, 0.98)

    local bagBar = CreateFrame("Frame", nil, frame)
    bagBar:SetWidth(156)
    bagBar:SetHeight(24)
    bagBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 8)
    ensureFrameChrome(bagBar)
    bagBar:SetParent(UIParent)
    bagBar:SetMovable(true)
    bagBar:EnableMouse(true)
    bagBar:RegisterForDrag("LeftButton")
    bagBar:SetScript("OnDragStart", function(self)
        if GPX.VisualBar and not GPX.VisualBar:IsLayoutEditLocked() then
            self:StartMoving()
        end
    end)
    bagBar:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if GPX.VisualBar then
            GPX.VisualBar:SaveBagPosition()
        end
    end)
    frame.bagButtons = {}
    for bagID = 0, 4 do
        local bagButton = CreateFrame("Button", nil, bagBar)
        bagButton:SetWidth(22)
        bagButton:SetHeight(22)
        bagButton:SetPoint("RIGHT", bagBar, "RIGHT", -(bagID * 30), 0)
        createBackdrop(bagButton, 0.22, 0.3, 0.4, 0.9)
        bagButton:SetBackdropColor(0.05, 0.07, 0.12, 0.08)
        bagButton:SetBackdropBorderColor(0.32, 0.36, 0.42, 0.28)
        layoutSlotWrapper(bagButton, 2, 2, 2, 2)

        local bagIcon = bagButton:CreateTexture(nil, "ARTWORK")
        bagIcon:SetPoint("TOPLEFT", bagButton.slotPanel, "TOPLEFT", 2, -2)
        bagIcon:SetPoint("BOTTOMRIGHT", bagButton.slotPanel, "BOTTOMRIGHT", -2, 2)
        bagIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        bagButton.icon = bagIcon
        bagButton:SetScript("OnClick", function()
            GPX.VisualBar:ToggleBagSlot(bagID)
        end)

        frame.bagButtons[bagID] = bagButton
    end

    frame.buttons = {}
    for index = 1, BAR_BUTTON_COUNT do
        local buttonName = "WoWXActionButton" .. index
        local button = CreateFrame("CheckButton", buttonName, frame, "SecureActionButtonTemplate")
        button:SetWidth(56)
        button:SetHeight(90)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", 16 + ((index - 1) * 62), -44)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:RegisterForDrag("LeftButton")
        createBackdrop(button, 0.14, 0.18, 0.24, 0.85)
        button:SetBackdropColor(0.05, 0.07, 0.12, 0.1)
        button:SetBackdropBorderColor(0.2, 0.24, 0.3, 0.32)

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetWidth(52)
        icon:SetHeight(52)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        layoutIconPriorityWrapper(button, icon, 48, 6)

        local glyph = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        glyph:SetPoint("TOPLEFT", button, "TOPLEFT", 8, -8)
        glyph:SetJustifyH("LEFT")
        glyph:SetTextColor(0.96, 0.98, 1.0)

        local name = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        name:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", -4, -8)
        name:SetPoint("RIGHT", button, "RIGHT", -6, 0)
        name:SetJustifyH("LEFT")
        name:Hide()

        local keyText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        keyText:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 8, 8)
        keyText:SetTextColor(1.0, 0.92, 0.58)

        local countText = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        countText:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -8, 8)
        countText:SetJustifyH("RIGHT")
        countText:SetTextColor(0.9, 0.96, 1.0)

        local shine = button:CreateTexture(nil, "OVERLAY")
        shine:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        shine:SetBlendMode("ADD")
        shine:SetPoint("CENTER", button, "CENTER", 0, 2)
        shine:SetWidth(72)
        shine:SetHeight(72)
        shine:SetVertexColor(0.2, 1.0, 0.42, 0.85)
        shine:Hide()

        local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        cooldown:SetAllPoints(icon)

        button.icon = icon
        button.glyph = glyph
        button.name = name
        button.keyText = keyText
        button.countText = countText
        button.shine = shine
        button.cooldown = cooldown
        button:SetAttribute("type", nil)
        button:SetAttribute("action", nil)
        button:SetAttribute("type2", nil)
        button:SetAttribute("action2", nil)
        button:SetScript("OnEnter", function(self)
            GPX.VisualBar:UpdateButtonTooltip(self)
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        button:SetScript("OnReceiveDrag", function(self)
            GPX.VisualBar:PlaceCursorIntoButton(self)
        end)
        button:SetScript("OnDragStart", function(self)
            GPX.VisualBar:PickupFromButton(self)
        end)
        button:HookScript("OnClick", function(self, mouseButton)
            if mouseButton == "RightButton" then
                GPX.VisualBar:HandleRightClickEdit(self)
            end
        end)
        frame.buttons[index] = button
    end

    self:EnsureBindingProxyButtons()

    self.frame = frame
    self.frame.title = title
    self.frame.pageText = pageText
    self.frame.bagBar = bagBar
    self:ApplyStoredPosition()
    self:ApplyStoredBagPosition()
    self:EnableFrameDrag(frame, "main")
    self:AttachMoveHandle(frame, "main")
    self:AttachResizeHandle(frame, "main")
    self:AttachEditButton(frame, "main")
    self:EnableFrameDrag(bagBar, "bag")
    self:AttachMoveHandle(bagBar, "bag")
    self:AttachResizeHandle(bagBar, "bag")
    self:AttachEditButton(bagBar, "bag")

    if GPX.UIMode then
        GPX.UIMode:RegisterContext("bar", {
            label = "Action Bar",
            getItems = function()
                return Bar.frame and Bar.frame.buttons or {}
            end,
            columns = BAR_BUTTON_COUNT,
            isAvailable = function()
                return Bar.frame and Bar.frame:IsShown() and not InCombatLockdown()
            end,
            getIndicatorText = function(_, baseText)
                return "Confirm opens spell assignment for the focused WoWX button.   " .. baseText
            end,
            onCancel = function(navigator)
                if GPX.SettingsUI and GPX.SettingsUI.frame and GPX.SettingsUI.frame:IsShown() then
                    navigator:Enter("settings")
                else
                    navigator:Exit()
                end
            end,
        })
    end
end

function Bar:CreateProgressFrame()
    if self.progressFrame then
        return
    end

    local progressFrame = CreateFrame("Frame", "WoWXProgressFrame", UIParent)
    progressFrame:SetWidth(520)
    progressFrame:SetHeight(24)
    progressFrame:SetFrameStrata("MEDIUM")
    progressFrame:EnableMouse(true)
    progressFrame:SetMovable(true)
    progressFrame:RegisterForDrag("LeftButton")
    createBackdrop(progressFrame, 0.18, 0.24, 0.3, 0.8)

    progressFrame:SetScript("OnDragStart", function(self)
        if GPX.VisualBar and not GPX.VisualBar:IsLayoutEditLocked() and shouldStartFrameDrag(self) then
            self:StartMoving()
            self._wowxDragStarted = true
        end
    end)

    progressFrame:SetScript("OnDragStop", function(self)
        if not self._wowxDragStarted then
            return
        end
        self._wowxDragStarted = nil
        self:StopMovingOrSizing()
        if GPX.VisualBar then
            GPX.VisualBar:SaveProgressPosition()
        end
    end)

    local progressBar = CreateFrame("StatusBar", nil, progressFrame)
    progressBar:SetPoint("TOPLEFT", progressFrame, "TOPLEFT", 6, -6)
    progressBar:SetPoint("BOTTOMRIGHT", progressFrame, "BOTTOMRIGHT", -6, 6)
    progressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    progressBar:SetMinMaxValues(0, 1)
    progressBar:SetValue(0)

    local progressText = progressBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    progressText:SetPoint("CENTER", progressBar, "CENTER", 0, 0)

    self.progressFrame = progressFrame
    self.progressFrame.progressBar = progressBar
    self.progressFrame.progressText = progressText
    progressBar._wowxDisableFrameDrag = true
    progressText._wowxDisableFrameDrag = true
    self:ApplyStoredProgressPosition()
    self:AttachEditButton(progressFrame, "progress")
end

function Bar:GetResolvedCooldown(slot)
    local start, duration, enable = GetActionCooldown(slot)

    if GetSpellCooldown then
        local gcdStart, gcdDuration, gcdEnable = GetSpellCooldown(GLOBAL_COOLDOWN_SPELL_ID)
        if gcdEnable and gcdEnable ~= 0 and gcdDuration and gcdDuration > 0 and gcdDuration <= 1.7 then
            if (not duration or duration <= 0) or gcdDuration > duration then
                return gcdStart, gcdDuration, gcdEnable
            end
        end
    end

    return start, duration, enable
end

function Bar:GetActionChargeState(slot)
    if not slot then
        return nil
    end

    if GetActionCharges then
        local current, maxCharges, cooldownStart, cooldownDuration = GetActionCharges(slot)
        if maxCharges and maxCharges > 1 then
            return current or maxCharges, maxCharges, cooldownStart or 0, cooldownDuration or 0, 1
        end
    end

    local actionType, actionID = GetActionInfo(slot)
    if actionType == "spell" and GetSpellCharges then
        local current, maxCharges, cooldownStart, cooldownDuration = GetSpellCharges(actionID)
        if maxCharges and maxCharges > 1 then
            return current or maxCharges, maxCharges, cooldownStart or 0, cooldownDuration or 0, 1
        end
    end

    return nil
end

function Bar:UpdateButtonVisualState(button)
    if not button then
        return
    end

    local display = button.display
    local alpha = button._wowxBaseAlpha or layoutDefaults.main.alpha
    local borderR, borderG, borderB, borderA = 0.14, 0.18, 0.24, 0.85
    if self:IsEditChromeActive() then
        borderR, borderG, borderB, borderA = 0.96, 0.8, 0.22, 0.9
    else
        borderR, borderG, borderB, borderA = 0.22, 0.66, 0.98, 0.9
    end

    if display and display.slot then
        local chargeCount, maxCharges, chargeStart, chargeDuration, chargeEnable = self:GetActionChargeState(display.slot)
        local start, duration, enable = self:GetResolvedCooldown(display.slot)
        if maxCharges and maxCharges > 1 and chargeCount and chargeCount < maxCharges and chargeDuration and chargeDuration > 0 then
            start, duration, enable = chargeStart, chargeDuration, chargeEnable
        end
        CooldownFrame_SetTimer(button.cooldown, start or 0, duration or 0, enable or 0)

        local usable, oom = IsUsableAction(display.slot)
        local inRange = IsActionInRange(display.slot)
        local actionType = GetActionInfo and select(1, GetActionInfo(display.slot)) or nil
        local actionCount = GetActionCount and (GetActionCount(display.slot) or 0) or 0
        local stackCount = (actionType == "spell") and 0 or actionCount
        local equippedAction = IsEquippedAction and IsEquippedAction(display.slot)
        local red, green, blue = 1.0, 1.0, 1.0
        local finalAlpha = alpha

        if inRange == 0 then
            red, green, blue = 0.95, 0.22, 0.22
            finalAlpha = math.max(0.35, alpha * 0.7)
            borderR, borderG, borderB, borderA = 0.9, 0.22, 0.22, 0.95
        elseif not usable and oom then
            red, green, blue = 0.3, 0.5, 1.0
        elseif not usable then
            red, green, blue = 0.45, 0.45, 0.45
            finalAlpha = math.max(0.45, alpha * 0.82)
        end

        button.icon:SetVertexColor(red, green, blue)
        button:SetAlpha(finalAlpha)
        if button.countText then
            local countToShow = stackCount
            local shouldShowCount = stackCount and stackCount > 1
            if maxCharges and maxCharges > 1 then
                countToShow = chargeCount or maxCharges
                shouldShowCount = countToShow ~= nil
            end
            if shouldShowCount then
                button.countText:SetText(countToShow)
                button.countText:Show()
            else
                button.countText:SetText("")
                button.countText:Hide()
            end
        end
        if button.shine then
            if equippedAction then
                button.shine:Show()
            else
                button.shine:Hide()
            end
        end
        if button.slotPanel then
            button.slotPanel:Hide()
        end
        if button.slotBorder then
            button.slotBorder:Hide()
        end
        button:SetBackdropColor(0.0, 0.0, 0.0, 0.0)
        button:SetBackdropBorderColor(borderR, borderG, borderB, 0.0)
    else
        CooldownFrame_SetTimer(button.cooldown, 0, 0, 0)
        button.icon:SetVertexColor(0.35, 0.4, 0.46)
        button:SetAlpha(math.max(0.45, alpha * 0.9))
        if button.countText then
            button.countText:SetText("")
            button.countText:Hide()
        end
        if button.shine then
            button.shine:Hide()
        end
        if button.slotPanel then
            button.slotPanel:Show()
        end
        if button.slotBorder then
            button.slotBorder:Show()
        end
        button:SetBackdropColor(0.05, 0.07, 0.12, 0.08)
        button:SetBackdropBorderColor(borderR, borderG, borderB, 0.24)
    end
end

function Bar:OnVisualUpdate(elapsed)
    if not self.frame or not self.frame:IsShown() then
        return
    end

    self._rangeTicker = (self._rangeTicker or 0) + (elapsed or 0)
    if self._rangeTicker < RANGE_UPDATE_INTERVAL then
        return
    end
    self._rangeTicker = 0

    local metrics = self._mainLayoutMetrics or self:GetMainLayoutMetrics()
    local visibleCount = metrics.visibleCount
    for index = 1, visibleCount do
        local button = self.frame.buttons[index]
        if button and button:IsShown() then
            self:UpdateButtonVisualState(button)
        end
    end
end

function Bar:UpdateButton(index, state)
    local button = self.frame.buttons[index]
    local display = self:GetDisplayForButton(index, state)
    local physicalKey = self:GetPhysicalKeyForButton(index)
    local inCombat = InCombatLockdown()
    local metrics = self._mainLayoutMetrics or self:GetMainLayoutMetrics()
    local visibleCount = metrics.visibleCount
    local buttonWidth = metrics.buttonWidth
    local buttonHeight = metrics.buttonHeight
    local spacing = metrics.spacing
    local padding = metrics.padding
    local showSecondaryKeyText = GPX:IsControllerEnabled()
    local bottomReserve = showSecondaryKeyText and 24 or 2
    local iconSize = math.max(20, math.min(buttonWidth - 4, buttonHeight - bottomReserve - 4))
    local buttonTopOffset = self.frame and self.frame._wowxButtonTopOffset or 44
    local iconTopInset = math.max(2, math.floor((buttonHeight - bottomReserve - iconSize) * 0.5))
    local hasAction = display and display.slot
    local iconInset = hasAction and 2 or 4

    local keyLabel = (GPX:IsControllerEnabled() and display and display.title) or physicalKey or defaultKeyHints[index] or tostring(index)
    button.glyph:SetText(keyLabel)
    button.name:SetText("")
    if showSecondaryKeyText then
        button.keyText:SetText(keyLabel)
        button.keyText:Show()
    else
        button.keyText:SetText("")
        button.keyText:Hide()
    end
    button.display = display
    button.physicalKey = physicalKey
    button._wowxBaseAlpha = metrics.alpha

    if not inCombat then
        if index <= visibleCount then
            button:Show()
            button:SetWidth(buttonWidth)
            button:SetHeight(buttonHeight)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", self.frame, "TOPLEFT", padding + ((index - 1) * (buttonWidth + spacing)), -buttonTopOffset)
            if hasAction then
                ensureSlotWrapper(button)
                if button.slotPanel then
                    button.slotPanel:Hide()
                end
                if button.slotBorder then
                    button.slotBorder:Hide()
                end
                button.icon:SetWidth(iconSize)
                button.icon:SetHeight(iconSize)
                button.icon:ClearAllPoints()
                button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", iconInset, -iconTopInset)
            else
                layoutIconPriorityWrapper(button, button.icon, iconSize, bottomReserve)
                if button.slotPanel then
                    button.slotPanel:Show()
                end
                if button.slotBorder then
                    button.slotBorder:Show()
                end
            end
            button.glyph:ClearAllPoints()
            if hasAction then
                button.glyph:SetPoint("TOPLEFT", button.icon, "TOPLEFT", 3, -3)
            else
                button.glyph:SetPoint("TOPLEFT", button.slotPanel, "TOPLEFT", 4, -4)
            end
            button.name:ClearAllPoints()
            button.name:SetPoint("TOPLEFT", button.slotPanel, "BOTTOMLEFT", 0, -8)
            button.name:SetPoint("RIGHT", button, "RIGHT", -6, 0)
            button.keyText:ClearAllPoints()
            button.keyText:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 8, 8)
            if button.countText then
                button.countText:ClearAllPoints()
                if hasAction then
                    button.countText:SetPoint("BOTTOMRIGHT", button.icon, "BOTTOMRIGHT", 2, 2)
                else
                    button.countText:SetPoint("BOTTOMRIGHT", button.slotPanel, "BOTTOMRIGHT", -2, 2)
                end
            end
            if button.shine then
                local shineSize = math.max(iconSize + 20, 54)
                button.shine:SetWidth(shineSize)
                button.shine:SetHeight(shineSize)
                button.shine:ClearAllPoints()
                button.shine:SetPoint("CENTER", button.icon, "CENTER", 0, 0)
            end
        else
            button:Hide()
        end
    end

    if not inCombat then
        local baseCommand = self:GetCommandForButton(index, "")
        local shiftCommand = self:GetCommandForButton(index, "SHIFT")
        local altCommand = self:GetCommandForButton(index, "ALT")
        local ctrlCommand = self:GetCommandForButton(index, "CTRL")
        local comboCommand = self:GetCommandForButton(index, "SHIFT-ALT")
        local baseSlot = self:GetSlotForButtonState(index, "")
        local shiftSlot = self:GetSlotForButtonState(index, "SHIFT")
        local altSlot = self:GetSlotForButtonState(index, "ALT")
        local ctrlSlot = self:GetSlotForButtonState(index, "CTRL")
        local comboSlot = self:GetSlotForButtonState(index, "SHIFT-ALT")

        setProxyOrActionAttribute(button, nil, baseCommand, baseSlot)
        setProxyOrActionAttribute(button, "shift", shiftCommand, shiftSlot)
        setProxyOrActionAttribute(button, "alt", altCommand, altSlot)
        setProxyOrActionAttribute(button, "ctrl", ctrlCommand, ctrlSlot)
        setProxyOrActionAttribute(button, "shift-alt", comboCommand, comboSlot)
        setProxyOrActionAttribute(button, "alt-shift", comboCommand, comboSlot)

        button:SetAttribute("type2", nil)
        button:SetAttribute("action2", nil)
        button:SetAttribute("shift-type2", nil)
        button:SetAttribute("shift-action2", nil)
        button:SetAttribute("alt-type2", nil)
        button:SetAttribute("alt-action2", nil)
        button:SetAttribute("ctrl-type2", nil)
        button:SetAttribute("ctrl-action2", nil)
        button:SetAttribute("shift-alt-type2", nil)
        button:SetAttribute("shift-alt-action2", nil)
        button:SetAttribute("alt-shift-type2", nil)
        button:SetAttribute("alt-shift-action2", nil)
        button:SetAttribute("macrotext2", nil)
        button:SetAttribute("shift-macrotext2", nil)
        button:SetAttribute("alt-macrotext2", nil)
        button:SetAttribute("ctrl-macrotext2", nil)
        button:SetAttribute("shift-alt-macrotext2", nil)
        button:SetAttribute("alt-shift-macrotext2", nil)
    else
        self.pendingAttributeRefresh = true
    end

    if display.icon then
        button.icon:SetTexture(display.icon)
        button.icon:SetVertexColor(1.0, 1.0, 1.0)
        if button.slotBorder then
            button.slotBorder:SetVertexColor(0.92, 0.93, 0.9, 0.92)
        end
    else
        button.icon:SetTexture(nil)
        button.icon:SetVertexColor(0.35, 0.4, 0.46)
        if button.slotBorder then
            button.slotBorder:SetVertexColor(0.62, 0.7, 0.82, 0.82)
        end
    end

    self:UpdateButtonVisualState(button)
end

function Bar:UpdateAll()
    self:CreateFrame()
    self:CreateProgressFrame()
    local inCombat = InCombatLockdown()
    self:UpdateBlizzardBars()
    self:UpdateBindingProxyButtons()

    if not GPX.db or not GPX.db.enabled or not GPX.db.ui or not GPX.db.ui.visualBar or not GPX.db.ui.visualBar.enabled then
        if not inCombat then
            self.frame:Hide()
            if self.frame and self.frame._wowxShell then
                self.frame._wowxShell:Hide()
            end
            if self.placementFrame then
                self.placementFrame:Hide()
            end
            if self.progressFrame then
                self.progressFrame:Hide()
            end
        end
        if GPX.UIMode and GPX.UIMode.activeContext == "bar" then
            GPX.UIMode:Exit()
        end
        return
    end

    local metrics = self:GetMainLayoutMetrics()
    self._mainLayoutMetrics = metrics
    local visibleCount = metrics.visibleCount
    local buttonWidth = metrics.buttonWidth
    local buttonHeight = metrics.buttonHeight
    local spacing = metrics.spacing
    local padding = metrics.padding
    local chromeAlpha = metrics.chromeAlpha
    local width = (padding * 2) + (visibleCount * buttonWidth) + ((visibleCount - 1) * spacing)
    if width < 460 then
        width = 460
    end

    if not inCombat then
        self.frame:SetWidth(width)
        self.frame:SetScale(self:GetBarScale())
    end
    self.frame:SetAlpha(metrics.alpha)
    self.frame:SetBackdropColor(0.05, 0.07, 0.12, 0.0)
    self.frame:SetBackdropBorderColor(0.22, 0.66, 0.98, 0.0)

    local state = self:GetCurrentState()
    local page = modifierStates[state] or modifierStates[""]
    local pageLabel = page.title
    local showHeader = (not self:IsLayoutEditLocked()) or (GPX.UIMode and GPX.UIMode.activeContext == "bar")
    local buttonTopOffset = showHeader and 34 or 12
    local bottomInset = 10
    if not self:UseModifierPages() and state ~= "" then
        pageLabel = "Base (modifier held)"
    end
    self.frame._wowxButtonTopOffset = buttonTopOffset
    if not inCombat then
        self.frame:SetHeight(buttonHeight + buttonTopOffset + bottomInset)
    end
    self.frame.title:SetText("Action Bar")
    self.frame.pageText:SetText(pageLabel)
    if GPX.actionStateSuspended and GPX.actionStateReason then
        self.frame.title:SetText("Action Bar ΓÇö Native " .. GPX.actionStateReason)
        self.frame:SetBackdropBorderColor(0.95, 0.36, 0.18, 0.98)
        self.frame:SetBackdropColor(0.1, 0.05, 0.04, math.max(chromeAlpha, 0.18))
        showHeader = true
    end
    if GPX.UIMode and GPX.UIMode.activeContext == "bar" then
        self.frame.title:SetText("Action Bar ΓÇö UI Mode")
        self.frame:SetBackdropBorderColor(0.96, 0.8, 0.22, 0.98)
    else
        if not (GPX.actionStateSuspended and GPX.actionStateReason) then
            self.frame:SetBackdropBorderColor(0.22, 0.66, 0.98, 0.9)
        end
    end
    self.frame.title:SetShown(showHeader)
    self.frame.pageText:SetShown(showHeader)
    self.frame.pageText:SetTextColor(self:IsLayoutEditLocked() and 0.85 or 1.0, self:IsLayoutEditLocked() and 0.88 or 0.9, self:IsLayoutEditLocked() and 0.98 or 0.35)
    if self.progressFrame then
        self:ApplyChromeBackdrop(self.progressFrame, 0.12)
    end
    self:UpdateModifierIndicator(state)
    self:UpdateProgressBar()
    self:UpdateBagBar()
    self:UpdateMicroMenu()
    self:UpdateDetachedClassBars()
    self:UpdateVehicleLeaveButton()
    self:UpdateResizeHandles()

    for index = 1, BAR_BUTTON_COUNT do
        self:UpdateButton(index, state)
    end

    updateShellAroundButtons(self.frame, self.frame.buttons, 4, 4)
    if self.frame._wowxShell then
        self.frame:SetBackdropBorderColor(0.22, 0.66, 0.98, 0.0)
        if GPX.actionStateSuspended and GPX.actionStateReason then
            self.frame._wowxShell:SetBackdropBorderColor(0.95, 0.36, 0.18, 0.98)
            self.frame._wowxShell:SetBackdropColor(0.1, 0.05, 0.04, math.max(chromeAlpha, 0.18))
        elseif GPX.UIMode and GPX.UIMode.activeContext == "bar" then
            self.frame._wowxShell:SetBackdropBorderColor(0.96, 0.8, 0.22, 0.98)
            self.frame._wowxShell:SetBackdropColor(0.12, 0.09, 0.03, math.max(chromeAlpha, 0.16))
        elseif self:IsLayoutEditLocked() then
            self.frame._wowxShell:SetBackdropBorderColor(0.22, 0.66, 0.98, 0.9)
            self.frame._wowxShell:SetBackdropColor(0.05, 0.07, 0.12, chromeAlpha)
        else
            self.frame._wowxShell:SetBackdropBorderColor(0.96, 0.8, 0.22, 0.96)
            self.frame._wowxShell:SetBackdropColor(0.12, 0.09, 0.03, math.max(chromeAlpha, 0.16))
        end
    end

    if not inCombat then
        self.frame:Show()
    end
    self:UpdatePlacementFrame()

    if not inCombat then
        self.pendingAttributeRefresh = false
    else
        self.pendingAttributeRefresh = true
    end
end

function Bar:Slash(msg)
    local cmd = (msg or ""):match("^(%S+)")
    cmd = cmd and string.lower(cmd) or "toggle"

    local config = ensureVisualBarConfig()

    if cmd == "hide" or cmd == "off" then
        config.enabled = false
        self:UpdateAll()
        GPX:Print("Visual bar hidden.")
    elseif cmd == "show" or cmd == "on" then
        config.enabled = true
        self:UpdateAll()
        GPX:Print("Visual bar shown.")
    elseif cmd == "lock" then
        config.locked = true
        config.progressLocked = true
        self:UpdateAll()
        GPX:Print("Visual bar locked.")
    elseif cmd == "unlock" then
        if InCombatLockdown() then
            GPX:Print("Cannot unlock layout edit in combat.")
            return
        end
        config.locked = false
        config.progressLocked = false
        self:UpdateAll()
        GPX:Print("Layout unlocked. Drag bars from any chrome around their buttons. Use resize commands for scale.")
    elseif cmd == "buttonlock" or cmd == "slotlock" then
        config.buttonLocked = true
        self:UpdateAll()
        GPX:Print("Bar buttons locked.")
    elseif cmd == "buttonunlock" or cmd == "slotunlock" then
        if InCombatLockdown() then
            GPX:Print("Cannot unlock bar buttons in combat.")
            return
        end
        config.buttonLocked = false
        self:UpdateAll()
        GPX:Print("Bar buttons unlocked. Lock layout edit to swap or assign spells.")
    elseif cmd == "buttons" or cmd == "buttonedit" or cmd == "slotedit" then
        if config.buttonLocked == false then
            self:Slash("buttonlock")
        else
            self:Slash("buttonunlock")
        end
    elseif cmd == "reset" then
        if InCombatLockdown() then
            GPX:Print("Cannot reset layout position in combat.")
            return
        end
        config.point = GPX:DeepCopy(GPX.defaults.ui.visualBar.point)
        config.scale = GPX.defaults.ui.visualBar.scale or 1.0
        self:ApplyStoredPosition()
        self:UpdateAll()
        GPX:Print("Visual bar position reset.")
    elseif cmd == "stancereset" or cmd == "aurareset" then
        if InCombatLockdown() then
            GPX:Print("Cannot reset aura / stance bar position in combat.")
            return
        end
        self:ResetAuxPosition("stance")
    elseif cmd == "petreset" then
        if InCombatLockdown() then
            GPX:Print("Cannot reset pet bar position in combat.")
            return
        end
        self:ResetAuxPosition("pet")
    elseif cmd == "bigger" then
        self:AdjustScale(0.05)
    elseif cmd == "smaller" then
        self:AdjustScale(-0.05)
    elseif cmd == "keepbags" then
        self:ToggleKeepBags()
    elseif cmd == "keepmenu" then
        self:ToggleKeepMicroMenu()
    elseif cmd == "keepstance" then
        self:ToggleKeepStanceBar()
    elseif cmd == "keeppet" then
        self:ToggleKeepPetBar()
    elseif cmd == "bagbar" then
        self:ToggleBagBar()
    elseif cmd == "progresslock" or cmd == "xplock" then
        self:ToggleProgressLock()
    elseif cmd == "xpbar" or cmd == "repbar" or cmd == "progress" then
        self:ToggleProgressBar()
    elseif cmd == "place" or cmd == "placement" then
        self:TogglePlacementMode()
    elseif cmd == "modpages" or cmd == "modpage" then
        local config = ensureVisualBarConfig()
        config.modifierPages = not (config.modifierPages == true)
        self:UpdateAll()
        GPX:Print("Modifier pages: " .. (config.modifierPages and "On" or "Off (same-slot modifiers)"))
    elseif cmd == "microbigger" then
        self:AdjustAuxScale("micro", 0.05)
    elseif cmd == "microsmaller" then
        self:AdjustAuxScale("micro", -0.05)
    elseif cmd == "stancebigger" then
        self:AdjustAuxScale("stance", 0.05)
    elseif cmd == "stancesmaller" then
        self:AdjustAuxScale("stance", -0.05)
    elseif cmd == "petbigger" then
        self:AdjustAuxScale("pet", 0.05)
    elseif cmd == "petsmaller" then
        self:AdjustAuxScale("pet", -0.05)
    else
        config.enabled = not config.enabled
        self:UpdateAll()
        GPX:Print(config.enabled and "Visual bar shown." or "Visual bar hidden.")
    end
end

local eventFrame = CreateFrame("Frame", "WoWXVisualBarEvents")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
eventFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
eventFrame:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
eventFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
eventFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_USABLE")
eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_COOLDOWN")
eventFrame:RegisterEvent("UPDATE_STEALTH")
eventFrame:RegisterEvent("PLAYER_AURAS_CHANGED")
eventFrame:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
eventFrame:RegisterEvent("UPDATE_POSSESS_BAR")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("UPDATE_BINDINGS")
eventFrame:RegisterEvent("PLAYER_XP_UPDATE")
eventFrame:RegisterEvent("UPDATE_FACTION")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(_, event)
    if GPX.VisualBar then
        if event == "PLAYER_REGEN_DISABLED" and GPX.UIMode and GPX.UIMode.activeContext == "bar" then
            GPX.UIMode:Exit()
        end
        if event == "PLAYER_REGEN_ENABLED" and GPX.VisualBar.pendingAttributeRefresh then
            GPX.VisualBar:UpdateAll()
            return
        end
        GPX.VisualBar:UpdateAll()
    end
end)
