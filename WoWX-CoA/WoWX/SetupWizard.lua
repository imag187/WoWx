if not GamePadX then return end

local GPX = GamePadX
local Wizard = {}

GPX.SetupWizard = Wizard

local deviceOrder = { "keyboard", "xbox", "playstation", "switch", "generic" }
local captureKeys = {
    "ESCAPE", "ENTER", "SPACE", "TAB", "BACKSPACE",
    "UP", "DOWN", "LEFT", "RIGHT",
    "LSHIFT", "RSHIFT", "SHIFT",
    "LALT", "RALT", "ALT",
    "LCTRL", "RCTRL", "CTRL",
    "NUMLOCK", "NUMPADPLUS", "NUMPADMINUS", "NUMPADMULTIPLY", "NUMPADDIVIDE", "NUMPADDECIMAL",
    "INSERT", "DELETE", "HOME", "END", "PAGEUP", "PAGEDOWN",
    "MOUSEWHEELUP", "MOUSEWHEELDOWN", "BUTTON3", "BUTTON4", "BUTTON5",
}

for i = 0, 9 do
    captureKeys[#captureKeys + 1] = tostring(i)
    captureKeys[#captureKeys + 1] = "NUMPAD" .. tostring(i)
end

for i = 1, 24 do
    captureKeys[#captureKeys + 1] = "F" .. tostring(i)
end

for byte = string.byte("A"), string.byte("Z") do
    captureKeys[#captureKeys + 1] = string.char(byte)
end

local function normalizeKey(key)
    if not key then
        return nil
    end

    local normalized = string.upper(key)
    local aliases = {
        LSHIFT = "SHIFT",
        RSHIFT = "SHIFT",
        LALT = "ALT",
        RALT = "ALT",
        LCTRL = "CTRL",
        RCTRL = "CTRL",
    }

    return aliases[normalized] or normalized
end

local function createBackdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.04, 0.05, 0.08, 0.96)
    frame:SetBackdropBorderColor(0.2, 0.66, 0.98, 0.85)
end

function Wizard:CreateFrame()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "WoWXSetupWizardFrame", UIParent)
    frame:SetWidth(860)
    frame:SetHeight(560)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableKeyboard(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    createBackdrop(frame)
    frame:Hide()

    frame:SetScript("OnHide", function(self)
        self:EnableKeyboard(false)
        Wizard:UnbindCaptureKeys()
        if Wizard.captureInput then
            Wizard.captureInput:ClearFocus()
        end
    end)

    frame:SetScript("OnShow", function(self)
        self:EnableKeyboard(true)
        if Wizard.awaitingInput then
            Wizard:BindCaptureKeys()
        end
        if Wizard.awaitingInput and Wizard.captureInput then
            Wizard.captureInput:SetFocus()
        end
    end)

    frame:SetScript("OnKeyDown", function(_, key)
        Wizard:OnKeyDown(key)
    end)

    frame:SetScript("OnUpdate", function()
        Wizard:TryCaptureModifierState()
    end)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -20)
    title:SetTextColor(0.95, 0.96, 1.0)
    title:SetText(GPX.brand .. " Setup")

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetWidth(760)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetTextColor(0.7, 0.78, 0.88)

    local leftPanel = CreateFrame("Frame", nil, frame)
    leftPanel:SetWidth(250)
    leftPanel:SetHeight(470)
    leftPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -72)
    createBackdrop(leftPanel)
    leftPanel:SetBackdropColor(0.06, 0.08, 0.12, 0.9)

    local leftTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    leftTitle:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 16, -16)
    leftTitle:SetText("Device Layout")

    local intro = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", leftTitle, "BOTTOMLEFT", 0, -8)
    intro:SetWidth(210)
    intro:SetJustifyH("LEFT")
    intro:SetText("Pick the family of device you want WoWX to present to the player. The actual inputs can still be keyboard keys from AntiMicroX, Steam Input, or your accessibility tools.")

    frame.deviceButtons = {}
    local prevButton = intro
    for _, deviceId in ipairs(deviceOrder) do
        local style = GPX:GetInputStyle(deviceId)
        local button = CreateFrame("Button", nil, leftPanel, "UIPanelButtonTemplate")
        button:SetWidth(210)
        button:SetHeight(28)
        button:SetPoint("TOPLEFT", prevButton, prevButton == intro and "BOTTOMLEFT" or "BOTTOMLEFT", 0, prevButton == intro and -16 or -8)
        button:SetText(style.name)
        button:SetScript("OnClick", function()
            Wizard:SelectDevice(deviceId)
        end)
        frame.deviceButtons[deviceId] = button
        prevButton = button
    end

    local rightPanel = CreateFrame("Frame", nil, frame)
    rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 18, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 22)
    createBackdrop(rightPanel)
    rightPanel:SetBackdropColor(0.05, 0.06, 0.1, 0.92)

    local progress = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    progress:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 18, -16)
    progress:SetText("Step 0 / 0")

    local stepTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    stepTitle:SetPoint("TOPLEFT", progress, "BOTTOMLEFT", 0, -8)
    stepTitle:SetTextColor(0.94, 0.96, 1.0)

    local stepText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    stepText:SetPoint("TOPLEFT", stepTitle, "BOTTOMLEFT", 0, -10)
    stepText:SetWidth(520)
    stepText:SetJustifyH("LEFT")

    local captureBox = CreateFrame("Frame", nil, rightPanel)
    captureBox:SetWidth(520)
    captureBox:SetHeight(88)
    captureBox:SetPoint("TOPLEFT", stepText, "BOTTOMLEFT", 0, -16)
    createBackdrop(captureBox)
    captureBox:SetBackdropColor(0.09, 0.11, 0.16, 0.95)
    captureBox:SetBackdropBorderColor(0.9, 0.72, 0.2, 0.8)

    local captureLabel = captureBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    captureLabel:SetPoint("CENTER", captureBox, "CENTER", 0, 12)
    captureLabel:SetTextColor(1.0, 0.92, 0.55)

    local captureHint = captureBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    captureHint:SetPoint("TOP", captureLabel, "BOTTOM", 0, -8)
    captureHint:SetWidth(470)
    captureHint:SetJustifyH("CENTER")

    local captureInput = CreateFrame("EditBox", nil, frame)
    captureInput:SetWidth(8)
    captureInput:SetHeight(8)
    captureInput:SetPoint("TOPLEFT", captureBox, "TOPLEFT", 2, -2)
    captureInput:SetAutoFocus(false)
    captureInput:EnableKeyboard(true)
    captureInput:SetText("")
    captureInput:SetMaxLetters(1)
    captureInput:SetScript("OnEditFocusLost", function(self)
        if Wizard.awaitingInput and Wizard.frame and Wizard.frame:IsShown() then
            self:SetFocus()
        end
    end)
    captureInput:SetScript("OnEscapePressed", function(self)
        Wizard:OnKeyDown("ESCAPE")
    end)
    captureInput:SetScript("OnEnterPressed", function(self)
        Wizard:OnKeyDown("ENTER")
    end)
    captureInput:SetScript("OnKeyDown", function(_, key)
        Wizard:OnKeyDown(key)
    end)
    captureInput:SetScript("OnChar", function(_, text)
        if text == " " then
            Wizard:OnKeyDown("SPACE")
        else
            Wizard:OnKeyDown(text)
        end
    end)

    captureBox:EnableMouse(true)
    captureBox:SetScript("OnMouseDown", function()
        Wizard:FocusCapture()
    end)

    local summaryTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    summaryTitle:SetPoint("TOPLEFT", captureBox, "BOTTOMLEFT", 0, -18)
    summaryTitle:SetText("Current Layout")

    local modifierRow = CreateFrame("Frame", nil, rightPanel)
    modifierRow:SetWidth(520)
    modifierRow:SetHeight(56)
    modifierRow:SetPoint("TOPLEFT", summaryTitle, "BOTTOMLEFT", 0, -10)
    frame.modifierCards = {}
    for index = 1, 3 do
        local card = CreateFrame("Frame", nil, modifierRow)
        card:SetWidth(160)
        card:SetHeight(52)
        card:SetPoint("LEFT", modifierRow, "LEFT", (index - 1) * 174, 0)
        createBackdrop(card)
        card:SetBackdropColor(0.07, 0.09, 0.14, 0.96)

        local label = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -10)
        label:SetJustifyH("LEFT")

        local value = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        value:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 10, 10)
        value:SetTextColor(1.0, 0.93, 0.6)

        card.label = label
        card.value = value
        frame.modifierCards[index] = card
    end

    local buttonGrid = CreateFrame("Frame", nil, rightPanel)
    buttonGrid:SetWidth(520)
    buttonGrid:SetHeight(270)
    buttonGrid:SetPoint("TOPLEFT", modifierRow, "BOTTOMLEFT", 0, -18)
    frame.actionCards = {}
    for index = 1, 12 do
        local card = CreateFrame("Frame", nil, buttonGrid)
        card:SetWidth(120)
        card:SetHeight(80)
        local column = (index - 1) % 4
        local row = math.floor((index - 1) / 4)
        card:SetPoint("TOPLEFT", buttonGrid, "TOPLEFT", column * 132, -row * 92)
        createBackdrop(card)
        card:SetBackdropColor(0.08, 0.09, 0.15, 0.95)

        local label = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -10)
        label:SetJustifyH("LEFT")

        local value = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        value:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 10, 12)
        value:SetTextColor(0.95, 0.97, 1.0)

        card.label = label
        card.value = value
        frame.actionCards[index] = card
    end

    local movementTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    movementTitle:SetPoint("TOPLEFT", buttonGrid, "BOTTOMLEFT", 0, -12)
    movementTitle:SetText("Core Inputs")

    local movementText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    movementText:SetPoint("TOPLEFT", movementTitle, "BOTTOMLEFT", 0, -8)
    movementText:SetWidth(520)
    movementText:SetJustifyH("LEFT")

    local startButton = CreateFrame("Button", nil, rightPanel, "UIPanelButtonTemplate")
    startButton:SetWidth(130)
    startButton:SetHeight(28)
    startButton:SetPoint("BOTTOMLEFT", rightPanel, "BOTTOMLEFT", 18, 18)
    startButton:SetText("Start")
    startButton:SetScript("OnClick", function()
        Wizard:StartCalibration()
    end)

    local restartButton = CreateFrame("Button", nil, rightPanel, "UIPanelButtonTemplate")
    restartButton:SetWidth(130)
    restartButton:SetHeight(28)
    restartButton:SetPoint("LEFT", startButton, "RIGHT", 10, 0)
    restartButton:SetText("Start Over")
    restartButton:SetScript("OnClick", function()
        Wizard:RestartCalibration()
    end)

    local skipButton = CreateFrame("Button", nil, rightPanel, "UIPanelButtonTemplate")
    skipButton:SetWidth(130)
    skipButton:SetHeight(28)
    skipButton:SetPoint("LEFT", restartButton, "RIGHT", 10, 0)
    skipButton:SetText("Skip Step")
    skipButton:SetScript("OnClick", function()
        Wizard:SkipStep()
    end)

    local applyButton = CreateFrame("Button", nil, rightPanel, "UIPanelButtonTemplate")
    applyButton:SetWidth(150)
    applyButton:SetHeight(28)
    applyButton:SetPoint("RIGHT", rightPanel, "RIGHT", -18, 18)
    applyButton:SetText("Apply Setup")
    applyButton:SetScript("OnClick", function()
        Wizard:Apply()
    end)

    frame.subtitle = subtitle
    frame.progress = progress
    frame.stepTitle = stepTitle
    frame.stepText = stepText
    frame.captureLabel = captureLabel
    frame.captureHint = captureHint
    frame.captureInput = captureInput
    frame.startButton = startButton
    frame.restartButton = restartButton
    frame.skipButton = skipButton
    frame.applyButton = applyButton
    frame.movementText = movementText
    self.frame = frame
    self.captureInput = captureInput

    self.captureButtons = {}
