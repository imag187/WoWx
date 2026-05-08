if not GamePadX then return end

local GPX = GamePadX
local Mode = {}

GPX.UIMode = Mode

local hiddenActions = {
    UP = "Up",
    DOWN = "Down",
    LEFT = "Left",
    RIGHT = "Right",
    CONFIRM = "Confirm",
    CANCEL = "Cancel",
    NEXT_WINDOW = "NextWindow",
    PREV_WINDOW = "PrevWindow",
}

local function createBackdrop(frame, borderR, borderG, borderB, borderA)
    frame:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropBorderColor(borderR or 0.96, borderG or 0.8, borderB or 0.22, borderA or 0.95)
end

function Mode:Create()
    if self.owner then
        return
    end

    self.contexts = {}
    self.windowOrder = { "settings", "bar", "spellbook", "menu" }
    self.owner = CreateFrame("Frame", "WoWXUIModeOwner", UIParent)
    self.buttons = {}

    local indicator = CreateFrame("Frame", "WoWXUIModeIndicator", UIParent)
    indicator:SetWidth(500)
    indicator:SetHeight(64)
    indicator:SetPoint("TOP", UIParent, "TOP", 0, -28)
    indicator:SetFrameStrata("DIALOG")
    indicator:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    indicator:SetBackdropColor(0.05, 0.07, 0.11, 0.95)
    indicator:SetBackdropBorderColor(0.96, 0.8, 0.22, 0.9)
    indicator:Hide()

    local title = indicator:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", indicator, "TOPLEFT", 14, -12)
    title:SetTextColor(1.0, 0.96, 0.72)

    local detail = indicator:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detail:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    detail:SetWidth(470)
    detail:SetJustifyH("LEFT")

    self.indicator = indicator
    self.indicatorTitle = title
    self.indicatorDetail = detail

    for bindingAction, name in pairs(hiddenActions) do
        local button = CreateFrame("Button", "WoWXUIMode" .. name, UIParent)
        button:Hide()
        button:SetScript("OnClick", function()
            if GPX.UIMode then
                GPX.UIMode:HandleAction(bindingAction)
            end
        end)
        self.buttons[bindingAction] = button
    end
end

function Mode:RegisterContext(name, config)
    self:Create()
    self.contexts[name] = config
end

function Mode:IsContextAvailable(name)
    local context = self:GetContext(name)
    if not context then
        return false
    end
    if context.isAvailable then
        return context.isAvailable()
    end
    local items = self:GetContextItems(name)
    return #items > 0
end

function Mode:GetContextLabel(name)
    local context = self:GetContext(name)
    return context and context.label or name
end

function Mode:GetContext(name)
    self:Create()
    return self.contexts[name]
end

function Mode:GetContextItems(name)
    local context = self:GetContext(name)
    if not context then
        return {}
    end

    if context.getItems then
        return context.getItems() or {}
    end
    return context.items or {}
end

function Mode:EnsureFocusRing(frame)
    if frame.GPXFocusRing then
        return frame.GPXFocusRing
    end

    local ring = CreateFrame("Frame", nil, frame)
    ring:SetFrameLevel(frame:GetFrameLevel() + 8)
    ring:SetPoint("TOPLEFT", frame, "TOPLEFT", -4, 4)
    ring:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 4, -4)
    createBackdrop(ring)
    ring:Hide()
    frame.GPXFocusRing = ring
    return ring
end

function Mode:ShowFocus(frame)
    if not frame then
        return
    end

    local ring = self:EnsureFocusRing(frame)
    ring:Show()
    if frame.LockHighlight then
        frame:LockHighlight()
    end
end

function Mode:HideFocus(frame)
    if not frame then
        return
    end

    if frame.GPXFocusRing then
        frame.GPXFocusRing:Hide()
    end
    if frame.UnlockHighlight then
        frame:UnlockHighlight()
    end
end

function Mode:GetNavigationKeys()
    local profile = GPX:GetProfile()
    local setup = profile and profile.setup or nil
    if not setup then
        return {}
    end

    local style = GPX:GetInputStyle(setup.deviceId)
    local slotLabels = style.slotLabels or {}
    local actionKeys = setup.actionKeys or {}
    local nav = {
        up = (setup.movement and setup.movement.forward) or "W",
        right = (setup.movement and setup.movement.right) or "D",
        down = (setup.movement and setup.movement.back) or "S",
        left = (setup.movement and setup.movement.left) or "A",
        confirm = setup.jumpKey,
        cancel = setup.menuKey or actionKeys[1] or "ESCAPE",
        nextWindow = setup.modifiers and setup.modifiers[2] or nil,
        prevWindow = setup.modifiers and setup.modifiers[3] or nil,
    }

    for slotIndex = 2, 8 do
        local label = slotLabels[slotIndex]
        local key = actionKeys[slotIndex - 1]
        if label == "D-Up" then
            nav.up = key
        elseif label == "D-Right" then
            nav.right = key
        elseif label == "D-Down" then
            nav.down = key
        elseif label == "D-Left" then
            nav.left = key
        end
    end

    return nav
end

