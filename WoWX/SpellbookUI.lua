if not GamePadX then return end

local GPX = GamePadX
local UI = {}

GPX.SpellbookUI = UI

local BOOK = BOOKTYPE_SPELL or "spell"

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

function UI:CreateFrame()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "WoWXSpellbookFrame", UIParent)
    frame:SetWidth(640)
    frame:SetHeight(500)
    frame:SetPoint("CENTER", UIParent, "CENTER", 180, 0)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:SetScript("OnHide", function()
        if GPX.UIMode and GPX.UIMode.activeContext == "spellbook" then
            GPX.UIMode:Exit()
        end
    end)
    createBackdrop(frame)
    frame:Hide()

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
    header:SetHeight(34)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -72)

    local prevTab = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    prevTab:SetWidth(90)
    prevTab:SetHeight(26)
    prevTab:SetPoint("LEFT", header, "LEFT", 0, 0)
    prevTab:SetText("Prev Tab")

    local nextTab = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    nextTab:SetWidth(90)
    nextTab:SetHeight(26)
    nextTab:SetPoint("LEFT", prevTab, "RIGHT", 8, 0)
    nextTab:SetText("Next Tab")

    local returnButton = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    returnButton:SetWidth(120)
    returnButton:SetHeight(26)
    returnButton:SetPoint("LEFT", nextTab, "RIGHT", 8, 0)
    returnButton:SetText("Return")

    local tabLabel = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tabLabel:SetPoint("LEFT", returnButton, "RIGHT", 14, 0)

    local grid = CreateFrame("Frame", nil, frame)
    grid:SetWidth(600)
    grid:SetHeight(340)
    grid:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -12)

    frame.navOrder = { prevTab, nextTab, returnButton }
    frame.spellButtons = {}
    for index = 1, 12 do
        local button = CreateFrame("Button", nil, grid)
        button:SetWidth(186)
        button:SetHeight(72)
        local col = (index - 1) % 3
        local row = math.floor((index - 1) / 3)
        button:SetPoint("TOPLEFT", grid, "TOPLEFT", col * 202, -row * 86)
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

        button.icon = icon
        button.name = name
        button.detail = detail
        frame.spellButtons[index] = button
        frame.navOrder[#frame.navOrder + 1] = button
    end

    prevTab:SetScript("OnClick", function() UI:ChangeTab(-1) end)
    nextTab:SetScript("OnClick", function() UI:ChangeTab(1) end)
    returnButton:SetScript("OnClick", function() UI:ReturnToPreviousContext() end)

    for _, button in ipairs(frame.spellButtons) do
        button:SetScript("OnClick", function(self)
            UI:AssignSpell(self.spellBookSlot)
        end)
        button:SetScript("OnEnter", function(self)
            if self.spellBookSlot then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpellBookItem(self.spellBookSlot, BOOK)
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
    self.frame.tabLabel = tabLabel
    self.frame.footer = footer

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
                    return "Assigning spell to action slot " .. UI.pendingActionSlot .. "   " .. baseText
                end
                return "Browsing spells   " .. baseText
            end,
        })
    end
end

function UI:GetTabCount()
    return GetNumSpellTabs() or 0
end

function UI:GetSpellSlotsForTab(tabIndex)
    local name, texture, offset, numSpells = GetSpellTabInfo(tabIndex)
    local slots = {}
    for localIndex = 1, (numSpells or 0) do
        local bookSlot = (offset or 0) + localIndex
        local spellName = GetSpellBookItemName(bookSlot, BOOK)
        local icon = GetSpellBookItemTexture(bookSlot, BOOK)
        if spellName then
            slots[#slots + 1] = {
                slot = bookSlot,
                name = spellName,
                icon = icon,
                passive = IsPassiveSpell(bookSlot, BOOK),
            }
        end
    end
    return slots, name
end

function UI:Refresh()
    if not self.frame then
        return
    end

    local totalTabs = self:GetTabCount()
    if totalTabs < 1 then
        self.currentTab = 1
    else
        if not self.currentTab or self.currentTab > totalTabs then
            self.currentTab = 1
        elseif self.currentTab < 1 then
            self.currentTab = totalTabs
        end
    end

    local spells, tabName = self:GetSpellSlotsForTab(self.currentTab or 1)
    self.frame.tabLabel:SetText((tabName or "Spells") .. "  (Tab " .. tostring(self.currentTab or 1) .. "/" .. tostring(totalTabs) .. ")")

    if self.pendingActionSlot then
        self.frame.subtitle:SetText("Choose a spell and press Confirm (your WoWX confirm/jump button) to place it on the selected WoWX button.")
        self.frame.footer:SetText("Assigning to action slot " .. self.pendingActionSlot .. ". Confirm binds the focused spell. Cancel returns to the previous window.")
    else
        self.frame.subtitle:SetText("Browse your spellbook with WoWX UI mode. This panel becomes an action picker when launched from a focused WoWX bar button.")
        self.frame.footer:SetText("Use Prev Tab and Next Tab to switch spell tabs. To assign, open Focus Bar first, pick a slot, then press Confirm.")
    end

    for index, button in ipairs(self.frame.spellButtons) do
        local data = spells[index]
        if data then
            button.spellBookSlot = data.slot
            button.icon:SetTexture(data.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            button.name:SetText(data.name)
            button.detail:SetText(data.passive and "Passive" or "Spell")
            button:Show()
        else
            button.spellBookSlot = nil
            button.icon:SetTexture("Interface\\Buttons\\UI-Quickslot2")
            button.name:SetText("")
            button.detail:SetText("")
            button:Hide()
        end
    end

    if GPX.UIMode and GPX.UIMode.activeContext == "spellbook" then
        GPX.UIMode:SetFocus(GPX.UIMode.index or 4)
    end
end

function UI:ChangeTab(delta)
    local count = self:GetTabCount()
    if count < 1 then
        return
    end
    self.currentTab = (self.currentTab or 1) + delta
    if self.currentTab < 1 then
        self.currentTab = count
    elseif self.currentTab > count then
        self.currentTab = 1
    end
    self:Refresh()
end

function UI:AssignSpell(bookSlot)
    if not bookSlot then
        return
    end

    if not self.pendingActionSlot then
        GPX:Print("No WoWX bar slot selected. Focus a bar button first, then open the spellbook.")
        return
    end

    if InCombatLockdown() then
        GPX:Print("Spell assignment is blocked in combat.")
        return
    end

    PickupSpellBookItem(bookSlot, BOOK)
    PlaceAction(self.pendingActionSlot)
    ClearCursor()

    if GPX.VisualBar then
        GPX.VisualBar:UpdateAll()
    end
    GPX:Print("Assigned spell to WoWX action slot " .. self.pendingActionSlot .. ".")
    self:ReturnToPreviousContext()
end

function UI:Open(actionSlot, returnContext)
    self:CreateFrame()
    self.pendingActionSlot = actionSlot
    self.returnContext = returnContext or "settings"
    self.currentTab = self.currentTab or 1
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