end

function Wizard:TryCaptureModifierState()
    if not self.awaitingInput then
        self.modifierHeld = false
        return
    end

    local step = self:GetCurrentStep()
    if not step or step.kind ~= "modifier" then
        self.modifierHeld = false
        return
    end

    local shift = IsShiftKeyDown()
    local alt = IsAltKeyDown()
    local ctrl = IsControlKeyDown()
    local any = shift or alt or ctrl

    if not any then
        self.modifierHeld = false
        return
    end

    if self.modifierHeld then
        return
    end

    local count = (shift and 1 or 0) + (alt and 1 or 0) + (ctrl and 1 or 0)
    if count ~= 1 then
        return
    end

    self.modifierHeld = true
    if shift then
        self:OnKeyDown("SHIFT")
    elseif alt then
        self:OnKeyDown("ALT")
    elseif ctrl then
        self:OnKeyDown("CTRL")
    end
end

function Wizard:CreateCaptureButton(key)
    local clean = key:gsub("[^%w]", "")
    local buttonName = "WoWXSetupCapture" .. clean
    if _G[buttonName] then
        return _G[buttonName]
    end

    local button = CreateFrame("Button", buttonName, UIParent)
    button:Hide()
    button:SetScript("OnClick", function()
        Wizard:OnKeyDown(key)
    end)
    return button
