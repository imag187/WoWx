if not GamePadX then return end

local GPX = GamePadX
local Bar = {}

GPX.VisualBar = Bar

local BAR_BUTTON_COUNT = 12
local PET_ACTION_BUTTON_COUNT = 10
local defaultKeyHints = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" }

local function SetFrameShown(frame, shown)
    if shown then
        frame:Show()
    else
        frame:Hide()
    end
end

local PS5Icons = {
    ["1"] = "Interface\\AddOns\\WoWX\\Textures\\PS5\\CP_R_LEFT",
    ["2"] = "Interface\\AddOns\\WoWX\\Textures\\PS5\\CP_R_UP",
    ["3"] = "Interface\\AddOns\\WoWX\\Textures\\PS5\\CP_R_RIGHT",
    ["4"] = "Interface\\AddOns\\WoWX\\Textures\\PS5\\CP_X_LEFT",
    ["5"] = "Interface\\AddOns\\WoWX\\Textures\\PS5\\CP_X_RIGHT",
    ["6"] = "Interface\\AddOns\\WoWX\\Textures\\PS5\\CP_L_LEFT",
    ["7"] = "Interface\\AddOns\\WoWX\\Textures\\PS5\\CP_L_UP",
    ["8"] = "Interface\\AddOns\\WoWX\\Textures\\PS5\\CP_L_RIGHT",
    ["9"] = "Interface\\AddOns\\WoWX\\Textures\\PS5\\CP_L_DOWN",
    ["0"] = "Interface\\AddOns\\WoWX\\Textures\\PS5\\CP_R_DOWN",
}

local modifierIconPaths = {
    ["SHIFT"] = "Interface\\AddOns\\WoWX\\Textures\\PS5\\CP_TR1",
    ["ALT"] = "Interface\\AddOns\\WoWX\\Textures\\PS5\\CP_TL1",
    ["CTRL"] = "Interface\\AddOns\\WoWX\\Textures\\PS5\\CP_T_L3",
}

local modifierStates = {
    [""] = { title = "Base", bar = nil },
    ["SHIFT"] = { title = "Modifier 1", bar = "MULTIACTIONBAR2BUTTON" },
    ["ALT"] = { title = "Modifier 2", bar = "MULTIACTIONBAR1BUTTON" },
    ["CTRL"] = { title = "Modifier 3", bar = "MULTIACTIONBAR4BUTTON" },
    ["SHIFT-ALT"] = { title = "Combo", bar = "MULTIACTIONBAR3BUTTON" },
}

local cachedDisplayStates = { "", "SHIFT", "ALT", "CTRL", "SHIFT-ALT" }

local controllerActionKeyOrder = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" }

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

local function copyPoint(point, fallback)
    local source = point or fallback or {}
    return {
        anchor = source.anchor or "BOTTOM",
        relativeTo = source.relativeTo or "UIParent",
        relativePoint = source.relativePoint or "BOTTOM",
        x = tonumber(source.x) or 0,
        y = tonumber(source.y) or 0,
    }
end

local function copyLayoutTable(layout)
    local source = layout or {}
    return GPX:DeepCopy(source)
end

local function getLayoutProfileSnapshot()
    local config = ensureVisualBarConfig()
    return {
        layout = copyLayoutTable(config.layout),
        point = copyPoint(config.point, GPX.defaults.ui.visualBar.point),
        progressPoint = copyPoint(config.progressPoint, GPX.defaults.ui.visualBar.progressPoint),
        bagPoint = copyPoint(config.bagPoint, GPX.defaults.ui.visualBar.bagPoint),
        microPoint = copyPoint(config.microPoint, GPX.defaults.ui.visualBar.microPoint),
        modifierPoint = copyPoint(config.modifierPoint, GPX.defaults.ui.visualBar.modifierPoint),
        stancePoint = copyPoint(config.stancePoint, GPX.defaults.ui.visualBar.stancePoint),
        petPoint = copyPoint(config.petPoint, GPX.defaults.ui.visualBar.petPoint),
        vehiclePoint = copyPoint(config.vehiclePoint, GPX.defaults.ui.visualBar.vehiclePoint),
        showAlignmentGrid = config.showAlignmentGrid == true,
        scale = tonumber(config.scale) or 1.0,
        bagScale = tonumber(config.bagScale) or nil,
        microScale = tonumber(config.microScale) or nil,
        modifierScale = tonumber(config.modifierScale) or nil,
        stanceScale = tonumber(config.stanceScale) or nil,
        petScale = tonumber(config.petScale) or nil,
        vehicleScale = tonumber(config.vehicleScale) or nil,
    }
end

function Bar:GetLayoutProfileName()
    local config = ensureVisualBarConfig()
    return config.layoutProfile or "default"
end

function Bar:GetLayoutProfiles()
    return GPX:GetLayoutProfilesStore()
end

function Bar:GetLayoutProfileNames()
    local names = {}
    local profiles = self:GetLayoutProfiles()
    for name in pairs(profiles) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

function Bar:EnsureLayoutProfile(profileName)
    local config = ensureVisualBarConfig()
    config.layoutProfiles = config.layoutProfiles or {}
    local name = tostring(profileName or config.layoutProfile or "default")
    if name == "" then
        name = "default"
    end
    if type(config.layoutProfiles[name]) ~= "table" then
        config.layoutProfiles[name] = getLayoutProfileSnapshot()
    end
    return config.layoutProfiles[name], name
end

function Bar:SaveLayoutProfile(profileName)
    local config = ensureVisualBarConfig()
    local snapshot, name = self:EnsureLayoutProfile(profileName)
    local fresh = getLayoutProfileSnapshot()
    config.layoutProfiles[name] = fresh
    config.layoutProfile = name
    return fresh
end

function Bar:ApplyLayoutProfile(profileName)
    local config = ensureVisualBarConfig()
    local snapshot, name = self:EnsureLayoutProfile(profileName)
    if type(snapshot) ~= "table" then
        return false
    end

    config.layout = copyLayoutTable(snapshot.layout)
    config.point = copyPoint(snapshot.point, GPX.defaults.ui.visualBar.point)
    config.progressPoint = copyPoint(snapshot.progressPoint, GPX.defaults.ui.visualBar.progressPoint)
    config.bagPoint = copyPoint(snapshot.bagPoint, GPX.defaults.ui.visualBar.bagPoint)
    config.microPoint = copyPoint(snapshot.microPoint, GPX.defaults.ui.visualBar.microPoint)
    config.modifierPoint = copyPoint(snapshot.modifierPoint, GPX.defaults.ui.visualBar.modifierPoint)
    config.stancePoint = copyPoint(snapshot.stancePoint, GPX.defaults.ui.visualBar.stancePoint)
    config.petPoint = copyPoint(snapshot.petPoint, GPX.defaults.ui.visualBar.petPoint)
    config.vehiclePoint = copyPoint(snapshot.vehiclePoint, GPX.defaults.ui.visualBar.vehiclePoint)
    config.showAlignmentGrid = snapshot.showAlignmentGrid == true
    if snapshot.scale ~= nil then config.scale = snapshot.scale end
    if snapshot.bagScale ~= nil then config.bagScale = snapshot.bagScale end
    if snapshot.microScale ~= nil then config.microScale = snapshot.microScale end
    if snapshot.modifierScale ~= nil then config.modifierScale = snapshot.modifierScale end
    if snapshot.stanceScale ~= nil then config.stanceScale = snapshot.stanceScale end
    if snapshot.petScale ~= nil then config.petScale = snapshot.petScale end
    if snapshot.vehicleScale ~= nil then config.vehicleScale = snapshot.vehicleScale end
    config.layoutProfile = name
    self:UpdateAll()
    return true
