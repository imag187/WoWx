if not GamePadX then return end

local GPX = GamePadX
local Bar = {}

GPX.VisualBar = Bar

local BAR_BUTTON_COUNT = 12
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
    "PVPMicroButton",
    "LFGMicroButton",
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
    PVPMicroButton = true,
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
    "PVPMicroButton",
    "LFGMicroButton",
    "CompanionsMicroButton",
    "EJMicroButton",
    "MainMenuMicroButton",
    "HelpMicroButton",
}

local function getPointFromConfig(config, key, fallback)
    return config[key] or fallback
end

local function clamp(value, minV, maxV)
    if value < minV then return minV end
    if value > maxV then return maxV end
    return value
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
        if GPX.VisualBar and not GPX.VisualBar:IsLocked() then
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

function Bar:SavePositionForKind(frame, kind)
    if kind == "main" then
        self:SavePosition()
    elseif kind == "bag" then
        self:SaveBagPosition()
    elseif kind == "micro" then
        self:SaveMicroPosition()
    elseif kind == "stance" then
        self:SaveAuxFramePosition(frame, "stancePoint", "BOTTOM", "BOTTOM")
    elseif kind == "pet" then
        self:SaveAuxFramePosition(frame, "petPoint", "BOTTOM", "BOTTOM")
    end
end