end

function Wizard:BindCaptureKeys()
    if not self.frame then
        return
    end

    ClearOverrideBindings(self.frame)
    for _, key in ipairs(captureKeys) do
        local button = self:CreateCaptureButton(key)
        self.captureButtons[key] = button
        SetOverrideBindingClick(self.frame, true, key, button:GetName())
    end
end

function Wizard:UnbindCaptureKeys()
    if self.frame then
        ClearOverrideBindings(self.frame)
    end
end

function Wizard:FocusCapture()
    if self.captureInput then
        self.captureInput:Show()
        self.captureInput:SetFocus()
    end
end

function Wizard:BuildSteps()
    local style = GPX:GetInputStyle(self.state.deviceId)
    local controllerEnabled = GPX:IsControllerEnabled()
    self.steps = {
        {
            kind = "modifier",
            index = 1,
            title = style.modifierLabels[1],
            text = "Press your first modifier button. WoWX will use it for the first modifier page.",
        },
        {
            kind = "modifier",
            index = 2,
            title = style.modifierLabels[2],
            text = "Press your second modifier button. This becomes the second modifier page.",
        },
        {
            kind = "modifier",
            index = 3,
            title = style.modifierLabels[3],
            text = "Press your third modifier button. This becomes the third modifier page.",
        },
        {
            kind = "jump",
            title = style.slotLabels[1],
            text = "Press the main jump button. Bare press stays Jump, and with a modifier it becomes the first action slot on that modifier page.",
        },
    }

    if controllerEnabled then
        self.steps[#self.steps + 1] = {
            kind = "menu",
            title = "Menu / Escape",
            text = "Press your center/menu button (for example Xbox logo). WoWX binds it to the game menu so it behaves like Escape on controller.",
        }
    end

    for index = 2, 12 do
        self.steps[#self.steps + 1] = {
            kind = "action",
            index = index - 1,
            slotIndex = index,
            title = style.slotLabels[index],
            text = "Press the button for " .. (style.slotLabels[index] or ("Action " .. index)) .. ". Bare press becomes a normal action slot, and each modifier gives it a matching page slot.",
        }
    end