end

function Bar:DeleteLayoutProfile(profileName)
    local config = ensureVisualBarConfig()
    local name = tostring(profileName or config.layoutProfile or "default")
    if name == "" or name == "default" then
        return false
    end
    if config.layoutProfiles then
        config.layoutProfiles[name] = nil
    end
    if config.layoutProfile == name then
        config.layoutProfile = "default"
    end
    return true
end

local function ensureAlignmentGrid(frame)
    if frame and frame._wowxAlignmentGrid then
        return frame._wowxAlignmentGrid
    end
    if not frame then
        return nil
    end

    local grid = CreateFrame("Frame", nil, frame)
    grid:SetFrameStrata("BACKGROUND")
    grid:SetFrameLevel(0)
    grid:EnableMouse(false)
    grid:SetAllPoints(UIParent)
    grid.lines = { vertical = {}, horizontal = {} }
    grid:Hide()

    frame._wowxAlignmentGrid = grid
    return grid
end

function Bar:UpdateAlignmentGrid()
    local config = ensureVisualBarConfig()
    local shouldShow = config.showAlignmentGrid == true or (not self:IsLayoutEditLocked())
    local grid = ensureAlignmentGrid(UIParent)
    if not grid then
        return
    end

    if not shouldShow then
        grid:Hide()
        return
    end

    local width = math.floor((UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 0)
    local height = math.floor((UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 0)
    local cell = 40
    local verticalCount = math.max(0, math.floor(width / cell))
    local horizontalCount = math.max(0, math.floor(height / cell))

    local function ensureLine(collection, index)
        if not collection[index] then
            local line = grid:CreateTexture(nil, "OVERLAY")
            line:SetTexture("Interface\\Buttons\\WHITE8x8")
            collection[index] = line
        end
        return collection[index]
    end

    for index = 1, verticalCount + 1 do
        local line = ensureLine(grid.lines.vertical, index)
        line:SetVertexColor(0.84, 0.9, 1.0, index % 5 == 0 and 0.16 or 0.07)
        line:SetWidth(1)
        local offset = (index - 1) * cell
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", grid, "TOPLEFT", offset, 0)
        line:SetPoint("BOTTOMLEFT", grid, "BOTTOMLEFT", offset, 0)
        line:Show()
    end
    for index = verticalCount + 2, #grid.lines.vertical do
        if grid.lines.vertical[index] then
            grid.lines.vertical[index]:Hide()
        end
    end

    for index = 1, horizontalCount + 1 do
        local line = ensureLine(grid.lines.horizontal, index)
        line:SetVertexColor(0.84, 0.9, 1.0, index % 5 == 0 and 0.16 or 0.07)
        line:SetHeight(1)
        local offset = (index - 1) * cell
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, -offset)
        line:SetPoint("TOPRIGHT", grid, "TOPRIGHT", 0, -offset)
        line:Show()
    end
    for index = horizontalCount + 2, #grid.lines.horizontal do
        if grid.lines.horizontal[index] then
            grid.lines.horizontal[index]:Hide()
        end
    end

    grid:Show()
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

    local function createStroke(parent, inset, thickness, layer)
        local stroke = {}
        stroke.top = parent:CreateTexture(nil, layer)
        stroke.bottom = parent:CreateTexture(nil, layer)
        stroke.left = parent:CreateTexture(nil, layer)
        stroke.right = parent:CreateTexture(nil, layer)

        for _, seg in pairs(stroke) do
            seg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        end

        stroke.top:SetPoint("TOPLEFT", parent, "TOPLEFT", -inset, inset)
        stroke.top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", inset, inset)
        stroke.top:SetHeight(thickness)

        stroke.bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -inset, -inset)
        stroke.bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", inset, -inset)
        stroke.bottom:SetHeight(thickness)

        stroke.left:SetPoint("TOPLEFT", parent, "TOPLEFT", -inset, inset)
        stroke.left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -inset, -inset)
        stroke.left:SetWidth(thickness)

        stroke.right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", inset, inset)
        stroke.right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", inset, -inset)
        stroke.right:SetWidth(thickness)

        function stroke:Hide()
            self.top:Hide(); self.bottom:Hide(); self.left:Hide(); self.right:Hide()
        end

        function stroke:Show()
            self.top:Show(); self.bottom:Show(); self.left:Show(); self.right:Show()
        end

        function stroke:SetVertexColor(r, g, b, a)
            self.top:SetVertexColor(r, g, b, a)
            self.bottom:SetVertexColor(r, g, b, a)
            self.left:SetVertexColor(r, g, b, a)
            self.right:SetVertexColor(r, g, b, a)
        end

        function stroke:SetAlpha(a)
            self.top:SetAlpha(a)
            self.bottom:SetAlpha(a)
            self.left:SetAlpha(a)
            self.right:SetAlpha(a)
        end

        function stroke:ClearAllPoints()
            self.top:ClearAllPoints()
            self.bottom:ClearAllPoints()
            self.left:ClearAllPoints()
            self.right:ClearAllPoints()
        end

        return stroke
    end

    local function setStrokeColor(stroke, r, g, b, a)
        if not stroke then return end
        stroke.top:SetVertexColor(r, g, b, a)
        stroke.bottom:SetVertexColor(r, g, b, a)
        stroke.left:SetVertexColor(r, g, b, a)
        stroke.right:SetVertexColor(r, g, b, a)
    end

    local panel = frame:CreateTexture(nil, "BACKGROUND")
    panel:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    panel:SetVertexColor(0.07, 0.09, 0.12, 0.22)

    local border = createStroke(frame, 0, 2, "OVERLAY")
    setStrokeColor(border, 0.22, 0.66, 0.98, 0.95)

    local tint = createStroke(frame, 0, 2, "OVERLAY")
    setStrokeColor(tint, 0.0, 0.0, 0.0, 0.0)

    frame.slotPanel = panel
    frame.slotBorder = border
    frame.slotTint = tint
    frame._wowxSlotSetStrokeColor = setStrokeColor
    frame._wowxSlotWrapper = true
end

