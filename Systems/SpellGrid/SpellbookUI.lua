if not GamePadX then return end

local GPX = GamePadX
local UI = {}

GPX.SpellbookUI = UI

local BOOK = BOOKTYPE_SPELL or "spell"
local ACTIONS_PER_PAGE = 12
local gridbookPages = {
    { id = "BASE", label = "Base", state = "" },
    { id = "SHIFT", label = "Shift", state = "SHIFT" },
    { id = "ALT", label = "Alt", state = "ALT" },
    { id = "CTRL", label = "Ctrl", state = "CTRL" },
    { id = "COMBO", label = "Shift+Alt", state = "SHIFT-ALT" },
}

local utilityActions = {
    { id = "gridbook", name = "Gridbook", detail = "Open/close Gridbook", icon = "Interface\\Icons\\INV_Misc_Book_09", macroName = "WX Gridbook", macro = "/run if GamePadX and GamePadX.SpellbookUI then if GamePadX.SpellbookUI.frame and GamePadX.SpellbookUI.frame:IsShown() then GamePadX.SpellbookUI:ReturnToPreviousContext() else GamePadX.SpellbookUI:Open(nil, \"settings\") end end" },
    { id = "bags", name = "Bags", detail = "Toggle backpack", icon = "Interface\\Icons\\INV_Misc_Bag_08", macroName = "WX Bags", macro = "/run ToggleBackpack()", bindingCommand = "OPENALLBAGS" },
    { id = "map", name = "World Map", detail = "Open/close map", icon = "Interface\\Icons\\INV_Misc_Map02", macroName = "WX Map", macro = "/run ToggleFrame(WorldMapFrame)", bindingCommand = "TOGGLEWORLDMAP" },
    { id = "character", name = "Character", detail = "Open character panel", icon = "Interface\\Icons\\INV_Chest_Cloth_17", macroName = "WX Char", macro = "/run ToggleCharacter(\"PaperDollFrame\")", bindingCommand = "TOGGLECHARACTER0" },
    { id = "minimap", name = "Minimap Menu", detail = "Minimap tracking", icon = "Interface\\Icons\\Spell_Arcane_TeleportIronForge", macroName = "WX MiniMap", macro = "/run if MiniMapTrackingDropDown then ToggleDropDownMenu(1,nil,MiniMapTrackingDropDown,\"cursor\",0,0) end" },
    { id = "spellbook", name = "Spellbook", detail = "Open spellbook", icon = "Interface\\Icons\\INV_Misc_Book_09", macroName = "WX Spellbk", macro = "/run ToggleSpellBook(BOOKTYPE_SPELL)", bindingCommand = "TOGGLESPELLBOOK" },
    { id = "talents", name = "Talents", detail = "Open talents", icon = "Interface\\Icons\\Ability_Marksmanship", macroName = "WX Talent", macro = "/run ToggleTalentFrame()", bindingCommand = "TOGGLETALENTS" },
    { id = "quest", name = "Quest Log", detail = "Open quests", icon = "Interface\\Icons\\INV_Misc_Note_01", macroName = "WX Quest", macro = "/run ToggleQuestLog()", bindingCommand = "TOGGLEQUESTLOG" },
    { id = "social", name = "Social", detail = "Friends/guild", icon = "Interface\\Icons\\INV_Misc_GroupLooking", macroName = "WX Social", macro = "/run ToggleFriendsFrame(1)", bindingCommand = "TOGGLESOCIAL" },
    { id = "lfg", name = "Dungeon Finder", detail = "LFD panel", icon = "Interface\\Icons\\Ability_DualWield", macroName = "WX LFG", macro = "/run if ToggleLFDParentFrame then ToggleLFDParentFrame() end" },
    { id = "achievements", name = "Achievements", detail = "Open achievements", icon = "Interface\\Icons\\Achievement_General", macroName = "WX Achieve", macro = "/run if ToggleAchievementFrame then ToggleAchievementFrame() end" },
}

local gridbookStateKeys = {
    [""] = "BASE",
    ["SHIFT"] = "SHIFT",
    ["ALT"] = "ALT",
    ["CTRL"] = "CTRL",
    ["SHIFT-ALT"] = "COMBO",
}

local function getGridbookStateKey(state)
    return gridbookStateKeys[state or ""] or "BASE"
end

local function resolveMacroIconIndex(texture)
    if type(texture) ~= "string" or texture == "" then
        return 1
    end

    if GetMacroIconInfo then
        local iconCount = GetNumMacroIcons and (tonumber(GetNumMacroIcons()) or 0) or 0
        if iconCount > 0 then
            local lowerNeedle = string.lower(texture)
            for idx = 1, iconCount do
                local candidate = GetMacroIconInfo(idx)
                if type(candidate) == "string" and string.lower(candidate) == lowerNeedle then
                    return idx
                end
            end

            local shortNeedle = lowerNeedle:gsub("^interface\\icons\\", "")
            for idx = 1, iconCount do
                local candidate = GetMacroIconInfo(idx)
                if type(candidate) == "string" then
                    local lowerCandidate = string.lower(candidate)
                    local shortCandidate = lowerCandidate:gsub("^interface\\icons\\", "")
                    if shortCandidate == shortNeedle then
                        return idx
                    end
                end
            end
        end
    end

    return 1
end

local function ensureGridbookDB()
    if not GPX.db then
        return nil
    end

    GPX.db.ui = GPX.db.ui or {}
    GPX.db.ui.gridbookByMachine = GPX.db.ui.gridbookByMachine or {}

    local machineKey = "__default"
    if GPX.GetMachineStateKey then
        machineKey = GPX:GetMachineStateKey()
    end

    local db = GPX.db.ui.gridbookByMachine[machineKey]
    if not db then
        db = {}
        -- One-time migration path: preserve existing shared gridbook content into this machine bucket.
        if type(GPX.db.ui.gridbook) == "table" then
            db = GPX:DeepCopy(GPX.db.ui.gridbook)
        end
        GPX.db.ui.gridbookByMachine[machineKey] = db
    end

    GPX.db.ui.gridbook = db
    db.version = tonumber(db.version) or 1
    db.pages = db.pages or {}
    db.autoSync = db.autoSync ~= false
    if db.spellRankView ~= "all" and db.spellRankView ~= "highest" then
        db.spellRankView = "highest"
    end

    for _, page in ipairs(gridbookPages) do
        local key = getGridbookStateKey(page.state)
        db.pages[key] = db.pages[key] or {}
    end

    return db
end

local function persistMachineState(reason)
    if GPX and GPX.SaveMachineScopedState then
        GPX:SaveMachineScopedState(reason or "gridbook", true)
    end
end

local function normalizeSpellFamilyKey(name)
    local text = tostring(name or "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return string.lower(text)
end

local function getSpellBookRankText(bookSlot)
    local rankText = nil
    if GetSpellBookItemName then
        local _, subName = GetSpellBookItemName(bookSlot, BOOK)
        rankText = subName
    end
    if (not rankText or rankText == "") and GetSpellSubtext then
        rankText = GetSpellSubtext(bookSlot, BOOK)
    end
    rankText = tostring(rankText or "")
    local rankNumber = tonumber(string.match(rankText, "(%d+)")) or 0
    return rankText, rankNumber
end

local function buildEntryFromActionSlot(slot, command)
    if not slot or slot < 1 or not GetActionInfo then
        return nil
    end

    local actionType, actionID = GetActionInfo(slot)
    if not actionType or not actionID then
        return nil
    end

    local entry = {
        kind = actionType,
        id = actionID,
        command = command,
        slot = slot,
    }

    if actionType == "macro" and GetMacroInfo then
        local macroName = GetMacroInfo(actionID)
        entry.macroName = macroName
    elseif actionType == "spell" and GetSpellInfo then
        local spellName = GetSpellInfo(actionID)
        entry.name = spellName
    elseif actionType == "item" and GetItemInfo then
        local itemName = GetItemInfo(actionID)
        entry.name = itemName
    end

    if GetActionTexture then
        entry.icon = GetActionTexture(slot)
    end

    return entry
end

local function placeEntryAtSlot(entry, slot)
    if not entry or not slot or slot < 1 then
        return false
    end

    local kind = tostring(entry.kind or "")
    local id = tonumber(entry.id)
    if not id then
        return false
    end

    if kind == "spell" and PickupSpell then
        local ok = pcall(PickupSpell, id)
        if not ok then
            return false
        end
    elseif kind == "item" and PickupItem then
        local ok = pcall(PickupItem, id)
        if not ok then
            return false
        end
    elseif kind == "macro" and PickupMacro then
        local macroIndex = nil
        if entry.macroName and GetMacroIndexByName then
            macroIndex = GetMacroIndexByName(entry.macroName)
        end
        if (not macroIndex or macroIndex <= 0) and id then
            macroIndex = id
        end
        if not macroIndex or macroIndex <= 0 then
            return false
        end
        local ok = pcall(PickupMacro, macroIndex)
        if not ok then
            return false
        end
    else
        return false
    end

    if not GetCursorInfo or not GetCursorInfo() then
        return false
    end
    PlaceAction(slot)
    ClearCursor()
    return true
end

local function setSpellTooltip(tooltip, bookSlot)
    if not tooltip or not bookSlot then
        return false
    end

    if tooltip.SetSpellBookItem then
        local ok = pcall(tooltip.SetSpellBookItem, tooltip, bookSlot, BOOK)
        if ok then
            return true
        end
    end

    if tooltip.SetSpell then
        local ok = pcall(tooltip.SetSpell, tooltip, bookSlot, BOOK)
        if ok then
            return true
        end
    end

    local spellName = GetSpellBookItemName and GetSpellBookItemName(bookSlot, BOOK) or nil
    if spellName then
        tooltip:AddLine(spellName, 1.0, 0.92, 0.58)
        tooltip:AddLine(IsPassiveSpell and IsPassiveSpell(bookSlot, BOOK) and "Passive" or "Spell", 0.82, 0.9, 1.0)
        return true
    end

    return false
end

local function pickupSpellBookSlot(bookSlot)
    if not bookSlot then
        return false
    end

    if PickupSpellBookItem then
        local ok = pcall(PickupSpellBookItem, bookSlot, BOOK)
        if ok and GetCursorInfo and GetCursorInfo() then
            return true
        end
    end

    if PickupSpell then
        local ok = pcall(PickupSpell, bookSlot, BOOK)
        if ok and GetCursorInfo and GetCursorInfo() then
            return true
        end

        local spellID = nil
        if GetSpellBookItemInfo then
            local _, id = GetSpellBookItemInfo(bookSlot, BOOK)
            spellID = id
        end
        if spellID then
            ok = pcall(PickupSpell, spellID)
            if ok and GetCursorInfo and GetCursorInfo() then
                return true
            end
        end
    end

    return false
end

local function shouldCaptureCommand(command)
    if not command or command == "" then
        return false
    end
    return command:find("^ACTIONBUTTON")
        or command:find("^MULTIACTIONBAR1BUTTON")
        or command:find("^MULTIACTIONBAR2BUTTON")
        or command:find("^MULTIACTIONBAR3BUTTON")
        or command:find("^MULTIACTIONBAR4BUTTON")
end

local function createBackdrop(frame, borderR, borderG, borderB, borderA)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.05, 0.07, 0.11, 0.96)
    frame:SetBackdropBorderColor(borderR or 0.24, borderG or 0.7, borderB or 0.98, borderA or 0.86)
