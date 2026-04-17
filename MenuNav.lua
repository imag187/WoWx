if not GamePadX then return end

local GPX = GamePadX
local Menu = {}

GPX.MenuNav = Menu

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

local function safeCall(fn)
    if not fn then
        return false
    end
    local ok = pcall(fn)
    return ok
end

local function openGameMenu()
    if ToggleGameMenu then
        ToggleGameMenu()
    elseif ShowUIPanel and GameMenuFrame then
        ShowUIPanel(GameMenuFrame)
    end
end

local function openInterfaceOptions()
    if InterfaceOptionsFrame_OpenToCategory and InterfaceOptionsFrame then
        InterfaceOptionsFrame_OpenToCategory(InterfaceOptionsFrame)
        InterfaceOptionsFrame_OpenToCategory(InterfaceOptionsFrame)
    elseif InterfaceOptionsFrame then
        ShowUIPanel(InterfaceOptionsFrame)
    end
end

local function openVideoOptions()
    if VideoOptionsFrame then
        ShowUIPanel(VideoOptionsFrame)
    else
        openGameMenu()
    end
end

local function openKeyBindings()
    if not KeyBindingFrame and LoadAddOn then
        pcall(LoadAddOn, "Blizzard_BindingUI")
    end
    if KeyBindingFrame then
        ShowUIPanel(KeyBindingFrame)
    else
        openGameMenu()
    end
end

local menuSpecs = {
    { key = "gameMenu", label = "Game Menu", hint = "Logout, macros, options", click = openGameMenu },
    { key = "interface", label = "Interface", hint = "General game options", click = openInterfaceOptions },
    { key = "video", label = "Video", hint = "Resolution and graphics", click = openVideoOptions },
    { key = "bindings", label = "Key Bindings", hint = "View keymap", click = openKeyBindings },
    { key = "character", label = "Character", hint = "Paper doll", click = function() if ToggleCharacter then ToggleCharacter("PaperDollFrame") end end },
    { key = "spellbook", label = "Spellbook", hint = "Spells and professions", click = function() if ToggleSpellBook then ToggleSpellBook(BOOKTYPE_SPELL or "spell") end end },
    { key = "talents", label = "Talents", hint = "Talent tree", click = function() if ToggleTalentFrame then ToggleTalentFrame() end end },
    { key = "achievements", label = "Achievements", hint = "Achievement panel", click = function() if ToggleAchievementFrame then ToggleAchievementFrame() end end },
    { key = "questLog", label = "Quest Log", hint = "Quest tracker", click = function() if ToggleQuestLog then ToggleQuestLog() end end },
    { key = "social", label = "Social", hint = "Friends and who", click = function() if ToggleFriendsFrame then ToggleFriendsFrame(1) end end },
    { key = "guild", label = "Guild", hint = "Guild roster", click = function() if ToggleGuildFrame then ToggleGuildFrame() end end },
    { key = "companions", label = "Mounts / Pets", hint = "Companion panel", click = function() if ToggleCompanionFrame then ToggleCompanionFrame("MOUNT") end end },
    { key = "worldMap", label = "World Map", hint = "Map and zones", click = function() if ToggleWorldMap then ToggleWorldMap() end end },
    { key = "bags", label = "Backpack", hint = "Open bags", click = function() if ToggleBackpack then ToggleBackpack() end end },
}

function Menu:CreateFrame()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "WoWXMenuNavFrame", UIParent)
    frame:SetWidth(620)
    frame:SetHeight(500)
    frame:SetPoint("CENTER", UIParent, "CENTER", -180, 0)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:SetScript("OnHide", function()
        if GPX.UIMode and GPX.UIMode.activeContext == "menu" then
            GPX.UIMode:Exit()
        end
    end)
    createBackdrop(frame)
    frame:Hide()

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -18)
    title:SetText(GPX.brand .. " Menu Navigator")
    title:SetTextColor(0.95, 0.97, 1.0)

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetWidth(580)
    subtitle:SetJustifyH("LEFT")

    local grid = CreateFrame("Frame", nil, frame)
    grid:SetWidth(580)
    grid:SetHeight(380)
    grid:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -78)

    frame.navOrder = {}

    for index, spec in ipairs(menuSpecs) do
        local button = CreateFrame("Button", nil, grid, "UIPanelButtonTemplate")
        button:SetWidth(180)
        button:SetHeight(64)
        local col = (index - 1) % 3
        local row = math.floor((index - 1) / 3)
        button:SetPoint("TOPLEFT", grid, "TOPLEFT", col * 196, -row * 74)
        button:SetText(spec.label)

        local hint = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOP", button, "BOTTOM", 0, -2)
        hint:SetText(spec.hint)

        button:SetScript("OnClick", function()
            if safeCall(spec.click) then
                if GPX.UIMode and GPX.UIMode.activeContext == "menu" then
                    GPX.UIMode:UpdateIndicator()
                end
            else
                GPX:Print("Unable to open " .. spec.label .. " on this client.")
            end
        end)

        frame.navOrder[#frame.navOrder + 1] = button
    end

    local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 16)
    footer:SetWidth(580)
    footer:SetJustifyH("LEFT")

    self.frame = frame
    self.frame.subtitle = subtitle
    self.frame.footer = footer

    if GPX.UIMode then
        GPX.UIMode:RegisterContext("menu", {
            label = "Menu Navigator",
            getItems = function()
                return Menu.frame and Menu.frame.navOrder or {}
            end,
            columns = 3,
            isAvailable = function()
                return Menu.frame and Menu.frame:IsShown()
            end,
            onCancel = function(navigator)
                if Menu.returnContext and navigator:IsContextAvailable(Menu.returnContext) then
                    navigator:Enter(Menu.returnContext)
                else
                    Menu.frame:Hide()
                end
            end,
            getIndicatorText = function(_, baseText)
                return "Open Blizzard menus, options, and character panels without the static microbar.   " .. baseText
            end,
        })
    end
end

function Menu:Refresh()
    if not self.frame then
        return
    end

    local profile = GPX:GetProfile()
    local setup = profile and profile.setup or nil
    local menuKey = setup and setup.menuKey or "ESCAPE"
    self.frame.subtitle:SetText("Use this as your replacement micro-menu. Bind your center/controller menu button to " .. menuKey .. " in WoWX setup.")
    self.frame.footer:SetText("Tip: in UI mode, Confirm opens the focused panel and Cancel returns to the previous WoWX window.")
end

function Menu:Open(returnContext)
    self:CreateFrame()
    self.returnContext = returnContext
    self:Refresh()
    self.frame:Show()

    if GPX.UIMode then
        GPX.UIMode:Enter("menu", { returnContext = returnContext })
    end
end