local function layoutSlotWrapper(frame, leftInset, topInset, rightInset, bottomInset)
    ensureSlotWrapper(frame)
    frame.slotPanel:ClearAllPoints()
    frame.slotPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", leftInset, -topInset)
    frame.slotPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -rightInset, bottomInset)

    frame.slotBorder:ClearAllPoints()
    frame.slotBorder.top:ClearAllPoints()
    frame.slotBorder.top:SetPoint("TOPLEFT", frame.slotPanel, "TOPLEFT", 0, 0)
    frame.slotBorder.top:SetPoint("TOPRIGHT", frame.slotPanel, "TOPRIGHT", 0, 0)
    frame.slotBorder.bottom:ClearAllPoints()
    frame.slotBorder.bottom:SetPoint("BOTTOMLEFT", frame.slotPanel, "BOTTOMLEFT", 0, 0)
    frame.slotBorder.bottom:SetPoint("BOTTOMRIGHT", frame.slotPanel, "BOTTOMRIGHT", 0, 0)
    frame.slotBorder.left:ClearAllPoints()
    frame.slotBorder.left:SetPoint("TOPLEFT", frame.slotPanel, "TOPLEFT", 0, 0)
    frame.slotBorder.left:SetPoint("BOTTOMLEFT", frame.slotPanel, "BOTTOMLEFT", 0, 0)
    frame.slotBorder.right:ClearAllPoints()
    frame.slotBorder.right:SetPoint("TOPRIGHT", frame.slotPanel, "TOPRIGHT", 0, 0)
    frame.slotBorder.right:SetPoint("BOTTOMRIGHT", frame.slotPanel, "BOTTOMRIGHT", 0, 0)

    if frame.slotTint then
        frame.slotTint.top:ClearAllPoints()
        frame.slotTint.top:SetPoint("TOPLEFT", frame.slotPanel, "TOPLEFT", 0, 0)
        frame.slotTint.top:SetPoint("TOPRIGHT", frame.slotPanel, "TOPRIGHT", 0, 0)
        frame.slotTint.bottom:ClearAllPoints()
        frame.slotTint.bottom:SetPoint("BOTTOMLEFT", frame.slotPanel, "BOTTOMLEFT", 0, 0)
        frame.slotTint.bottom:SetPoint("BOTTOMRIGHT", frame.slotPanel, "BOTTOMRIGHT", 0, 0)
        frame.slotTint.left:ClearAllPoints()
        frame.slotTint.left:SetPoint("TOPLEFT", frame.slotPanel, "TOPLEFT", 0, 0)
        frame.slotTint.left:SetPoint("BOTTOMLEFT", frame.slotPanel, "BOTTOMLEFT", 0, 0)
        frame.slotTint.right:ClearAllPoints()
        frame.slotTint.right:SetPoint("TOPRIGHT", frame.slotPanel, "TOPRIGHT", 0, 0)
        frame.slotTint.right:SetPoint("BOTTOMRIGHT", frame.slotPanel, "BOTTOMRIGHT", 0, 0)
    end
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
    frame.slotBorder.top:ClearAllPoints()
    frame.slotBorder.top:SetPoint("TOPLEFT", frame.slotPanel, "TOPLEFT", 0, 0)
    frame.slotBorder.top:SetPoint("TOPRIGHT", frame.slotPanel, "TOPRIGHT", 0, 0)
    frame.slotBorder.bottom:ClearAllPoints()
    frame.slotBorder.bottom:SetPoint("BOTTOMLEFT", frame.slotPanel, "BOTTOMLEFT", 0, 0)
    frame.slotBorder.bottom:SetPoint("BOTTOMRIGHT", frame.slotPanel, "BOTTOMRIGHT", 0, 0)
    frame.slotBorder.left:ClearAllPoints()
    frame.slotBorder.left:SetPoint("TOPLEFT", frame.slotPanel, "TOPLEFT", 0, 0)
    frame.slotBorder.left:SetPoint("BOTTOMLEFT", frame.slotPanel, "BOTTOMLEFT", 0, 0)
    frame.slotBorder.right:ClearAllPoints()
    frame.slotBorder.right:SetPoint("TOPRIGHT", frame.slotPanel, "TOPRIGHT", 0, 0)
    frame.slotBorder.right:SetPoint("BOTTOMRIGHT", frame.slotPanel, "BOTTOMRIGHT", 0, 0)

    if frame.slotTint then
        frame.slotTint.top:ClearAllPoints()
        frame.slotTint.top:SetPoint("TOPLEFT", frame.slotPanel, "TOPLEFT", 0, 0)
        frame.slotTint.top:SetPoint("TOPRIGHT", frame.slotPanel, "TOPRIGHT", 0, 0)
        frame.slotTint.bottom:ClearAllPoints()
        frame.slotTint.bottom:SetPoint("BOTTOMLEFT", frame.slotPanel, "BOTTOMLEFT", 0, 0)
        frame.slotTint.bottom:SetPoint("BOTTOMRIGHT", frame.slotPanel, "BOTTOMRIGHT", 0, 0)
        frame.slotTint.left:ClearAllPoints()
        frame.slotTint.left:SetPoint("TOPLEFT", frame.slotPanel, "TOPLEFT", 0, 0)
        frame.slotTint.left:SetPoint("BOTTOMLEFT", frame.slotPanel, "BOTTOMLEFT", 0, 0)
        frame.slotTint.right:ClearAllPoints()
        frame.slotTint.right:SetPoint("TOPRIGHT", frame.slotPanel, "TOPRIGHT", 0, 0)
        frame.slotTint.right:SetPoint("BOTTOMRIGHT", frame.slotPanel, "BOTTOMRIGHT", 0, 0)
    end
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
    frame.slotBorder.top:ClearAllPoints()
    frame.slotBorder.top:SetPoint("TOPLEFT", frame.slotPanel, "TOPLEFT", 0, 0)
    frame.slotBorder.top:SetPoint("TOPRIGHT", frame.slotPanel, "TOPRIGHT", 0, 0)
    frame.slotBorder.bottom:ClearAllPoints()
    frame.slotBorder.bottom:SetPoint("BOTTOMLEFT", frame.slotPanel, "BOTTOMLEFT", 0, 0)
    frame.slotBorder.bottom:SetPoint("BOTTOMRIGHT", frame.slotPanel, "BOTTOMRIGHT", 0, 0)
    frame.slotBorder.left:ClearAllPoints()
    frame.slotBorder.left:SetPoint("TOPLEFT", frame.slotPanel, "TOPLEFT", 0, 0)
    frame.slotBorder.left:SetPoint("BOTTOMLEFT", frame.slotPanel, "BOTTOMLEFT", 0, 0)
    frame.slotBorder.right:ClearAllPoints()
    frame.slotBorder.right:SetPoint("TOPRIGHT", frame.slotPanel, "TOPRIGHT", 0, 0)
    frame.slotBorder.right:SetPoint("BOTTOMRIGHT", frame.slotPanel, "BOTTOMRIGHT", 0, 0)

    if frame.slotTint then
        frame.slotTint.top:ClearAllPoints()
        frame.slotTint.top:SetPoint("TOPLEFT", frame.slotPanel, "TOPLEFT", 0, 0)
        frame.slotTint.top:SetPoint("TOPRIGHT", frame.slotPanel, "TOPRIGHT", 0, 0)
        frame.slotTint.bottom:ClearAllPoints()
        frame.slotTint.bottom:SetPoint("BOTTOMLEFT", frame.slotPanel, "BOTTOMLEFT", 0, 0)
        frame.slotTint.bottom:SetPoint("BOTTOMRIGHT", frame.slotPanel, "BOTTOMRIGHT", 0, 0)
        frame.slotTint.left:ClearAllPoints()
        frame.slotTint.left:SetPoint("TOPLEFT", frame.slotPanel, "TOPLEFT", 0, 0)
        frame.slotTint.left:SetPoint("BOTTOMLEFT", frame.slotPanel, "BOTTOMLEFT", 0, 0)
        frame.slotTint.right:ClearAllPoints()
        frame.slotTint.right:SetPoint("TOPRIGHT", frame.slotPanel, "TOPRIGHT", 0, 0)
        frame.slotTint.right:SetPoint("BOTTOMRIGHT", frame.slotPanel, "BOTTOMRIGHT", 0, 0)
    end
end