function Mode:ApplyBindings()
    self:Create()
    ClearOverrideBindings(self.owner)

    if not self.activeContext then
        return
    end

    local nav = self:GetNavigationKeys()
    local bindingMap = {
        { key = nav.up, action = "UP" },
        { key = nav.down, action = "DOWN" },
        { key = nav.left, action = "LEFT" },
        { key = nav.right, action = "RIGHT" },
        { key = nav.confirm, action = "CONFIRM" },
        { key = nav.cancel, action = "CANCEL" },
        { key = nav.nextWindow, action = "NEXT_WINDOW" },
        { key = nav.prevWindow, action = "PREV_WINDOW" },
        { key = "ESCAPE", action = "CANCEL" },
    }

    local seen = {}
    for _, entry in ipairs(bindingMap) do
        if entry.key and entry.key ~= "" and not seen[entry.key] then
            seen[entry.key] = true
            SetOverrideBindingClick(self.owner, true, entry.key, "WoWXUIMode" .. hiddenActions[entry.action])
        end
    end
end

function Mode:UpdateIndicator()
    if not self.indicator then
        return
    end

    if not self.activeContext then
        self.indicator:Hide()
        return
    end

    local context = self:GetContext(self.activeContext)
    local nav = self:GetNavigationKeys()
    local detail = string.format(
        "Navigate: %s/%s/%s/%s   Confirm: %s   Cancel: %s   Window: %s / %s",
        nav.up or "--",
        nav.right or "--",
        nav.down or "--",
        nav.left or "--",
        nav.confirm or "--",
        nav.cancel or "ESCAPE",
        nav.prevWindow or "--",
        nav.nextWindow or "--"
    )

    if context and context.getIndicatorText then
        detail = context.getIndicatorText(self, detail) or detail
    end

    self.indicatorTitle:SetText("WoWX UI Mode — " .. self:GetContextLabel(self.activeContext))
    self.indicatorDetail:SetText(detail)
    self.indicator:Show()
end

function Mode:Exit()
    if self.currentFrame then
        self:HideFocus(self.currentFrame)
    end
    self.currentFrame = nil
    self.activeContext = nil
    self.index = nil
    self.returnContext = nil
    self:ApplyBindings()
    self:UpdateIndicator()
end

function Mode:FindFirstVisibleIndex(items)
    for index, frame in ipairs(items) do
        if frame and frame:IsShown() then
            return index
        end
    end
    return nil
end

function Mode:SetFocus(index)
    local items = self:GetContextItems(self.activeContext)
    local frame = items[index]
    if not frame or not frame:IsShown() then
        index = self:FindFirstVisibleIndex(items)
        frame = index and items[index] or nil
    end

    if self.currentFrame == frame then
        self.index = index
        return
    end

    if self.currentFrame then
        self:HideFocus(self.currentFrame)
    end

    self.currentFrame = frame
    self.index = index
    if self.currentFrame then
        self:ShowFocus(self.currentFrame)
    end
    self:UpdateIndicator()
end

function Mode:Enter(contextName, opts)
    local context = self:GetContext(contextName)
    if not context then
        return
    end
    if not self:IsContextAvailable(contextName) then
        return
    end

    self.activeContext = contextName
    self.returnContext = opts and opts.returnContext or nil
    self:ApplyBindings()
    self:SetFocus((opts and opts.index) or self:FindFirstVisibleIndex(self:GetContextItems(contextName)))
    self:UpdateIndicator()
end

function Mode:SwitchWindow(direction)
    if not self.activeContext then
        return
    end

    local currentIndex = 1
    for index, name in ipairs(self.windowOrder) do
        if name == self.activeContext then
            currentIndex = index
            break
        end
    end

    local attempts = #self.windowOrder
    local index = currentIndex
    while attempts > 0 do
        index = index + direction
        if index < 1 then
            index = #self.windowOrder
        elseif index > #self.windowOrder then
            index = 1
        end

        local name = self.windowOrder[index]
        if name ~= self.activeContext and self:IsContextAvailable(name) then
            self:Enter(name)
            return
        end
        attempts = attempts - 1
    end
end

function Mode:GetStep(columns, action)
    if action == "LEFT" then return -1 end
    if action == "RIGHT" then return 1 end
    if action == "UP" then return -(columns or 1) end
    if action == "DOWN" then return (columns or 1) end
    return 0
end

function Mode:Move(action)
    local context = self:GetContext(self.activeContext)
    if not context then
        return
    end

    local items = self:GetContextItems(self.activeContext)
    if #items == 0 then
        return
    end

    local step = self:GetStep(context.columns, action)
    if step == 0 then
        return
    end

    local index = self.index or self:FindFirstVisibleIndex(items) or 1
    local attempts = #items
    local candidate = index

    while attempts > 0 do
        candidate = candidate + step
        if candidate < 1 then
            candidate = #items
        elseif candidate > #items then
            candidate = 1
        end

        local frame = items[candidate]
        if frame and frame:IsShown() then
            self:SetFocus(candidate)
            return
        end
        attempts = attempts - 1
    end
end

function Mode:Confirm()
    if self.currentFrame and self.currentFrame.Click then
        self.currentFrame:Click("LeftButton")
    end
end

function Mode:Cancel()
    local context = self:GetContext(self.activeContext)
    if context and context.onCancel then
        context.onCancel(self)
    else
        self:Exit()
    end
end

function Mode:HandleAction(action)
    if not self.activeContext then
        return
    end

    if action == "CONFIRM" then
        self:Confirm()
    elseif action == "CANCEL" then
        self:Cancel()
    elseif action == "NEXT_WINDOW" then
        self:SwitchWindow(1)
    elseif action == "PREV_WINDOW" then
        self:SwitchWindow(-1)
    else
        self:Move(action)
    end
end