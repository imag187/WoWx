if not GamePadX then return end

local GPX = GamePadX
local UI = {}

local function SetFrameShown(frame, shown)
    if shown then
        frame:Show()
    else
        frame:Hide()
    end
end

local function SetFrameEnabled(frame, enabled)
    if enabled then
        frame:Enable()
    else
        frame:Disable()
    end
end

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

local function trimText(value)
    local text = tostring(value or "")
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function toNumberOrNil(value)
    local text = trimText(value)
    if text == "" then
        return nil
    end
    return tonumber(text)
end

local function getAuraStackByID(unit, auraID, filter)
    local id = tonumber(auraID)
    if not UnitAura or not id then
        return 0, nil
    end

    local unitToken = unit or "player"
    local function scan(oneFilter)
        for index = 1, 40 do
            local name, _, icon, count, _, _, _, _, _, _, spellID = UnitAura(unitToken, index, oneFilter)
            if not name then
                break
            end
            if tonumber(spellID) == id then
                local stacks = tonumber(count) or 0
                if stacks < 1 then
                    stacks = 1
                end
                return stacks, icon
            end
        end
        return 0, nil
    end

    local auraFilter = trimText(filter):upper()
    if auraFilter == "HARMFUL_OR_HELPFUL" then
        local helpfulCount, helpfulIcon = scan("HELPFUL")
        local harmfulCount, harmfulIcon = scan("HARMFUL")
        if harmfulCount > helpfulCount then
            return harmfulCount, harmfulIcon
        end
        return helpfulCount, helpfulIcon
    end

    local mode = auraFilter == "HARMFUL" and "HARMFUL" or "HELPFUL"
    return scan(mode)
end

local systemSpecs = {
    { id = "core", label = "Core Runtime", hint = "Required for all WoWX behavior.", locked = true },
    { id = "ui", label = "Control Center UI", hint = "Settings and navigation surfaces.", locked = true },
    { id = "transport", label = "Action Transport", hint = "Click/proxy action execution layer.", locked = true },
    { id = "gamepad", label = "Gamepad Input", hint = "Controller mappings and mouselook tools." },
    { id = "keyboard", label = "Keyboard Input", hint = "Keyboard-focused mapping surfaces." },
    { id = "bags", label = "Bags System", hint = "WoWX bag action button and bag window." },
    { id = "spellgrid", label = "Spell Grid", hint = "Gridbook and spell-ring assignment surfaces." },
    { id = "cues", label = "Combat Cues", hint = "Dispel prompts and unit frame cue overlays." },
    { id = "unitframes", label = "Unit Frames", hint = "WoWX-owned unit frame system foundation." },
}

function UI:GetSystemSpecs()
    return systemSpecs
end