local function layoutSlotWrapperToIcon(frame, icon, padding)
    ensureSlotWrapper(frame)
    if not frame or not icon then
        return
    end

    local pad = math.max(0, tonumber(padding) or 0)

    frame.slotPanel:ClearAllPoints()
    frame.slotPanel:SetPoint("TOPLEFT", icon, "TOPLEFT", -pad, pad)
    frame.slotPanel:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", pad, -pad)

    frame.slotBorder:ClearAllPoints()
    frame.slotBorder.top:ClearAllPoints()
    frame.slotBorder.top:SetPoint("TOPLEFT", frame.slotPanel, "TOPLEFT", 0, 0)
    frame.slotBorder.top:SetPoint("TOPRIGHT", frame.slotPanel, "TOPRIGHT", 0, 0)
    frame.slotBorder.bottom:ClearAllPoints()
    frame.slotBorder.bottom:SetPoint("BOTTOMLEFT", frame.slotPanel, "BOTTOMLEFT", 0, 0)
    frame.slotBorder.bottom:SetPoint("BOTTOMRIGHT", frame.slotPanel, "BOTTOMRIGHT", 0, 0)
    frame.slotBorder.left:ClearAllPoints()
    frame.slotBorder.left:SetPoint("TOPLEFT", frame.slotPanel, "TOPLEFT", 0, 0)
    frame.slotBorder.left:SetPoint("BOTTOMLEFT", frame.slotPanel, "BOTTOMLEFT", 0, 0)
    frame.slotBorder.right:ClearAllPoints()
    frame.slotBorder.right:SetPoint("TOPRIGHT", frame.slotPanel, "TOPRIGHT", 0, 0)
    frame.slotBorder.right:SetPoint("BOTTOMRIGHT", frame.slotPanel, "BOTTOMRIGHT", 0, 0)

    if frame.slotTint then
        frame.slotTint.top:ClearAllPoints()
        frame.slotTint.top:SetPoint("TOPLEFT", frame.slotPanel, "TOPLEFT", 0, 0)
        frame.slotTint.top:SetPoint("TOPRIGHT", frame.slotPanel, "TOPRIGHT", 0, 0)
        frame.slotTint.bottom:ClearAllPoints()
        frame.slotTint.bottom:SetPoint("BOTTOMLEFT", frame.slotPanel, "BOTTOMLEFT", 0, 0)
        frame.slotTint.bottom:SetPoint("BOTTOMRIGHT", frame.slotPanel, "BOTTOMRIGHT", 0, 0)
        frame.slotTint.left:ClearAllPoints()
        frame.slotTint.left:SetPoint("TOPLEFT", frame.slotPanel, "TOPLEFT", 0, 0)
        frame.slotTint.left:SetPoint("BOTTOMLEFT", frame.slotPanel, "BOTTOMLEFT", 0, 0)
        frame.slotTint.right:ClearAllPoints()
        frame.slotTint.right:SetPoint("TOPRIGHT", frame.slotPanel, "TOPRIGHT", 0, 0)
        frame.slotTint.right:SetPoint("BOTTOMRIGHT", frame.slotPanel, "BOTTOMRIGHT", 0, 0)
    end
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

-- Transport functions removed. All secure attribute writes go through GPX.ClickTransport.
-- See ClickTransport.lua. Do not add transport logic here.

function Bar:GetBindingProxyButtonName(command)
    return GPX.ClickTransport and GPX.ClickTransport:ProxyButtonName(command) or nil
end

function Bar:EnsureBindingProxyButtons()
    if not GPX.ClickTransport then return end
    for _, row in ipairs(placementRows) do
        for index = 1, BAR_BUTTON_COUNT do
            local command = self:GetCommandForButton(index, row.state)
            if command then
                GPX.ClickTransport:EnsureProxyButton(command)
            end
        end
    end
    -- Keep a reference so GamePadX can still iterate .bindingButtons if needed.
    self.bindingButtons = GPX.ClickTransport.proxyButtons
end

function Bar:UpdateBindingProxyButtons()
    self:EnsureBindingProxyButtons()
    if InCombatLockdown() then
        self.pendingAttributeRefresh = true
        return
    end
    if not GPX.ClickTransport then return end
    GPX.ClickTransport:UpdateAllProxyButtons(function(command)
        return self:ResolveCommand(command)
    end)
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
    
    -- If controller mode is disabled, always show all 12 buttons
    if not GPX:IsControllerEnabled() then
        return BAR_BUTTON_COUNT
    end
    
    -- Controller mode: respect configured button count
    local visibleCount = clamp(math.floor((tonumber(layout.buttonCount) or BAR_BUTTON_COUNT) + 0.5), 1, BAR_BUTTON_COUNT)
    local setup = self:GetSetup()
    local style = self:GetStyle()
    local combatLabels = style and style.combatSlotLabels or nil
    local combatVisibleCount = type(combatLabels) == "table" and #combatLabels or BAR_BUTTON_COUNT
    visibleCount = math.min(visibleCount, combatVisibleCount)
    visibleCount = math.min(visibleCount, GPX:GetConfiguredActionButtonCount(setup, self:GetProfile()))
    
    return visibleCount
end