end

local function fallbackCommandForCell(state, slotIndex)
    if state == "SHIFT" then
        return "MULTIACTIONBAR2BUTTON" .. tostring(slotIndex)
    end
    if state == "ALT" then
        return "MULTIACTIONBAR1BUTTON" .. tostring(slotIndex)
    end
    if state == "CTRL" then
        return "MULTIACTIONBAR4BUTTON" .. tostring(slotIndex)
    end
    if state == "SHIFT-ALT" then
        return "MULTIACTIONBAR3BUTTON" .. tostring(slotIndex)
    end
    return "ACTIONBUTTON" .. tostring(slotIndex)
end

local function fallbackSlotForCommand(command)
    local index = tonumber(command and command:match("(%d+)$") or "")
    if not index or index < 1 then
        return nil
    end

    if command:find("^ACTIONBUTTON") then
        return index
    elseif command:find("^MULTIACTIONBAR2BUTTON") then
        return 48 + index
    elseif command:find("^MULTIACTIONBAR1BUTTON") then
        return 60 + index
    elseif command:find("^MULTIACTIONBAR4BUTTON") then
        return 36 + index
    elseif command:find("^MULTIACTIONBAR3BUTTON") then
        return 24 + index
    end

    return nil
end

local guideSlotLabels = {
    [1] = "1", [2] = "2", [3] = "3",
    [4] = "4", [5] = "5", [6] = "6",
    [7] = "7", [8] = "8", [9] = "9",
    [10] = "0", [11] = "-", [12] = "=",
}

local controllerActionKeyOrder = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" }

local function getControllerGuideSlotLabel(slotIndex)
    local profile = GPX:GetProfile()
    local setup = profile and profile.setup
    local styleId = GPX:GetEffectiveControllerStyleId(setup, profile)
    local labels = GPX:GetCombatDisplayLabels(styleId)
    local key = GPX:GetSetupActionKey(setup, slotIndex)

    if (not key or key == "") and setup and setup.jumpKey and tonumber(slotIndex) == 1 then
        key = setup.jumpKey
    end

    local normalizedKey = string.upper(tostring(key or ""))
    for index, actionKey in ipairs(controllerActionKeyOrder) do
        if normalizedKey == actionKey and labels and labels[index] and labels[index] ~= "" then
            return labels[index]
        end
    end

    local style = GPX:GetInputStyle(styleId)
    if setup and setup.jumpKey and string.upper(tostring(setup.jumpKey)) == normalizedKey then
        return style and style.confirmLabel or nil
    end

    return labels and labels[tonumber(slotIndex) or 0] or nil
end

local function getGuideSlotLabel(slotIndex)
    if GPX:IsControllerEnabled() then
        local label = getControllerGuideSlotLabel(slotIndex)
        if label and label ~= "" then
            return label
        end
    end
    return guideSlotLabels[tonumber(slotIndex) or 1] or tostring(slotIndex)
end

local function buildHighestSpellRankByName()
    local bestByName = {}
    local tabCount = tonumber(GetNumSpellTabs and GetNumSpellTabs() or 0) or 0

    for tabIndex = 1, tabCount do
        local _, _, offset, numSpells = GetSpellTabInfo(tabIndex)
        local totalSpells = tonumber(numSpells) or 0
        for localIndex = 1, totalSpells do
            local bookSlot = (offset or 0) + localIndex
            local spellName = GetSpellBookItemName and GetSpellBookItemName(bookSlot, BOOK) or nil
            if spellName and spellName ~= "" then
                local _, rankNumber = getSpellBookRankText(bookSlot)
                local key = normalizeSpellFamilyKey(spellName)
                local existing = bestByName[key]
                if not existing or (tonumber(rankNumber) or 0) > (tonumber(existing.rankNumber) or 0) then
                    bestByName[key] = {
                        rankNumber = tonumber(rankNumber) or 0,
                    }
                end
            end
        end
    end

    return bestByName
end

local function getActionSpellRankNumber(spellID)
    local id = tonumber(spellID)
    if not id then
        return 0
    end

    local rankText = GetSpellSubtext and GetSpellSubtext(id) or nil
    local rankNumber = tonumber(string.match(tostring(rankText or ""), "(%d+)")) or 0
    return rankNumber
end