function UI:ApplySystemToggle(systemId, enabled)
    if not GPX or not GPX.SetSystemEnabled then
        return
    end

    local ok = GPX:SetSystemEnabled(systemId, enabled)
    if not ok then
        GPX:Print("Unable to apply system toggle: " .. tostring(systemId))
        return
    end

    if systemId == "core" or systemId == "ui" or systemId == "transport" then
        GPX:Print("System setting saved for " .. tostring(systemId) .. ". Reload recommended for full effect.")
    else
        GPX:Print("System " .. tostring(systemId) .. ": " .. (enabled and "enabled" or "disabled"))
    end

    self:Refresh()
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
    tabProfiles:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -424, -14)
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

    local tabClasses = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tabClasses:SetWidth(92)
    tabClasses:SetHeight(22)
    tabClasses:SetPoint("LEFT", tabGeneral, "RIGHT", 8, 0)
    tabClasses:SetText("Classes")
    tabClasses:SetScript("OnClick", function()
        if setTab then
            setTab("classes")
        end
    end)

    local tabController = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tabController:SetWidth(92)
    tabController:SetHeight(22)
    tabController:SetPoint("LEFT", tabClasses, "RIGHT", 8, 0)
    tabController:SetText("Keybinds")
    tabController:SetScript("OnClick", function()
        if setTab then
            setTab("controller")
        end
    end)

    frame.tabProfiles = tabProfiles
    frame.tabGeneral = tabGeneral
    frame.tabClasses = tabClasses
    frame.tabController = tabController
    frame.navOrder = {}

    local systemsPanel = CreateFrame("Frame", nil, frame)
    systemsPanel:SetWidth(214)
    systemsPanel:SetHeight(540)
    systemsPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 542, -76)
    createBackdrop(systemsPanel, 0.18, 0.3, 0.5, 0.8)
    systemsPanel:SetBackdropColor(0.06, 0.08, 0.12, 0.92)

    local systemsTitle = systemsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    systemsTitle:SetPoint("TOPLEFT", systemsPanel, "TOPLEFT", 12, -12)
    systemsTitle:SetText("Systems")

    local systemsHint = systemsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    systemsHint:SetPoint("TOPLEFT", systemsTitle, "BOTTOMLEFT", 0, -6)
    systemsHint:SetWidth(190)
    systemsHint:SetJustifyH("LEFT")
    systemsHint:SetText("Enable or disable WoWX subsystems. Core/UI/Transport are required and locked.")

    local systemsStatus = systemsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    systemsStatus:SetPoint("BOTTOMLEFT", systemsPanel, "BOTTOMLEFT", 12, 12)
    systemsStatus:SetWidth(190)
    systemsStatus:SetJustifyH("LEFT")
    systemsStatus:SetText("")

    frame.systemsPanel = systemsPanel
    frame.systemsStatus = systemsStatus
    frame.systemCheckboxes = {}

    local systemTop = -78
    for index, spec in ipairs(self:GetSystemSpecs()) do
        local y = systemTop - ((index - 1) * 48)

        local check = CreateFrame("CheckButton", nil, systemsPanel, "UICheckButtonTemplate")
        check:SetWidth(22)
        check:SetHeight(22)
        check:SetPoint("TOPLEFT", systemsPanel, "TOPLEFT", 10, y)
        check.systemId = spec.id
        check.locked = spec.locked == true

        local label = systemsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", check, "RIGHT", 6, 0)
        label:SetText(spec.label)
        check.label = label

        local hint = systemsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
        hint:SetWidth(178)
        hint:SetJustifyH("LEFT")
        hint:SetText(spec.hint or "")
        check.hint = hint

        check:SetScript("OnClick", function(btn)
            UI:ApplySystemToggle(btn.systemId, btn:GetChecked() == 1)
        end)

        frame.systemCheckboxes[spec.id] = check
        frame.navOrder[#frame.navOrder + 1] = check
    end

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
    profilePanel:SetHeight(250)
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
    profileHint:SetText("Layout profiles save sizing/placement. Class profile selection is per character and can be managed below.")

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

    local profileClassText = profilePanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    profileClassText:SetPoint("TOPLEFT", currentProfileText, "BOTTOMLEFT", 0, -10)
    profileClassText:SetWidth(480)
    profileClassText:SetJustifyH("LEFT")

    local profileClassPrev = CreateFrame("Button", nil, profilePanel, "UIPanelButtonTemplate")
    profileClassPrev:SetWidth(64)
    profileClassPrev:SetHeight(22)
    profileClassPrev:SetPoint("TOPLEFT", profileClassText, "BOTTOMLEFT", 0, -6)
    profileClassPrev:SetText("< Prev")

    local profileClassNext = CreateFrame("Button", nil, profilePanel, "UIPanelButtonTemplate")
    profileClassNext:SetWidth(64)
    profileClassNext:SetHeight(22)
    profileClassNext:SetPoint("LEFT", profileClassPrev, "RIGHT", 8, 0)
    profileClassNext:SetText("Next >")

    local profileClassUsePlayer = CreateFrame("Button", nil, profilePanel, "UIPanelButtonTemplate")
    profileClassUsePlayer:SetWidth(96)
    profileClassUsePlayer:SetHeight(22)
    profileClassUsePlayer:SetPoint("LEFT", profileClassNext, "RIGHT", 8, 0)
    profileClassUsePlayer:SetText("Use Player")

    local profileClassOpenClasses = CreateFrame("Button", nil, profilePanel, "UIPanelButtonTemplate")
    profileClassOpenClasses:SetWidth(120)
    profileClassOpenClasses:SetHeight(22)
    profileClassOpenClasses:SetPoint("LEFT", profileClassUsePlayer, "RIGHT", 8, 0)
    profileClassOpenClasses:SetText("Open Classes")

    local profileButtons = {
        { key = "saveProfile", label = "Save", x = 14, y = -186, width = 92 },
        { key = "loadProfile", label = "Load", x = 114, y = -186, width = 92 },
        { key = "newProfile", label = "New From Current", x = 214, y = -186, width = 132 },
        { key = "deleteProfile", label = "Delete", x = 354, y = -186, width = 92 },
    }

    frame.profilePanel = profilePanel
    frame.profileNameBox = profileNameBox
    frame.currentProfileText = currentProfileText
    frame.profileClassText = profileClassText
    frame.profileClassPrev = profileClassPrev
    frame.profileClassNext = profileClassNext
    frame.profileClassUsePlayer = profileClassUsePlayer
    frame.profileClassOpenClasses = profileClassOpenClasses
    frame.profileButtons = {}

    local classesPanel = CreateFrame("Frame", nil, frame)
    classesPanel:SetWidth(510)
    classesPanel:SetHeight(650)
    classesPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -76)
    createBackdrop(classesPanel, 0.18, 0.3, 0.5, 0.8)
    classesPanel:SetBackdropColor(0.06, 0.08, 0.12, 0.92)

    local classesTitle = classesPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    classesTitle:SetPoint("TOPLEFT", classesPanel, "TOPLEFT", 14, -12)
    classesTitle:SetText("Classes and Resources")

    local classesHint = classesPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    classesHint:SetPoint("TOPLEFT", classesTitle, "BOTTOMLEFT", 0, -6)
    classesHint:SetWidth(480)
    classesHint:SetJustifyH("LEFT")
    classesHint:SetText("Manage class profile naming, resources, reactive spells, and SpellDB sharing. CoA resource IDs are seeded from local XPerl definitions.")

    local classesStateText = classesPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    classesStateText:SetPoint("TOPLEFT", classesHint, "BOTTOMLEFT", 0, -10)
    classesStateText:SetWidth(480)
    classesStateText:SetJustifyH("LEFT")

    local classNameLabel = classesPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    classNameLabel:SetPoint("TOPLEFT", classesStateText, "BOTTOMLEFT", 0, -14)
    classNameLabel:SetText("Display Name")

    local classNameBox = CreateFrame("EditBox", nil, classesPanel, "InputBoxTemplate")
    classNameBox:SetWidth(172)
    classNameBox:SetHeight(20)
    classNameBox:SetPoint("LEFT", classNameLabel, "RIGHT", 10, 0)
    classNameBox:SetAutoFocus(false)
    classNameBox:SetTextColor(1.0, 0.92, 0.58)

    local classSaveName = CreateFrame("Button", nil, classesPanel, "UIPanelButtonTemplate")
    classSaveName:SetWidth(92)
    classSaveName:SetHeight(22)
    classSaveName:SetPoint("LEFT", classNameBox, "RIGHT", 10, 0)
    classSaveName:SetText("Save Name")

    local classPrevProfile = CreateFrame("Button", nil, classesPanel, "UIPanelButtonTemplate")
    classPrevProfile:SetWidth(64)
    classPrevProfile:SetHeight(22)
    classPrevProfile:SetPoint("TOPLEFT", classNameLabel, "BOTTOMLEFT", 0, -10)
    classPrevProfile:SetText("< Prev")

    local classNextProfile = CreateFrame("Button", nil, classesPanel, "UIPanelButtonTemplate")
    classNextProfile:SetWidth(64)
    classNextProfile:SetHeight(22)
    classNextProfile:SetPoint("LEFT", classPrevProfile, "RIGHT", 8, 0)
    classNextProfile:SetText("Next >")

    local classProfileLabel = classesPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    classProfileLabel:SetPoint("LEFT", classNextProfile, "RIGHT", 12, 0)
    classProfileLabel:SetWidth(320)
    classProfileLabel:SetJustifyH("LEFT")

    local classUsePlayerButton = CreateFrame("Button", nil, classesPanel, "UIPanelButtonTemplate")
    classUsePlayerButton:SetWidth(96)
    classUsePlayerButton:SetHeight(22)
    classUsePlayerButton:SetPoint("TOPLEFT", classPrevProfile, "BOTTOMLEFT", 0, -8)
    classUsePlayerButton:SetText("Use Player")

    local classNewTokenBox = CreateFrame("EditBox", nil, classesPanel, "InputBoxTemplate")
    classNewTokenBox:SetWidth(120)
    classNewTokenBox:SetHeight(20)
    classNewTokenBox:SetPoint("LEFT", classUsePlayerButton, "RIGHT", 8, 0)
    classNewTokenBox:SetAutoFocus(false)
    classNewTokenBox:SetTextColor(1.0, 0.92, 0.58)
    classNewTokenBox:SetText("")

    local classAddButton = CreateFrame("Button", nil, classesPanel, "UIPanelButtonTemplate")
    classAddButton:SetWidth(88)
    classAddButton:SetHeight(22)
    classAddButton:SetPoint("LEFT", classNewTokenBox, "RIGHT", 8, 0)
    classAddButton:SetText("Add Class")

    local classAddHint = classesPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    classAddHint:SetPoint("LEFT", classAddButton, "RIGHT", 8, 0)
    classAddHint:SetWidth(160)
    classAddHint:SetJustifyH("LEFT")
    classAddHint:SetText("Token")

    local resourcesHeader = classesPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    resourcesHeader:SetPoint("TOPLEFT", classUsePlayerButton, "BOTTOMLEFT", 0, -14)
    resourcesHeader:SetText("Resources")

    local resourcesText = classesPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    resourcesText:SetPoint("TOPLEFT", resourcesHeader, "BOTTOMLEFT", 0, -6)
    resourcesText:SetWidth(236)
    resourcesText:SetJustifyH("LEFT")

    local resourceEditorBorder = CreateFrame("Frame", nil, classesPanel)
    resourceEditorBorder:SetPoint("TOPLEFT", resourcesHeader, "TOPLEFT", 244, 0)
    resourceEditorBorder:SetWidth(236)
    resourceEditorBorder:SetHeight(148)
    createBackdrop(resourceEditorBorder, 0.18, 0.3, 0.5, 0.8)
    resourceEditorBorder:SetBackdropColor(0.05, 0.08, 0.14, 0.9)

    local resourceEditorTitle = resourceEditorBorder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resourceEditorTitle:SetPoint("TOPLEFT", resourceEditorBorder, "TOPLEFT", 8, -8)
    resourceEditorTitle:SetText("Resource Inspector")

    local resourceIcon = resourceEditorBorder:CreateTexture(nil, "ARTWORK")
    resourceIcon:SetWidth(20)
    resourceIcon:SetHeight(20)
    resourceIcon:SetPoint("TOPLEFT", resourceEditorTitle, "BOTTOMLEFT", 0, -4)
    resourceIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    resourceIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local resourcePickText = resourceEditorBorder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    resourcePickText:SetPoint("LEFT", resourceIcon, "RIGHT", 6, 0)
    resourcePickText:SetWidth(132)
    resourcePickText:SetJustifyH("LEFT")

    local resourcePrevButton = CreateFrame("Button", nil, resourceEditorBorder, "UIPanelButtonTemplate")
    resourcePrevButton:SetWidth(28)
    resourcePrevButton:SetHeight(18)
    resourcePrevButton:SetPoint("LEFT", resourcePickText, "RIGHT", 2, 0)
    resourcePrevButton:SetText("<")

    local resourceNextButton = CreateFrame("Button", nil, resourceEditorBorder, "UIPanelButtonTemplate")
    resourceNextButton:SetWidth(28)
    resourceNextButton:SetHeight(18)
    resourceNextButton:SetPoint("LEFT", resourcePrevButton, "RIGHT", 2, 0)
    resourceNextButton:SetText(">")

    local resourceIdBox = CreateFrame("EditBox", nil, resourceEditorBorder, "InputBoxTemplate")
    resourceIdBox:SetWidth(108)
    resourceIdBox:SetHeight(18)
    resourceIdBox:SetPoint("TOPLEFT", resourceIcon, "BOTTOMLEFT", 0, -6)
    resourceIdBox:SetAutoFocus(false)

    local resourceAuraBox = CreateFrame("EditBox", nil, resourceEditorBorder, "InputBoxTemplate")
    resourceAuraBox:SetWidth(58)
    resourceAuraBox:SetHeight(18)
    resourceAuraBox:SetPoint("LEFT", resourceIdBox, "RIGHT", 6, 0)
    resourceAuraBox:SetAutoFocus(false)

    local resourceMaxBox = CreateFrame("EditBox", nil, resourceEditorBorder, "InputBoxTemplate")
    resourceMaxBox:SetWidth(38)
    resourceMaxBox:SetHeight(18)
    resourceMaxBox:SetPoint("LEFT", resourceAuraBox, "RIGHT", 6, 0)
    resourceMaxBox:SetAutoFocus(false)

    local resourceFragmentBox = CreateFrame("EditBox", nil, resourceEditorBorder, "InputBoxTemplate")
    resourceFragmentBox:SetWidth(58)
    resourceFragmentBox:SetHeight(18)
    resourceFragmentBox:SetPoint("TOPLEFT", resourceIdBox, "BOTTOMLEFT", 0, -6)
    resourceFragmentBox:SetAutoFocus(false)

    local resourceInfusionBox = CreateFrame("EditBox", nil, resourceEditorBorder, "InputBoxTemplate")
    resourceInfusionBox:SetWidth(58)
    resourceInfusionBox:SetHeight(18)
    resourceInfusionBox:SetPoint("LEFT", resourceFragmentBox, "RIGHT", 6, 0)
    resourceInfusionBox:SetAutoFocus(false)

    local resourceDivideBox = CreateFrame("EditBox", nil, resourceEditorBorder, "InputBoxTemplate")
    resourceDivideBox:SetWidth(38)
    resourceDivideBox:SetHeight(18)
    resourceDivideBox:SetPoint("LEFT", resourceInfusionBox, "RIGHT", 6, 0)
    resourceDivideBox:SetAutoFocus(false)

    local resourceUseCountCheck = CreateFrame("CheckButton", nil, resourceEditorBorder, "UICheckButtonTemplate")
    resourceUseCountCheck:SetPoint("TOPLEFT", resourceFragmentBox, "BOTTOMLEFT", -2, -4)
    if resourceUseCountCheck.text then
        resourceUseCountCheck.text:SetText("Count")
    end

    local resourcePipCheck = CreateFrame("CheckButton", nil, resourceEditorBorder, "UICheckButtonTemplate")
    resourcePipCheck:SetPoint("LEFT", resourceUseCountCheck, "RIGHT", 54, 0)
    if resourcePipCheck.text then
        resourcePipCheck.text:SetText("Pips")
    end

    local resourceFragmentsCheck = CreateFrame("CheckButton", nil, resourceEditorBorder, "UICheckButtonTemplate")
    resourceFragmentsCheck:SetPoint("LEFT", resourcePipCheck, "RIGHT", 52, 0)
    if resourceFragmentsCheck.text then
        resourceFragmentsCheck.text:SetText("Fragments")
    end

    local resourceSaveButton = CreateFrame("Button", nil, resourceEditorBorder, "UIPanelButtonTemplate")
    resourceSaveButton:SetWidth(64)
    resourceSaveButton:SetHeight(18)
    resourceSaveButton:SetPoint("TOPRIGHT", resourceEditorBorder, "TOPRIGHT", -8, -8)
    resourceSaveButton:SetText("Save")

    local resourceEditorLegend = resourceEditorBorder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    resourceEditorLegend:SetPoint("TOPLEFT", resourceUseCountCheck, "BOTTOMLEFT", 2, -2)
    resourceEditorLegend:SetWidth(220)
    resourceEditorLegend:SetJustifyH("LEFT")
    resourceEditorLegend:SetText("ID | Aura | Max | Frag | Infuse | /")

    local resourcePreviewText = classesPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    resourcePreviewText:SetPoint("TOPLEFT", resourcesText, "BOTTOMLEFT", 0, -40)
    resourcePreviewText:SetWidth(480)
    resourcePreviewText:SetJustifyH("LEFT")

    local addManaButton = CreateFrame("Button", nil, classesPanel, "UIPanelButtonTemplate")
    addManaButton:SetWidth(74)
    addManaButton:SetHeight(22)
    addManaButton:SetPoint("TOPLEFT", resourcesText, "BOTTOMLEFT", 0, -8)
    addManaButton:SetText("+ Mana")

    local addRageButton = CreateFrame("Button", nil, classesPanel, "UIPanelButtonTemplate")
    addRageButton:SetWidth(74)
    addRageButton:SetHeight(22)
    addRageButton:SetPoint("LEFT", addManaButton, "RIGHT", 6, 0)
    addRageButton:SetText("+ Rage")

    local addEnergyButton = CreateFrame("Button", nil, classesPanel, "UIPanelButtonTemplate")
    addEnergyButton:SetWidth(74)
    addEnergyButton:SetHeight(22)
    addEnergyButton:SetPoint("LEFT", addRageButton, "RIGHT", 6, 0)
    addEnergyButton:SetText("+ Energy")

    local addRunicButton = CreateFrame("Button", nil, classesPanel, "UIPanelButtonTemplate")
    addRunicButton:SetWidth(84)
    addRunicButton:SetHeight(22)
    addRunicButton:SetPoint("LEFT", addEnergyButton, "RIGHT", 6, 0)
    addRunicButton:SetText("+ Runic")

    local removeResourceButton = CreateFrame("Button", nil, classesPanel, "UIPanelButtonTemplate")
    removeResourceButton:SetWidth(110)
    removeResourceButton:SetHeight(22)
    removeResourceButton:SetPoint("LEFT", addRunicButton, "RIGHT", 6, 0)
    removeResourceButton:SetText("Remove Last")

    local reactivesHeader = classesPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    reactivesHeader:SetPoint("TOPLEFT", resourcePreviewText, "BOTTOMLEFT", 0, -16)
    reactivesHeader:SetText("Reactive Spells")

    local reactiveInput = CreateFrame("EditBox", nil, classesPanel, "InputBoxTemplate")
    reactiveInput:SetWidth(124)
    reactiveInput:SetHeight(20)
    reactiveInput:SetPoint("TOPLEFT", reactivesHeader, "BOTTOMLEFT", 0, -8)
    reactiveInput:SetAutoFocus(false)
    reactiveInput:SetTextColor(1.0, 0.92, 0.58)

    local reactiveAddButton = CreateFrame("Button", nil, classesPanel, "UIPanelButtonTemplate")
    reactiveAddButton:SetWidth(94)
    reactiveAddButton:SetHeight(22)
    reactiveAddButton:SetPoint("LEFT", reactiveInput, "RIGHT", 8, 0)
    reactiveAddButton:SetText("Add Reactive")

    local reactiveEditHint = classesPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    reactiveEditHint:SetPoint("LEFT", reactiveAddButton, "RIGHT", 10, 0)
    reactiveEditHint:SetWidth(250)
    reactiveEditHint:SetJustifyH("LEFT")
    reactiveEditHint:SetText("")

    local reactiveRows = {}
    for row = 1, 4 do
        local rowFrame = CreateFrame("Frame", nil, classesPanel)
        rowFrame:SetWidth(480)
        rowFrame:SetHeight(24)
        rowFrame:SetPoint("TOPLEFT", reactiveInput, "BOTTOMLEFT", 0, -8 - ((row - 1) * 26))

        local iconButton = CreateFrame("Button", nil, rowFrame)
        iconButton:SetWidth(20)
        iconButton:SetHeight(20)
        iconButton:SetPoint("LEFT", rowFrame, "LEFT", 0, 0)
        local icon = iconButton:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(iconButton)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        rowFrame.iconButton = iconButton
        rowFrame.icon = icon

        local spellText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        spellText:SetPoint("LEFT", iconButton, "RIGHT", 8, 0)
        spellText:SetWidth(250)
        spellText:SetJustifyH("LEFT")
        rowFrame.spellText = spellText

        local editButton = CreateFrame("Button", nil, rowFrame, "UIPanelButtonTemplate")
        editButton:SetWidth(54)
        editButton:SetHeight(20)
        editButton:SetPoint("LEFT", spellText, "RIGHT", 6, 0)
        editButton:SetText("Edit")
        rowFrame.editButton = editButton

        local deleteButton = CreateFrame("Button", nil, rowFrame, "UIPanelButtonTemplate")
        deleteButton:SetWidth(54)
        deleteButton:SetHeight(20)
        deleteButton:SetPoint("LEFT", editButton, "RIGHT", 6, 0)
        deleteButton:SetText("Delete")
        rowFrame.deleteButton = deleteButton

        reactiveRows[row] = rowFrame
    end

    local spellDBHeader = classesPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    spellDBHeader:SetPoint("TOPLEFT", reactiveRows[4], "BOTTOMLEFT", 0, -14)
    spellDBHeader:SetText("SpellDB Share")

    local spellDBHint = classesPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    spellDBHint:SetPoint("TOPLEFT", spellDBHeader, "BOTTOMLEFT", 0, -6)
    spellDBHint:SetWidth(480)
    spellDBHint:SetJustifyH("LEFT")
    spellDBHint:SetText("Use this box for copy/paste export/import in-game. Slash commands remain optional.")

    local spellDBExportButton = CreateFrame("Button", nil, classesPanel, "UIPanelButtonTemplate")
    spellDBExportButton:SetWidth(92)
    spellDBExportButton:SetHeight(22)
    spellDBExportButton:SetPoint("TOPLEFT", spellDBHint, "BOTTOMLEFT", 0, -8)
    spellDBExportButton:SetText("Export")

    local spellDBImportMergeButton = CreateFrame("Button", nil, classesPanel, "UIPanelButtonTemplate")
    spellDBImportMergeButton:SetWidth(110)
    spellDBImportMergeButton:SetHeight(22)
    spellDBImportMergeButton:SetPoint("LEFT", spellDBExportButton, "RIGHT", 6, 0)
    spellDBImportMergeButton:SetText("Import Merge")

    local spellDBImportReplaceButton = CreateFrame("Button", nil, classesPanel, "UIPanelButtonTemplate")
    spellDBImportReplaceButton:SetWidth(114)
    spellDBImportReplaceButton:SetHeight(22)
    spellDBImportReplaceButton:SetPoint("LEFT", spellDBImportMergeButton, "RIGHT", 6, 0)
    spellDBImportReplaceButton:SetText("Import Replace")

    local spellDBOutputButton = CreateFrame("Button", nil, classesPanel, "UIPanelButtonTemplate")
    spellDBOutputButton:SetWidth(66)
    spellDBOutputButton:SetHeight(22)
    spellDBOutputButton:SetPoint("LEFT", spellDBImportReplaceButton, "RIGHT", 6, 0)
    spellDBOutputButton:SetText("Output")

    local spellDBLoadButton = CreateFrame("Button", nil, classesPanel, "UIPanelButtonTemplate")
    spellDBLoadButton:SetWidth(76)
    spellDBLoadButton:SetHeight(22)
    spellDBLoadButton:SetPoint("LEFT", spellDBOutputButton, "RIGHT", 6, 0)
    spellDBLoadButton:SetText("Load Out")

    local spellDBStatus = classesPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    spellDBStatus:SetPoint("TOPLEFT", spellDBExportButton, "BOTTOMLEFT", 0, -4)
    spellDBStatus:SetWidth(480)
    spellDBStatus:SetJustifyH("LEFT")
    spellDBStatus:SetText("")

    local spellDBBorder = CreateFrame("Frame", nil, classesPanel)
    spellDBBorder:SetPoint("TOPLEFT", spellDBStatus, "BOTTOMLEFT", 0, -4)
    spellDBBorder:SetWidth(480)
    spellDBBorder:SetHeight(92)
    createBackdrop(spellDBBorder, 0.18, 0.3, 0.5, 0.8)
    spellDBBorder:SetBackdropColor(0.04, 0.06, 0.1, 0.92)

    local spellDBScroll = CreateFrame("ScrollFrame", nil, spellDBBorder, "UIPanelScrollFrameTemplate")
    spellDBScroll:SetPoint("TOPLEFT", spellDBBorder, "TOPLEFT", 8, -8)
    spellDBScroll:SetPoint("BOTTOMRIGHT", spellDBBorder, "BOTTOMRIGHT", -28, 8)

    local spellDBEdit = CreateFrame("EditBox", nil, spellDBScroll)
    spellDBEdit:SetMultiLine(true)
    spellDBEdit:SetAutoFocus(false)
    spellDBEdit:EnableMouse(true)
    spellDBEdit:SetFontObject(ChatFontNormal)
    spellDBEdit:SetWidth(440)
    spellDBEdit:SetTextInsets(4, 4, 4, 4)
    spellDBEdit:SetText("")
    spellDBEdit:SetScript("OnEscapePressed", function(selfEdit)
        selfEdit:ClearFocus()
    end)
    spellDBEdit:SetScript("OnTextChanged", function(selfEdit)
        local text = selfEdit:GetText() or ""
        local lineCount = 1
        for _ in string.gmatch(text, "\n") do
            lineCount = lineCount + 1
        end
        local _, fontHeight = selfEdit:GetFont()
        local rowHeight = tonumber(fontHeight) or 12
        selfEdit:SetHeight((lineCount * rowHeight) + 24)
    end)
    spellDBScroll:SetScrollChild(spellDBEdit)

    frame.classesPanel = classesPanel
    frame.classesStateText = classesStateText
    frame.classNameBox = classNameBox
    frame.classSaveName = classSaveName
    frame.classPrevProfile = classPrevProfile
    frame.classNextProfile = classNextProfile
    frame.classProfileLabel = classProfileLabel
    frame.classUsePlayerButton = classUsePlayerButton
    frame.classNewTokenBox = classNewTokenBox
    frame.classAddButton = classAddButton
    frame.classAddHint = classAddHint
    frame.resourcesText = resourcesText
    frame.resourceInspector = {
        icon = resourceIcon,
        pickText = resourcePickText,
        prev = resourcePrevButton,
        next = resourceNextButton,
        idBox = resourceIdBox,
        auraBox = resourceAuraBox,
        maxBox = resourceMaxBox,
        fragmentBox = resourceFragmentBox,
        infusionBox = resourceInfusionBox,
        divideBox = resourceDivideBox,
        useCountCheck = resourceUseCountCheck,
        pipCheck = resourcePipCheck,
        fragmentsCheck = resourceFragmentsCheck,
        saveButton = resourceSaveButton,
        previewText = resourcePreviewText,
    }
    frame.resourceButtons = {
        addMana = addManaButton,
        addRage = addRageButton,
        addEnergy = addEnergyButton,
        addRunic = addRunicButton,
        removeLast = removeResourceButton,
    }
    frame.reactiveInput = reactiveInput
    frame.reactiveAddButton = reactiveAddButton
    frame.reactiveEditHint = reactiveEditHint
    frame.reactiveRows = reactiveRows
    frame.spellDBShareButtons = {
        export = spellDBExportButton,
        importMerge = spellDBImportMergeButton,
        importReplace = spellDBImportReplaceButton,
        output = spellDBOutputButton,
        loadOutput = spellDBLoadButton,
    }
    frame.spellDBShareEdit = spellDBEdit
    frame.spellDBShareStatus = spellDBStatus

    for _, spec in ipairs(profileButtons) do
        local button = CreateFrame("Button", nil, profilePanel, "UIPanelButtonTemplate")
        button:SetWidth(spec.width)
        button:SetHeight(24)
        button:SetPoint("TOPLEFT", profilePanel, "TOPLEFT", spec.x, spec.y)
        button:SetText(spec.label)
        frame.profileButtons[spec.key] = button
    end

    local tabHeights = {
        general = 684,
        controller = 620,
        profiles = 520,
        classes = 780,
    }

    setTab = function(tab)
        frame.activeTab = tab
        local showGeneral = tab == "general"
        local showProfiles = tab == "profiles"
        local showClasses = tab == "classes"
        local showController = tab == "controller"

        if showGeneral then
            bindingPanel:ClearAllPoints()
            bindingPanel:SetPoint("TOPLEFT", actionPanel, "BOTTOMLEFT", 0, -16)
            profilePanel:ClearAllPoints()
            profilePanel:SetPoint("TOPLEFT", utilityPanel, "BOTTOMLEFT", 0, -14)
        elseif showController then
            bindingPanel:ClearAllPoints()
            bindingPanel:SetPoint("TOPLEFT", inputPanel, "BOTTOMLEFT", 0, -14)
            profilePanel:ClearAllPoints()
            profilePanel:SetPoint("TOPLEFT", utilityPanel, "BOTTOMLEFT", 0, -14)
        elseif showProfiles then
            profilePanel:ClearAllPoints()
            profilePanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -76)
            bindingPanel:ClearAllPoints()
            bindingPanel:SetPoint("TOPLEFT", actionPanel, "BOTTOMLEFT", 0, -16)
        elseif showClasses then
            bindingPanel:ClearAllPoints()
            bindingPanel:SetPoint("TOPLEFT", actionPanel, "BOTTOMLEFT", 0, -16)
        end

        frame:SetHeight(tabHeights[tab] or tabHeights.general)
        SetFrameShown(statusPanel, showGeneral)
        SetFrameShown(actionPanel, showGeneral)
        SetFrameShown(bindingPanel, showController)
        SetFrameShown(utilityPanel, showController)
        SetFrameShown(inputPanel, showController)
        SetFrameShown(profilePanel, showProfiles)
        SetFrameShown(classesPanel, showClasses)
        SetFrameShown(systemsPanel, true)
        if showClasses then
            UI:SyncSelectedClassProfileToPlayer(true)
        end
        if frame.tabProfiles and frame.tabGeneral and frame.tabClasses and frame.tabController then
            frame.tabProfiles:SetText(showProfiles and "Profiles *" or "Profiles")
            frame.tabGeneral:SetText(showGeneral and "General *" or "General")
            frame.tabClasses:SetText(showClasses and "Classes *" or "Classes")
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

    if frame.profileClassPrev then
        frame.profileClassPrev:SetScript("OnClick", function()
            UI:CycleSelectedClassProfile(-1)
            UI:RefreshProfilePanel()
        end)
        frame.navOrder[#frame.navOrder + 1] = frame.profileClassPrev
    end

    if frame.profileClassNext then
        frame.profileClassNext:SetScript("OnClick", function()
            UI:CycleSelectedClassProfile(1)
            UI:RefreshProfilePanel()
        end)
        frame.navOrder[#frame.navOrder + 1] = frame.profileClassNext
    end

    if frame.profileClassUsePlayer then
        frame.profileClassUsePlayer:SetScript("OnClick", function()
            UI:SyncSelectedClassProfileToPlayer(true)
            UI:RefreshProfilePanel()
        end)
        frame.navOrder[#frame.navOrder + 1] = frame.profileClassUsePlayer
    end

    if frame.profileClassOpenClasses then
        frame.profileClassOpenClasses:SetScript("OnClick", function()
            if setTab then
                setTab("classes")
            end
            UI:Refresh()
        end)
        frame.navOrder[#frame.navOrder + 1] = frame.profileClassOpenClasses
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

    if frame.classSaveName then
        frame.classSaveName:SetScript("OnClick", function()
            UI:SaveSelectedClassDisplayName()
        end)
        frame.navOrder[#frame.navOrder + 1] = frame.classSaveName
    end

    if frame.classPrevProfile then
        frame.classPrevProfile:SetScript("OnClick", function()
            UI:CycleSelectedClassProfile(-1)
        end)
        frame.navOrder[#frame.navOrder + 1] = frame.classPrevProfile
    end

    if frame.classNextProfile then
        frame.classNextProfile:SetScript("OnClick", function()
            UI:CycleSelectedClassProfile(1)
        end)
        frame.navOrder[#frame.navOrder + 1] = frame.classNextProfile
    end

    if frame.classUsePlayerButton then
        frame.classUsePlayerButton:SetScript("OnClick", function()
            UI:SyncSelectedClassProfileToPlayer(true)
        end)
        frame.navOrder[#frame.navOrder + 1] = frame.classUsePlayerButton
    end

    if frame.classAddButton and frame.classNewTokenBox then
        frame.classAddButton:SetScript("OnClick", function()
            UI:CreateClassProfileFromInput()
        end)
        frame.navOrder[#frame.navOrder + 1] = frame.classAddButton
    end

    if frame.resourceButtons then
        frame.resourceButtons.addMana:SetScript("OnClick", function()
            UI:AddCoreResourceToSelected("mana", "Mana", { r = 0.18, g = 0.48, b = 1.0 })
        end)
        frame.resourceButtons.addRage:SetScript("OnClick", function()
            UI:AddCoreResourceToSelected("rage", "Rage", { r = 0.88, g = 0.22, b = 0.18 })
        end)
        frame.resourceButtons.addEnergy:SetScript("OnClick", function()
            UI:AddCoreResourceToSelected("energy", "Energy", { r = 0.98, g = 0.86, b = 0.18 })
        end)
        frame.resourceButtons.addRunic:SetScript("OnClick", function()
            UI:AddCoreResourceToSelected("runic_power", "Runic Power", { r = 0.32, g = 0.9, b = 1.0 })
        end)
        frame.resourceButtons.removeLast:SetScript("OnClick", function()
            UI:RemoveLastResourceFromSelected()
        end)
        frame.navOrder[#frame.navOrder + 1] = frame.resourceButtons.addMana
        frame.navOrder[#frame.navOrder + 1] = frame.resourceButtons.addRage
        frame.navOrder[#frame.navOrder + 1] = frame.resourceButtons.addEnergy
        frame.navOrder[#frame.navOrder + 1] = frame.resourceButtons.addRunic
        frame.navOrder[#frame.navOrder + 1] = frame.resourceButtons.removeLast
    end

    if frame.resourceInspector then
        frame.resourceInspector.prev:SetScript("OnClick", function()
            UI:CycleSelectedResource(-1)
        end)
        frame.resourceInspector.next:SetScript("OnClick", function()
            UI:CycleSelectedResource(1)
        end)
        frame.resourceInspector.saveButton:SetScript("OnClick", function()
            UI:SaveSelectedResourceEdit()
        end)
        frame.navOrder[#frame.navOrder + 1] = frame.resourceInspector.prev
        frame.navOrder[#frame.navOrder + 1] = frame.resourceInspector.next
        frame.navOrder[#frame.navOrder + 1] = frame.resourceInspector.saveButton
    end

    if frame.reactiveAddButton then
        frame.reactiveAddButton:SetScript("OnClick", function()
            UI:CommitReactiveEdit()
        end)
        frame.navOrder[#frame.navOrder + 1] = frame.reactiveAddButton
    end

    if frame.reactiveRows then
        for index, row in ipairs(frame.reactiveRows) do
            row.editButton:SetScript("OnClick", function()
                UI:BeginReactiveEdit(index)
            end)
            row.deleteButton:SetScript("OnClick", function()
                UI:DeleteReactiveSpell(index)
            end)
            row.iconButton:SetScript("OnEnter", function()
                UI:ShowReactiveTooltip(index, row.iconButton)
            end)
            row.iconButton:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            frame.navOrder[#frame.navOrder + 1] = row.editButton
            frame.navOrder[#frame.navOrder + 1] = row.deleteButton
        end
    end

    if frame.spellDBShareButtons then
        frame.spellDBShareButtons.export:SetScript("OnClick", function()
            UI:ExportSpellDBToShareText()
        end)
        frame.spellDBShareButtons.importMerge:SetScript("OnClick", function()
            UI:ImportSpellDBFromShareText("merge")
        end)
        frame.spellDBShareButtons.importReplace:SetScript("OnClick", function()
            UI:ImportSpellDBFromShareText("replace")
        end)
        frame.spellDBShareButtons.output:SetScript("OnClick", function()
            UI:OpenSpellDBShareInOutputWindow()
        end)
        frame.spellDBShareButtons.loadOutput:SetScript("OnClick", function()
            UI:LoadSpellDBShareFromOutputWindow()
        end)

        frame.navOrder[#frame.navOrder + 1] = frame.spellDBShareButtons.export
        frame.navOrder[#frame.navOrder + 1] = frame.spellDBShareButtons.importMerge
        frame.navOrder[#frame.navOrder + 1] = frame.spellDBShareButtons.importReplace
        frame.navOrder[#frame.navOrder + 1] = frame.spellDBShareButtons.output
        frame.navOrder[#frame.navOrder + 1] = frame.spellDBShareButtons.loadOutput
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
    self.frame.navOrder[#self.frame.navOrder + 1] = tabClasses
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

function UI:RefreshSystemsPanel()
    if not self.frame or not self.frame.systemCheckboxes then
        return
    end

    local enabledCount = 0
    local totalCount = 0

    for _, spec in ipairs(self:GetSystemSpecs()) do
        local check = self.frame.systemCheckboxes[spec.id]
        if check then
            local enabled = GPX:IsSystemEnabled(spec.id)
            check:SetChecked(enabled and 1 or nil)

            totalCount = totalCount + 1
            if enabled then
                enabledCount = enabledCount + 1
            end

            if check.locked then
                check:Disable()
                check:SetAlpha(0.75)
                if check.label then
                    check.label:SetText(spec.label .. " (required)")
                end
            else
                check:Enable()
                check:SetAlpha(1.0)
                if check.label then
                    check.label:SetText(spec.label)
                end
            end
        end
    end

    if self.frame.systemsStatus then
        self.frame.systemsStatus:SetText("Enabled systems: " .. tostring(enabledCount) .. "/" .. tostring(totalCount))
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
    local activeProfile = visualBar.GetLayoutProfiles and visualBar:GetLayoutProfiles()[activeName] or nil
    local inputMode = activeProfile and activeProfile.inputMode or "unknown"
    if self.frame.currentProfileText then
        self.frame.currentProfileText:SetText("Active Layout Profile: " .. tostring(activeName) .. "   Mode: " .. tostring(inputMode) .. "   Available: " .. table.concat(names, ", "))
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
            SetFrameEnabled(self.frame.profileButtons.newProfile, hasName)
        end
        if self.frame.profileButtons.deleteProfile then
            SetFrameEnabled(self.frame.profileButtons.deleteProfile, hasName and self.frame.profileNameBox:GetText() ~= "default")
        end
    end

    local classToken = GPX:GetResolvedClassToken("player") or "UNKNOWN"
    local profileId = self:GetSelectedClassProfileId()
    local classProfile = self:GetSelectedClassProfile()
    if self.frame.profileClassText then
        local displayName = classProfile and (classProfile.displayName or profileId) or (profileId or "none")
        self.frame.profileClassText:SetText(
            "Class Profile: " .. tostring(displayName)
            .. " (ID: " .. tostring(profileId or "none") .. ")"
            .. "   Player Class: " .. tostring(classToken)
        )
    end

    local order = self:GetClassProfileOrder()
    local hasProfiles = #order > 0
    if self.frame.profileClassPrev then
        SetFrameEnabled(self.frame.profileClassPrev, hasProfiles and #order > 1)
    end
    if self.frame.profileClassNext then
        SetFrameEnabled(self.frame.profileClassNext, hasProfiles and #order > 1)
    end
    if self.frame.profileClassUsePlayer then
        SetFrameEnabled(self.frame.profileClassUsePlayer, classToken ~= "")
    end
end

function UI:GetClassProfileOrder()
    local profiles = GPX:GetClassProfiles() or {}
    local order = {}
    for token in pairs(profiles) do
        order[#order + 1] = token
    end
    table.sort(order)
    return order
end

function UI:GetSelectedClassProfileId()
    local active = self.selectedClassProfileId
    local profiles = GPX:GetClassProfiles() or {}
    if active and profiles[active] then
        return active
    end

    local fromDB = GPX:GetActiveClassProfileId()
    if fromDB and profiles[fromDB] then
        self.selectedClassProfileId = fromDB
        return fromDB
    end

    local classToken = GPX:GetResolvedClassToken("player")
    if classToken and profiles[classToken] then
        self.selectedClassProfileId = classToken
        GPX:SetActiveClassProfileId(classToken)
        return classToken
    end

    local order = self:GetClassProfileOrder()
    self.selectedClassProfileId = order[1]
    if self.selectedClassProfileId then
        GPX:SetActiveClassProfileId(self.selectedClassProfileId)
    end
    return self.selectedClassProfileId
end

function UI:GetSelectedClassProfile()
    local id = self:GetSelectedClassProfileId()
    local profiles = GPX:GetClassProfiles() or {}
    return id and profiles[id] or nil
end

function UI:SelectClassProfile(profileId)
    local key = string.upper(trimText(profileId))
    if key == "" then
        return false
    end

    local profiles = GPX:GetClassProfiles() or {}
    if not profiles[key] then
        return false
    end

    self.selectedClassProfileId = key
    GPX:SetActiveClassProfileId(key)
    self.selectedReactiveRow = nil
    self.selectedResourceIndex = nil
    self:RefreshClassesPanel()
    return true
end

function UI:SyncSelectedClassProfileToPlayer(shouldCreate)
    local classToken = string.upper(trimText(GPX:GetResolvedClassToken("player") or ""))
    if classToken == "" then
        return false
    end

    local profiles = GPX:GetClassProfiles() or {}
    if not profiles[classToken] and shouldCreate then
        GPX:EnsureClassProfile(classToken, classToken, classToken)
        profiles = GPX:GetClassProfiles() or {}
    end

    if not profiles[classToken] then
        return false
    end

    return self:SelectClassProfile(classToken)
end

function UI:CreateClassProfileFromInput()
    if not self.frame or not self.frame.classNewTokenBox then
        return
    end

    local token = string.upper(trimText(self.frame.classNewTokenBox:GetText()))
    if token == "" then
        GPX:Print("Enter a class token first, e.g. REAPER.")
        return
    end

    local ok = GPX:EnsureClassProfile(token, token, token)
    if not ok then
        GPX:Print("Unable to add class profile: " .. tostring(token))
        return
    end

    self.frame.classNewTokenBox:SetText("")
    self:SelectClassProfile(token)
    GPX:Print("Class profile ready: " .. tostring(token))
end

function UI:GetSelectedResourceIndex()
    local profile = self:GetSelectedClassProfile()
    local resources = profile and profile.resources or nil
    if type(resources) ~= "table" or #resources < 1 then
        self.selectedResourceIndex = nil
        return nil
    end

    local index = tonumber(self.selectedResourceIndex)
    if not index or index < 1 or index > #resources then
        index = 1
    end
    self.selectedResourceIndex = index
    return index
end

function UI:GetSelectedResource()
    local profile = self:GetSelectedClassProfile()
    local resources = profile and profile.resources or nil
    local index = self:GetSelectedResourceIndex()
    if not resources or not index then
        return nil, nil
    end
    return resources[index], index
end

function UI:CycleSelectedResource(delta)
    local profile = self:GetSelectedClassProfile()
    local resources = profile and profile.resources or nil
    if type(resources) ~= "table" or #resources < 1 then
        self.selectedResourceIndex = nil
        self:RefreshClassesPanel()
        return
    end

    local index = self:GetSelectedResourceIndex() or 1
    local nextIndex = index + (tonumber(delta) or 0)
    if nextIndex < 1 then
        nextIndex = #resources
    elseif nextIndex > #resources then
        nextIndex = 1
    end

    self.selectedResourceIndex = nextIndex
    self:RefreshClassesPanel()
end

function UI:BuildResourcePreviewLines(resource)
    if type(resource) ~= "table" then
        return {
            "Preview: no resource selected.",
        }, nil
    end

    local lines = {}
    local auraStacks, auraIcon = getAuraStackByID("player", resource.auraID, resource.filter)
    local maxValue = tonumber(resource.maxValue) or 0
    local useCount = resource.useCount == true
    local displayType = tostring(resource.displayType or "bar")

    lines[#lines + 1] = "Preview: " .. tostring(resource.label or resource.id or "Resource")
    lines[#lines + 1] = "Type=" .. displayType .. "  AuraID=" .. tostring(resource.auraID or "-") .. "  Stacks=" .. tostring(auraStacks)

    if displayType == "fragments" then
        local divideBy = tonumber(resource.fragmentDivideBy or resource.fragmentCount or 3) or 3
        if divideBy < 1 then
            divideBy = 1
        end
        local raw = useCount and auraStacks or math.min(1, auraStacks)
        local full = math.floor(raw / divideBy)
        local partial = raw % divideBy
        lines[#lines + 1] = "Souls=" .. tostring(full) .. "/" .. tostring(maxValue) .. "  Fragments=" .. tostring(partial) .. "/" .. tostring(divideBy)
        lines[#lines + 1] = "Math: totalFragments=" .. tostring(raw) .. " = (souls * " .. tostring(divideBy) .. ") + partial"
    elseif displayType == "pips" then
        local current = useCount and auraStacks or math.min(1, auraStacks)
        lines[#lines + 1] = "Pips=" .. tostring(current) .. "/" .. tostring(maxValue)
    else
        local current = useCount and auraStacks or math.min(1, auraStacks)
        lines[#lines + 1] = "BarValue=" .. tostring(current) .. "  Max=" .. tostring(maxValue)
    end

    if resource.fragmentSpellID then
        lines[#lines + 1] = "FragmentSpellID=" .. tostring(resource.fragmentSpellID)
    end
    if resource.infusionSpellID then
        lines[#lines + 1] = "InfusionSpellID=" .. tostring(resource.infusionSpellID)
    end

    return lines, auraIcon
end

function UI:SaveSelectedResourceEdit()
    local profileId = self:GetSelectedClassProfileId()
    local resource, index = self:GetSelectedResource()
    local inspector = self.frame and self.frame.resourceInspector or nil
    if not profileId or not resource or not index or not inspector then
        return
    end

    local nextValue = GPX.DeepCopy and GPX:DeepCopy(resource) or {}
    if not GPX.DeepCopy then
        for key, value in pairs(resource) do
            nextValue[key] = value
        end
    end

    local nextID = trimText(inspector.idBox:GetText())
    if nextID ~= "" then
        nextValue.id = nextID
    end

    local nextAuraID = toNumberOrNil(inspector.auraBox:GetText())
    nextValue.auraID = nextAuraID
    if nextAuraID then
        nextValue.sourceType = "aura"
    end

    local nextMax = toNumberOrNil(inspector.maxBox:GetText())
    nextValue.maxValue = nextMax
    nextValue.fragmentSpellID = toNumberOrNil(inspector.fragmentBox:GetText())
    nextValue.infusionSpellID = toNumberOrNil(inspector.infusionBox:GetText())
    nextValue.fragmentDivideBy = toNumberOrNil(inspector.divideBox:GetText())
    nextValue.useCount = inspector.useCountCheck:GetChecked() and true or false

    local fragmentsChecked = inspector.fragmentsCheck:GetChecked() and true or false
    local pipChecked = inspector.pipCheck:GetChecked() and true or false
    if fragmentsChecked then
        nextValue.displayType = "fragments"
    elseif pipChecked then
        nextValue.displayType = "pips"
    else
        nextValue.displayType = "bar"
    end

    if trimText(nextValue.label or "") == "" then
        nextValue.label = nextValue.id or "Resource"
    end

    local ok = GPX:UpdateClassProfileResource(profileId, index, nextValue)
    if not ok then
        GPX:Print("Unable to save resource row " .. tostring(index) .. ".")
        return
    end

    GPX:Print("Saved resource: " .. tostring(nextValue.label or nextValue.id or index))
    self:RefreshClassesPanel()
end

function UI:CycleSelectedClassProfile(delta)
    local order = self:GetClassProfileOrder()
    if #order == 0 then
        return
    end

    local current = self:GetSelectedClassProfileId()
    local index = 1
    for i, token in ipairs(order) do
        if token == current then
            index = i
            break
        end
    end

    local nextIndex = index + (tonumber(delta) or 0)
    if nextIndex < 1 then
        nextIndex = #order
    elseif nextIndex > #order then
        nextIndex = 1
    end

    self.selectedClassProfileId = order[nextIndex]
    GPX:SetActiveClassProfileId(self.selectedClassProfileId)
    self.selectedReactiveRow = nil
    self.selectedResourceIndex = nil
    self:RefreshClassesPanel()
end

function UI:SaveSelectedClassDisplayName()
    local profileId = self:GetSelectedClassProfileId()
    if not profileId or not self.frame or not self.frame.classNameBox then
        return
    end

    local text = trimText(self.frame.classNameBox:GetText())
    if text == "" then
        text = profileId
    end

    if GPX:SetClassProfileDisplayName(profileId, text) then
        GPX:Print("Class profile renamed: " .. tostring(text))
    end
    self:RefreshClassesPanel()
end

function UI:AddCoreResourceToSelected(engineResource, label, color)
    local profileId = self:GetSelectedClassProfileId()
    if not profileId then
        return
    end

    local definition = {
        id = string.lower(tostring(profileId)) .. "_" .. tostring(engineResource),
        label = tostring(label),
        displayType = "bar",
        sourceType = "engine",
        engineResource = tostring(engineResource),
        minValue = 0,
        startsAtZero = true,
        color = color,
    }

    if GPX:AddClassProfileResource(profileId, definition) then
        GPX:Print("Added resource: " .. tostring(label))
    end
    self:RefreshClassesPanel()
end

function UI:RemoveLastResourceFromSelected()
    local profileId = self:GetSelectedClassProfileId()
    local profile = self:GetSelectedClassProfile()
    if not profileId or not profile or type(profile.resources) ~= "table" then
        return
    end

    if #profile.resources < 1 then
        return
    end
    GPX:RemoveClassProfileResource(profileId, #profile.resources)
    self:RefreshClassesPanel()
end

function UI:BeginReactiveEdit(index)
    local profile = self:GetSelectedClassProfile()
    if not profile or type(profile.reactiveSpells) ~= "table" then
        return
    end
    local row = profile.reactiveSpells[index]
    if not row or not self.frame or not self.frame.reactiveInput then
        return
    end
    self.selectedReactiveRow = index
    self.frame.reactiveInput:SetText(tostring(row.spellID or ""))
    self:RefreshClassesPanel()
end

function UI:CommitReactiveEdit()
    local profileId = self:GetSelectedClassProfileId()
    if not profileId or not self.frame or not self.frame.reactiveInput then
        return
    end

    local spellID = tonumber(trimText(self.frame.reactiveInput:GetText()))
    if not spellID then
        GPX:Print("Reactive spell requires a numeric spell ID.")
        return
    end

    if self.selectedReactiveRow then
        GPX:UpdateClassProfileReactiveSpell(profileId, self.selectedReactiveRow, spellID)
    else
        GPX:AddClassProfileReactiveSpell(profileId, spellID)
    end

    self.selectedReactiveRow = nil
    self.frame.reactiveInput:SetText("")
    self:RefreshClassesPanel()
end

function UI:DeleteReactiveSpell(index)
    local profileId = self:GetSelectedClassProfileId()
    if not profileId then
        return
    end

    GPX:RemoveClassProfileReactiveSpell(profileId, index)
    if self.selectedReactiveRow == index then
        self.selectedReactiveRow = nil
        if self.frame and self.frame.reactiveInput then
            self.frame.reactiveInput:SetText("")
        end
    end
    self:RefreshClassesPanel()
end

function UI:ShowReactiveTooltip(index, anchor)
    local profile = self:GetSelectedClassProfile()
    if not profile or type(profile.reactiveSpells) ~= "table" then
        return
    end
    local row = profile.reactiveSpells[index]
    if not row then
        return
    end

    local spellID = tonumber(row.spellID)
    local spellName = spellID and GetSpellInfo(spellID) or nil
    GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
    GameTooltip:AddLine(spellName or "Reactive Spell")
    GameTooltip:AddLine("Spell ID: " .. tostring(spellID or "?"), 0.85, 0.85, 0.95)
    GameTooltip:Show()
end

function UI:GetSpellDBShareText()
    if not self.frame or not self.frame.spellDBShareEdit then
        return ""
    end
    return tostring(self.frame.spellDBShareEdit:GetText() or "")
end

function UI:SetSpellDBShareText(text)
    if not self.frame or not self.frame.spellDBShareEdit then
        return
    end
    self.frame.spellDBShareEdit:SetText(tostring(text or ""))
    self.frame.spellDBShareEdit:SetCursorPosition(0)
end

function UI:ExportSpellDBToShareText()
    if not GPX or not GPX.ExportSpellDBText then
        GPX:Print("SpellDB export is unavailable.")
        return
    end

    local text = GPX:ExportSpellDBText()
    if not text or text == "" then
        GPX:Print("SpellDB export is empty.")
        return
    end

    self:SetSpellDBShareText(text)
    if self.frame and self.frame.spellDBShareStatus then
        self.frame.spellDBShareStatus:SetText("SpellDB exported to share box. Copy with Ctrl+C.")
    end
end

function UI:ImportSpellDBFromShareText(mode)
    local text = self:GetSpellDBShareText()
    if trimText(text) == "" then
        GPX:Print("Share box is empty. Paste SpellDB text first.")
        return
    end

    local importMode = tostring(mode or "merge")
    local ok, result = GPX:ImportSpellDBText(text, importMode)
    if not ok then
        GPX:Print("SpellDB import failed: " .. tostring(result))
        if self.frame and self.frame.spellDBShareStatus then
            self.frame.spellDBShareStatus:SetText("Import failed: " .. tostring(result))
        end
        return
    end

    if self.frame and self.frame.spellDBShareStatus then
        self.frame.spellDBShareStatus:SetText("Import complete: " .. tostring(result.importedProfiles or 0) .. " profile(s), mode=" .. tostring(result.mode or importMode))
    end
    GPX:Print("SpellDB import complete: " .. tostring(result.importedProfiles or 0) .. " profile(s).")
    self.selectedReactiveRow = nil
    self:RefreshClassesPanel()
end

function UI:OpenSpellDBShareInOutputWindow()
    local text = self:GetSpellDBShareText()
    if trimText(text) == "" then
        GPX:Print("Share box is empty. Export or paste text first.")
        return
    end

    local lines = {}
    for line in string.gmatch(text, "[^\n]+") do
        lines[#lines + 1] = line
    end
    GPX:SetOutputWindowLines(lines, "SpellDB Share", true)
    if self.frame and self.frame.spellDBShareStatus then
        self.frame.spellDBShareStatus:SetText("Sent share text to output window.")
    end
end

function UI:LoadSpellDBShareFromOutputWindow()
    if not GPX or not GPX.GetOutputWindowText then
        GPX:Print("Output window bridge is unavailable.")
        return
    end

    local text = GPX:GetOutputWindowText()
    if trimText(text) == "" then
        GPX:Print("Output window is empty.")
        return
    end

    local headerPos = string.find(text, "WOWX_SPELLDB_V1", 1, true)
    if headerPos then
        text = string.sub(text, headerPos)
    end

    self:SetSpellDBShareText(text)
    if self.frame and self.frame.spellDBShareStatus then
        self.frame.spellDBShareStatus:SetText("Loaded SpellDB text from output window.")
    end
end

function UI:GetCurrentSpecText()
    if not GetNumTalentTabs or not GetTalentTabInfo then
        return "Unknown"
    end

    local bestName = nil
    local bestPoints = -1
    for tab = 1, (GetNumTalentTabs() or 0) do
        local name, _, points = GetTalentTabInfo(tab)
        local score = tonumber(points) or 0
        if score > bestPoints then
            bestPoints = score
            bestName = name
        end
    end

    return bestName or "Unknown"
end

function UI:RefreshClassesPanel()
    if not self.frame or not self.frame.classesPanel then
        return
    end

    local descriptor = GPX:GetGameTypeDescriptor()
    local classToken = GPX:GetResolvedClassToken("player") or "UNKNOWN"
    local specText = self:GetCurrentSpecText()
    local profileId = self:GetSelectedClassProfileId()
    local profile = self:GetSelectedClassProfile()

    if self.frame.classesStateText then
        self.frame.classesStateText:SetText(
            "Class: " .. tostring(classToken)
            .. "\nSpec: " .. tostring(specText)
            .. "\nGame Type: " .. tostring(descriptor and descriptor.gameType or "classic")
            .. "\nActive Profile: " .. tostring(profileId or "none")
        )
    end

    if self.frame.classProfileLabel then
        local displayName = profile and profile.displayName or profileId or "none"
        local lockText = (profile and profile.lockedResourceIDs) and " (resource IDs locked)" or ""
        self.frame.classProfileLabel:SetText("Profile: " .. tostring(displayName) .. lockText)
    end

    if self.frame.classNameBox then
        local desired = profile and (profile.displayName or profileId) or ""
        if trimText(self.frame.classNameBox:GetText()) == "" or not self.frame.classNameBox:HasFocus() then
            self.frame.classNameBox:SetText(desired)
        end
    end

    if self.frame.classAddHint then
        self.frame.classAddHint:SetText("Player: " .. tostring(classToken))
    end

    if self.frame.resourcesText then
        local lines = {}
        local resources = (profile and profile.resources) or {}
        if #resources == 0 then
            lines[#lines + 1] = "No resources configured. Add core resources or custom aura resources."
        else
            for i, resource in ipairs(resources) do
                local marker = (self:GetSelectedResourceIndex() == i) and "*" or " "
                local source = resource.engineResource or resource.auraID or resource.spellID or "custom"
                local mode = tostring(resource.displayType or "bar")
                lines[#lines + 1] = marker .. i .. ". " .. tostring(resource.label or resource.id or "Resource") .. " [" .. mode .. "] [" .. tostring(source) .. "]"
            end
        end
        self.frame.resourcesText:SetText(table.concat(lines, "\n"))
    end

    if self.frame.resourceInspector then
        local inspector = self.frame.resourceInspector
        local resource, selectedIndex = self:GetSelectedResource()
        local resources = (profile and profile.resources) or {}

        if not resource then
            inspector.pickText:SetText("No resource")
            inspector.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            inspector.idBox:SetText("")
            inspector.auraBox:SetText("")
            inspector.maxBox:SetText("")
            inspector.fragmentBox:SetText("")
            inspector.infusionBox:SetText("")
            inspector.divideBox:SetText("")
            inspector.useCountCheck:SetChecked(nil)
            inspector.pipCheck:SetChecked(nil)
            inspector.fragmentsCheck:SetChecked(nil)
            inspector.previewText:SetText("Preview: add/select a resource to inspect pips and fragment math.")
            SetFrameEnabled(inspector.prev, false)
            SetFrameEnabled(inspector.next, false)
            SetFrameEnabled(inspector.saveButton, false)
        else
            local auraIcon = nil
            if resource.auraID then
                local _, icon = getAuraStackByID("player", resource.auraID, resource.filter)
                auraIcon = icon
            end
            if not auraIcon then
                local iconID = tonumber(resource.fragmentSpellID) or tonumber(resource.spellID) or tonumber(resource.infusionSpellID)
                if iconID and GetSpellTexture then
                    auraIcon = GetSpellTexture(iconID)
                end
            end
            inspector.icon:SetTexture(auraIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
            inspector.pickText:SetText("#" .. tostring(selectedIndex) .. "/" .. tostring(#resources))

            if not inspector.idBox:HasFocus() then
                inspector.idBox:SetText(tostring(resource.id or ""))
            end
            if not inspector.auraBox:HasFocus() then
                inspector.auraBox:SetText(resource.auraID and tostring(resource.auraID) or "")
            end
            if not inspector.maxBox:HasFocus() then
                inspector.maxBox:SetText(resource.maxValue and tostring(resource.maxValue) or "")
            end
            if not inspector.fragmentBox:HasFocus() then
                inspector.fragmentBox:SetText(resource.fragmentSpellID and tostring(resource.fragmentSpellID) or "")
            end
            if not inspector.infusionBox:HasFocus() then
                inspector.infusionBox:SetText(resource.infusionSpellID and tostring(resource.infusionSpellID) or "")
            end
            if not inspector.divideBox:HasFocus() then
                inspector.divideBox:SetText(resource.fragmentDivideBy and tostring(resource.fragmentDivideBy) or "")
            end

            local displayType = tostring(resource.displayType or "bar")
            inspector.useCountCheck:SetChecked(resource.useCount and 1 or nil)
            inspector.pipCheck:SetChecked((displayType == "pips" or displayType == "fragments") and 1 or nil)
            inspector.fragmentsCheck:SetChecked(displayType == "fragments" and 1 or nil)

            local previewLines = self:BuildResourcePreviewLines(resource)
            inspector.previewText:SetText(table.concat(previewLines, "\n"))
            SetFrameEnabled(inspector.prev, #resources > 1)
            SetFrameEnabled(inspector.next, #resources > 1)
            SetFrameEnabled(inspector.saveButton, true)
        end
    end

    if self.frame.reactiveRows then
        local reactive = (profile and profile.reactiveSpells) or {}
        for rowIndex, rowFrame in ipairs(self.frame.reactiveRows) do
            local entry = reactive[rowIndex]
            if entry then
                local spellID = tonumber(entry.spellID)
                local spellName, _, icon = spellID and GetSpellInfo(spellID) or nil
                rowFrame.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                rowFrame.spellText:SetText((spellName or "Unknown") .. " (" .. tostring(spellID or "?") .. ")")
                rowFrame.editButton:Enable()
                rowFrame.deleteButton:Enable()
                rowFrame:Show()
            else
                rowFrame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                rowFrame.spellText:SetText("-")
                rowFrame.editButton:Disable()
                rowFrame.deleteButton:Disable()
                rowFrame:Show()
            end
        end
    end

    if self.frame.reactiveAddButton and self.frame.reactiveEditHint then
        if self.selectedReactiveRow then
            self.frame.reactiveAddButton:SetText("Save Edit")
            self.frame.reactiveEditHint:SetText("Editing row " .. tostring(self.selectedReactiveRow) .. ".")
        else
            self.frame.reactiveAddButton:SetText("Add Reactive")
            self.frame.reactiveEditHint:SetText("Use this panel to build reactives in-game, then share/import via SpellDB Share.")
        end
    end

    if self.frame.spellDBShareStatus then
        local text = self:GetSpellDBShareText()
        local lineCount = 0
        if text ~= "" then
            lineCount = 1
            for _ in string.gmatch(text, "\n") do
                lineCount = lineCount + 1
            end
        end
        if trimText(self.frame.spellDBShareStatus:GetText() or "") == "" then
            self.frame.spellDBShareStatus:SetText("Share box lines: " .. tostring(lineCount) .. "")
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
    local descriptor = GPX.GetGameTypeDescriptor and GPX:GetGameTypeDescriptor() or nil
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
    local gameType = descriptor and descriptor.gameType or "classic"
    local realmType = descriptor and descriptor.realmType or "unknown"
    local expansionType = descriptor and descriptor.expansionType or "wotlk_full"

    return string.format(
        "Mode: %s\nProfile: %s\nGame Type: %s\nRealm Type: %s\nExpansion Type: %s\nInput Style: %s\nController Mode: %s\nMouselook Mode: %s\nVisual Bar: %s\nWoWX Bags: %s\nLayout Edit: %s\nButton Edit: %s\nMinimap Button: %s\nLast Error: %s",
        mode,
        profileName,
        gameType,
        realmType,
        expansionType,
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
    self:RefreshSystemsPanel()
    self:RefreshProfilePanel()
    self:RefreshClassesPanel()
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