function Bar:GetMainLayoutMetrics()
    local layout = self:GetLayoutConfig("main")
    return {
        layout = layout,
        visibleCount = self:GetVisibleButtonCount(),
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
    local keepMicro = config.keepMicroMenu ~= false
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
            SetFrameShown(frame._wowxResizeHandle, unlocked)
        end
        if frame and frame._wowxMoveHandle then
            SetFrameShown(frame._wowxMoveHandle, unlocked and frame == self.modifierFrame)
        end
        if frame and frame._wowxEditButton then
            SetFrameShown(frame._wowxEditButton, unlocked)
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
        if not shouldStartFrameDrag(self) then
            return
        end
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -12)
    title:SetTextColor(0.96, 0.98, 1.0)
    title._wowxDisableFrameDrag = true

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    subtitle:SetWidth(252)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetTextColor(0.78, 0.84, 0.95)
    subtitle._wowxDisableFrameDrag = true

    local aspectButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    aspectButton:SetWidth(116)
    aspectButton:SetHeight(20)
    aspectButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -40)
    aspectButton._wowxDisableFrameDrag = true

    local gridButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    gridButton:SetWidth(116)
    gridButton:SetHeight(20)
    gridButton:SetPoint("TOPLEFT", aspectButton, "TOPRIGHT", 8, 0)
    gridButton._wowxDisableFrameDrag = true

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    closeButton._wowxDisableFrameDrag = true

    local resetButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetButton:SetWidth(82)
    resetButton:SetHeight(22)
    resetButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 12)
    resetButton:SetText("Defaults")
    resetButton._wowxDisableFrameDrag = true

    local doneButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    doneButton:SetWidth(82)
    doneButton:SetHeight(22)
    doneButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
    doneButton:SetText("Close")
    doneButton._wowxDisableFrameDrag = true
    doneButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame.title = title
    frame.subtitle = subtitle
    frame.aspectButton = aspectButton
    frame.gridButton = gridButton
    frame.resetButton = resetButton
    frame.controls = {}

    local function nudgeSlider(slider, direction)
        if not slider or not slider.control then
            return
        end
        local control = slider.control
        local minValue, maxValue = slider:GetMinMaxValues()
        local currentValue = slider:GetValue()
        local step = control.step or 1
        local nudged = clamp(roundToStep(currentValue + (step * direction), step), minValue, maxValue)
        slider:SetValue(nudged)
    end

    for index = 1, 7 do
        local slider = CreateFrame("Slider", nil, frame)
        slider:SetOrientation("HORIZONTAL")
        slider:SetWidth(212)
        slider:SetHeight(18)
        slider:SetPoint("TOPLEFT", frame, "TOPLEFT", 42, -72 - ((index - 1) * 36))
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
        label._wowxDisableFrameDrag = true

        local valueText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        valueText:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 4)
        valueText:SetTextColor(1.0, 0.92, 0.58)
        valueText._wowxDisableFrameDrag = true

        local decButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        decButton:SetWidth(18)
        decButton:SetHeight(18)
        decButton:SetPoint("LEFT", slider, "LEFT", -24, 0)
        decButton:SetText("<")
        decButton._wowxDisableFrameDrag = true
        decButton:Hide()

        local incButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        incButton:SetWidth(18)
        incButton:SetHeight(18)
        incButton:SetPoint("RIGHT", slider, "RIGHT", 24, 0)
        incButton:SetText(">")
        incButton._wowxDisableFrameDrag = true
        incButton:Hide()

        slider.label = label
        slider.valueText = valueText
        slider.decButton = decButton
        slider.incButton = incButton
        slider._wowxDisableFrameDrag = true
        slider:Hide()
        decButton:SetScript("OnClick", function()
            nudgeSlider(slider, -1)
        end)
        incButton:SetScript("OnClick", function()
            nudgeSlider(slider, 1)
        end)
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
        local function syncMainSize(axis, value)
            local size = math.floor(value + 0.5)
            layout[axis] = size
            if layout.aspectLock then
                layout.buttonWidth = size
                layout.buttonHeight = size
                if self.layoutEditor and self.layoutEditor.controls then
                    local widthSlider = self.layoutEditor.controls[3]
                    local heightSlider = self.layoutEditor.controls[4]
                    if widthSlider and widthSlider ~= axis then
                        widthSlider._suspend = true
                        widthSlider:SetValue(size)
                        widthSlider.valueText:SetText(tostring(size))
                        widthSlider._suspend = false
                    end
                    if heightSlider then
                        heightSlider._suspend = true
                        heightSlider:SetValue(size)
                        heightSlider.valueText:SetText(tostring(size))
                        heightSlider._suspend = false
                    end
                end
            end
        end
        add("Scale", 0.5, 2.0, 0.01,
            function() return select(1, self:GetScaleForKind("main")) end,
            function(value) self:SetScaleForKind("main", value) end,
            formatScaleValue)
        add("Visible Buttons", 1, 12, 1,
            function() return self:GetVisibleButtonCount() end,
            function(value) layout.buttonCount = clamp(math.floor(value + 0.5), 1, BAR_BUTTON_COUNT) end)
        add("Button Width", 42, 120, 1,
            function() return tonumber(layout.buttonWidth) or layoutDefaults.main.buttonWidth end,
            function(value) syncMainSize("buttonWidth", value) end)
        add("Button Height", 68, 156, 1,
            function() return tonumber(layout.buttonHeight) or layoutDefaults.main.buttonHeight end,
            function(value) syncMainSize("buttonHeight", value) end)
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
    if editor.aspectButton then
        if kind == "main" then
            local layout = self:GetLayoutConfig("main")
            editor.aspectButton:Show()
            editor.aspectButton:SetText((layout.aspectLock == true) and "Aspect: Locked" or "Aspect: Free")
            editor.aspectButton:SetScript("OnClick", function()
                layout.aspectLock = not (layout.aspectLock == true)
                if layout.aspectLock then
                    local size = tonumber(layout.buttonWidth) or tonumber(layout.buttonHeight) or layoutDefaults.main.buttonWidth
                    layout.buttonWidth = size
                    layout.buttonHeight = size
                end
                if GPX.VisualBar then
                    GPX.VisualBar:UpdateAll()
                end
                GPX.VisualBar:OpenLayoutEditor(kind, anchorFrame)
            end)
        else
            editor.aspectButton:Hide()
        end
    end
    if editor.gridButton then
        local config = ensureVisualBarConfig()
        editor.gridButton:Show()
        editor.gridButton:SetText((config.showAlignmentGrid == true) and "Grid: On" or "Grid: Off")
        editor.gridButton:SetScript("OnClick", function()
            local cfg = ensureVisualBarConfig()
            cfg.showAlignmentGrid = not (cfg.showAlignmentGrid == true)
            if GPX.VisualBar then
                GPX.VisualBar:UpdateAlignmentGrid()
                GPX.VisualBar:UpdateAll()
            end
            GPX.VisualBar:OpenLayoutEditor(kind, anchorFrame)
        end)
    end
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
            if slider.decButton then
                slider.decButton:Show()
            end
            if slider.incButton then
                slider.incButton:Show()
            end
        else
            slider.control = nil
            slider:Hide()
            if slider.decButton then
                slider.decButton:Hide()
            end
            if slider.incButton then
                slider.incButton:Hide()
            end
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

        local icon = chip:CreateTexture(nil, "OVERLAY")
        icon:SetWidth(18)
        icon:SetHeight(18)
        icon:SetPoint("CENTER", chip, "CENTER", 0, 0)
        icon:Hide()

        local comboLeftIcon = chip:CreateTexture(nil, "OVERLAY")
        comboLeftIcon:SetWidth(16)
        comboLeftIcon:SetHeight(16)
        comboLeftIcon:SetPoint("RIGHT", chip, "CENTER", -8, 0)
        comboLeftIcon:Hide()

        local comboPlus = chip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        comboPlus:SetPoint("CENTER", chip, "CENTER", 0, 0)
        comboPlus:SetText("+")
        comboPlus:Hide()

        local comboRightIcon = chip:CreateTexture(nil, "OVERLAY")
        comboRightIcon:SetWidth(16)
        comboRightIcon:SetHeight(16)
        comboRightIcon:SetPoint("LEFT", chip, "CENTER", 8, 0)
        comboRightIcon:Hide()

        chip.label = label
        chip.icon = icon
        chip.comboLeftIcon = comboLeftIcon
        chip.comboPlus = comboPlus
        chip.comboRightIcon = comboRightIcon
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

        if GPX:IsControllerEnabled() and key == "SHIFT+ALT" and chip.comboLeftIcon and chip.comboPlus and chip.comboRightIcon then
            chip.comboLeftIcon:SetTexture(modifierIconPaths["SHIFT"])
            chip.comboRightIcon:SetTexture(modifierIconPaths["ALT"])
            chip.comboLeftIcon:Show()
            chip.comboPlus:Show()
            chip.comboRightIcon:Show()
            if chip.icon then
                chip.icon:Hide()
            end
            chip.label:Hide()
        elseif GPX:IsControllerEnabled() and chip.icon and modifierIconPaths[key] then
            chip.icon:SetTexture(modifierIconPaths[key])
            chip.icon:Show()
            if chip.comboLeftIcon then
                chip.comboLeftIcon:Hide()
            end
            if chip.comboPlus then
                chip.comboPlus:Hide()
            end
            if chip.comboRightIcon then
                chip.comboRightIcon:Hide()
            end
            chip.label:Hide()
        else
            if chip.icon then
                chip.icon:Hide()
            end
            if chip.comboLeftIcon then
                chip.comboLeftIcon:Hide()
            end
            if chip.comboPlus then
                chip.comboPlus:Hide()
            end
            if chip.comboRightIcon then
                chip.comboRightIcon:Hide()
            end
            chip.label:Show()
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
    local config = ensureVisualBarConfig()
    local show = self:ShouldReplaceBlizzardBars() and config.keepMicroMenu ~= false
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
    local config = ensureVisualBarConfig()
    config.keepMicroMenu = not (config.keepMicroMenu ~= false)
    self:UpdateAll()
    GPX:Print("Micro menu: " .. ((config.keepMicroMenu ~= false) and "shown" or "hidden"))
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

    -- Consolidation policy: the standalone WoWX bags utility button is the
    -- single bag surface; keep the legacy compact bag bar hidden.
    self.frame.bagBar:Hide()
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
    if GPX:IsControllerEnabled() then
        if not setup then
            return GPX:GetLegacyControllerActionKey(self:GetProfile(), index) or defaultKeyHints[index]
        end
        return GPX:GetSetupActionKey(setup, index) or defaultKeyHints[index]
    end

    if not setup then
        return defaultKeyHints[index]
    end

    if index == 1 then
        return setup.jumpKey or defaultKeyHints[index]
    end
    return GPX:GetSetupActionKey(setup, index) or defaultKeyHints[index]
