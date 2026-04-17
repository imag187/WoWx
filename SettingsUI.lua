if not GamePadX then return end

local GPX = GamePadX
local UI = {}

GPX.SettingsUI = UI

local function createBackdrop(frame, borderR, borderG, borderB, borderA)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.04, 0.05, 0.08, 0.96)
    frame:SetBackdropBorderColor(borderR or 0.22, borderG or 0.66, borderB or 0.98, borderA or 0.85)
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

local function getActionCommandForField(field)
    if field == "jump" then
        return "ACTIONBUTTON1"
    end

    local actionSlot = tonumber((field or ""):match("^action(%d+)$") or "")
    if actionSlot and actionSlot >= 2 and actionSlot <= 12 then
        return "ACTIONBUTTON" .. actionSlot
    end
    return nil
end

function UI:CreateFrame()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "WoWXSettingsFrame", UIParent)
    frame:SetWidth(780)
    frame:SetHeight(800)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:SetScript("OnHide", function()
        UI.captureField = nil
        if UI.frame and UI.frame.keyCapture then
            UI.frame.keyCapture:ClearFocus()
        end
        if GPX.UIMode and GPX.UIMode.activeContext == "settings" then
            GPX.UIMode:Exit()
        end
    end)
    createBackdrop(frame)
    frame:Hide()

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -18)
    title:SetText(GPX.brand .. " Control Center")
    title:SetTextColor(0.95, 0.97, 1.0)

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetWidth(480)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Visual setup, bar control, and couch-play status in one place. Use this instead of remembering slash commands.")

    local setTab

    local tabGeneral = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tabGeneral:SetWidth(92)
    tabGeneral:SetHeight(22)
    tabGeneral:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -124, -14)
    tabGeneral:SetText("General")
    tabGeneral:SetScript("OnClick", function()
        if setTab then
            setTab("general")
        end
    end)

    local tabController = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tabController:SetWidth(92)
    tabController:SetHeight(22)
    tabController:SetPoint("LEFT", tabGeneral, "RIGHT", 8, 0)
    tabController:SetText("Controllers")
    tabController:SetScript("OnClick", function()
        if setTab then
            setTab("controller")
        end
    end)

    frame.tabGeneral = tabGeneral
    frame.tabController = tabController

    local statusPanel = CreateFrame("Frame", nil, frame)
    statusPanel:SetWidth(510)
    statusPanel:SetHeight(90)
    statusPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -76)
    createBackdrop(statusPanel, 0.18, 0.3, 0.5, 0.8)
    statusPanel:SetBackdropColor(0.07, 0.09, 0.14, 0.92)

    local statusTitle = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusTitle:SetPoint("TOPLEFT", statusPanel, "TOPLEFT", 14, -14)
    statusTitle:SetText("Current State")

    local statusText = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    statusText:SetPoint("TOPLEFT", statusTitle, "BOTTOMLEFT", 0, -10)
    statusText:SetWidth(480)
    statusText:SetJustifyH("LEFT")

    local actionPanel = CreateFrame("Frame", nil, frame)
    actionPanel:SetWidth(510)
    actionPanel:SetHeight(256)
    actionPanel:SetPoint("TOPLEFT", statusPanel, "BOTTOMLEFT", 0, -18)
    createBackdrop(actionPanel, 0.18, 0.3, 0.5, 0.8)
    actionPanel:SetBackdropColor(0.06, 0.08, 0.12, 0.92)

    local actionTitle = actionPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    actionTitle:SetPoint("TOPLEFT", actionPanel, "TOPLEFT", 14, -14)
    actionTitle:SetText("Actions")

    local bindingPanel = CreateFrame("Frame", nil, frame)
    bindingPanel:SetWidth(510)
    bindingPanel:SetHeight(92)
    bindingPanel:SetPoint("TOPLEFT", actionPanel, "BOTTOMLEFT", 0, -16)
    createBackdrop(bindingPanel, 0.18, 0.3, 0.5, 0.8)
    bindingPanel:SetBackdropColor(0.06, 0.08, 0.12, 0.92)

    local bindingTitle = bindingPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bindingTitle:SetPoint("TOPLEFT", bindingPanel, "TOPLEFT", 14, -14)
    bindingTitle:SetText("Current Bindings")

    local bindingText = bindingPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bindingText:SetPoint("TOPLEFT", bindingTitle, "BOTTOMLEFT", 0, -8)
    bindingText:SetWidth(480)
    bindingText:SetJustifyH("LEFT")

    local utilityPanel = CreateFrame("Frame", nil, frame)
    utilityPanel:SetWidth(510)
    utilityPanel:SetHeight(108)
    utilityPanel:SetPoint("TOPLEFT", bindingPanel, "BOTTOMLEFT", 0, -14)
    createBackdrop(utilityPanel, 0.18, 0.3, 0.5, 0.8)
    utilityPanel:SetBackdropColor(0.06, 0.08, 0.12, 0.92)

    local utilityTitle = utilityPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    utilityTitle:SetPoint("TOPLEFT", utilityPanel, "TOPLEFT", 14, -12)
    utilityTitle:SetText("Controller Integration")

    local utilityHint = utilityPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    utilityHint:SetPoint("TOPLEFT", utilityTitle, "BOTTOMLEFT", 0, -6)
    utilityHint:SetWidth(480)
    utilityHint:SetJustifyH("LEFT")
    utilityHint:SetText("Enable controller mode to verify your AntiMicroX keyboard mapping and show controller labels on the WoWX bar.")

    local inputPanel = CreateFrame("Frame", nil, frame)
    inputPanel:SetWidth(510)
    inputPanel:SetHeight(178)
    inputPanel:SetPoint("TOPLEFT", utilityPanel, "BOTTOMLEFT", 0, -14)
    createBackdrop(inputPanel, 0.18, 0.3, 0.5, 0.8)
    inputPanel:SetBackdropColor(0.06, 0.08, 0.12, 0.92)

    local inputTitle = inputPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    inputTitle:SetPoint("TOPLEFT", inputPanel, "TOPLEFT", 14, -12)
    inputTitle:SetText("Controller Verification (Click To Capture)")

    local inputHint = inputPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    inputHint:SetPoint("TOPLEFT", inputTitle, "BOTTOMLEFT", 0, -6)
    inputHint:SetWidth(480)
    inputHint:SetJustifyH("LEFT")
    inputHint:SetText("Enable controller mode first. Then click a mapping button and press the key sent by your AntiMicroX profile.")

    setTab = function(tab)
        frame.activeTab = tab
        local showGeneral = tab ~= "controller"
        statusPanel:SetShown(showGeneral)
        actionPanel:SetShown(showGeneral)
        bindingPanel:SetShown(showGeneral)
        utilityPanel:SetShown(not showGeneral)
        inputPanel:SetShown(not showGeneral)
        if frame.tabGeneral and frame.tabController then
            frame.tabGeneral:SetText(showGeneral and "General *" or "General")
            frame.tabController:SetText((not showGeneral) and "Controllers *" or "Controllers")
        end
    end

    frame.buttons = {}
    local specs = {
        { key = "init", label = "Run Init", x = 14, y = -42, width = 116, click = function() GPX:OpenSetupWizard("init") end },
        { key = "recal", label = "Recalibrate", x = 140, y = -42, width = 116, click = function() GPX:OpenSetupWizard("recal") end },
        { key = "toggleMode", label = "Enable / Disable", x = 266, y = -42, width = 140, click = function() GPX.db.enabled = not GPX.db.enabled if GPX.db.enabled then GPX:ApplyBindings() else GPX:ClearBindings() end UI:Refresh() end },
        { key = "toggleBar", label = "Show / Hide Bar", x = 14, y = -82, width = 116, click = function() if GPX.VisualBar then GPX.VisualBar:Slash("toggle") end UI:Refresh() end },
        { key = "lockBar", label = "Layout Edit", x = 140, y = -82, width = 116, click = function() if GPX.VisualBar then GPX.VisualBar:Slash(GPX.db.ui.visualBar.locked and "unlock" or "lock") end UI:Refresh() end },
        { key = "resetBar", label = "Reset Bar", x = 266, y = -82, width = 140, click = function() if GPX.VisualBar then GPX.VisualBar:Slash("reset") end UI:Refresh() end },
        { key = "toggleMinimap", label = "Minimap Button", x = 14, y = -122, width = 116, click = function() if GPX.MinimapButton then GPX.MinimapButton:Toggle() end UI:Refresh() end },
        { key = "reload", label = "Reapply Binds", x = 140, y = -122, width = 116, click = function() GPX:ClearBindings() GPX:ApplyBindings() UI:Refresh() end },
        { key = "focusBar", label = "Focus Bar", x = 266, y = -122, width = 140, click = function() if GPX.UIMode then GPX.UIMode:Enter("bar", { returnContext = "settings" }) end end },
        { key = "spellbook", label = "Open Spellbook", x = 14, y = -162, width = 116, click = function() if GPX.SpellbookUI then GPX.SpellbookUI:Open(nil, "settings") end end },
        { key = "menuNav", label = "Menu Navigator", x = 266, y = -162, width = 140, click = function() GPX:OpenMenuNav("settings") end },
        { key = "lockProgress", label = "Lock XP Bar", x = 140, y = -162, width = 116, click = function() if GPX.VisualBar then GPX.VisualBar:Slash("progresslock") end UI:Refresh() end },
        { key = "close", label = "Close", x = 140, y = -242, width = 116, click = function() frame:Hide() end },
    }

    frame.navOrder = {}

    for _, spec in ipairs(specs) do
        local button = CreateFrame("Button", nil, actionPanel, "UIPanelButtonTemplate")
        button:SetWidth(spec.width)
        button:SetHeight(30)
        button:SetPoint("TOPLEFT", actionPanel, "TOPLEFT", spec.x, spec.y)
        button:SetText(spec.label)
        button:SetScript("OnClick", spec.click)
        frame.buttons[spec.key] = button
        frame.navOrder[#frame.navOrder + 1] = button
    end

    frame.controllerEnable = CreateFrame("Button", nil, utilityPanel, "UIPanelButtonTemplate")
    frame.controllerEnable:SetWidth(146)
    frame.controllerEnable:SetHeight(24)
    frame.controllerEnable:SetPoint("TOPRIGHT", utilityPanel, "TOPRIGHT", -14, -10)
    frame.controllerEnable:SetScript("OnClick", function()
        GPX:SetControllerEnabled(not GPX:IsControllerEnabled())
        UI:Refresh()
        if GPX.VisualBar then
            GPX.VisualBar:UpdateAll()
        end
    end)
    frame.navOrder[#frame.navOrder + 1] = frame.controllerEnable

    frame.styleButtons = {}
    local styleSpecs = {
        { id = "keyboard", label = "Keyboard" },
        { id = "xbox", label = "Xbox" },
        { id = "playstation", label = "PlayStation" },
        { id = "switch", label = "Switch" },
        { id = "generic", label = "Generic" },
    }
    for index, spec in ipairs(styleSpecs) do
        local button = CreateFrame("Button", nil, utilityPanel, "UIPanelButtonTemplate")
        button:SetWidth(92)
        button:SetHeight(22)
        local col = (index - 1) % 5
        button:SetPoint("TOPLEFT", utilityPanel, "TOPLEFT", 14 + (col * 98), -44)
        button.styleId = spec.id
        button.baseLabel = spec.label
        button:SetScript("OnClick", function(self)
            UI:SetControllerStyle(self.styleId)
        end)
        frame.styleButtons[#frame.styleButtons + 1] = button
        frame.navOrder[#frame.navOrder + 1] = button
    end

    frame.barOptions = {}
    local optionSpecs = {
        { key = "toggleProgress", label = "XP/Rep Bar", x = 14, click = function() if GPX.VisualBar then GPX.VisualBar:Slash("progress") end UI:Refresh() end },
    }

    for _, spec in ipairs(optionSpecs) do
        local button = CreateFrame("Button", nil, actionPanel, "UIPanelButtonTemplate")
        button:SetWidth(104)
        button:SetHeight(24)
        local y = (spec.row == 2) and -206 or -206
        if spec.row == 2 then
            y = -236
        end
        button:SetPoint("TOPLEFT", actionPanel, "TOPLEFT", spec.x, y)
        button:SetText(spec.label)
        button:SetScript("OnClick", spec.click)
        frame.barOptions[spec.key] = button
        frame.navOrder[#frame.navOrder + 1] = button
    end

    frame.mappingButtons = {}
    local mappingFields = {
        { field = "jump", label = "Action 1" },
        { field = "menu", label = "Menu" },
        { field = "mod1", label = "Mod 1" },
        { field = "mod2", label = "Mod 2" },
        { field = "mod3", label = "Mod 3" },
        { field = "action2", label = "Action 2" },
        { field = "action3", label = "Action 3" },
        { field = "action4", label = "Action 4" },
        { field = "action5", label = "Action 5" },
        { field = "action6", label = "Action 6" },
        { field = "action7", label = "Action 7" },
        { field = "action8", label = "Action 8" },
        { field = "action9", label = "Action 9" },
        { field = "action10", label = "Action 10" },
        { field = "action11", label = "Action 11" },
        { field = "action12", label = "Action 12" },
    }

    for index, entry in ipairs(mappingFields) do
        local button = CreateFrame("Button", nil, inputPanel, "UIPanelButtonTemplate")
        button:SetWidth(154)
        button:SetHeight(22)
        local col = (index - 1) % 3
        local row = math.floor((index - 1) / 3)
        button:SetPoint("TOPLEFT", inputPanel, "TOPLEFT", 14 + (col * 164), -40 - (row * 24))
        button.field = entry.field
        button.baseLabel = entry.label
        button:SetScript("OnClick", function(self)
            UI:StartInputCapture(self.field)
        end)
        frame.mappingButtons[entry.field] = button
        frame.navOrder[#frame.navOrder + 1] = button
    end

    local keyCapture = CreateFrame("EditBox", nil, frame)
    keyCapture:SetWidth(8)
    keyCapture:SetHeight(8)
    keyCapture:SetPoint("TOPLEFT", inputPanel, "TOPLEFT", 2, -2)
    keyCapture:SetAutoFocus(false)
    keyCapture:EnableKeyboard(true)
    keyCapture:EnableMouse(true)
    keyCapture:SetMaxLetters(1)
    keyCapture:SetText("")
    keyCapture:SetScript("OnKeyDown", function(_, key)
        UI:HandleCapturedKey(key)
    end)
    keyCapture:SetScript("OnChar", function(_, text)
        if text == " " then
            UI:HandleCapturedKey("SPACE")
        else
            UI:HandleCapturedKey(text)
        end
    end)
    keyCapture:SetScript("OnEscapePressed", function()
        UI:HandleCapturedKey("ESCAPE")
    end)
    keyCapture:SetScript("OnMouseDown", function(_, mouseButton)
        UI:HandleCapturedKey(mouseButton)
    end)
    keyCapture:SetScript("OnEditFocusLost", function(self)
        if UI.captureField and UI.frame and UI.frame:IsShown() then
            self:SetFocus()
        end
    end)

    local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 4)
    footer:SetWidth(500)
    footer:SetJustifyH("LEFT")
    footer:SetText("Tip: Turn Layout Edit on, then drag bars by the Drag handle and resize with corner grips. Turn Layout Edit off when finished.")

    self.frame = frame
    self.frame.statusText = statusText
    self.frame.bindingText = bindingText
    self.frame.inputHint = inputHint
    self.frame.keyCapture = keyCapture
    self.frame.setTab = setTab
    self.frame.navOrder[#self.frame.navOrder + 1] = tabGeneral
    self.frame.navOrder[#self.frame.navOrder + 1] = tabController
    setTab("general")

    if GPX.UIMode then
        GPX.UIMode:RegisterContext("settings", {
            label = "Control Center",
            getItems = function()
                return UI.frame and UI.frame.navOrder or {}
            end,
            columns = 3,
            isAvailable = function()
                return UI.frame and UI.frame:IsShown()
            end,
            getIndicatorText = function(_, baseText)
                return "Use Focus Bar or Open Spellbook to move deeper into WoWX UI.   " .. baseText
            end,
            onCancel = function()
                if UI.frame then
                    UI.frame:Hide()
                end
            end,
        })
    end
end

function UI:RefreshUtilityButtons()
    if not self.frame then
        return
    end

    local profile = GPX:GetProfile()
    local setup = profile and profile.setup or nil

    local controllerEnabled = GPX:IsControllerEnabled()
    if self.frame.controllerEnable then
        self.frame.controllerEnable:SetText(controllerEnabled and "Controller: Enabled" or "Enable Controller")
    end

    if self.frame.styleButtons then
        local styleId = setup and (setup.deviceId or setup.inputStyle) or "keyboard"
        for _, button in ipairs(self.frame.styleButtons) do
            local isSelected = button.styleId == styleId
            button:SetText(button.baseLabel .. (isSelected and " *" or ""))
            if controllerEnabled then
                button:Enable()
                button:SetAlpha(1.0)
            else
                button:Disable()
                button:SetAlpha(0.5)
            end
        end
    end

    if self.frame.barOptions and GPX.db and GPX.db.ui and GPX.db.ui.visualBar then
        local cfg = GPX.db.ui.visualBar
        if self.frame.barOptions.microSmaller then
            self.frame.barOptions.microSmaller:SetText("Micro -")
            self.frame.barOptions.microBigger:SetText("Micro +")
        end
        if self.frame.barOptions.stanceSmaller then
            self.frame.barOptions.stanceSmaller:SetText("Stance -")
            self.frame.barOptions.stanceBigger:SetText("Stance +")
        end
        if self.frame.barOptions.petSmaller then
            self.frame.barOptions.petSmaller:SetText("Pet -")
            self.frame.barOptions.petBigger:SetText("Pet +")
        end
        if self.frame.barOptions.toggleProgress then
            self.frame.barOptions.toggleProgress:SetText((cfg.showProgress ~= false) and "XP/Rep: On" or "XP/Rep: Off")
        end
        if self.frame.buttons and self.frame.buttons.lockProgress then
            self.frame.buttons.lockProgress:SetText((cfg.progressLocked ~= false) and "Unlock XP Bar" or "Lock XP Bar")
        end
    end
end

function UI:SetControllerStyle(styleId)
    local profile = GPX:GetProfile()
    local setup = GPX:GetOrCreateSetup(profile)
    setup.deviceId = styleId
    setup.inputStyle = styleId

    local ok, err = GPX:ApplySetupFromProfile(profile)
    if not ok and err then
        GPX:Print(err)
    end

    if GPX.VisualBar then
        GPX.VisualBar:UpdateAll()
    end
    self:Refresh()
end

function UI:GetMappingValue(field)
    local profile = GPX:GetProfile()
    local setup = profile and profile.setup or nil
    if not setup then
        return "--"
    end

    if field == "jump" then
        return setup.jumpKey or "--"
    elseif field == "menu" then
        return setup.menuKey or "--"
    elseif field == "mod1" then
        return (setup.modifiers and setup.modifiers[1]) or "--"
    elseif field == "mod2" then
        return (setup.modifiers and setup.modifiers[2]) or "--"
    elseif field == "mod3" then
        return (setup.modifiers and setup.modifiers[3]) or "--"
    end

    local actionSlot = tonumber((field or ""):match("^action(%d)$") or "")
    if actionSlot and actionSlot >= 2 and actionSlot <= 12 then
        return (setup.actionKeys and setup.actionKeys[actionSlot - 1]) or "--"
    end
    return "--"
end

function UI:SetMappingValue(field, value)
    local profile = GPX:GetProfile()
    local setup = GPX:GetOrCreateSetup(profile)

    if field == "jump" then
        setup.jumpKey = value
    elseif field == "menu" then
        setup.menuKey = value
    elseif field == "mod1" then
        setup.modifiers[1] = value
    elseif field == "mod2" then
        setup.modifiers[2] = value
    elseif field == "mod3" then
        setup.modifiers[3] = value
    else
        local actionSlot = tonumber((field or ""):match("^action(%d)$") or "")
        if actionSlot and actionSlot >= 2 and actionSlot <= 12 then
            setup.actionKeys[actionSlot - 1] = value
        end
    end

    local ok, err = GPX:ApplySetupFromProfile(profile)
    if ok then
        GPX.db.enabled = true
        GPX:ApplyBindings()
    else
        GPX:Print(err or "Failed to update mapping.")
    end
end

function UI:StartInputCapture(field)
    if not self.frame or not self.frame.keyCapture then
        return
    end

    if not GPX:IsControllerEnabled() and not getActionCommandForField(field) then
        self.frame.inputHint:SetText("This field is for controller mode only. Enable Controller first.")
        return
    end

    self.captureField = field
    self.frame.inputHint:SetText("Capturing " .. field .. "... press a key now (ESC to cancel)")
    self.frame.keyCapture:SetFocus()
end

function UI:HandleCapturedKey(rawKey)
    if not self.captureField then
        return
    end

    local key = normalizeKey(rawKey)
    if not key then
        return
    end

    if key == "ESCAPE" then
        self.captureField = nil
        self.frame.inputHint:SetText("Click a mapping button, then press a key. WoWX maps these keys to its own bar buttons for this session.")
        self.frame.keyCapture:ClearFocus()
        self:Refresh()
        return
    end

    if (self.captureField == "mod1" or self.captureField == "mod2" or self.captureField == "mod3") and key ~= "SHIFT" and key ~= "ALT" and key ~= "CTRL" then
        self.frame.inputHint:SetText("Modifiers must be SHIFT, ALT, or CTRL. Try again.")
        return
    end

    self:SetMappingValue(self.captureField, key)
    self.frame.inputHint:SetText("Mapped " .. self.captureField .. " to " .. key .. ". Click another mapping button to continue.")
    self.captureField = nil
    self.frame.keyCapture:ClearFocus()
    self:Refresh()
end

function UI:RefreshMappingButtons()
    if not self.frame or not self.frame.mappingButtons then
        return
    end

    local controllerEnabled = GPX:IsControllerEnabled()

    for field, button in pairs(self.frame.mappingButtons) do
        button:SetText(button.baseLabel .. ": " .. self:GetMappingValue(field))
        local keyboardField = getActionCommandForField(field) ~= nil
        if controllerEnabled or keyboardField then
            button:Enable()
            button:SetAlpha(1.0)
        else
            button:Disable()
            button:SetAlpha(0.45)
        end
    end
end

function UI:BuildBindingSummary()
    local profile = GPX:GetProfile()
    local setup = profile and profile.setup or nil
    if not profile or not profile.bindings or not setup then
        return "No bindings available. Run Init to build controller bindings."
    end

    local style = GPX:GetInputStyle(setup.deviceId)
    local lines = {}

    local actionKeys = setup.actionKeys or {}
    for slotIndex = 1, 12 do
        local key
        if slotIndex == 1 then
            key = setup.jumpKey or "--"
        else
            key = actionKeys[slotIndex - 1] or "--"
        end
        lines[#lines + 1] = "Action " .. slotIndex .. " (Base)  " .. key .. " -> ACTIONBUTTON" .. slotIndex
    end

    local mods = setup.modifiers or {}
    local modLabels = style.modifierLabels or { "Modifier 1", "Modifier 2", "Modifier 3" }
    local pages = {
        { name = modLabels[1] or "Modifier 1", key = mods[1], bar = "MULTIACTIONBAR2BUTTON" },
        { name = modLabels[2] or "Modifier 2", key = mods[2], bar = "MULTIACTIONBAR1BUTTON" },
        { name = modLabels[3] or "Modifier 3", key = mods[3], bar = "MULTIACTIONBAR4BUTTON" },
    }

    for _, page in ipairs(pages) do
        if page.key and page.key ~= "" then
            lines[#lines + 1] = "[" .. page.name .. " = " .. page.key .. "] page -> " .. page.bar
        end
    end

    return table.concat(lines, "\n")
end

function UI:BuildStatusText()
    local profile = GPX:GetProfile()
    local setup = profile and profile.setup or nil
    local mode = GPX.db and GPX.db.enabled and "Enabled" or "Disabled"
    local profileName = profile and (profile.name or GPX.db.profile or "default") or "default"
    local styleId = setup and (setup.inputStyle or setup.deviceId)
    local inputStyle = styleId and GPX:GetInputStyle(styleId).name or "Not calibrated"
    local visualBar = GPX.db and GPX.db.ui and GPX.db.ui.visualBar and GPX.db.ui.visualBar.enabled and "Shown" or "Hidden"
    local lockState = GPX.db and GPX.db.ui and GPX.db.ui.visualBar and GPX.db.ui.visualBar.locked and "Locked" or "Unlocked"
    local minimap = GPX.db and GPX.db.ui and GPX.db.ui.minimapButton and GPX.db.ui.minimapButton.enabled and "Shown" or "Hidden"
    local controllerMode = GPX:IsControllerEnabled() and "Enabled" or "Disabled"
    local lastError = GPX.db and GPX.db.lastError and GPX.db.lastError ~= "" and GPX.db.lastError or "None"

    return string.format(
        "Mode: %s\nProfile: %s\nInput Style: %s\nController Mode: %s\nVisual Bar: %s (%s)\nMinimap Button: %s\nLast Error: %s",
        mode,
        profileName,
        inputStyle,
        controllerMode,
        visualBar,
        lockState,
        minimap,
        lastError
    )
end

function UI:Refresh()
    if not self.frame then
        return
    end

    self.frame.statusText:SetText(self:BuildStatusText())
    self.frame.bindingText:SetText(self:BuildBindingSummary())
    if self.frame.buttons and self.frame.buttons.lockBar and GPX.db and GPX.db.ui and GPX.db.ui.visualBar then
        self.frame.buttons.lockBar:SetText((GPX.db.ui.visualBar.locked ~= false) and "Layout Edit: Off" or "Layout Edit: On")
    end
    if not self.captureField and self.frame.inputHint then
        if GPX:IsControllerEnabled() then
            self.frame.inputHint:SetText("Click a mapping button, then press the key sent by your AntiMicroX controller mapping.")
        else
            self.frame.inputHint:SetText("Keyboard mode: map Action 1-12 to WoWX bar slots (session override binds).")
        end
    end
    self:RefreshUtilityButtons()
    self:RefreshMappingButtons()
end

function UI:Open()
    self:CreateFrame()
    self:Refresh()
    self.frame:Show()
    if GPX.UIMode then
        GPX.UIMode:Enter("settings")
    end
end