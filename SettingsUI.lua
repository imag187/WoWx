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
    local actionSlot = tonumber((field or ""):match("^action(%d+)$") or "")
    if actionSlot and actionSlot >= 1 and actionSlot <= 12 then
        return "ACTIONBUTTON" .. actionSlot
    end
    return nil
end

local function getActionSlotForField(field)
    return tonumber((field or ""):match("^action(%d+)$") or "")
end

function UI:ScheduleBindingRefresh(delaySeconds)
    if not GPX or not GPX.db then
        return
    end

    GPX.db.enabled = true
    self.pendingBindingRefreshAt = GetTime() + (delaySeconds or 0.35)

    if self.bindingRefreshTicker then
        return
    end

    self.bindingRefreshTicker = CreateFrame("Frame")
    self.bindingRefreshTicker:SetScript("OnUpdate", function(frame)
        if not UI.pendingBindingRefreshAt then
            frame:SetScript("OnUpdate", nil)
            UI.bindingRefreshTicker = nil
            return
        end

        if GetTime() < UI.pendingBindingRefreshAt then
            return
        end

        UI.pendingBindingRefreshAt = nil
        frame:SetScript("OnUpdate", nil)
        UI.bindingRefreshTicker = nil
        GPX:ClearBindings()
        GPX:ApplyBindings(true)
        if UI.frame and UI.frame:IsShown() then
            UI:Refresh()
        end
    end)
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
    frame:SetToplevel(true)
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
    subtitle:SetText("General tab is for bar/actions. Keybinds tab is for key mapping and optional controller setup.")

    local setTab

    local tabProfiles = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tabProfiles:SetWidth(92)
    tabProfiles:SetHeight(22)
    tabProfiles:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -324, -14)
    tabProfiles:SetText("Profiles")
    tabProfiles:SetScript("OnClick", function()
        if setTab then
            setTab("profiles")
        end
    end)

    local tabGeneral = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tabGeneral:SetWidth(92)
    tabGeneral:SetHeight(22)
    tabGeneral:SetPoint("LEFT", tabProfiles, "RIGHT", 8, 0)
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
    tabController:SetText("Keybinds")
    tabController:SetScript("OnClick", function()
        if setTab then
            setTab("controller")
        end
    end)

    frame.tabProfiles = tabProfiles
    frame.tabGeneral = tabGeneral
    frame.tabController = tabController

    local statusPanel = CreateFrame("Frame", nil, frame)
    statusPanel:SetWidth(510)
    statusPanel:SetHeight(192)
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
    utilityPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -76)
    createBackdrop(utilityPanel, 0.18, 0.3, 0.5, 0.8)
    utilityPanel:SetBackdropColor(0.06, 0.08, 0.12, 0.92)

    local utilityTitle = utilityPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    utilityTitle:SetPoint("TOPLEFT", utilityPanel, "TOPLEFT", 14, -12)
    utilityTitle:SetText("Controller Integration")

    local utilityHint = utilityPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    utilityHint:SetPoint("TOPLEFT", utilityTitle, "BOTTOMLEFT", 0, -6)
    utilityHint:SetWidth(480)
    utilityHint:SetJustifyH("LEFT")
    utilityHint:SetText("Controller tools are optional. Use them to verify AntiMicroX keys and choose label style shown on the WoWX bar.")

    local inputPanel = CreateFrame("Frame", nil, frame)
    inputPanel:SetWidth(510)
    inputPanel:SetHeight(214)
    inputPanel:SetPoint("TOPLEFT", utilityPanel, "BOTTOMLEFT", 0, -14)
    createBackdrop(inputPanel, 0.18, 0.3, 0.5, 0.8)
    inputPanel:SetBackdropColor(0.06, 0.08, 0.12, 0.92)

    local inputTitle = inputPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    inputTitle:SetPoint("TOPLEFT", inputPanel, "TOPLEFT", 14, -12)
    inputTitle:SetText("Input Mapping (Optional Override Capture)")

    local inputHint = inputPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    inputHint:SetPoint("TOPLEFT", inputTitle, "BOTTOMLEFT", 0, -6)
    inputHint:SetWidth(480)
    inputHint:SetJustifyH("LEFT")
    inputHint:SetText("Click a mapping field, then press a key to update WoWX mapping labels and optional session overrides.")

    local profilePanel = CreateFrame("Frame", nil, frame)
    profilePanel:SetWidth(510)
    profilePanel:SetHeight(194)
    profilePanel:SetPoint("TOPLEFT", utilityPanel, "BOTTOMLEFT", 0, -14)
    createBackdrop(profilePanel, 0.18, 0.3, 0.5, 0.8)
    profilePanel:SetBackdropColor(0.06, 0.08, 0.12, 0.92)

    local profileTitle = profilePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    profileTitle:SetPoint("TOPLEFT", profilePanel, "TOPLEFT", 14, -12)
    profileTitle:SetText("Layout Profiles")

    local profileHint = profilePanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    profileHint:SetPoint("TOPLEFT", profileTitle, "BOTTOMLEFT", 0, -6)
    profileHint:SetWidth(480)
    profileHint:SetJustifyH("LEFT")
    profileHint:SetText("These profiles save sizing and placement only. WoWX bindings stay per character.")

    local profileNameLabel = profilePanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    profileNameLabel:SetPoint("TOPLEFT", profileHint, "BOTTOMLEFT", 0, -14)
    profileNameLabel:SetText("Profile Name")

    local profileNameBox = CreateFrame("EditBox", nil, profilePanel, "InputBoxTemplate")
    profileNameBox:SetWidth(160)
    profileNameBox:SetHeight(20)
    profileNameBox:SetPoint("LEFT", profileNameLabel, "RIGHT", 10, 0)
    profileNameBox:SetAutoFocus(false)
    profileNameBox:SetTextColor(1.0, 0.92, 0.58)

    local currentProfileText = profilePanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    currentProfileText:SetPoint("TOPLEFT", profileNameLabel, "BOTTOMLEFT", 0, -14)
    currentProfileText:SetWidth(480)
    currentProfileText:SetJustifyH("LEFT")

    local profileButtons = {
        { key = "saveProfile", label = "Save", x = 14, y = -130, width = 92 },
        { key = "loadProfile", label = "Load", x = 114, y = -130, width = 92 },
        { key = "newProfile", label = "New From Current", x = 214, y = -130, width = 132 },
        { key = "deleteProfile", label = "Delete", x = 354, y = -130, width = 92 },
    }

    frame.profilePanel = profilePanel
    frame.profileNameBox = profileNameBox
    frame.currentProfileText = currentProfileText
    frame.profileButtons = {}

    for _, spec in ipairs(profileButtons) do
        local button = CreateFrame("Button", nil, profilePanel, "UIPanelButtonTemplate")
        button:SetWidth(spec.width)
        button:SetHeight(24)
        button:SetPoint("TOPLEFT", profilePanel, "TOPLEFT", spec.x, spec.y)
        button:SetText(spec.label)
        frame.profileButtons[spec.key] = button
    end

    setTab = function(tab)
        frame.activeTab = tab
        local showGeneral = tab == "general"
        local showProfiles = tab == "profiles"
        local showController = tab == "controller"
        statusPanel:SetShown(showGeneral)
        actionPanel:SetShown(showGeneral)
        bindingPanel:SetShown(showController)
        utilityPanel:SetShown(showController)
        inputPanel:SetShown(showController)
        profilePanel:SetShown(showProfiles)
        if frame.tabProfiles and frame.tabGeneral and frame.tabController then
            frame.tabProfiles:SetText(showProfiles and "Profiles *" or "Profiles")
            frame.tabGeneral:SetText(showGeneral and "General *" or "General")
            frame.tabController:SetText(showController and "Keybinds *" or "Keybinds")
        end
    end

    frame.buttons = {}
    local specs = {
        { key = "init", label = "Init Wizard", x = 14, y = -42, width = 116, click = function() GPX:OpenSetupWizard("init") end },
        { key = "recal", label = "Recalibrate", x = 140, y = -42, width = 116, click = function() GPX:OpenSetupWizard("recal") end },
        { key = "toggleMode", label = "Enable / Disable", x = 266, y = -42, width = 140, click = function() GPX.db.enabled = not GPX.db.enabled if GPX.db.enabled then GPX:ApplyBindings() else GPX:ClearBindings() end UI:Refresh() end },
        { key = "toggleBar", label = "Show / Hide Bar", x = 14, y = -82, width = 116, click = function() if GPX.VisualBar then GPX.VisualBar:Slash("toggle") end UI:Refresh() end },
        { key = "lockBar", label = "Layout Edit", x = 140, y = -82, width = 116, click = function() if GPX.VisualBar then GPX.VisualBar:Slash(GPX.db.ui.visualBar.locked and "unlock" or "lock") end UI:Refresh() end },
        { key = "resetBar", label = "Reset Bar", x = 266, y = -82, width = 140, click = function() if GPX.VisualBar then GPX.VisualBar:Slash("reset") end UI:Refresh() end },
        { key = "toggleMinimap", label = "Minimap Button", x = 14, y = -122, width = 116, click = function() if GPX.MinimapButton then GPX.MinimapButton:Toggle() end UI:Refresh() end },
        { key = "reload", label = "Reapply Binds", x = 140, y = -122, width = 116, click = function() GPX:ClearBindings() GPX:ApplyBindings() UI:Refresh() end },
        { key = "focusBar", label = "Focus Bar", x = 266, y = -122, width = 140, click = function() if GPX.UIMode then GPX.UIMode:Enter("bar", { returnContext = "settings" }) end end },
        { key = "spellbook", label = "Open Spellbook", x = 14, y = -162, width = 116, click = function() if GPX.SpellbookUI then GPX.SpellbookUI:Open(nil, "settings") end end },
        { key = "menuNav", label = "Menu Navigator", x = 140, y = -162, width = 140, click = function() GPX:OpenMenuNav("settings") end },
        { key = "buttonEdit", label = "Button Edit", x = 290, y = -162, width = 116, click = function() if GPX.VisualBar then GPX.VisualBar:Slash((GPX.db.ui.visualBar.buttonLocked ~= false) and "buttonunlock" or "buttonlock") end UI:Refresh() end },
        { key = "gridbook", label = "Open Gridbook", x = 14, y = -202, width = 116, click = function() GPX:Slash("gridbook") end },
        { key = "toggleBags", label = "WoWX Bags", x = 140, y = -202, width = 116, click = function() if GPX.ActionButtons and GPX.ActionButtons.Slash then GPX.ActionButtons:Slash("toggle") end UI:Refresh() end },
        { key = "layoutProfiles", label = "Layout Profiles", x = 266, y = -202, width = 140, click = function() if setTab then setTab("profiles") end end },
        { key = "close", label = "Close", x = 290, y = -242, width = 116, click = function() frame:Hide() end },
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

    frame.mouseLookMode = CreateFrame("Button", nil, utilityPanel, "UIPanelButtonTemplate")
    frame.mouseLookMode:SetWidth(146)
    frame.mouseLookMode:SetHeight(24)
    frame.mouseLookMode:SetPoint("TOPRIGHT", utilityPanel, "TOPRIGHT", -14, -38)
    frame.mouseLookMode:SetScript("OnClick", function()
        local cfg = GPX:GetControllerConfig()
        if cfg.mouseLookMode == "platformer" then
            GPX:SetControllerMouseLookMode("move")
        else
            GPX:SetControllerMouseLookMode("platformer")
        end
        UI:Refresh()
    end)
    frame.navOrder[#frame.navOrder + 1] = frame.mouseLookMode

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
        button:SetPoint("TOPLEFT", utilityPanel, "TOPLEFT", 14 + (col * 98), -70)
        button.styleId = spec.id
        button.baseLabel = spec.label
        button:SetScript("OnClick", function(self)
            UI:SetControllerStyle(self.styleId)
        end)
        frame.styleButtons[#frame.styleButtons + 1] = button
        frame.navOrder[#frame.navOrder + 1] = button
    end

    for _, button in pairs(frame.profileButtons) do
        frame.navOrder[#frame.navOrder + 1] = button
    end

    if frame.profileButtons then
        if frame.profileButtons.saveProfile then
            frame.profileButtons.saveProfile:SetScript("OnClick", function()
                local name = UI.frame and UI.frame.profileNameBox and UI.frame.profileNameBox:GetText() or nil
                if GPX.VisualBar and GPX.VisualBar.SaveLayoutProfile then
                    GPX.VisualBar:SaveLayoutProfile(name)
                    UI:Refresh()
                end
            end)
        end
        if frame.profileButtons.loadProfile then
            frame.profileButtons.loadProfile:SetScript("OnClick", function()
                local name = UI.frame and UI.frame.profileNameBox and UI.frame.profileNameBox:GetText() or nil
                if GPX.VisualBar and GPX.VisualBar.ApplyLayoutProfile then
                    GPX.VisualBar:ApplyLayoutProfile(name)
                    UI:Refresh()
                end
            end)
        end
        if frame.profileButtons.newProfile then
            frame.profileButtons.newProfile:SetScript("OnClick", function()
                local name = UI.frame and UI.frame.profileNameBox and UI.frame.profileNameBox:GetText() or nil
                if GPX.VisualBar and GPX.VisualBar.SaveLayoutProfile then
                    GPX.VisualBar:SaveLayoutProfile(name)
                    UI:Refresh()
                end
            end)
        end
        if frame.profileButtons.deleteProfile then
            frame.profileButtons.deleteProfile:SetScript("OnClick", function()
                local name = UI.frame and UI.frame.profileNameBox and UI.frame.profileNameBox:GetText() or nil
                if GPX.VisualBar and GPX.VisualBar.DeleteLayoutProfile then
                    GPX.VisualBar:DeleteLayoutProfile(name)
                    UI:Refresh()
                end
            end)
        end
    end

    frame.barOptions = {}
    local optionSpecs = {
        { key = "toggleProgress", label = "XP/Rep Bar", x = 266, y = -202, width = 140, click = function() if GPX.VisualBar then GPX.VisualBar:Slash("progress") end UI:Refresh() end },
    }

    for _, spec in ipairs(optionSpecs) do
        local button = CreateFrame("Button", nil, actionPanel, "UIPanelButtonTemplate")
        button:SetWidth(spec.width or 104)
        button:SetHeight(30)
        button:SetPoint("TOPLEFT", actionPanel, "TOPLEFT", spec.x, spec.y or -202)
        button:SetText(spec.label)
        button:SetScript("OnClick", spec.click)
        frame.barOptions[spec.key] = button
        frame.navOrder[#frame.navOrder + 1] = button
    end

    frame.mappingButtons = {}
    local mappingFields = {
        { field = "jump", label = "Confirm / Jump" },
        { field = "menu", label = "Menu" },
        { field = "look", label = "Look" },
        { field = "mod1", label = "Mod 1" },
        { field = "mod2", label = "Mod 2" },
        { field = "mod3", label = "Mod 3" },
        { field = "action1", label = "Action 1" },
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
    keyCapture:SetScript("OnTabPressed", function()
        UI:HandleCapturedKey("TAB")
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
    footer:SetText("Tip: Turn Layout Edit on, then drag bars from their surrounding chrome and use Edit for precise size and spacing values. Turn Layout Edit off when finished.")

    self.frame = frame
    self.frame.statusText = statusText
    self.frame.bindingText = bindingText
    self.frame.inputHint = inputHint
    self.frame.utilityHint = utilityHint
    self.frame.keyCapture = keyCapture
    self.frame.setTab = setTab
    self.frame.profileNameBox = profileNameBox
    self.frame.currentProfileText = currentProfileText
    self.frame.navOrder[#self.frame.navOrder + 1] = tabGeneral
    self.frame.navOrder[#self.frame.navOrder + 1] = tabProfiles
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
                local hint = "Use Focus Bar or Open Spellbook to go deeper."
                if baseText and baseText ~= "" then
                    return hint .. "   " .. baseText
                end
                return hint
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
    local controllerCfg = GPX:GetControllerConfig()
    if self.frame.controllerEnable then
        self.frame.controllerEnable:SetText(controllerEnabled and "Controller: Enabled" or "Controller: Disabled - Click to Enable")
    end
    if self.frame.mouseLookMode then
        if controllerEnabled then
            local modeText = "Move"
            if controllerCfg.mouseLookMode == "platformer" then
                modeText = "On"
            elseif controllerCfg.mouseLookMode == "off" then
                modeText = "Off"
            end
            self.frame.mouseLookMode:SetText("Mouselook: " .. modeText)
            self.frame.mouseLookMode:Show()
        else
            self.frame.mouseLookMode:Hide()
        end
    end

    if self.frame.styleButtons then
        local styleId = setup and (setup.deviceId or setup.inputStyle) or "keyboard"
        for _, button in ipairs(self.frame.styleButtons) do
            if controllerEnabled then
                local isSelected = button.styleId == styleId
                button:SetText(button.baseLabel .. (isSelected and " *" or ""))
                button:Enable()
                button:SetAlpha(1.0)
                button:Show()
            else
                button:Hide()
            end
        end
    end

    if self.frame.utilityHint then
        if controllerEnabled then
            self.frame.utilityHint:SetText("Choose your controller label style below. AntiMicroX maps physical buttons to these keys.")
        else
            self.frame.utilityHint:SetText("Controller integration is disabled. Enable above to access controller label and mapping options.")
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
    end
end

function UI:RefreshProfilePanel()
    if not self.frame then
        return
    end

    local visualBar = GPX.VisualBar
    if not self.frame.profilePanel or not visualBar then
        return
    end

    local activeName = visualBar.GetLayoutProfileName and visualBar:GetLayoutProfileName() or "default"
    local names = visualBar.GetLayoutProfileNames and visualBar:GetLayoutProfileNames() or {}
    if self.frame.currentProfileText then
        self.frame.currentProfileText:SetText("Active Layout Profile: " .. tostring(activeName) .. "   Available: " .. table.concat(names, ", "))
    end
    if self.frame.profileNameBox and (not self.captureField) then
        if self.frame.profileNameBox:GetText() == nil or self.frame.profileNameBox:GetText() == "" then
            self.frame.profileNameBox:SetText(activeName)
        end
    end
    if self.frame.profileButtons then
        local hasName = self.frame.profileNameBox and self.frame.profileNameBox:GetText() and self.frame.profileNameBox:GetText() ~= ""
        if self.frame.profileButtons.saveProfile then
            self.frame.profileButtons.saveProfile:Enable()
            self.frame.profileButtons.saveProfile:SetText("Save")
        end
        if self.frame.profileButtons.loadProfile then
            self.frame.profileButtons.loadProfile:Enable()
        end
        if self.frame.profileButtons.newProfile then
            self.frame.profileButtons.newProfile:SetEnabled(hasName)
        end
        if self.frame.profileButtons.deleteProfile then
            self.frame.profileButtons.deleteProfile:SetEnabled(hasName and self.frame.profileNameBox:GetText() ~= "default")
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

function UI:GetActiveMappingFields()
    local profile = GPX:GetProfile()
    local setup = profile and profile.setup or nil
    local controllerEnabled = GPX:IsControllerEnabled()
    local fields = {}

    if controllerEnabled then
        fields[#fields + 1] = { field = "mod1", label = "Mod 1" }
        fields[#fields + 1] = { field = "mod2", label = "Mod 2" }
        fields[#fields + 1] = { field = "mod3", label = "Mod 3" }

        local actionCount = GPX:GetConfiguredActionButtonCount(setup)
        local labels = GPX:GetCombatSlotLabels(setup and setup.deviceId)
        for slotIndex = 1, actionCount do
            fields[#fields + 1] = {
                field = "action" .. slotIndex,
                label = labels[slotIndex] or ("Action " .. slotIndex),
            }
        end

        return fields
    end

    fields[#fields + 1] = { field = "mod1", label = "Mod 1" }
    fields[#fields + 1] = { field = "mod2", label = "Mod 2" }
    fields[#fields + 1] = { field = "mod3", label = "Mod 3" }

    for slotIndex = 1, 12 do
        fields[#fields + 1] = {
            field = "action" .. slotIndex,
            label = "Action " .. slotIndex,
        }
    end

    return fields
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
    elseif field == "look" then
        return setup.lookKey or "--"
    elseif field == "mod1" then
        return (setup.modifiers and setup.modifiers[1]) or "--"
    elseif field == "mod2" then
        return (setup.modifiers and setup.modifiers[2]) or "--"
    elseif field == "mod3" then
        return (setup.modifiers and setup.modifiers[3]) or "--"
    end

    local actionSlot = getActionSlotForField(field)
    if actionSlot and actionSlot >= 1 and actionSlot <= 12 then
        return GPX:GetSetupActionKey(setup, actionSlot) or "--"
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
    elseif field == "look" then
        setup.lookKey = value
    elseif field == "mod1" then
        setup.modifiers[1] = value
    elseif field == "mod2" then
        setup.modifiers[2] = value
    elseif field == "mod3" then
        setup.modifiers[3] = value
    else
        local actionSlot = getActionSlotForField(field)
        if actionSlot and actionSlot >= 1 and actionSlot <= 12 then
            if GPX:IsControllerEnabled() then
                setup.actionKeyBaseSlot = 1
                setup.actionButtonCount = math.max(9, GPX:GetConfiguredActionButtonCount(setup), actionSlot)
            elseif not setup.actionKeyBaseSlot or setup.actionKeyBaseSlot < 2 then
                setup.actionKeyBaseSlot = 2
                setup.actionButtonCount = 12
            end
            GPX:SetSetupActionKey(setup, actionSlot, value)
        end
    end

    local ok, err = GPX:ApplySetupFromProfile(profile, { deferBindings = true })
    if ok then
        self:ScheduleBindingRefresh()
    else
        GPX:Print(err or "Failed to update mapping.")
    end
end

function UI:StartInputCapture(field)
    if not self.frame or not self.frame.keyCapture then
        return
    end

    self.captureField = field
    self.frame.inputHint:SetText("Capturing " .. field .. "... press a key now (ESC cancels)")
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
        self.frame.inputHint:SetText("Click a mapping button, then press a key to update labels and optional session overrides.")
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

    local activeFields = self:GetActiveMappingFields()
    local used = {}

    for index, entry in ipairs(activeFields) do
        local button = self.frame.mappingButtons[entry.field]
        if button then
            local col = (index - 1) % 3
            local row = math.floor((index - 1) / 3)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", self.frame.inputHint:GetParent(), "TOPLEFT", 14 + (col * 164), -40 - (row * 24))
            button:SetText(entry.label .. ": " .. self:GetMappingValue(entry.field))
            button:Enable()
            button:SetAlpha(1.0)
            button:Show()
            used[entry.field] = true
        end
    end

    for field, button in pairs(self.frame.mappingButtons) do
        if not used[field] then
            button:Hide()
        end
    end
end

function UI:BuildBindingSummary()
    local profile = GPX:GetProfile()
    local setup = profile and profile.setup or nil
    if not profile or not profile.bindings or not setup then
        return "No mapping profile yet. Init is optional; keyboard slot routing still works with defaults."
    end

    local style = GPX:GetInputStyle(setup.deviceId)
    local lines = {}

    if GPX:IsControllerEnabled() then
        if setup.jumpKey and setup.jumpKey ~= "" then
            lines[#lines + 1] = "Confirm / Jump  " .. setup.jumpKey
        end
        if setup.lookKey and setup.lookKey ~= "" then
            lines[#lines + 1] = "Hold Look  " .. setup.lookKey .. " -> CAMERAORSELECTORMOVE"
        end
    elseif setup.jumpKey and setup.jumpKey ~= "" then
        lines[#lines + 1] = "Action 1 (Base)  " .. setup.jumpKey .. " -> ACTIONBUTTON1"
    end

    local firstActionSlot = GPX:GetActionKeyBaseSlot(setup)
    local lastActionSlot = GPX:GetConfiguredActionButtonCount(setup)
    for slotIndex = firstActionSlot, lastActionSlot do
        local key = GPX:GetSetupActionKey(setup, slotIndex) or "--"
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

    if GPX:IsControllerEnabled() and setup.jumpKey and setup.jumpKey ~= "" then
        local jumpKey = setup.jumpKey
        local mods = setup.modifiers or {}
        local m1 = mods[1] or "SHIFT"
        local m2 = mods[2] or "ALT"
        local m3 = mods[3] or "CTRL"
        lines[#lines + 1] = "Utility (machine-wide): " .. jumpKey .. "=JUMP"
        lines[#lines + 1] = "Utility (machine-wide): " .. m1 .. "-" .. jumpKey .. "=TOGGLEWORLDMAP"
        lines[#lines + 1] = "Utility (machine-wide): " .. m2 .. "-" .. jumpKey .. "=TOGGLECHARACTER0"
        lines[#lines + 1] = "Utility (machine-wide): " .. m3 .. "-" .. jumpKey .. "=TOGGLEBATTLEFIELD"
        lines[#lines + 1] = "Utility (machine-wide): " .. m1 .. "-" .. m2 .. "-" .. jumpKey .. "=TOGGLESOCIAL"
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
    local layoutLockState = GPX.db and GPX.db.ui and GPX.db.ui.visualBar and GPX.db.ui.visualBar.locked and "Locked" or "Unlocked"
    local buttonLockState = GPX.db and GPX.db.ui and GPX.db.ui.visualBar and GPX.db.ui.visualBar.buttonLocked ~= false and "Locked" or "Unlocked"
    local minimap = GPX.db and GPX.db.ui and GPX.db.ui.minimapButton and GPX.db.ui.minimapButton.enabled and "Shown" or "Hidden"
    local controllerMode = GPX:IsControllerEnabled() and "Enabled" or "Disabled"
    local controllerCfg = GPX:GetControllerConfig()
    local mouseLookMode = "Move"
    if controllerCfg.mouseLookMode == "platformer" then
        mouseLookMode = "On"
    elseif controllerCfg.mouseLookMode == "off" then
        mouseLookMode = "Off"
    end
    local bagsCfg = GPX.db and GPX.db.ui and GPX.db.ui.actionButtons
    local wowxBags = (bagsCfg and bagsCfg.enabled ~= false and bagsCfg.showBags ~= false) and "On" or "Off"
    local lastError = GPX.db and GPX.db.lastError and GPX.db.lastError ~= "" and GPX.db.lastError or "None"

    return string.format(
        "Mode: %s\nProfile: %s\nInput Style: %s\nController Mode: %s\nMouselook Mode: %s\nVisual Bar: %s\nWoWX Bags: %s\nLayout Edit: %s\nButton Edit: %s\nMinimap Button: %s\nLast Error: %s",
        mode,
        profileName,
        inputStyle,
        controllerMode,
        mouseLookMode,
        visualBar,
        wowxBags,
        layoutLockState,
        buttonLockState,
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
    if self.frame.buttons and self.frame.buttons.buttonEdit and GPX.db and GPX.db.ui and GPX.db.ui.visualBar then
        self.frame.buttons.buttonEdit:SetText((GPX.db.ui.visualBar.buttonLocked ~= false) and "Button Edit: Off" or "Button Edit: On")
    end
    if self.frame.buttons and self.frame.buttons.toggleBags and GPX.db and GPX.db.ui and GPX.db.ui.actionButtons then
        local cfg = GPX.db.ui.actionButtons
        self.frame.buttons.toggleBags:SetText((cfg.enabled ~= false and cfg.showBags ~= false) and "WoWX Bags: On" or "WoWX Bags: Off")
    end
    if not self.captureField and self.frame.inputHint then
        if GPX:IsControllerEnabled() then
            self.frame.inputHint:SetText("Controller mode: capture keys to sync displayed labels and optional overrides.")
        else
            self.frame.inputHint:SetText("Action 1-12 and Mod 1-3 keys shown below. Caution: changing these also updates your main action bar bindings in-game.")
        end
    end
    self:RefreshUtilityButtons()
    self:RefreshProfilePanel()
    self:RefreshMappingButtons()
end

function UI:Open()
    self:CreateFrame()
    self:Refresh()
    self.frame:Show()
    self.frame:Raise()
    if GPX.UIMode then
        GPX.UIMode:Enter("settings")
    end
end