end

function Bar:GetControllerVisualForSlot(index)
    if not GPX:IsControllerEnabled() then
        return nil, nil
    end

    local setup = self:GetSetup()
    local profile = self:GetProfile()
    local styleId = GPX:GetEffectiveControllerStyleId(setup, profile)
    local style = GPX:GetInputStyle(styleId)
    local labels = GPX:GetCombatDisplayLabels(styleId)
    local keyText = tostring(self:GetPhysicalKeyForButton(index) or "")
    local normalizedKey = string.upper(keyText)

    local slotLabel = nil
    if labels and #labels > 0 then
        for labelIndex, key in ipairs(controllerActionKeyOrder) do
            if normalizedKey == key then
                slotLabel = labels[labelIndex]
                break
            end
        end
    end

    if (not slotLabel or slotLabel == "") and setup and setup.jumpKey and string.upper(tostring(setup.jumpKey)) == normalizedKey then
        slotLabel = style and style.confirmLabel or nil
    end

    if (not slotLabel or slotLabel == "") and style and style.slotLabels then
        slotLabel = style.slotLabels[tonumber(index) or 0]
    end

    if not slotLabel or slotLabel == "" then
        return nil, nil
    end

    return slotLabel, GPX:GetButtonTexture(styleId, slotLabel), styleId
end

local function buildControllerBadgeText(styleId, slotLabel, index)
    if styleId == "generic" then
        return tostring(index)
    end

    return tostring(slotLabel or "")
end

function Bar:GetCommandForButton(index, state)
    if GPX.ClickTransport and GPX.ClickTransport.CommandForCell then
        return GPX.ClickTransport:CommandForCell(state, index, self:UseModifierPages())
    end

    local page = modifierStates[state]
    if state == "" or not self:UseModifierPages() then
        return "ACTIONBUTTON" .. index
    end
    return page and page.bar and (page.bar .. index) or nil
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
    if GPX and GPX.GetMainActionPageState then
        local page = GPX:GetMainActionPageState("player")
        return tonumber(page) or 1
    end
    return 1
end

function Bar:ResolveCommand(command)
    local mainIndex = tonumber(command and command:match("^ACTIONBUTTON(%d+)$"))
    if mainIndex then
        local liveButton = _G["ActionButton" .. mainIndex]
        local liveAction = liveButton and liveButton.action or nil
        local _, classFile = UnitClass("player")
        local stealthed = IsStealthed and IsStealthed() or false
        local bonusOffset = GetBonusBarOffset and (tonumber(GetBonusBarOffset()) or 0) or 0
        local page = getCurrentMainActionPage()
        local slot = ((page - 1) * 12) + mainIndex

        if GPX and GPX.IsCoAStealthPageClass and GPX:IsCoAStealthPageClass("player") then
            if stealthed then
                local bonusButton = _G["BonusActionButton" .. mainIndex]
                local bonusAction = bonusButton and tonumber(bonusButton.action)
                if bonusAction and bonusAction > 0 then
                    return bonusAction
                end
                if liveAction and liveAction ~= mainIndex then
                    return liveAction
                end
                if HasAction and HasAction(mainIndex) then
                    return mainIndex
                end
                return slot
            end
            return mainIndex
        end

        -- On CoA realms, hasOverride can remain noisy while bonusOffset is the
        -- reliable signal for Runeshroud page routing. Treat bonusOffset as
        -- authoritative when present for ACTIONBUTTON slot resolution.
        if bonusOffset > 0 then
            if GPX and GPX.IsDruidDualStealthPagerClass and GPX:IsDruidDualStealthPagerClass("player") then
                local bonusButton = _G["BonusActionButton" .. mainIndex]
                local bonusAction = bonusButton and tonumber(bonusButton.action)
                if bonusAction and bonusAction > 0 then
                    return bonusAction
                end
                if HasAction and HasAction(slot) then
                    return slot
                end
            end
            return slot
        end

        if classFile == "DRUID" and GPX and GPX.IsDruidDualStealthPagerClass and GPX:IsDruidDualStealthPagerClass("player") then
            if stealthed then
                local prowlSlot = (7 * 12) + mainIndex
                if HasAction and HasAction(prowlSlot) then
                    return prowlSlot
                end
                return prowlSlot
            end
            if GPX.IsDruidCatFormActive and GPX:IsDruidCatFormActive() then
                local catSlot = (6 * 12) + mainIndex
                if HasAction and HasAction(catSlot) then
                    return catSlot
                end
                return catSlot
            end
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

    -- Modifier rows are modeled as deterministic Blizzard page slot ranges.
    -- Resolve static slot first so display and key transport stay aligned with
    -- cross-machine slot placement even when multibar frames are hidden.
    local staticSlot = GPX.ClickTransport and GPX.ClickTransport:StaticSlotForCommand(command) or nil
    if staticSlot then
        return staticSlot
    end

    local candidates = self:GetButtonCandidates(command)
    if candidates then
        for _, buttonName in ipairs(candidates) do
            local button = _G[buttonName]
            if button and button.action then
                return button.action
            end
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

function Bar:IsReactiveSpellActive(actionSlot, actionType, actionID, isUsable)
    if actionType ~= "spell" or not actionID then
        return false
    end

    if IsSpellOverlayed and IsSpellOverlayed(actionID) then
        return true
    end

    if GPX and GPX.IsReactiveSpellID and GPX:IsReactiveSpellID(actionID) then
        return isUsable == true
    end

    return false
end

function Bar:IsNativeUtilitySlot(slot)
    local actionSlot = tonumber(slot)
    if not actionSlot or actionSlot < 1 then
        return false
    end
    if GPX and GPX.SpellbookUI and GPX.SpellbookUI.IsNativeUtilityMacroAtSlot then
        return GPX.SpellbookUI:IsNativeUtilityMacroAtSlot(actionSlot) == true
    end
    return false
end

function Bar:InvalidateDisplayLayerCache()
    self._displayLayerCache = nil
end

function Bar:BuildDisplayLayerCache()
    local cache = {}
    for _, state in ipairs(cachedDisplayStates) do
        cache[state] = {}
        for index = 1, BAR_BUTTON_COUNT do
            cache[state][index] = self:GetDisplayForButton(index, state, true)
        end
    end
    self._displayLayerCache = cache
end

function Bar:GetDisplayForButton(index, state, bypassCache)
    state = state or ""

    if not bypassCache then
        local cache = self._displayLayerCache
        local stateCache = cache and cache[state]
        if stateCache and stateCache[index] then
            return stateCache[index]
        end
    end

    local style = self:GetStyle()
    local setup = self:GetSetup()
    local styleId = GPX:GetEffectiveControllerStyleId(setup, self:GetProfile())
    local slotLabel = "Action " .. index
    if GPX:IsControllerEnabled() then
        local labels = GPX:GetCombatSlotLabels(styleId)
        if labels[index] then
            slotLabel = labels[index]
        end
    elseif style and style.slotLabels and style.slotLabels[index] then
        slotLabel = style.slotLabels[index]
    end

    local command = self:GetCommandForButton(index, state)

    if not command then
        local out = {
            icon = nil,
            title = slotLabel,
            subtitle = state == "" and "Empty" or "No page",
            hint = "No mapped page",
        }
        if not bypassCache then
            self._displayLayerCache = self._displayLayerCache or {}
            self._displayLayerCache[state] = self._displayLayerCache[state] or {}
            self._displayLayerCache[state][index] = out
        end
        return out
    end

    local slot = self:ResolveCommand(command)
    local texture = slot and GetActionTexture(slot) or nil
    if (not texture) and slot and GPX and GPX.SpellbookUI and GPX.SpellbookUI.GetUtilityIconForActionSlot then
        texture = GPX.SpellbookUI:GetUtilityIconForActionSlot(slot)
    end
    local out = {
        icon = texture,
        title = slotLabel,
        subtitle = "",
        slot = slot,
        command = command,
        hint = command,
    }
    if not bypassCache then
        self._displayLayerCache = self._displayLayerCache or {}
        self._displayLayerCache[state] = self._displayLayerCache[state] or {}
        self._displayLayerCache[state][index] = out
    end
    return out