end

function Wizard:SelectDevice(deviceId)
    self.state.deviceId = deviceId
    self:RefreshDeviceButtons()
    self:BuildSteps()
    self:Refresh()
end

function Wizard:RefreshDeviceButtons()
    if not self.frame then
        return
    end

    for deviceId, button in pairs(self.frame.deviceButtons) do
        if deviceId == self.state.deviceId then
            button:LockHighlight()
        else
            button:UnlockHighlight()
        end
    end
end

function Wizard:GetCurrentStep()
    if not self.steps or self.stepIndex < 1 then
        return nil
    end
    return self.steps[self.stepIndex]
end

function Wizard:IsDuplicate(key, currentStep)
    if not key or key == "" then
        return false
    end

    local seen = {}
    local movement = self.state.movement or {}
    local modifiers = self.state.modifiers or {}
    local actionKeys = self.state.actionKeys or {}

    for movementKey, value in pairs(movement) do
        if not (currentStep.kind == "movement" and currentStep.key == movementKey) then
            seen[value] = true
        end
    end

    for index, value in ipairs(modifiers) do
        if not (currentStep.kind == "modifier" and currentStep.index == index) then
            seen[value] = true
        end
    end

    if self.state.jumpKey and currentStep.kind ~= "jump" then
        seen[self.state.jumpKey] = true
    end

    if self.state.menuKey and currentStep.kind ~= "menu" then
        seen[self.state.menuKey] = true
    end

    for index, value in ipairs(actionKeys) do
        if not (currentStep.kind == "action" and currentStep.index == index) then
            seen[value] = true
        end
    end

    return seen[key] and true or false
end

function Wizard:StoreKey(step, key)
    if step.kind == "movement" then
        self.state.movement[step.key] = key
    elseif step.kind == "modifier" then
        self.state.modifiers[step.index] = key
    elseif step.kind == "jump" then
        self.state.jumpKey = key
    elseif step.kind == "menu" then
        self.state.menuKey = key
    elseif step.kind == "action" then
        self.state.actionKeys[step.index] = key
    end