function Bar:AttachMoveHandle(frame, kind)
    if not frame or frame._wowxMoveKind == kind then
        return
    end

    local handle = CreateFrame("Button", nil, frame)
    handle:SetWidth(120)
    handle:SetHeight(20)
    handle:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    handle:RegisterForDrag("LeftButton")
    handle:EnableMouse(true)

    createBackdrop(handle, 0.96, 0.8, 0.22, 0.85)
    handle:SetBackdropColor(0.1, 0.08, 0.03, 0.75)

    local text = handle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER", handle, "CENTER", 0, 0)
    text:SetText("Drag")
    text:SetTextColor(1.0, 0.92, 0.58)
    handle.text = text

    handle:SetScript("OnDragStart", function(self)
        if not GPX.VisualBar or GPX.VisualBar:IsLocked() then
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

function Bar:GetScaleForKind(kind)
    local config = ensureVisualBarConfig()
    if kind == "main" then
        return self:GetBarScale(), 0.75, 1.35, "scale"
    end
    if kind == "bag" then
        local scale = tonumber(config.bagScale) or self:GetBarScale()
        return clamp(scale, 0.6, 1.6), 0.6, 1.6, "bagScale"
    end
    if kind == "micro" then
        local scale = tonumber(config.microScale) or 1.0
        return clamp(scale, 0.6, 1.6), 0.6, 1.6, "microScale"
    end
    if kind == "stance" then
        local scale = tonumber(config.stanceScale) or 1.0
        return clamp(scale, 0.6, 1.6), 0.6, 1.6, "stanceScale"
    end
    if kind == "pet" then
        local scale = tonumber(config.petScale) or 1.0
        return clamp(scale, 0.6, 1.6), 0.6, 1.6, "petScale"
    end
    return 1.0, 0.6, 1.6, nil
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
    elseif kind == "stance" then
        local stanceFrame = _G.StanceBarFrame or _G.ShapeshiftBarFrame or _G.PossessBarFrame
        if stanceFrame then
            stanceFrame:SetScale(finalScale)
        end
    elseif kind == "pet" and _G.PetActionBarFrame then
        _G.PetActionBarFrame:SetScale(finalScale)
    end
end

function Bar:AttachResizeHandle(frame, kind)
    if not frame or frame._wowxResizeKind == kind then
        return
    end

    local handle = CreateFrame("Button", nil, frame)
    handle:SetWidth(14)
    handle:SetHeight(14)
    handle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    handle:RegisterForDrag("LeftButton")
    handle:EnableMouse(true)

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
        if not GPX.VisualBar or GPX.VisualBar:IsLocked() then
            return
        end
        local uiScale = UIParent:GetEffectiveScale()
        self._startX = GetCursorPosition() / uiScale
        self._startScale = select(1, GPX.VisualBar:GetScaleForKind(kind))
        self:SetScript("OnUpdate", function(btn)
            local nowX = GetCursorPosition() / uiScale
            local delta = (nowX - btn._startX) / 220
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
    local unlocked = not self:IsLocked()
    local function showHandle(frame)
        if frame and frame._wowxResizeHandle then
            frame._wowxResizeHandle:SetShown(unlocked)
        end
        if frame and frame._wowxMoveHandle then
            frame._wowxMoveHandle:SetShown(unlocked)
        end
    end
    showHandle(self.frame)
    showHandle(self.frame and self.frame.bagBar or nil)
    showHandle(self.microMenuFrame)
    showHandle(_G.StanceBarFrame or _G.ShapeshiftBarFrame or _G.PossessBarFrame)
    showHandle(_G.PetActionBarFrame)
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
    self:AttachMoveHandle(frame, "micro")
end

function Bar:UpdateMicroMenu()
    self:CreateMicroMenuFrame()
    local config = ensureVisualBarConfig()
    local show = self:ShouldReplaceBlizzardBars() and (not GPX:IsControllerEnabled())
    if not show then
        self.microMenuFrame:Hide()
        return
    end

    local point = self:GetStoredMicroPosition()
    self.microMenuFrame:ClearAllPoints()
    self.microMenuFrame:SetPoint(point.anchor, UIParent, point.relativePoint, point.x, point.y)
    self.microMenuFrame:SetScale(select(1, self:GetScaleForKind("micro")))
    self:AttachResizeHandle(self.microMenuFrame, "micro")

    local prev
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
            btn:Show()
            prev = btn
        end
    end

    self.microMenuFrame:Show()
end

function Bar:UpdateDetachedClassBars()
    local config = ensureVisualBarConfig()
    local show = self:ShouldReplaceBlizzardBars()

    local stanceFrame = _G.StanceBarFrame or _G.ShapeshiftBarFrame or _G.PossessBarFrame
    if stanceFrame and show then
        ensureFrameChrome(stanceFrame)
        local point = self:GetStoredStancePosition()
        stanceFrame:SetParent(UIParent)
        stanceFrame:ClearAllPoints()
        stanceFrame:SetPoint(point.anchor, UIParent, point.relativePoint, point.x, point.y)
        stanceFrame:SetScale(select(1, self:GetScaleForKind("stance")))
        stanceFrame:Show()
        self:EnsureAuxMovable(stanceFrame, function(selfFrame)
            GPX.VisualBar:SaveAuxFramePosition(selfFrame, "stancePoint", "BOTTOM", "BOTTOM")
        end)
        self:AttachMoveHandle(stanceFrame, "stance")
        self:AttachResizeHandle(stanceFrame, "stance")
    end

    local petFrame = _G.PetActionBarFrame
    if petFrame and show then
        ensureFrameChrome(petFrame)
        local point = self:GetStoredPetPosition()
        petFrame:SetParent(UIParent)
        petFrame:ClearAllPoints()
        petFrame:SetPoint(point.anchor, UIParent, point.relativePoint, point.x, point.y)
        petFrame:SetScale(select(1, self:GetScaleForKind("pet")))
        petFrame:Show()
        self:EnsureAuxMovable(petFrame, function(selfFrame)
            GPX.VisualBar:SaveAuxFramePosition(selfFrame, "petPoint", "BOTTOM", "BOTTOM")
        end)
        self:AttachMoveHandle(petFrame, "pet")
        self:AttachResizeHandle(petFrame, "pet")
    end
end

function Bar:GetUtilityForButton(index, state)
    return nil
end

function Bar:RunUtilityAction(utilityId)
    if utilityId == "OPENALLBAGS" then
        if OpenAllBags then
            OpenAllBags()
        elseif ToggleBackpack then
            ToggleBackpack()
        end
    elseif utilityId == "TOGGLEWORLDMAP" then
        if ToggleWorldMap then ToggleWorldMap() end
    elseif utilityId == "TOGGLEGAMEMENU" then
        if ToggleGameMenu then ToggleGameMenu() end
    elseif utilityId == "TOGGLECHARACTER0" then
        if ToggleCharacter then ToggleCharacter("PaperDollFrame") end
    elseif utilityId == "TOGGLESPELLBOOK" then
        if ToggleSpellBook then ToggleSpellBook(BOOKTYPE_SPELL or "spell") end
    elseif utilityId == "TOGGLETALENTS" then
        if ToggleTalentFrame then ToggleTalentFrame() end
    elseif utilityId == "TOGGLEQUESTLOG" then
        if ToggleQuestLog then ToggleQuestLog() end
    elseif utilityId == "TOGGLESOCIAL" then
        if ToggleFriendsFrame then ToggleFriendsFrame(1) end
    else
        GPX:Print("Unknown utility action: " .. tostring(utilityId))
    end
end

function Bar:GetBarScale()
    local config = ensureVisualBarConfig()
    local scale = tonumber(config.scale) or 1.0
    if scale < 0.75 then scale = 0.75 end
    if scale > 1.35 then scale = 1.35 end
    return scale
end

function Bar:AdjustScale(delta)
    if self:IsLocked() then
        GPX:Print("Visual bar is locked. Unlock it to resize.")
        return
    end

    local config = ensureVisualBarConfig()
    local scale = self:GetBarScale() + delta
    if scale < 0.75 then scale = 0.75 end
    if scale > 1.35 then scale = 1.35 end
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
    if config.showProgress == false then
        self.progressFrame:Hide()
        return
    end

    local progressBar = self.progressFrame.progressBar
    local progressText = self.progressFrame.progressText

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

    progressBar:SetMinMaxValues(0, 1)
    progressBar:SetValue(1)
    progressBar:SetStatusBarColor(0.25, 0.45, 0.25)
    progressText:SetText("No XP/Rep Track")
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
    local show = config.showBagBar ~= false
    self.frame.bagBar:SetShown(show)
    if not show then
        return
    end

    self.frame.bagBar:SetScale(select(1, self:GetScaleForKind("bag")))
    self:ApplyStoredBagPosition()

    for bagID, button in pairs(self.frame.bagButtons) do
        local invSlot = bagID == 0 and 16 or ((ContainerIDToInventoryID and ContainerIDToInventoryID(bagID)) or (19 + bagID))
        local texture = GetInventoryItemTexture("player", invSlot)
        button.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_Bag_08")
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

function Bar:IsProgressLocked()
    return ensureVisualBarConfig().progressLocked ~= false
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
    local config = ensureVisualBarConfig()
    config.progressLocked = not (config.progressLocked ~= false)
    self:UpdateAll()
    GPX:Print(config.progressLocked and "XP/Rep bar locked." or "XP/Rep bar unlocked. Drag to move.")
end

function Bar:GetPhysicalKeyForButton(index)
    local setup = self:GetSetup()
    if not setup then
        return defaultKeyHints[index]
    end

    if index == 1 then
        return setup.jumpKey or defaultKeyHints[index]
    end
    return (setup.actionKeys and setup.actionKeys[index - 1]) or defaultKeyHints[index]
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

function Bar:ResolveCommand(command)
    local mainIndex = tonumber(command and command:match("^ACTIONBUTTON(%d+)$"))
    if mainIndex then
        local liveButton = _G["ActionButton" .. mainIndex]
        if liveButton and liveButton.action then
            return liveButton.action
        end
        return mainIndex
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
    if GPX:IsControllerEnabled() and style and style.slotLabels and style.slotLabels[index] then
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
    if self:IsLocked() then
        GPX:Print("Button lock is enabled. Unlock bar buttons to edit slots.")
        return
    end
    local cursorType = GetCursorInfo and select(1, GetCursorInfo()) or nil
    if cursorType or CursorHasItem() or CursorHasSpell() or CursorHasMacro() or CursorHasMoney() then
        PlaceAction(button.display.slot)
        self:UpdateAll()
    end
end

function Bar:HandleRightClickEdit(button)
    if not button or not button.display or not button.display.slot or button.display.utilityId then
        return
    end
    if self:IsLocked() then
        GPX:Print("Button lock is enabled. Unlock bar buttons to edit slots.")
        return
    end

    local cursorType = GetCursorInfo and select(1, GetCursorInfo()) or nil
    if cursorType or CursorHasItem() or CursorHasSpell() or CursorHasMacro() or CursorHasMoney() then
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
    if self:IsLocked() then
        GPX:Print("Button lock is enabled. Unlock bar buttons to edit slots.")
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
    if self:IsLocked() then
        GPX:Print("Button lock is enabled. Unlock bar buttons to edit slots.")
        return
    end

    local slot = self:GetSlotForButtonState(button.slotIndex, button.state)
    if not slot then
        return
    end

    local cursorType = GetCursorInfo and select(1, GetCursorInfo()) or nil
    if cursorType or CursorHasItem() or CursorHasSpell() or CursorHasMacro() or CursorHasMoney() then
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

    if not self.frame or not self:IsPlacementModeEnabled() or not GPX.db or not GPX.db.enabled then
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

    if self:IsLocked() then
        GPX:Print("Button lock is enabled. Unlock bar buttons to assign spells.")
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
        if GPX.VisualBar and not GPX.VisualBar:IsLocked() then
            self:StartMoving()
        end
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if GPX.VisualBar then
            GPX.VisualBar:SavePosition()
        end
    end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
    title:SetTextColor(0.92, 0.96, 1.0)

    local pageText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pageText:SetPoint("LEFT", title, "RIGHT", 12, 0)
    pageText:SetTextColor(0.85, 0.88, 0.98)

    local chipContainer = CreateFrame("Frame", nil, frame)
    chipContainer:SetWidth(320)
    chipContainer:SetHeight(26)
    chipContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -10)

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

    local bagBar = CreateFrame("Frame", nil, frame)
    bagBar:SetWidth(156)
    bagBar:SetHeight(24)
    bagBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 8)
    ensureFrameChrome(bagBar)
    bagBar:SetParent(UIParent)
    bagBar:SetMovable(true)
    bagBar:RegisterForDrag("LeftButton")
    bagBar:SetScript("OnDragStart", function(self)
        if GPX.VisualBar and not GPX.VisualBar:IsLocked() then
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

        local bagIcon = bagButton:CreateTexture(nil, "ARTWORK")
        bagIcon:SetAllPoints(bagButton)
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

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetWidth(52)
        icon:SetHeight(52)
        icon:SetPoint("TOP", button, "TOP", 0, -10)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local glyph = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        glyph:SetPoint("TOPLEFT", button, "TOPLEFT", 8, -8)
        glyph:SetJustifyH("LEFT")
        glyph:SetTextColor(0.96, 0.98, 1.0)

        local name = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        name:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", -4, -8)
        name:SetPoint("RIGHT", button, "RIGHT", -6, 0)
        name:SetJustifyH("LEFT")

        local keyText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        keyText:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 8, 8)
        keyText:SetTextColor(1.0, 0.92, 0.58)

        local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        cooldown:SetAllPoints(icon)

        button.icon = icon
        button.glyph = glyph
        button.name = name
        button.keyText = keyText
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

    self.frame = frame
    self.frame.title = title
    self.frame.pageText = pageText
    self.frame.bagBar = bagBar
    self:ApplyStoredPosition()
    self:ApplyStoredBagPosition()
    self:AttachMoveHandle(frame, "main")
    self:AttachResizeHandle(frame, "main")
    self:AttachMoveHandle(bagBar, "bag")
    self:AttachResizeHandle(bagBar, "bag")

    if GPX.UIMode then
        GPX.UIMode:RegisterContext("bar", {
            label = "Action Bar",
            getItems = function()
                return Bar.frame and Bar.frame.buttons or {}
            end,
            columns = BAR_BUTTON_COUNT,
            isAvailable = function()
                return Bar.frame and Bar.frame:IsShown()
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
        if GPX.VisualBar and not GPX.VisualBar:IsProgressLocked() then
            self:StartMoving()
        end
    end)

    progressFrame:SetScript("OnDragStop", function(self)
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
    self:ApplyStoredProgressPosition()
end

function Bar:UpdateModifierChips(state)
    local active = {
        SHIFT = state == "SHIFT" or state == "SHIFT-ALT",
        ALT = state == "ALT" or state == "SHIFT-ALT",
        CTRL = state == "CTRL",
        ["SHIFT+ALT"] = state == "SHIFT-ALT",
    }

    local order = { "SHIFT", "ALT", "CTRL", "SHIFT+ALT" }
    for index, key in ipairs(order) do
        local chip = self.frame.chips[index]
        if active[key] then
            chip:SetBackdropBorderColor(0.96, 0.8, 0.22, 0.95)
            chip:SetBackdropColor(0.18, 0.14, 0.05, 0.95)
        else
            chip:SetBackdropBorderColor(0.25, 0.32, 0.42, 0.8)
            chip:SetBackdropColor(0.05, 0.07, 0.12, 0.86)
        end
    end
end

function Bar:UpdateButton(index, state)
    local button = self.frame.buttons[index]
    local display = self:GetDisplayForButton(index, state)
    local physicalKey = self:GetPhysicalKeyForButton(index)

    local keyLabel = physicalKey or defaultKeyHints[index] or tostring(index)
    button.glyph:SetText(keyLabel)
    button.name:SetText("")
    button.keyText:SetText(keyLabel)
    button.display = display
    button.physicalKey = physicalKey

    if not InCombatLockdown() then
        local baseSlot = self:GetSlotForButtonState(index, "")
        local shiftSlot = self:GetSlotForButtonState(index, "SHIFT")
        local altSlot = self:GetSlotForButtonState(index, "ALT")
        local ctrlSlot = self:GetSlotForButtonState(index, "CTRL")
        local comboSlot = self:GetSlotForButtonState(index, "SHIFT-ALT")

        if baseSlot then
            button:SetAttribute("type", "action")
            button:SetAttribute("action", baseSlot)
        else
            button:SetAttribute("type", nil)
            button:SetAttribute("action", nil)
        end

        button:SetAttribute("shift-type", shiftSlot and "action" or nil)
        button:SetAttribute("shift-action", shiftSlot)
        button:SetAttribute("shift-type1", shiftSlot and "action" or nil)
        button:SetAttribute("shift-action1", shiftSlot)

        button:SetAttribute("alt-type", altSlot and "action" or nil)
        button:SetAttribute("alt-action", altSlot)
        button:SetAttribute("alt-type1", altSlot and "action" or nil)
        button:SetAttribute("alt-action1", altSlot)

        button:SetAttribute("ctrl-type", ctrlSlot and "action" or nil)
        button:SetAttribute("ctrl-action", ctrlSlot)
        button:SetAttribute("ctrl-type1", ctrlSlot and "action" or nil)
        button:SetAttribute("ctrl-action1", ctrlSlot)

        button:SetAttribute("shift-alt-type", comboSlot and "action" or nil)
        button:SetAttribute("shift-alt-action", comboSlot)
        button:SetAttribute("alt-shift-type", comboSlot and "action" or nil)
        button:SetAttribute("alt-shift-action", comboSlot)
        button:SetAttribute("shift-alt-type1", comboSlot and "action" or nil)
        button:SetAttribute("shift-alt-action1", comboSlot)
        button:SetAttribute("alt-shift-type1", comboSlot and "action" or nil)
        button:SetAttribute("alt-shift-action1", comboSlot)

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
    else
        self.pendingAttributeRefresh = true
    end

    if display.icon then
        button.icon:SetTexture(display.icon)
        button.icon:SetVertexColor(1.0, 1.0, 1.0)
    else
        button.icon:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        button.icon:SetVertexColor(0.35, 0.4, 0.46)
    end

    if display.slot then
        local start, duration, enable = GetActionCooldown(display.slot)
        CooldownFrame_SetTimer(button.cooldown, start, duration, enable)
        local usable, oom = IsUsableAction(display.slot)
        if not usable and oom then
            button.icon:SetVertexColor(0.3, 0.5, 1.0)
        elseif not usable then
            button.icon:SetVertexColor(0.45, 0.45, 0.45)
        end
    else
        CooldownFrame_SetTimer(button.cooldown, 0, 0, 0)
    end

    if self:IsLocked() then
        button:SetBackdropBorderColor(0.14, 0.18, 0.24, 0.85)
    else
        button:SetBackdropBorderColor(0.96, 0.8, 0.22, 0.9)
    end
end

function Bar:UpdateAll()
    self:CreateFrame()
    self:CreateProgressFrame()
    self:UpdateBlizzardBars()

    if not GPX.db or not GPX.db.enabled or not GPX.db.ui or not GPX.db.ui.visualBar or not GPX.db.ui.visualBar.enabled then
        self.frame:Hide()
        if self.placementFrame then
            self.placementFrame:Hide()
        end
        if self.progressFrame then
            self.progressFrame:Hide()
        end
        if GPX.UIMode and GPX.UIMode.activeContext == "bar" then
            GPX.UIMode:Exit()
        end
        return
    end

    local setup = self:GetSetup()
    self.frame:SetScale(self:GetBarScale())

    local state = self:GetCurrentState()
    local page = modifierStates[state] or modifierStates[""]
    local pageLabel = page.title
    if not self:UseModifierPages() and state ~= "" then
        pageLabel = "Base (modifier held)"
    end
    self.frame.title:SetText(GPX.brand .. (setup and " Action Bar" or " Action Bar — Not Calibrated"))
    self.frame.pageText:SetText(pageLabel)
    if GPX.UIMode and GPX.UIMode.activeContext == "bar" then
        self.frame.title:SetText(GPX.brand .. " Action Bar — UI Mode")
        self.frame:SetBackdropBorderColor(0.96, 0.8, 0.22, 0.98)
    else
        self.frame:SetBackdropBorderColor(0.22, 0.66, 0.98, 0.9)
    end
    self.frame.pageText:SetTextColor(self:IsLocked() and 0.85 or 1.0, self:IsLocked() and 0.88 or 0.9, self:IsLocked() and 0.98 or 0.35)
    if self.progressFrame then
        if self:IsProgressLocked() then
            self.progressFrame:SetBackdropBorderColor(0.18, 0.24, 0.3, 0.8)
        else
            self.progressFrame:SetBackdropBorderColor(0.96, 0.8, 0.22, 0.9)
        end
    end
    self:UpdateModifierChips(state)
    self:UpdateProgressBar()
    self:UpdateBagBar()
    self:UpdateMicroMenu()
    self:UpdateDetachedClassBars()
    self:UpdateResizeHandles()

    for index = 1, BAR_BUTTON_COUNT do
        self:UpdateButton(index, state)
    end

    self.frame:Show()
    self:UpdatePlacementFrame()

    if not InCombatLockdown() then
        self.pendingAttributeRefresh = false
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
        self:UpdateAll()
        GPX:Print("Visual bar locked.")
    elseif cmd == "unlock" then
        config.locked = false
        self:UpdateAll()
        GPX:Print("Layout unlocked. Drag main/bag/micro/stance/pet bars. Use resize commands for scale.")
    elseif cmd == "reset" then
        config.point = GPX:DeepCopy(GPX.defaults.ui.visualBar.point)
        config.scale = GPX.defaults.ui.visualBar.scale or 1.0
        self:ApplyStoredPosition()
        self:UpdateAll()
        GPX:Print("Visual bar position reset.")
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
eventFrame:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
eventFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("UPDATE_BINDINGS")
eventFrame:RegisterEvent("PLAYER_XP_UPDATE")
eventFrame:RegisterEvent("UPDATE_FACTION")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(_, event)
    if GPX.VisualBar then
        if event == "PLAYER_REGEN_ENABLED" and GPX.VisualBar.pendingAttributeRefresh then
            GPX.VisualBar:UpdateAll()
            return
        end
        GPX.VisualBar:UpdateAll()
    end
end)