end

function Bar:UpdateButtonTooltip(button)
    if not button.display then
        return
    end

    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    if button.display.slot and not self:IsNativeUtilitySlot(button.display.slot) then
        GameTooltip:SetAction(button.display.slot)
    elseif button.display.slot then
        GameTooltip:AddLine(button.display.title or "WoWX", 1.0, 0.96, 0.7)
        GameTooltip:AddLine("Native utility placeholder", 0.82, 0.9, 1.0)
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

    if button.display and button.display.slot and not self:IsNativeUtilitySlot(button.display.slot) then
        GameTooltip:AddLine("Drag spells, items, or macros here to place them on this WoWX page.", 0.75, 0.82, 0.9, true)
    elseif button.display and button.display.slot then
        GameTooltip:AddLine("This slot is reserved for a native keybind utility. Replace it with a spell to restore normal click casting.", 0.75, 0.82, 0.9, true)
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
                btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                btn.icon:SetVertexColor(0.32, 0.44, 0.62)
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
        shine:SetPoint("CENTER", button.slotPanel, "CENTER", 0, 0)
        shine:SetWidth(62)
        shine:SetHeight(62)
        shine:SetVertexColor(0.2, 1.0, 0.42, 0.72)
        shine:Hide()

        local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        cooldown:SetAllPoints(icon)

        local controllerIcon = button:CreateTexture(nil, "OVERLAY")
        controllerIcon:SetWidth(20)
        controllerIcon:SetHeight(20)
        controllerIcon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -6, 8)
        controllerIcon:SetTexCoord(0, 1, 0, 1)
        controllerIcon:Hide()

        local controllerBadge = button:CreateTexture(nil, "OVERLAY")
        controllerBadge:SetWidth(20)
        controllerBadge:SetHeight(20)
        controllerBadge:SetPoint("CENTER", controllerIcon, "CENTER", 0, 0)
        controllerBadge:SetTexture("Interface\\COMMON\\Indicator-Black")
        controllerBadge:SetVertexColor(0.02, 0.02, 0.02, 0.95)
        controllerBadge:Hide()

        local controllerBadgeText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        controllerBadgeText:SetPoint("CENTER", controllerBadge, "CENTER", 0, 0)
        controllerBadgeText:SetJustifyH("CENTER")
        controllerBadgeText:SetTextColor(1.0, 1.0, 1.0)
        controllerBadgeText:Hide()

        button.icon = icon
        button.glyph = glyph
        button.name = name
        button.keyText = keyText
        button.countText = countText
        button.shine = shine
        button.cooldown = cooldown
        button.controllerIcon = controllerIcon
        button.controllerBadge = controllerBadge
        button.controllerBadgeText = controllerBadgeText
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
    local slotR, slotG, slotB, slotA = 0.62, 0.72, 0.84, 0.9
    if self:IsEditChromeActive() then
        borderR, borderG, borderB, borderA = 0.96, 0.8, 0.22, 0.9
        slotR, slotG, slotB, slotA = 0.96, 0.8, 0.22, 0.95
    else
        borderR, borderG, borderB, borderA = 0.22, 0.66, 0.98, 0.9
    end

    local isNativeUtility = display and display.slot and self:IsNativeUtilitySlot(display.slot)

    if display and display.slot then
        if isNativeUtility then
            CooldownFrame_SetTimer(button.cooldown, 0, 0, 0)
            button.icon:SetVertexColor(0.95, 0.95, 0.95)
            button:SetAlpha(alpha)
            if button.countText then
                button.countText:SetText("")
                button.countText:Hide()
            end
            if button.shine then
                button.shine:Hide()
            end
            if button.slotPanel then
                button.slotPanel:Hide()
            end
            if button.slotBorder then
                button.slotBorder:Hide()
            end
            if button.slotTint then
                button.slotTint:Hide()
            end
            button:SetBackdropColor(0.0, 0.0, 0.0, 0.0)
            button:SetBackdropBorderColor(borderR, borderG, borderB, 0.0)
            return
        end

        local chargeCount, maxCharges, chargeStart, chargeDuration, chargeEnable = self:GetActionChargeState(display.slot)
        local start, duration, enable = self:GetResolvedCooldown(display.slot)
        if maxCharges and maxCharges > 1 and chargeCount and chargeCount < maxCharges and chargeDuration and chargeDuration > 0 then
            start, duration, enable = chargeStart, chargeDuration, chargeEnable
        end
        CooldownFrame_SetTimer(button.cooldown, start or 0, duration or 0, enable or 0)

        local usable, oom = IsUsableAction(display.slot)
        local inRange = IsActionInRange(display.slot)
        local actionType, actionID = nil, nil
        if GetActionInfo then
            actionType, actionID = GetActionInfo(display.slot)
        end
        local actionCount = GetActionCount and (GetActionCount(display.slot) or 0) or 0
        local stackCount = (actionType == "spell") and 0 or actionCount
        local equippedAction = IsEquippedAction and IsEquippedAction(display.slot)
        local reactiveGlow = self:IsReactiveSpellActive(display.slot, actionType, actionID, usable)
        local red, green, blue = 1.0, 1.0, 1.0
        local finalAlpha = alpha

        if inRange == 0 then
            red, green, blue = 0.95, 0.22, 0.22
            finalAlpha = math.max(0.35, alpha * 0.7)
            borderR, borderG, borderB, borderA = 0.9, 0.22, 0.22, 0.95
            slotR, slotG, slotB, slotA = 0.9, 0.22, 0.22, 0.95
        elseif not usable and oom then
            red, green, blue = 0.3, 0.5, 1.0
            slotR, slotG, slotB, slotA = 0.3, 0.5, 1.0, 0.95
        elseif not usable then
            red, green, blue = 0.45, 0.45, 0.45
            finalAlpha = math.max(0.45, alpha * 0.82)
            slotR, slotG, slotB, slotA = 0.45, 0.45, 0.45, 0.85
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
            local isQueued = IsCurrentAction and IsCurrentAction(display.slot)
            if isQueued then
                button.shine:SetVertexColor(1.0, 0.82, 0.0, 0.55)
                button.shine:Show()
            elseif reactiveGlow then
                button.shine:SetVertexColor(1.0, 0.55, 0.16, 0.78)
                button.shine:Show()
            elseif equippedAction then
                button.shine:SetVertexColor(0.2, 1.0, 0.42, 0.5)
                button.shine:Show()
            else
                button.shine:Hide()
            end
        end
        if button.slotPanel then
            button.slotPanel:Show()
            button.slotPanel:SetVertexColor(0.07, 0.09, 0.12, 0.18)
        end
        if button.slotBorder then
            button.slotBorder:Show()
            if button._wowxSlotSetStrokeColor then
                button._wowxSlotSetStrokeColor(button.slotBorder, slotR, slotG, slotB, slotA)
            end
        end
        if button.slotTint then
            if button._wowxSlotSetStrokeColor then
                button._wowxSlotSetStrokeColor(button.slotTint, 0.0, 0.0, 0.0, 0.0)
            end
            button.slotTint:Show()
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
            button.slotPanel:SetVertexColor(0.07, 0.09, 0.12, 0.22)
        end
        if button.slotBorder then
            button.slotBorder:Show()
            if button._wowxSlotSetStrokeColor then
                button._wowxSlotSetStrokeColor(button.slotBorder, 0.62, 0.7, 0.82, 0.82)
            end
        end
        if button.slotTint then
            if button._wowxSlotSetStrokeColor then
                button._wowxSlotSetStrokeColor(button.slotTint, 0.0, 0.0, 0.0, 0.0)
            end
            button.slotTint:Show()
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
    local showSecondaryKeyText = false
    local bottomReserve = showSecondaryKeyText and 24 or 2
    local iconSize = math.max(20, math.min(buttonWidth - 4, buttonHeight - bottomReserve - 4))
    local buttonTopOffset = self.frame and self.frame._wowxButtonTopOffset or 44
    local iconTopInset = math.max(2, math.floor((buttonHeight - bottomReserve - iconSize) * 0.5))
    local hasAction = display and display.slot
    local iconInset = hasAction and 2 or 4

    local keyLabel = physicalKey or defaultKeyHints[index] or tostring(index)
    local controllerLabel, controllerTexture, controllerStyleId = self:GetControllerVisualForSlot(index)
    button.glyph:SetText(keyLabel)
    button.name:SetText("")
    if showSecondaryKeyText then
        button.keyText:SetText(keyLabel)
        button.keyText:Show()
    else
        button.keyText:SetText("")
        button.keyText:Hide()
    end

    if button.controllerIcon then
        local iconPath = GPX:IsControllerEnabled() and controllerTexture
        if iconPath then
            button.controllerIcon:SetTexture(iconPath)
            button.controllerIcon:Show()
        else
            button.controllerIcon:Hide()
        end
    end

    local showBadge = GPX:IsControllerEnabled() and controllerLabel and controllerLabel ~= "" and not controllerTexture
    if button.controllerBadge and button.controllerBadgeText then
        if showBadge then
            local badgeText = buildControllerBadgeText(controllerStyleId, controllerLabel, index)
            button.controllerBadgeText:SetText(tostring(badgeText or ""))
            button.controllerBadge:Show()
            button.controllerBadgeText:Show()
        else
            button.controllerBadge:Hide()
            button.controllerBadgeText:Hide()
        end
    end

    if GPX:IsControllerEnabled() and controllerLabel and controllerLabel ~= "" then
        if controllerTexture or showBadge then
            button.name:SetText("")
            button.name:Hide()
        else
            button.name:SetText(tostring(controllerLabel))
            button.name:SetTextColor(0.95, 0.96, 1.0)
            button.name:Show()
        end
    else
        button.name:SetText("")
        button.name:Hide()
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
                    button.slotPanel:Show()
                end
                if button.slotBorder then
                    button.slotBorder:Show()
                end
                button.icon:SetWidth(iconSize)
                button.icon:SetHeight(iconSize)
                button.icon:ClearAllPoints()
                button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", iconInset, -iconTopInset)
                layoutSlotWrapperToIcon(button, button.icon, 2)
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
                local shineWidth = math.max(((button.slotPanel and button.slotPanel.GetWidth and button.slotPanel:GetWidth()) or iconSize) + 10, 48)
                local shineHeight = math.max(((button.slotPanel and button.slotPanel.GetHeight and button.slotPanel:GetHeight()) or iconSize) + 10, 48)
                button.shine:SetWidth(shineWidth)
                button.shine:SetHeight(shineHeight)
                button.shine:ClearAllPoints()
                if button.slotPanel then
                    button.shine:SetPoint("CENTER", button.slotPanel, "CENTER", 0, 0)
                else
                    button.shine:SetPoint("CENTER", button.icon, "CENTER", 0, 0)
                end
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

        if GPX.ClickTransport then
            GPX.ClickTransport:ApplyButtonModifiers(button,
                { base = baseSlot, shift = shiftSlot, alt = altSlot, ctrl = ctrlSlot, combo = comboSlot },
                { base = baseCommand, shift = shiftCommand, alt = altCommand, ctrl = ctrlCommand, combo = comboCommand }
            )
        end
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
        self:InvalidateDisplayLayerCache()
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
    self:BuildDisplayLayerCache()
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
        self.frame.title:SetText("Action Bar - Native " .. GPX.actionStateReason)
        self.frame:SetBackdropBorderColor(0.95, 0.36, 0.18, 0.98)
        self.frame:SetBackdropColor(0.1, 0.05, 0.04, math.max(chromeAlpha, 0.18))
        showHeader = true
    end
    if GPX.UIMode and GPX.UIMode.activeContext == "bar" then
        self.frame.title:SetText("Action Bar - UI Mode")
        self.frame:SetBackdropBorderColor(0.96, 0.8, 0.22, 0.98)
    else
        if not (GPX.actionStateSuspended and GPX.actionStateReason) then
            self.frame:SetBackdropBorderColor(0.22, 0.66, 0.98, 0.9)
        end
    end
    SetFrameShown(self.frame.title, showHeader)
    SetFrameShown(self.frame.pageText, showHeader)
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
    self:UpdateAlignmentGrid()

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
            self.frame._wowxShell:SetBackdropBorderColor(0.22, 0.66, 0.98, 0.0)
            self.frame._wowxShell:SetBackdropColor(0.05, 0.07, 0.12, 0.0)
        else
            self.frame._wowxShell:SetBackdropBorderColor(0.96, 0.8, 0.22, 0.0)
            self.frame._wowxShell:SetBackdropColor(0.12, 0.09, 0.03, 0.0)
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
eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
eventFrame:RegisterEvent("PLAYER_XP_UPDATE")
eventFrame:RegisterEvent("UPDATE_FACTION")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