function UI:CreateFrame()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "WoWXSpellbookFrame", UIParent)
    local desiredWidth = 640
    local desiredHeight = 620
    frame:SetWidth(desiredWidth)
    frame:SetHeight(desiredHeight)
    frame:SetPoint("CENTER", UIParent, "CENTER", 180, 0)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:SetScript("OnHide", function()
        if UI and UI.FlushNativeBindingRefresh then
            UI:FlushNativeBindingRefresh()
        end
        if GPX.UIMode and GPX.UIMode.activeContext == "spellbook" then
            GPX.UIMode:Exit()
        end
    end)
    createBackdrop(frame)
    frame:Hide()

    -- Keep 12-card layout intact; scale down on low-resolution screens instead of clipping content.
    do
        local uiWidth = UIParent and UIParent:GetWidth() or desiredWidth
        local uiHeight = UIParent and UIParent:GetHeight() or desiredHeight
        local widthScale = (uiWidth - 40) / desiredWidth
        local heightScale = (uiHeight - 40) / desiredHeight
        local scale = math.min(1, widthScale, heightScale)
        if scale < 0.7 then
            scale = 0.7
        end
        frame:SetScale(scale)
    end

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -18)
    title:SetText(GPX.brand .. " Spellbook")
    title:SetTextColor(0.95, 0.97, 1.0)

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetWidth(590)
    subtitle:SetJustifyH("LEFT")

    local header = CreateFrame("Frame", nil, frame)
    header:SetWidth(600)
    header:SetHeight(82)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -72)

    local prevTab = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    prevTab:SetWidth(36)
    prevTab:SetHeight(24)
    prevTab:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 44)
    prevTab:SetText("<")

    local nextTab = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    nextTab:SetWidth(36)
    nextTab:SetHeight(24)
    nextTab:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 44)
    nextTab:SetText(">")

    local modeGuide = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    modeGuide:SetWidth(90)
    modeGuide:SetHeight(26)
    modeGuide:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
    modeGuide:SetText("Guide")

    local modeSpells = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    modeSpells:SetWidth(90)
    modeSpells:SetHeight(26)
    modeSpells:SetPoint("LEFT", modeGuide, "RIGHT", 8, 0)
    modeSpells:SetText("Spells")

    local modeActions = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    modeActions:SetWidth(90)
    modeActions:SetHeight(26)
    modeActions:SetPoint("LEFT", modeSpells, "RIGHT", 8, 0)
    modeActions:SetText("Actions")

    local rankToggle = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    rankToggle:SetWidth(124)
    rankToggle:SetHeight(26)
    rankToggle:SetPoint("LEFT", modeActions, "RIGHT", 8, 0)
    rankToggle:SetText("Ranks: Max")
    rankToggle:SetScript("OnClick", function()
        UI:ToggleSpellRankViewMode()
    end)

    local spellTabBar = CreateFrame("Frame", nil, header)
    spellTabBar:SetWidth(600)
    spellTabBar:SetHeight(50)
    spellTabBar:SetPoint("TOPLEFT", modeGuide, "BOTTOMLEFT", 0, -6)

    local tabLabel = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tabLabel:SetPoint("TOPLEFT", spellTabBar, "BOTTOMLEFT", 0, -4)

    local grid = CreateFrame("Frame", nil, frame)
    grid:SetWidth(600)
    grid:SetHeight(340)
    grid:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -78)

    local targetPanel = CreateFrame("Frame", nil, frame)
    targetPanel:SetWidth(600)
    targetPanel:SetHeight(58)
    targetPanel:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -10)
    targetPanel:EnableMouse(true)
    createBackdrop(targetPanel, 0.18, 0.3, 0.5, 0.8)
    targetPanel:SetBackdropColor(0.06, 0.08, 0.12, 0.92)

    local targetLabel = targetPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    targetLabel:SetPoint("TOPLEFT", targetPanel, "TOPLEFT", 10, -8)
    targetLabel:SetText("Target")

    local targetValue = targetPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    targetValue:SetPoint("LEFT", targetLabel, "RIGHT", 8, 0)
    targetValue:SetTextColor(1.0, 0.92, 0.58)

    local hiddenNote = targetPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hiddenNote:SetPoint("BOTTOMLEFT", targetPanel, "BOTTOMLEFT", 10, 6)
    hiddenNote:SetWidth(420)
    hiddenNote:SetJustifyH("LEFT")
    hiddenNote:SetText("")

    local hiddenEditToggle = CreateFrame("Button", nil, targetPanel, "UIPanelButtonTemplate")
    hiddenEditToggle:SetWidth(118)
    hiddenEditToggle:SetHeight(20)
    hiddenEditToggle:SetPoint("TOPRIGHT", targetPanel, "TOPRIGHT", -8, -4)
    hiddenEditToggle:SetText("Hidden Slots: Off")
    hiddenEditToggle:SetScript("OnClick", function()
        UI.allowHiddenSlotEdit = not (UI.allowHiddenSlotEdit == true)
        UI:Refresh()
    end)

    local saveButton = CreateFrame("Button", nil, targetPanel, "UIPanelButtonTemplate")
    saveButton:SetWidth(118)
    saveButton:SetHeight(20)
    saveButton:SetPoint("RIGHT", hiddenEditToggle, "LEFT", -6, 0)
    saveButton:SetText("Auto Sync")
    saveButton:SetScript("OnClick", function()
        GPX:Print("Gridbook sync is automatic from action bar state.")
    end)

    frame.navOrder = { prevTab, nextTab, modeGuide, modeSpells, modeActions, rankToggle }

    targetPanel:SetScript("OnEnter", function(self)
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Target Panel", 1.0, 0.92, 0.58)
        GameTooltip:AddLine("Left-click with cursor: place/replace on target slot.", 0.82, 0.9, 1.0)
        GameTooltip:AddLine("Right-click: clear target slot.", 0.82, 0.9, 1.0)
        GameTooltip:Show()
    end)
    targetPanel:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    targetPanel:SetScript("OnReceiveDrag", function()
        local targetSlot = UI:GetAssignmentTargetSlot() or UI:GetGridTargetSlot()
        if targetSlot then
            UI:TryPlaceCursorOnTarget(targetSlot, true)
        end
    end)
    targetPanel:SetScript("OnMouseUp", function(_, mouseButton)
        local targetSlot = UI:GetAssignmentTargetSlot() or UI:GetGridTargetSlot()
        if not targetSlot then
            return
        end
        if mouseButton == "RightButton" then
            UI:ClearActionSlot(targetSlot, true)
        elseif mouseButton == "LeftButton" and GetCursorInfo and GetCursorInfo() then
            UI:TryPlaceCursorOnTarget(targetSlot, true)
        end
    end)

    frame.spellTabButtons = {}
    for index = 1, 12 do
        local tabButton = CreateFrame("Button", nil, spellTabBar, "UIPanelButtonTemplate")
        tabButton:SetWidth(94)
        tabButton:SetHeight(22)
        local col = (index - 1) % 6
        local row = math.floor((index - 1) / 6)
        tabButton:SetPoint("TOPLEFT", spellTabBar, "TOPLEFT", col * 100, -row * 24)
        tabButton.tabIndex = index
        tabButton:SetText("Tab " .. index)
        tabButton:SetScript("OnClick", function(self)
            UI.currentTab = self.tabIndex
            UI.currentSpellPage = 1
            UI:Refresh()
        end)
        tabButton:Hide()
        frame.spellTabButtons[index] = tabButton
        frame.navOrder[#frame.navOrder + 1] = tabButton
    end

    frame.pageButtons = {}
    for index, entry in ipairs(gridbookPages) do
        local pageButton = CreateFrame("Button", nil, grid, "UIPanelButtonTemplate")
        pageButton:SetWidth(index == 5 and 72 or 58)
        pageButton:SetHeight(34)
        if index == 1 then
            pageButton:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, -2)
        else
            pageButton:SetPoint("TOPLEFT", frame.pageButtons[index - 1], "BOTTOMLEFT", 0, -8)
        end
        pageButton.pageState = entry.state
        pageButton.baseLabel = entry.label
        pageButton:SetText(entry.label)
        pageButton:SetScript("OnClick", function(self)
            UI.selectedPageState = self.pageState
            UI:Refresh()
        end)
        frame.pageButtons[index] = pageButton
        frame.navOrder[#frame.navOrder + 1] = pageButton
    end

    frame.slotButtons = {}
    for slotIndex = 1, 12 do
        local slotButton = CreateFrame("Button", nil, targetPanel, "UIPanelButtonTemplate")
        slotButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        slotButton:SetWidth(24)
        slotButton:SetHeight(20)
        local col = (slotIndex - 1) % 6
        local row = math.floor((slotIndex - 1) / 6)
        slotButton:SetPoint("TOPRIGHT", targetPanel, "TOPRIGHT", -10 - ((5 - col) * 26), -6 - (row * 22))
        slotButton.slotIndex = slotIndex
        slotButton:SetText(tostring(slotIndex))

        local slotIcon = slotButton:CreateTexture(nil, "ARTWORK")
        slotIcon:SetPoint("TOPLEFT", slotButton, "TOPLEFT", 2, -2)
        slotIcon:SetPoint("BOTTOMRIGHT", slotButton, "BOTTOMRIGHT", -2, 2)
        slotIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        slotIcon:Hide()
        slotButton._slotIcon = slotIcon
        slotButton:SetScript("OnClick", function(self, mouseButton)
            UI.selectedSlotIndex = self.slotIndex
            if mouseButton == "RightButton" then
                local targetSlot = UI:GetGridTargetSlot()
                if targetSlot then
                    UI:ClearActionSlot(targetSlot, true)
                end
                return
            end
            if UI.mode == "guide" then
                UI:BeginGuideAssignmentFlow(self.slotIndex)
                return
            end
            UI:Refresh()
        end)
        slotButton:SetScript("OnReceiveDrag", function(self)
            UI.selectedSlotIndex = self.slotIndex
            local targetSlot = UI:GetGridTargetSlot()
            if targetSlot then
                UI:TryPlaceCursorOnTarget(targetSlot, true)
            end
        end)
        slotButton:SetScript("OnEnter", function(self)
            if not GameTooltip then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local maxSlot = UI:GetGridMaxAssignableSlot()
            if self.slotIndex <= maxSlot then
                GameTooltip:AddLine("Slot " .. tostring(self.slotIndex), 1.0, 0.92, 0.58)
                GameTooltip:AddLine("Assignable in current mode.", 0.82, 0.9, 1.0)
            elseif UI.allowHiddenSlotEdit then
                GameTooltip:AddLine("Slot " .. tostring(self.slotIndex), 1.0, 0.82, 0.4)
                GameTooltip:AddLine("Hidden in controller mode, but editable right now.", 1.0, 0.76, 0.4)
                GameTooltip:AddLine("This slot may not be castable from current controller mapping.", 0.82, 0.9, 1.0, true)
            else
                GameTooltip:AddLine("Slot " .. tostring(self.slotIndex), 1.0, 0.82, 0.4)
                GameTooltip:AddLine("Not accessible in current controller mode.", 1.0, 0.5, 0.5)
                GameTooltip:AddLine("Max active slots right now: " .. tostring(maxSlot), 0.82, 0.9, 1.0)
            end
            GameTooltip:Show()
        end)
        slotButton:SetScript("OnLeave", function()
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)
        frame.slotButtons[slotIndex] = slotButton
        frame.navOrder[#frame.navOrder + 1] = slotButton
    end

    frame.navOrder[#frame.navOrder + 1] = hiddenEditToggle

    frame.spellButtons = {}
    for index = 1, 12 do
        local button = CreateFrame("Button", nil, grid)
        button:SetWidth(162)
        button:SetHeight(70)
        local col = (index - 1) % 3
        local row = math.floor((index - 1) / 3)
        button:SetPoint("TOPLEFT", grid, "TOPLEFT", 86 + (col * 172), -row * 82)
        createBackdrop(button, 0.16, 0.22, 0.3, 0.8)

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetWidth(44)
        icon:SetHeight(44)
        icon:SetPoint("LEFT", button, "LEFT", 10, 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local name = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 2)
        name:SetPoint("RIGHT", button, "RIGHT", -10, 0)
        name:SetJustifyH("LEFT")

        local detail = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        detail:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -6)
        detail:SetPoint("RIGHT", button, "RIGHT", -10, 0)
        detail:SetJustifyH("LEFT")

        local slotBadge = button:CreateTexture(nil, "OVERLAY")
        slotBadge:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        slotBadge:SetWidth(30)
        slotBadge:SetHeight(30)
        slotBadge:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
        slotBadge:Hide()

        local slotBadgeText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        slotBadgeText:SetPoint("CENTER", slotBadge, "CENTER", 0, 0)
        slotBadgeText:SetTextColor(1.0, 0.95, 0.75)
        slotBadgeText:Hide()

        button.icon = icon
        button.name = name
        button.detail = detail
        button.slotBadge = slotBadge
        button.slotBadgeText = slotBadgeText
        frame.spellButtons[index] = button
        frame.navOrder[#frame.navOrder + 1] = button
    end

    prevTab:SetScript("OnClick", function() UI:ChangeTab(-1) end)
    nextTab:SetScript("OnClick", function() UI:ChangeTab(1) end)
    modeGuide:SetScript("OnClick", function() UI:SetMode("guide") end)
    modeSpells:SetScript("OnClick", function() UI:SetMode("spells") end)
    modeActions:SetScript("OnClick", function()
        if UI:IsActionsModeAvailable() then
            UI:SetMode("actions")
        end
    end)

    for _, button in ipairs(frame.spellButtons) do
        button:SetScript("OnClick", function(self)
            UI:AssignSelection(self, self.spellBookSlot)
        end)
        button:SetScript("OnReceiveDrag", function(self)
            UI:AssignSelection(self, self.spellBookSlot)
        end)
        button:SetScript("OnEnter", function(self)
            if self.guideSlotIndex then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local slotLabel = getGuideSlotLabel(self.guideSlotIndex)
                GameTooltip:AddLine("Grid Slot " .. tostring(slotLabel), 1.0, 0.92, 0.58)
                if self.guideCommand then
                    GameTooltip:AddLine(self.guideCommand, 0.82, 0.9, 1.0)
                end
                if self.guideBlocked then
                    GameTooltip:AddLine("Unavailable in current controller layout.", 1.0, 0.5, 0.5)
                end
                GameTooltip:Show()
            elseif self.utilityAction then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(self.utilityAction.name, 1.0, 0.92, 0.58)
                GameTooltip:AddLine(self.utilityAction.detail, 0.85, 0.9, 1.0)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Places a WoWX utility macro on the selected slot.", 0.75, 0.82, 0.9, true)
                GameTooltip:Show()
            elseif self.spellBookSlot then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                setSpellTooltip(GameTooltip, self.spellBookSlot)
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 18)
    footer:SetWidth(590)
    footer:SetJustifyH("LEFT")

    self.frame = frame
    self.frame.subtitle = subtitle
    self.frame.prevTab = prevTab
    self.frame.nextTab = nextTab
    self.frame.tabLabel = tabLabel
    self.frame.footer = footer
    self.frame.modeGuide = modeGuide
    self.frame.modeSpells = modeSpells
    self.frame.modeActions = modeActions
    self.frame.rankToggle = rankToggle
    self.frame.grid = grid
    self.frame.targetPanel = targetPanel
    self.frame.targetValue = targetValue
    self.frame.hiddenNote = hiddenNote
    self.frame.hiddenEditToggle = hiddenEditToggle
    self.frame.saveButton = saveButton

    if GPX.UIMode then
        GPX.UIMode:RegisterContext("spellbook", {
            label = "Spellbook",
            getItems = function()
                return UI.frame and UI.frame.navOrder or {}
            end,
            columns = 3,
            isAvailable = function()
                return UI.frame and UI.frame:IsShown()
            end,
            onCancel = function()
                UI:ReturnToPreviousContext()
            end,
            getIndicatorText = function(_, baseText)
                if UI.pendingActionSlot then
                    return "Assigning to action slot " .. UI.pendingActionSlot .. "   " .. baseText
                end
                return "Browsing spellbook   " .. baseText
            end,
        })
    end
end

function UI:GetGridTargetCommand()
    return self:GetGridCommandFor(self.selectedPageState or "", tonumber(self.selectedSlotIndex) or 1)
end

function UI:GetGridCommandFor(state, slotIndex)
    state = state or ""
    local slotIndex = tonumber(slotIndex) or 1
    slotIndex = math.max(1, math.min(slotIndex, 12))

    if GPX.ClickTransport and GPX.ClickTransport.CommandForCell then
        return GPX.ClickTransport:CommandForCell(state, slotIndex, true)
    end

    return fallbackCommandForCell(state, slotIndex)
end

function UI:GetGridMaxAssignableSlot()
    if GPX:IsControllerEnabled() then
        local profile = GPX:GetProfile()
        local setup = profile and profile.setup or nil
        local count = GPX:GetConfiguredActionButtonCount(setup, profile)
        return math.max(1, math.min(12, tonumber(count) or 10))
    end
    return 12
end

function UI:IsGridSlotAccessible(slotIndex)
    local slot = tonumber(slotIndex) or 0
    if slot < 1 then
        return false
    end
    return slot <= self:GetGridMaxAssignableSlot()
end

function UI:CanAssignToGridSlot(slotIndex)
    local slot = tonumber(slotIndex) or 0
    if slot < 1 then
        return false
    end

    if slot <= 12 then
        if self:IsGridSlotAccessible(slot) then
            return true
        end
        return GPX:IsControllerEnabled() and self.allowHiddenSlotEdit == true
    end

    local logicalSlot = tonumber(self.selectedSlotIndex) or 1
    if logicalSlot >= 1 and logicalSlot <= 12 then
        if self:IsGridSlotAccessible(logicalSlot) then
            return true
        end
        return GPX:IsControllerEnabled() and self.allowHiddenSlotEdit == true
    end

    return not GPX:IsControllerEnabled()
end

function UI:GetGridTargetSlot()
    return self:GetGridSlotForCommand(self:GetGridTargetCommand())
end

function UI:GetGridSlotForCommand(command)
    if not command or command == "" then
        return nil
    end
    if GPX.ClickTransport and GPX.ClickTransport.StaticSlotForCommand then
        local slot = GPX.ClickTransport:StaticSlotForCommand(command)
        if slot then
            return slot
        end
    end
    return fallbackSlotForCommand(command)
end

function UI:SaveGridbookEntryForTarget(targetSlot)
    local slot = tonumber(targetSlot)
    if not slot or slot < 1 then
        return
    end

    local db = ensureGridbookDB()
    if not db then
        return
    end

    local selectedState = self.selectedPageState or ""
    local selectedIndex = tonumber(self.selectedSlotIndex) or 1
    selectedIndex = math.max(1, math.min(12, selectedIndex))

    local pageKey = getGridbookStateKey(selectedState)
    db.pages[pageKey] = db.pages[pageKey] or {}
    local command = self:GetGridCommandFor(selectedState, selectedIndex)
    local entry = buildEntryFromActionSlot(slot, command)
    db.pages[pageKey][selectedIndex] = entry
    persistMachineState("gridbook-save-target")
end

function UI:CaptureGridbookEntryForActionSlot(actionSlot)
    local slot = tonumber(actionSlot)
    if not slot or slot < 1 then
        return false
    end

    local db = ensureGridbookDB()
    if not db then
        return false
    end

    for _, page in ipairs(gridbookPages) do
        local pageKey = getGridbookStateKey(page.state)
        db.pages[pageKey] = db.pages[pageKey] or {}

        for slotIndex = 1, 12 do
            local command = self:GetGridCommandFor(page.state, slotIndex)
            if shouldCaptureCommand(command) then
                local mappedSlot = self:GetGridSlotForCommand(command)
                if mappedSlot == slot then
                    db.pages[pageKey][slotIndex] = buildEntryFromActionSlot(slot, command)
                    persistMachineState("gridbook-capture-slot")
                    return true
                end
            end
        end
    end

    return false
end

function UI:CaptureGridbookFromActionSlots()
    local db = ensureGridbookDB()
    if not db then
        return false
    end

    local changedAny = false
    for _, page in ipairs(gridbookPages) do
        local pageKey = getGridbookStateKey(page.state)
        db.pages[pageKey] = db.pages[pageKey] or {}
        for slotIndex = 1, 12 do
            local command = self:GetGridCommandFor(page.state, slotIndex)
            if shouldCaptureCommand(command) then
                local actionSlot = self:GetGridSlotForCommand(command)
                if actionSlot then
                    local newEntry = buildEntryFromActionSlot(actionSlot, command)
                    local oldEntry = db.pages[pageKey][slotIndex]
                    local oldKind = oldEntry and oldEntry.kind or nil
                    local oldID = oldEntry and oldEntry.id or nil
                    local newKind = newEntry and newEntry.kind or nil
                    local newID = newEntry and newEntry.id or nil
                    if oldKind ~= newKind or oldID ~= newID then
                        db.pages[pageKey][slotIndex] = newEntry
                        changedAny = true
                    end
                end
            end
        end
    end

    if changedAny then
        persistMachineState("gridbook-capture-all")
    end
    return changedAny
end

function UI:HasAnyGridbookEntries()
    local db = ensureGridbookDB()
    if not db then
        return false
    end

    local pages = db.pages or {}
    for _, page in ipairs(gridbookPages) do
        local pageKey = getGridbookStateKey(page.state)
        local pageEntries = pages[pageKey]
        if type(pageEntries) == "table" then
            for slotIndex = 1, 12 do
                local entry = pageEntries[slotIndex]
                if type(entry) == "table" and entry.kind and entry.id then
                    return true
                end
            end
        end
    end

    return false
end

function UI:SyncGridbookToActionSlots()
    local db = ensureGridbookDB()
    if not db or db.autoSync == false then
        return false
    end
    if InCombatLockdown() then
        self.pendingGridbookSync = true
        return false
    end

    local pages = db.pages or {}
    local syncedAny = false

    for _, page in ipairs(gridbookPages) do
        local pageKey = getGridbookStateKey(page.state)
        local pageEntries = pages[pageKey]
        if type(pageEntries) == "table" then
            for slotIndex = 1, 12 do
                local entry = pageEntries[slotIndex]
                if type(entry) == "table" and entry.kind and entry.id then
                    local command = self:GetGridCommandFor(page.state, slotIndex)
                    local actionSlot = self:GetGridSlotForCommand(command)
                    if actionSlot then
                        local currentType, currentID = GetActionInfo(actionSlot)
                        if currentType ~= entry.kind or currentID ~= entry.id then
                            if placeEntryAtSlot(entry, actionSlot) then
                                syncedAny = true
                            end
                        end
                    end
                end
            end
        end
    end

    return syncedAny
end

function UI:GetHiddenAssignmentCountForSelectedPage()
    if not GPX:IsControllerEnabled() then
        return 0, 12
    end

    local maxSlot = self:GetGridMaxAssignableSlot()
    local state = self.selectedPageState or ""
    local hiddenCount = 0

    for slotIndex = maxSlot + 1, 12 do
        local command = self:GetGridCommandFor(state, slotIndex)
        local actionSlot = self:GetGridSlotForCommand(command)
        if actionSlot and GetActionTexture and GetActionTexture(actionSlot) then
            hiddenCount = hiddenCount + 1
        end
    end

    return hiddenCount, maxSlot
end

function UI:GetAssignmentTargetSlot()
    if self.pendingActionSlot then
        return self.pendingActionSlot
    end
    return self:GetGridTargetSlot()
end

function UI:WriteGridbookForSlot(targetSlot, useSelectedPage)
    local slot = tonumber(targetSlot)
    if not slot or slot < 1 then
        return false
    end

    if useSelectedPage then
        self:SaveGridbookEntryForTarget(slot)
        return true
    end

    return self:CaptureGridbookEntryForActionSlot(slot)
end

function UI:PlacePickedCursorOnSlot(targetSlot)
    local slot = tonumber(targetSlot)
    if not slot or slot < 1 then
        return false, "No target slot selected."
    end

    if not GetCursorInfo or not GetCursorInfo() then
        return false, "Nothing is selected to place."
    end

    local cursorType = GetCursorInfo and select(1, GetCursorInfo()) or nil
    PlaceAction(slot)
    -- Keep action cursor on swap/move so users can continue chaining placements.
    if cursorType ~= "action" then
        ClearCursor()
    end
    return true
end

function UI:TryPlaceCursorOnTarget(targetSlot, useSelectedPage)
    local slot = tonumber(targetSlot)
    if not slot or slot < 1 then
        return false
    end
    if not GetCursorInfo or not GetCursorInfo() then
        return false
    end
    if InCombatLockdown() then
        GPX:Print("Assignment is blocked in combat.")
        return false
    end
    if not self:CanAssignToGridSlot(slot) then
        GPX:Print("Slot " .. tostring(slot) .. " is not accessible in current input mode.")
        return false
    end

    local nativeUtilityBefore = self:IsNativeUtilityMacroAtSlot(slot)

    local ok, placeErr = self:PlacePickedCursorOnSlot(slot)
    if not ok then
        GPX:Print(placeErr or "Could not place on selected slot.")
        return false
    end

    self:HandlePostPlacement(slot, "Placed onto WoWX action slot " .. slot .. ".", useSelectedPage, nativeUtilityBefore)
    return true
end

function UI:ClearActionSlot(targetSlot, useSelectedPage)
    local slot = tonumber(targetSlot)
    if not slot or slot < 1 or not PickupAction then
        return false
    end
    if InCombatLockdown() then
        GPX:Print("Assignment is blocked in combat.")
        return false
    end
    if not self:CanAssignToGridSlot(slot) then
        GPX:Print("Slot " .. tostring(slot) .. " is not accessible in current input mode.")
        return false
    end

    local nativeUtilityBefore = self:IsNativeUtilityMacroAtSlot(slot)

    PickupAction(slot)
    ClearCursor()
    self:HandlePostPlacement(slot, "Cleared WoWX action slot " .. slot .. ".", useSelectedPage, nativeUtilityBefore)
    return true
end

function UI:HandlePostPlacement(targetSlot, msg, useSelectedPage, nativeUtilityBefore)
    self:WriteGridbookForSlot(targetSlot, useSelectedPage)

    local nativeUtilityAfter = self:IsNativeUtilityMacroAtSlot(targetSlot)
    if nativeUtilityBefore or nativeUtilityAfter then
        self:ScheduleNativeBindingRefresh()
    end

    if GPX.VisualBar then
        GPX.VisualBar:UpdateAll()
    end

    if msg and msg ~= "" then
        GPX:Print(msg)
    end

    if self.pendingActionSlot then
        if self.assignmentOrigin == "guide" then
            self.pendingActionSlot = nil
            self.assignmentOrigin = nil
            self.mode = "guide"
            self:CaptureGridbookFromActionSlots()
            self:Refresh()
        else
            self:ReturnToPreviousContext()
        end
    else
        self:CaptureGridbookFromActionSlots()
        self:Refresh()
    end
end

function UI:BeginGuideAssignmentFlow(slotIndex)
    self.selectedSlotIndex = tonumber(slotIndex) or self.selectedSlotIndex or 1
    local targetSlot = self:GetGridTargetSlot()
    if not targetSlot then
        GPX:Print("No target slot selected. Pick a Gridbook page + slot first.")
        return
    end
    if not self:CanAssignToGridSlot(targetSlot) then
        GPX:Print("Slot " .. tostring(targetSlot) .. " is not accessible in current input mode.")
        return
    end

    self.pendingActionSlot = targetSlot
    self.assignmentOrigin = "guide"
    self.mode = "spells"
    self.currentSpellPage = 1
    self:Refresh()
end

function UI:IsActionsModeAvailable()
    return GPX:IsControllerEnabled() == true
end

function UI:SetMode(mode)
    if mode ~= "actions" and mode ~= "spells" and mode ~= "guide" then
        mode = "guide"
    end
    if mode == "actions" and not self:IsActionsModeAvailable() then
        mode = "spells"
    end
    self.mode = mode
    self.currentTab = 1
    self.currentSpellPage = 1
    self:Refresh()
end

function UI:GetTabCount()
    return GetNumSpellTabs() or 0
end

function UI:GetSpellRankViewMode()
    local db = ensureGridbookDB()
    if not db then
        return "highest"
    end
    if db.spellRankView ~= "all" and db.spellRankView ~= "highest" then
        db.spellRankView = "highest"
    end
    return db.spellRankView
end

function UI:SetSpellRankViewMode(mode)
    local db = ensureGridbookDB()
    if not db then
        return
    end
    if mode ~= "all" and mode ~= "highest" then
        mode = "highest"
    end
    if db.spellRankView ~= mode then
        db.spellRankView = mode
        self.currentSpellPage = 1
        persistMachineState("gridbook-rank-mode")
    end
end

function UI:ToggleSpellRankViewMode()
    local current = self:GetSpellRankViewMode()
    if current == "all" then
        self:SetSpellRankViewMode("highest")
    else
        self:SetSpellRankViewMode("all")
    end
    self:Refresh()
end

function UI:BuildSpellRowsForTab(tabIndex)
    local tab = tonumber(tabIndex) or 1
    if tab < 1 then
        tab = 1
    end

    local tabName, _, offset, numSpells = GetSpellTabInfo(tab)
    local totalSpells = tonumber(numSpells) or 0
    local rows = {}

    if totalSpells > 0 then
        for localIndex = 1, totalSpells do
            local bookSlot = (offset or 0) + localIndex
            local spellName = GetSpellBookItemName and GetSpellBookItemName(bookSlot, BOOK) or nil
            local icon = nil
            if GetSpellBookItemTexture then
                icon = GetSpellBookItemTexture(bookSlot, BOOK)
            elseif GetSpellTexture then
                icon = GetSpellTexture(bookSlot, BOOK)
            end

            if not icon and GetSpellBookItemInfo and GetSpellTexture then
                local _, spellID = GetSpellBookItemInfo(bookSlot, BOOK)
                if spellID then
                    icon = GetSpellTexture(spellID)
                end
            end

            if spellName then
                local rankText, rankNumber = getSpellBookRankText(bookSlot)
                rows[#rows + 1] = {
                    slot = bookSlot,
                    name = spellName,
                    icon = icon,
                    passive = IsPassiveSpell and IsPassiveSpell(bookSlot, BOOK) or false,
                    rankText = rankText,
                    rankNumber = rankNumber,
                    detail = rankText ~= "" and rankText or nil,
                }
            end
        end
    end

    if self:GetSpellRankViewMode() == "all" then
        return rows, (tabName or "Spells")
    end

    local bestBySpell = {}
    for _, row in ipairs(rows) do
        local key = normalizeSpellFamilyKey(row.name)
        local existing = bestBySpell[key]
        if not existing then
            bestBySpell[key] = row
        else
            local rowRank = tonumber(row.rankNumber) or 0
            local existingRank = tonumber(existing.rankNumber) or 0
            local rowSlot = tonumber(row.slot) or 0
            local existingSlot = tonumber(existing.slot) or 0
            if rowRank > existingRank or (rowRank == existingRank and rowSlot > existingSlot) then
                bestBySpell[key] = row
            end
        end
    end

    local condensed = {}
    for _, row in pairs(bestBySpell) do
        condensed[#condensed + 1] = row
    end

    table.sort(condensed, function(a, b)
        return (tonumber(a.slot) or 0) < (tonumber(b.slot) or 0)
    end)

    return condensed, (tabName or "Spells")
end

function UI:GetSpellPageCountForTab(tabIndex)
    local rows = self:BuildSpellRowsForTab(tabIndex)
    local count = #rows
    if count < 1 then
        return 1
    end
    return math.max(1, math.ceil(count / ACTIONS_PER_PAGE))
end

function UI:GetSpellSlotsForTab(tabIndex, pageIndex)
    local tab = tonumber(tabIndex) or 1
    if tab < 1 then
        tab = 1
    end

    local allRows, tabName = self:BuildSpellRowsForTab(tab)
    local totalRows = #allRows
    local spellPageCount = self:GetSpellPageCountForTab(tab)
    local page = tonumber(pageIndex) or 1
    if page < 1 then
        page = 1
    elseif page > spellPageCount then
        page = spellPageCount
    end

    local slots = {}
    if totalRows > 0 then
        local startIndex = ((page - 1) * ACTIONS_PER_PAGE) + 1
        local endIndex = math.min(totalRows, startIndex + ACTIONS_PER_PAGE - 1)

        for localIndex = startIndex, endIndex do
            slots[#slots + 1] = allRows[localIndex]
        end
    end

    return slots, (tabName or "Spells"), page, spellPageCount
end

function UI:GetActionsPageCount()
    local count = #utilityActions
    if count < 1 then
        return 1
    end
    return math.max(1, math.ceil(count / ACTIONS_PER_PAGE))
end

function UI:GetActionsForPage(pageIndex)
    local page = tonumber(pageIndex) or 1
    if page < 1 then
        page = 1
    end
    local out = {}
    local startIndex = ((page - 1) * ACTIONS_PER_PAGE) + 1
    local endIndex = math.min(#utilityActions, startIndex + ACTIONS_PER_PAGE - 1)
    for i = startIndex, endIndex do
        out[#out + 1] = utilityActions[i]
    end
    return out
end

function UI:GetGuideRowsForSelectedPage()
    local rows = {}
    local state = self.selectedPageState or ""
    local maxSlot = self:GetGridMaxAssignableSlot()
    local showHiddenSlots = not (GPX:IsControllerEnabled() and self.allowHiddenSlotEdit ~= true)
    local highestRankByName = buildHighestSpellRankByName()

    for slotIndex = 1, 12 do
        if not showHiddenSlots and slotIndex > maxSlot then
            break
        end

        local command = self:GetGridCommandFor(state, slotIndex)
        local actionSlot = self:GetGridSlotForCommand(command)
        local icon = actionSlot and GetActionTexture and GetActionTexture(actionSlot) or nil
        local name = "Empty"
        local detail = command

        if actionSlot then
            local actionEntry = buildEntryFromActionSlot(actionSlot, command)
            if actionEntry then
                if actionEntry.icon then
                    icon = actionEntry.icon
                end
                if actionEntry.kind == "spell" then
                    name = actionEntry.name or ("Spell " .. tostring(actionEntry.id))
                    detail = "Spell ID " .. tostring(actionEntry.id)
                    local key = normalizeSpellFamilyKey(name)
                    local highest = highestRankByName[key]
                    if highest and (tonumber(highest.rankNumber) or 0) > 0 then
                        local currentRank = getActionSpellRankNumber(actionEntry.id)
                        if currentRank > 0 and currentRank < (tonumber(highest.rankNumber) or 0) then
                            detail = detail .. "  (rank " .. tostring(currentRank) .. " < max " .. tostring(highest.rankNumber) .. ")"
                        end
                    end
                elseif actionEntry.kind == "item" then
                    name = actionEntry.name or ("Item " .. tostring(actionEntry.id))
                    detail = "Item ID " .. tostring(actionEntry.id)
                elseif actionEntry.kind == "macro" then
                    name = actionEntry.macroName or actionEntry.name or ("Macro " .. tostring(actionEntry.id))
                    detail = "Macro ID " .. tostring(actionEntry.id)
                elseif actionEntry.kind and actionEntry.id then
                    name = tostring(actionEntry.kind) .. " " .. tostring(actionEntry.id)
                    detail = "Action ID " .. tostring(actionEntry.id)
                end
            end
        end

        rows[#rows + 1] = {
            guideEntry = true,
            guideSlotIndex = slotIndex,
            command = command,
            icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark",
            name = getGuideSlotLabel(slotIndex),
            detail = name == "Empty" and ("Empty - " .. detail) or detail,
        }
    end

    return rows
end

function UI:Refresh()
    if not self.frame then
        return
    end

    if self.mode == "actions" and not self:IsActionsModeAvailable() then
        self.mode = "spells"
        self.currentTab = 1
        self.currentSpellPage = 1
    end

    local mode = self.mode or "guide"
    local totalTabs = 1
    local pageIndex = self.currentSpellPage or 1
    local pageCount = 1
    if mode == "actions" then
        totalTabs = self:GetActionsPageCount()
    elseif mode == "spells" then
        totalTabs = self:GetTabCount()
    end
    if totalTabs < 1 then
        self.currentTab = 1
    else
        if not self.currentTab or self.currentTab > totalTabs then
            self.currentTab = 1
        elseif self.currentTab < 1 then
            self.currentTab = totalTabs
        end
    end

    local rows = nil
    local tabName = nil
    if mode == "actions" then
        rows = self:GetActionsForPage(self.currentTab or 1)
        tabName = "Utility Actions"
    elseif mode == "guide" then
        rows = self:GetGuideRowsForSelectedPage()
        tabName = "Gridbook Guide"
    else
        local tabCount = self:GetTabCount()
        if tabCount < 1 then
            self.currentTab = 1
        else
            self.currentTab = math.max(1, math.min(self.currentTab or 1, tabCount))
        end
        rows, tabName, pageIndex, pageCount = self:GetSpellSlotsForTab(self.currentTab or 1, self.currentSpellPage or 1)
        self.currentSpellPage = pageIndex
    end
    if mode == "spells" then
        local rankModeLabel = self:GetSpellRankViewMode() == "all" and "All Ranks" or "Highest Rank"
        self.frame.tabLabel:SetText((tabName or "Spells") .. "  (Tab " .. tostring(self.currentTab or 1) .. "/" .. tostring(totalTabs) .. " | Page " .. tostring(pageIndex or 1) .. "/" .. tostring(pageCount or 1) .. " | " .. rankModeLabel .. ")")
    else
        self.frame.tabLabel:SetText((tabName or "Spells") .. "  (Page " .. tostring(self.currentTab or 1) .. "/" .. tostring(totalTabs) .. ")")
    end
        if self.frame.prevTab and self.frame.nextTab then
            local showPager = false
            if mode == "spells" then
                showPager = (pageCount or 1) > 1
            elseif mode == "actions" then
                showPager = totalTabs > 1
            end
            if showPager then
                self.frame.prevTab:Show()
                self.frame.nextTab:Show()
            else
                self.frame.prevTab:Hide()
                self.frame.nextTab:Hide()
            end
        end
    if self.frame.spellTabButtons then
        if mode == "spells" then
            local tabCount = self:GetTabCount()
            for index, button in ipairs(self.frame.spellTabButtons) do
                if index <= tabCount then
                    local tabName = GetSpellTabInfo(index)
                    local selected = (index == (self.currentTab or 1))
                    button.tabIndex = index
                    button:SetText((tabName or ("Tab " .. index)) .. (selected and " *" or ""))
                    button:SetAlpha(selected and 1.0 or 0.9)
                    button:Show()
                    button:Enable()
                else
                    button:Hide()
                end
            end
        else
            for _, button in ipairs(self.frame.spellTabButtons) do
                button:Hide()
            end
        end
    end
    if self.frame.modeGuide and self.frame.modeSpells and self.frame.modeActions then
        self.frame.modeGuide:SetText(mode == "guide" and "Guide *" or "Guide")
        self.frame.modeSpells:SetText(mode == "spells" and "Spells *" or "Spells")
        if self:IsActionsModeAvailable() then
            self.frame.modeActions:SetText(mode == "actions" and "Actions *" or "Actions")
            self.frame.modeActions:Enable()
            self.frame.modeActions:Show()
        else
            self.frame.modeActions:SetText("Actions")
            self.frame.modeActions:Disable()
            self.frame.modeActions:Hide()
        end
    end
    if self.frame.rankToggle then
        local rankMode = self:GetSpellRankViewMode()
        self.frame.rankToggle:SetText(rankMode == "all" and "Ranks: All" or "Ranks: Max")
        if mode == "spells" then
            self.frame.rankToggle:Show()
        else
            self.frame.rankToggle:Hide()
        end
    end

    local showTargetPanel = true
    if self.frame.targetPanel then
        if showTargetPanel then
            self.frame.targetPanel:Show()
            self.frame.targetPanel:ClearAllPoints()
            self.frame.targetPanel:SetPoint("TOPLEFT", self.frame.prevTab:GetParent(), "BOTTOMLEFT", 0, -10)
            self.frame.targetPanel:SetWidth(600)
            self.frame.targetPanel:SetHeight(58)
            if self.frame.grid then
                self.frame.grid:ClearAllPoints()
                self.frame.grid:SetPoint("TOPLEFT", self.frame.prevTab:GetParent(), "BOTTOMLEFT", 0, -78)
            end
        else
            self.frame.targetPanel:Hide()
            if self.frame.grid then
                self.frame.grid:ClearAllPoints()
                self.frame.grid:SetPoint("TOPLEFT", self.frame.prevTab:GetParent(), "BOTTOMLEFT", 0, -10)
            end
        end
    end

    if self.pendingActionSlot then
        self.frame.subtitle:SetText("Choose a spell or action and press Confirm to place it on the selected WoWX slot.")
        self.frame.footer:SetText("Assigning to action slot " .. self.pendingActionSlot .. ". Confirm places the focused entry. Cancel returns to the previous window.")
        if self.frame.targetValue then
            self.frame.targetValue:SetText("Focused Slot: " .. tostring(self.pendingActionSlot))
        end
        if self.frame.hiddenNote then
            self.frame.hiddenNote:SetText("")
        end
    elseif mode == "actions" then
        local command = self:GetGridTargetCommand() or "(none)"
        local slot = self:GetGridTargetSlot() or 0
        self.frame.subtitle:SetText("Choose a page + slot, then place a utility action without changing live gameplay state.")
        self.frame.footer:SetText("Editing " .. command .. " (slot " .. tostring(slot) .. "). Utility command keys remain machine-scoped.")
        if self.frame.targetValue then
            self.frame.targetValue:SetText(command)
        end
        if self.frame.hiddenNote then
            self.frame.hiddenNote:SetText("")
        end
    elseif mode ~= "guide" then
        local command = self:GetGridTargetCommand() or "(none)"
        local slot = self:GetGridTargetSlot() or 0
        self.frame.subtitle:SetText("Browse spells and click to place directly on the selected Gridbook page + slot.")
        self.frame.footer:SetText("Editing " .. command .. " (slot " .. tostring(slot) .. "). Change page/slot here; modifiers do not need to be held.")
        if self.frame.targetValue then
            self.frame.targetValue:SetText(command)
        end
        if self.frame.hiddenNote then
            local hiddenCount, maxSlot = self:GetHiddenAssignmentCountForSelectedPage()
            if GPX:IsControllerEnabled() and hiddenCount > 0 and self.allowHiddenSlotEdit ~= true then
                self.frame.hiddenNote:SetText("Hidden in controller mode on this page: " .. tostring(hiddenCount) .. " (slots " .. tostring(maxSlot + 1) .. "-12)")
                self.frame.hiddenNote:SetTextColor(1.0, 0.72, 0.4)
            elseif GPX:IsControllerEnabled() then
                self.frame.hiddenNote:SetText("Controller active slots on this page: 1-" .. tostring(maxSlot))
                self.frame.hiddenNote:SetTextColor(0.72, 0.86, 1.0)
            else
                self.frame.hiddenNote:SetText("")
            end
        end
    else
        local slot = self:GetGridTargetSlot() or 0
        local command = self:GetGridTargetCommand() or "(none)"
        local hiddenCount, maxSlot = self:GetHiddenAssignmentCountForSelectedPage()
        self.frame.subtitle:SetText("Gridbook guide mode: pick page, pick slot, then assign. Gameplay modifiers do not change this view.")
        self.frame.footer:SetText("Editing " .. command .. " (slot " .. tostring(slot) .. "). Order: 1) Page 2) Slot 3) Assign.")
        if self.frame.targetValue then
            self.frame.targetValue:SetText(command)
        end
        if self.frame.hiddenNote then
            if GPX:IsControllerEnabled() and hiddenCount > 0 then
                if self.allowHiddenSlotEdit then
                    self.frame.hiddenNote:SetText("Hidden controller slots on this page: " .. tostring(hiddenCount) .. " (editing enabled)")
                    self.frame.hiddenNote:SetTextColor(1.0, 0.82, 0.45)
                else
                    self.frame.hiddenNote:SetText("Hidden in controller mode on this page: " .. tostring(hiddenCount) .. " (slots " .. tostring(maxSlot + 1) .. "-12)")
                    self.frame.hiddenNote:SetTextColor(1.0, 0.72, 0.4)
                end
            elseif GPX:IsControllerEnabled() then
                self.frame.hiddenNote:SetText("Controller active slots on this page: 1-" .. tostring(maxSlot))
                self.frame.hiddenNote:SetTextColor(0.72, 0.86, 1.0)
            else
                self.frame.hiddenNote:SetText("")
            end
        end
    end

    if self.frame.pageButtons then
        local selectedState = self.selectedPageState or ""
        local pageLabels = nil
        if GPX:IsControllerEnabled() then
            local profile = GPX:GetProfile()
            local setup = profile and profile.setup
            local styleId = GPX:GetEffectiveControllerStyleId(setup, profile)
            pageLabels = GPX:GetPageLabels(styleId)
        end
        for _, button in ipairs(self.frame.pageButtons) do
            local selected = button.pageState == selectedState
            local label = (pageLabels and pageLabels[button.pageState]) or button.baseLabel
            button:SetText(label .. (selected and " *" or ""))
            button:SetAlpha(selected and 1.0 or 0.85)
            button:Show()
        end
    end
    if self.frame.slotButtons then
        local showSlotButtons = true
        local selectedSlot = tonumber(self.selectedSlotIndex) or 1
        local maxSlot = self:GetGridMaxAssignableSlot()
        local collapseHiddenSlots = GPX:IsControllerEnabled() and self.allowHiddenSlotEdit ~= true
        local state = self.selectedPageState or ""
        for _, button in ipairs(self.frame.slotButtons) do
            local selected = button.slotIndex == selectedSlot
            local accessible = button.slotIndex <= maxSlot
            local editableHidden = (not accessible) and GPX:IsControllerEnabled() and self.allowHiddenSlotEdit == true
            local command = self:GetGridCommandFor(state, button.slotIndex)
            local actionSlot = self:GetGridSlotForCommand(command)
            local actionTexture = actionSlot and GetActionTexture and GetActionTexture(actionSlot) or nil

            if button._slotIcon then
                if actionTexture then
                    button._slotIcon:SetTexture(actionTexture)
                    button._slotIcon:Show()
                else
                    button._slotIcon:SetTexture(nil)
                    button._slotIcon:Hide()
                end
            end

            button:SetText(selected and ("[" .. getGuideSlotLabel(button.slotIndex) .. "]") or getGuideSlotLabel(button.slotIndex))
            if accessible or editableHidden then
                button:Enable()
                button:SetAlpha(editableHidden and 0.65 or 1.0)
            else
                button:Disable()
                button:SetAlpha(0.35)
            end
            if showSlotButtons and (not collapseHiddenSlots or accessible or editableHidden) then
                button:Show()
            else
                button:Hide()
            end
        end
        if selectedSlot > maxSlot and not (GPX:IsControllerEnabled() and self.allowHiddenSlotEdit == true) then
            self.selectedSlotIndex = maxSlot
        end
    end
    if self.frame.hiddenEditToggle then
        if GPX:IsControllerEnabled() then
            self.frame.hiddenEditToggle:Show()
            self.frame.hiddenEditToggle:SetText((self.allowHiddenSlotEdit and "Hidden Slots: Edit" or "Hidden Slots: Off"))
        else
            self.frame.hiddenEditToggle:Hide()
        end
    end
    if self.frame.saveButton then
        self.frame.saveButton:Hide()
    end

    for index, button in ipairs(self.frame.spellButtons) do
        local data = rows[index]
        if data and mode == "guide" then
            local selectedGuideSlot = (tonumber(self.selectedSlotIndex) or 1) == (tonumber(data.guideSlotIndex) or 0)
            button.spellBookSlot = nil
            button.utilityAction = nil
            button.guideSlotIndex = data.guideSlotIndex
            button.guideCommand = data.command
            button.icon:SetTexture(data.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            button.name:SetText(data.name)
            button.detail:SetText(data.detail or "Action")
            local slotAccessible = self:IsGridSlotAccessible(data.guideSlotIndex)
            local editableHidden = (not slotAccessible) and GPX:IsControllerEnabled() and self.allowHiddenSlotEdit == true
            local canUse = slotAccessible or editableHidden
            button.guideBlocked = not canUse
            button:SetAlpha(canUse and 1.0 or 0.38)
            button.icon:SetDesaturated(not canUse)
            if canUse then
                button:Enable()
            else
                button:Disable()
            end
            if button.slotBadge and button.slotBadgeText then
                if GPX:IsControllerEnabled() then
                    local badgeBoost = selectedGuideSlot and 1.0 or 0.82
                    local alpha = (canUse and 1.0 or 0.45) * badgeBoost
                    local slotLabel = getGuideSlotLabel(data.guideSlotIndex)
                    local profile = GPX:GetProfile()
                    local setup = profile and profile.setup
                    local styleId = GPX:GetEffectiveControllerStyleId(setup, profile)
                    local btnTex = GPX:GetButtonTexture(styleId, slotLabel)
                    if btnTex then
                        button.slotBadge:SetTexture(btnTex)
                        button.slotBadge:SetTexCoord(0, 1, 0, 1)
                        button.slotBadge:SetVertexColor(alpha, alpha, alpha, 1.0)
                        button.slotBadgeText:SetText(selectedGuideSlot and "*" or "")
                    else
                        button.slotBadge:SetTexture("Interface\\Buttons\\UI-Quickslot2")
                        button.slotBadge:SetTexCoord(0, 1, 0, 1)
                        button.slotBadge:SetVertexColor(alpha, alpha, alpha, 1.0)
                        button.slotBadgeText:SetText(selectedGuideSlot and ("[" .. slotLabel .. "]") or slotLabel)
                    end
                    button.slotBadgeText:SetTextColor(canUse and 1.0 or 0.7, canUse and 0.95 or 0.7, canUse and 0.75 or 0.7)
                    button.slotBadge:Show()
                    button.slotBadgeText:Show()
                else
                    button.slotBadge:SetTexture("Interface\\Buttons\\UI-Quickslot2")
                    button.slotBadge:SetTexCoord(0, 1, 0, 1)
                    button.slotBadge:Hide()
                    button.slotBadgeText:Hide()
                end
            end
            button:Show()
        elseif data and mode == "actions" then
            button.spellBookSlot = nil
            button.utilityAction = data
            button.guideSlotIndex = nil
            button.guideCommand = nil
            button.guideBlocked = nil
            button.icon:SetTexture(data.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            button.name:SetText(data.name)
            button.detail:SetText(data.detail or "Action")
            button:SetAlpha(1.0)
            button.icon:SetDesaturated(false)
            button:Enable()
            if button.slotBadge and button.slotBadgeText then
                button.slotBadge:Hide()
                button.slotBadgeText:Hide()
            end
            button:Show()
        elseif data then
            button.spellBookSlot = data.slot
            button.utilityAction = nil
            button.guideSlotIndex = nil
            button.guideCommand = nil
            button.guideBlocked = nil
            button.icon:SetTexture(data.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            button.name:SetText(data.name)
            button.detail:SetText(data.detail or (data.passive and "Passive" or "Spell"))
            button:SetAlpha(1.0)
            button.icon:SetDesaturated(false)
            button:Enable()
            if button.slotBadge and button.slotBadgeText then
                button.slotBadge:Hide()
                button.slotBadgeText:Hide()
            end
            button:Show()
        else
            button.spellBookSlot = nil
            button.utilityAction = nil
            button.guideSlotIndex = nil
            button.guideCommand = nil
            button.guideBlocked = nil
            button.icon:SetTexture("Interface\\Buttons\\UI-Quickslot2")
            button.name:SetText("")
            button.detail:SetText("")
            button:SetAlpha(1.0)
            button.icon:SetDesaturated(false)
            button:Enable()
            if button.slotBadge and button.slotBadgeText then
                button.slotBadge:Hide()
                button.slotBadgeText:Hide()
            end
            button:Hide()
        end
    end

    if GPX.UIMode and GPX.UIMode.activeContext == "spellbook" then
        GPX.UIMode:SetFocus(GPX.UIMode.index or 4)
    end
end

function UI:ChangeTab(delta)
    local count = 1
    if self.mode == "actions" then
        count = self:GetActionsPageCount()
    elseif self.mode == "spells" then
        count = self:GetSpellPageCountForTab(self.currentTab or 1)
    end
    if count < 1 then
        return
    end
    if self.mode == "spells" then
        self.currentSpellPage = (self.currentSpellPage or 1) + delta
        if self.currentSpellPage < 1 then
            self.currentSpellPage = count
        elseif self.currentSpellPage > count then
            self.currentSpellPage = 1
        end
    else
        self.currentTab = (self.currentTab or 1) + delta
        if self.currentTab < 1 then
            self.currentTab = count
        elseif self.currentTab > count then
            self.currentTab = 1
        end
    end
    self:Refresh()
end

function UI:EnsureUtilityMacro(entry)
    if not entry then
        return nil, "Missing action entry."
    end

    local macroName = tostring(entry.macroName or entry.name or "WoWXAct")
    local iconTexture = tostring(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    local body = tostring(entry.macro or "")

    local iconIndex = resolveMacroIconIndex(iconTexture)

    local macroIndex = GetMacroIndexByName and GetMacroIndexByName(macroName) or 0
    if macroIndex and macroIndex > 0 then
        if EditMacro then
            local ok = pcall(EditMacro, macroIndex, macroName, iconIndex, body, 1)
            if not ok then
                pcall(EditMacro, macroIndex, macroName, iconIndex, body)
            end
        end
        return macroIndex
    end

    if not CreateMacro then
        return nil, "CreateMacro unavailable on this client."
    end

    local created = CreateMacro(macroName, iconIndex, body, 1)
    if not created or created == 0 then
        return nil, "Could not create macro (macro list may be full)."
    end
    return created
end

function UI:RepairUtilityMacros()
    if self._utilityMacrosRepaired then
        return
    end
    self._utilityMacrosRepaired = true

    if not EditMacro or not GetMacroIndexByName then
        return
    end

    for _, entry in ipairs(utilityActions) do
        local macroName = tostring(entry.macroName or entry.name or "WoWXAct")
        local macroIndex = GetMacroIndexByName(macroName) or 0
        if macroIndex and macroIndex > 0 then
            local iconIndex = resolveMacroIconIndex(tostring(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark"))
            local body = tostring(entry.macro or "")
            local ok = pcall(EditMacro, macroIndex, macroName, iconIndex, body, 1)
            if not ok then
                pcall(EditMacro, macroIndex, macroName, iconIndex, body)
            end
        end
    end
end

function UI:GetNativeBindingCommandForUtilityMacro(macroName)
    local name = tostring(macroName or "")
    if name == "" then
        return nil
    end

    -- Backward compatibility for older jump macro names.
    if name == "WX Jump" or name == "WX Jump Token" then
        return "JUMP"
    end

    for _, entry in ipairs(utilityActions) do
        if entry.macroName == name and entry.bindingCommand and entry.bindingCommand ~= "" then
            return entry.bindingCommand
        end
    end

    return nil
end

function UI:IsNativeUtilityMacroAtSlot(actionSlot)
    local slot = tonumber(actionSlot)
    if not slot or slot < 1 or not GetActionInfo or not GetMacroInfo then
        return false
    end

    local actionType, actionID = GetActionInfo(slot)
    if actionType ~= "macro" or not actionID then
        return false
    end

    local macroName = GetMacroInfo(actionID)
    local nativeCommand = self:GetNativeBindingCommandForUtilityMacro(macroName)
    return nativeCommand and nativeCommand ~= "" or false
end

function UI:GetUtilityIconForActionSlot(actionSlot)
    local slot = tonumber(actionSlot)
    if not slot or slot < 1 or not GetActionInfo or not GetMacroInfo then
        return nil
    end

    local actionType, actionID = GetActionInfo(slot)
    if actionType ~= "macro" or not actionID then
        return nil
    end

    local macroName = GetMacroInfo(actionID)
    if not macroName or macroName == "" then
        return nil
    end

    for _, entry in ipairs(utilityActions) do
        if entry.macroName == macroName and entry.icon and entry.icon ~= "" then
            return entry.icon
        end
    end

    return nil
end

function UI:ScheduleNativeBindingRefresh()
    if self.frame and self.frame:IsShown() then
        self._nativeBindingRefreshPending = true
        return
    end

    if self._nativeBindingRefreshQueued then
        return
    end

    self._nativeBindingRefreshQueued = true

    local function runRefresh()
        self._nativeBindingRefreshQueued = nil
        if not (GPX.db and GPX.db.enabled) then
            return
        end
        if InCombatLockdown() then
            self._nativeBindingRefreshAfterCombat = true
            return
        end
        GPX:ClearBindings(true)
        GPX:ApplyBindings(true)
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.08, runRefresh)
    else
        runRefresh()
    end
end

function UI:FlushNativeBindingRefresh()
    if not self._nativeBindingRefreshPending then
        return
    end

    self._nativeBindingRefreshPending = nil
    self:ScheduleNativeBindingRefresh()
end

function UI:UtilityJump()
    if JumpOrAscendStart then
        local ok = pcall(JumpOrAscendStart)
        if ok then
            return true
        end
    end

    if JumpStart then
        local ok = pcall(JumpStart)
        if ok then
            return true
        end
    end

    if Jump then
        local ok = pcall(Jump)
        if ok then
            return true
        end
    end

    if not self._jumpWarned then
        self._jumpWarned = true
        GPX:Print("Jump utility is unavailable on this client build.")
    end
    return false
end

function UI:AssignUtilityAction(entry)
    if not entry then
        return
    end

    local targetSlot = self:GetAssignmentTargetSlot()
    if not targetSlot then
        if self.mode ~= "guide" and not self.pendingActionSlot then
            return
        end
        GPX:Print("No target slot selected. Pick a Gridbook page + slot first.")
        return
    end
    if not self:CanAssignToGridSlot(targetSlot) then
        GPX:Print("Slot " .. tostring(targetSlot) .. " is not accessible in current input mode.")
        return
    end

    if InCombatLockdown() then
        GPX:Print("Action assignment is blocked in combat.")
        return
    end

    self:RepairUtilityMacros()

    local macroIndex, err = self:EnsureUtilityMacro(entry)
    if not macroIndex then
        GPX:Print(err or "Failed to prepare utility action macro.")
        return
    end

    local nativeUtilityBefore = self:IsNativeUtilityMacroAtSlot(targetSlot)

    PickupMacro(macroIndex)
    local ok, placeErr = self:PlacePickedCursorOnSlot(targetSlot)
    if not ok then
        GPX:Print(placeErr or "Could not place action.")
        return
    end

    self:HandlePostPlacement(targetSlot, "Assigned action '" .. entry.name .. "' to WoWX action slot " .. targetSlot .. ".", true, nativeUtilityBefore)
end

function UI:AssignSelection(button, bookSlot)
    if self.mode == "guide" and button and button.guideSlotIndex then
        self.selectedSlotIndex = tonumber(button.guideSlotIndex) or self.selectedSlotIndex

        if GetCursorInfo and GetCursorInfo() then
            local targetSlot = self:GetGridTargetSlot()
            if not targetSlot then
                GPX:Print("No target slot selected. Pick a Gridbook page + slot first.")
                self:Refresh()
                return
            end
            if not self:CanAssignToGridSlot(targetSlot) then
                GPX:Print("Slot " .. tostring(targetSlot) .. " is not accessible in current input mode.")
                self:Refresh()
                return
            end
            if InCombatLockdown() then
                GPX:Print("Assignment is blocked in combat.")
                self:Refresh()
                return
            end

            self:TryPlaceCursorOnTarget(targetSlot, true)
            return
        end

        self:BeginGuideAssignmentFlow(self.selectedSlotIndex)
        return
    end

    if button and button.utilityAction then
        self:AssignUtilityAction(button.utilityAction)
        return
    end
    self:AssignSpell(bookSlot)
end

function UI:AssignSpell(bookSlot)
    if not bookSlot then
        return
    end

    local targetSlot = self:GetAssignmentTargetSlot()
    if not targetSlot then
        if self.mode ~= "guide" and not self.pendingActionSlot then
            return
        end
        GPX:Print("No target slot selected. Pick a Gridbook page + slot first.")
        return
    end
    if not self:CanAssignToGridSlot(targetSlot) then
        GPX:Print("Slot " .. tostring(targetSlot) .. " is not accessible in current input mode.")
        return
    end

    if InCombatLockdown() then
        GPX:Print("Spell assignment is blocked in combat.")
        return
    end

    local nativeUtilityBefore = self:IsNativeUtilityMacroAtSlot(targetSlot)

    local picked = pickupSpellBookSlot(bookSlot)
    if not picked then
        GPX:Print("Could not pick that spell from this client's spellbook API.")
        return
    end
    local ok, placeErr = self:PlacePickedCursorOnSlot(targetSlot)
    if not ok then
        GPX:Print(placeErr or "Could not place spell.")
        return
    end

    self:HandlePostPlacement(targetSlot, "Assigned spell to WoWX action slot " .. targetSlot .. ".", true, nativeUtilityBefore)
end

function UI:Open(actionSlot, returnContext)
    self:CreateFrame()
    self:RepairUtilityMacros()
    self.pendingActionSlot = actionSlot
    self.assignmentOrigin = actionSlot and "external" or nil
    self.returnContext = returnContext or "settings"
    self.currentTab = self.currentTab or 1
    self.currentSpellPage = self.currentSpellPage or 1
    self.mode = "spells"
    self.selectedPageState = self.selectedPageState or ""
    self.selectedSlotIndex = self.selectedSlotIndex or 1
    if self.allowHiddenSlotEdit == nil then
        self.allowHiddenSlotEdit = false
    end
    self:Refresh()
    self.frame:Show()
    if GPX.UIMode then
        GPX.UIMode:Enter("spellbook")
    end
end

function UI:ReturnToPreviousContext()
    local returnContext = self.returnContext
    self.pendingActionSlot = nil
    self.returnContext = nil
    self.frame:Hide()

    if GPX.UIMode then
        if returnContext and GPX.UIMode:GetContext(returnContext) and GPX.UIMode:IsContextAvailable(returnContext) then
            GPX.UIMode:Enter(returnContext)
        else
            GPX.UIMode:Exit()
        end
    end
end

local gridbookSyncFrame = CreateFrame("Frame", "WoWXGridbookSyncFrame")
gridbookSyncFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
gridbookSyncFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
gridbookSyncFrame:SetScript("OnEvent", function(_, event, ...)
    if not GPX.SpellbookUI then
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if GPX.SpellbookUI._nativeBindingRefreshPending and not (GPX.SpellbookUI.frame and GPX.SpellbookUI.frame:IsShown()) then
            GPX.SpellbookUI:FlushNativeBindingRefresh()
        end
        if GPX.SpellbookUI._nativeBindingRefreshAfterCombat then
            GPX.SpellbookUI._nativeBindingRefreshAfterCombat = nil
            GPX.SpellbookUI:ScheduleNativeBindingRefresh()
        end
        if GPX.SpellbookUI.pendingBarCapture then
            GPX.SpellbookUI.pendingBarCapture = nil
            GPX.SpellbookUI:CaptureGridbookFromActionSlots()
        end
        if GPX.SpellbookUI.frame and GPX.SpellbookUI.frame:IsShown() then
            GPX.SpellbookUI:Refresh()
        end
        return
    end

    if event == "ACTIONBAR_SLOT_CHANGED" then
        if InCombatLockdown() then
            GPX.SpellbookUI.pendingBarCapture = true
            if GPX.SpellbookUI.frame and GPX.SpellbookUI.frame:IsShown() then
                GPX.SpellbookUI:Refresh()
            end
            return
        end

        local changedSlot = select(1, ...)
        local changed = false
        if changedSlot and tonumber(changedSlot) and tonumber(changedSlot) > 0 then
            changed = GPX.SpellbookUI:WriteGridbookForSlot(changedSlot, false)
        else
            changed = GPX.SpellbookUI:CaptureGridbookFromActionSlots()
        end
        if changed and GPX.SpellbookUI.frame and GPX.SpellbookUI.frame:IsShown() then
            GPX.SpellbookUI:Refresh()
        end
    end
end)