end

function Wizard:OnKeyDown(key)
    if not self.frame or not self.frame:IsShown() or not self.awaitingInput then
        return
    end

    local step = self:GetCurrentStep()
    if not step then
        return
    end

    local normalized = normalizeKey(key)
    if not normalized then
        return
    end

    self.frame.captureLabel:SetText("Captured: " .. normalized)

    if normalized == "ESCAPE" then
        self.awaitingInput = false
        self:UnbindCaptureKeys()
        if self.captureInput then
            self.captureInput:ClearFocus()
        end
        self.frame.captureLabel:SetText("Capture paused")
        self.frame.captureHint:SetText("Press Start Over to restart or Apply Setup if you are done.")
        return
    end

    if self:IsDuplicate(normalized, step) then
        self.frame.captureLabel:SetText("Already used")
        self.frame.captureHint:SetText(normalized .. " is already assigned. Choose a different key.")
        return
    end

    if step.kind == "modifier" and normalized ~= "SHIFT" and normalized ~= "ALT" and normalized ~= "CTRL" then
        self.frame.captureLabel:SetText("Need SHIFT, ALT, or CTRL")
        self.frame.captureHint:SetText("Modifier capture only accepts real WoW modifier keys. Map your controller shoulder or stick buttons to SHIFT, ALT, or CTRL in AntiMicroX or your input tool.")
        return
    end

    if step.kind ~= "modifier" and (normalized == "SHIFT" or normalized == "ALT" or normalized == "CTRL") then
        self.frame.captureLabel:SetText("Modifier only")
        self.frame.captureHint:SetText("Use plain keys for jump, menu, and action slots. SHIFT, ALT, and CTRL are reserved for modifier capture.")
        return
    end

    self:StoreKey(step, normalized)
    self.stepIndex = self.stepIndex + 1
    if self.stepIndex > #self.steps then
        self.awaitingInput = false
        self:UnbindCaptureKeys()
        if self.captureInput then
            self.captureInput:ClearFocus()
        end
    end
    self:Refresh()
    self:FocusCapture()
end

function Wizard:SkipStep()
    if not self.awaitingInput then
        return
    end

    local step = self:GetCurrentStep()
    if not step then
        return
    end

    self.frame.captureLabel:SetText("Step required")
    self.frame.captureHint:SetText("All current setup steps are required for reliable combat controls.")
end

function Wizard:FormatMovementSummary()
    local style = GPX:GetInputStyle(self.state.deviceId)
    local modifiers = self.state.modifiers or {}
    local labels = {
        "Jump: " .. (self.state.jumpKey or "--"),
        "Menu: " .. (self.state.menuKey or "--"),
        (style.modifierLabels[1] or "Modifier 1") .. ": " .. (modifiers[1] or "--"),
        (style.modifierLabels[2] or "Modifier 2") .. ": " .. (modifiers[2] or "--"),
        (style.modifierLabels[3] or "Modifier 3") .. ": " .. (modifiers[3] or "--"),
    }
    return table.concat(labels, "    ")
end

function Wizard:RefreshSummary()
    if not self.frame then
        return
    end

    local style = GPX:GetInputStyle(self.state.deviceId)
    for index, card in ipairs(self.frame.modifierCards) do
        card.label:SetText(style.modifierLabels[index])
        card.value:SetText(self.state.modifiers[index] or "Press to assign")
    end

    self.frame.actionCards[1].label:SetText(style.slotLabels[1])
    self.frame.actionCards[1].value:SetText(self.state.jumpKey or "Press to assign")
    for slotIndex = 2, 12 do
        local card = self.frame.actionCards[slotIndex]
        if not card then
            break
        end
        card.label:SetText(style.slotLabels[slotIndex])
        card.value:SetText(self.state.actionKeys[slotIndex - 1] or "Press to assign")
    end

    self.frame.movementText:SetText(self:FormatMovementSummary())
end