local _vbUpdatePending = false
local function scheduleVisualBarUpdate()
    if _vbUpdatePending then return end
    _vbUpdatePending = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0.15, function()
            _vbUpdatePending = false
            if GPX.VisualBar then GPX.VisualBar:UpdateAll() end
        end)
    else
        _vbUpdatePending = false
        if GPX.VisualBar then GPX.VisualBar:UpdateAll() end
    end
end

eventFrame:SetScript("OnEvent", function(_, event)
    if not GPX.VisualBar then return end
    if event == "PLAYER_REGEN_DISABLED" then
        if GPX.UIMode and GPX.UIMode.activeContext == "bar" then
            GPX.UIMode:Exit()
        end
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if GPX.VisualBar.pendingAttributeRefresh then
            GPX.VisualBar:UpdateAll()
        end
        return
    end
    -- High-frequency / storm events: coalesce into one deferred update.
    if event == "ACTIONBAR_SLOT_CHANGED"
        or event == "ACTIONBAR_UPDATE_USABLE"
        or event == "ACTIONBAR_UPDATE_COOLDOWN"
        or event == "UPDATE_SHAPESHIFT_USABLE"
        or event == "UPDATE_SHAPESHIFT_COOLDOWN"
        or event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW"
        or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE"
        or event == "PLAYER_XP_UPDATE"
        or event == "UPDATE_FACTION"
        or event == "UNIT_INVENTORY_CHANGED"
        or event == "SPELLS_CHANGED"
        or event == "UPDATE_BINDINGS" then
        scheduleVisualBarUpdate()
        return
    end
    -- All other events trigger an immediate full update.
    GPX.VisualBar:UpdateAll()
end)