function Wizard:Refresh()
    self:RefreshDeviceButtons()
    self:RefreshSummary()

    if self.stepIndex == 0 then
        self.frame.progress:SetText("Choose a device")
        self.frame.stepTitle:SetText("Select a layout family")
        self.frame.stepText:SetText("WoWX uses this choice for on-screen labels like A/B/X/Y or Cross/Circle/Square/Triangle. The actual captured inputs can still be ordinary keyboard keys.")
        self.frame.captureLabel:SetText("Ready")
        self.frame.captureHint:SetText("Click Start when you want to begin capture, or Start Over to discard the stored layout and recalibrate.")
        self.frame.startButton:Enable()
        self.frame.skipButton:Disable()
        self.frame.applyButton:Disable()
        return
    end

    local step = self:GetCurrentStep()
    if not step then
        self.frame.progress:SetText("Ready to apply")
        self.frame.stepTitle:SetText("Calibration Complete")
        self.frame.stepText:SetText("Review the layout and click Apply Setup to replace the current profile bindings. WoWX will enable itself automatically for this session.")
        self.frame.captureLabel:SetText("Review and apply")
        self.frame.captureHint:SetText("Use Start Over if you want to recapture the layout.")
        self.frame.applyButton:Enable()
        self.frame.startButton:Disable()
        self.frame.skipButton:Disable()
        return
    end

    self.frame.progress:SetText("Step " .. self.stepIndex .. " / " .. #self.steps)
    self.frame.stepTitle:SetText(step.title)
    self.frame.stepText:SetText(step.text)
    self.frame.captureLabel:SetText("Press a key now")
    self.frame.captureHint:SetText("ESC pauses capture. Duplicate keys are rejected so the layout stays deterministic.")
    self.frame.applyButton:Disable()
    self.frame.startButton:Disable()
    self.frame.skipButton:Disable()
end

function Wizard:StartCalibration()
    if not self.state.deviceId then
        self:SelectDevice("keyboard")
    end

    self:BuildSteps()
    self.stepIndex = 1
    self.awaitingInput = true
    self.modifierHeld = false
    self:BindCaptureKeys()
    self:Refresh()
    self:FocusCapture()
end

function Wizard:RestartCalibration()
    self.state.movement = {}
    self.state.modifiers = {}
    self.state.actionKeys = {}
    self.state.jumpKey = nil
    self.awaitingInput = false
    self.modifierHeld = false
    self:StartCalibration()
end

function Wizard:BuildSetupPayload()
    return {
        deviceId = self.state.deviceId,
        movement = GPX:DeepCopy(self.state.movement),
        modifiers = GPX:DeepCopy(self.state.modifiers),
        jumpKey = self.state.jumpKey,
        menuKey = self.state.menuKey,
        actionKeys = GPX:DeepCopy(self.state.actionKeys),
    }
end

function Wizard:Apply()
    if self.awaitingInput then
        return
    end

    local needMenuKey = GPX:IsControllerEnabled()
    if not self.state.jumpKey or (needMenuKey and not self.state.menuKey) or #self.state.actionKeys < 11 then
        if needMenuKey then
            GPX:Print("Setup is incomplete. Capture Jump, Menu/Escape, and action buttons 2 through 12 first.")
        else
            GPX:Print("Setup is incomplete. Capture Jump and action buttons 2 through 12 first.")
        end
        return
    end

    GPX:ApplySetup(self:BuildSetupPayload())
    GPX:Print("Visual setup applied. Use /gpx status to review the active profile.")
    self:UnbindCaptureKeys()
    self.frame:Hide()
end

function Wizard:Open(mode)
    self:CreateFrame()
    self.mode = mode or "init"
    self.state = {
        deviceId = "keyboard",
        movement = {},
        modifiers = {},
        actionKeys = {},
        jumpKey = nil,
        menuKey = nil,
    }
    self.steps = nil
    self.stepIndex = 0
    self.awaitingInput = false
    self.modifierHeld = false
    self:UnbindCaptureKeys()

    local profile = GPX:GetProfile()
    if profile and profile.setup then
        self.state = GPX:DeepCopy(profile.setup)
        self.state.deviceId = self.state.deviceId or profile.inputStyle or "keyboard"
        self.state.movement = self.state.movement or {}
        self.state.modifiers = self.state.modifiers or {}
        self.state.actionKeys = self.state.actionKeys or {}
        self.state.menuKey = self.state.menuKey or nil
    end

    self.frame.subtitle:SetText("A visual calibration pass for couch play and accessibility. Pick a device family, then press the real keys you mapped through AntiMicroX, Steam Input, or your keyboard.")
    self.frame.startButton:Enable()
    self.frame.applyButton:Disable()
    self.frame:Show()
    self.frame:Raise()
    self:SelectDevice(self.state.deviceId)

    if mode == "recal" then
        self:RestartCalibration()
    elseif mode == "init" then
        self:StartCalibration()
    else
        self:Refresh()
    end
end