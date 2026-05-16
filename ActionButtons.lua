if not GamePadX then return end

local GPX = GamePadX
local Buttons = {}

GPX.ActionButtons = Buttons

local defaultConfig = {
    enabled = true,
    showBags = true,
    point = { anchor = "BOTTOMRIGHT", relativeTo = "UIParent", relativePoint = "BOTTOM", x = 320, y = 64 },
    scale = 1.0,
    alpha = 1.0,
}

local updateFrame = CreateFrame("Frame", "WoWXActionButtonsEventFrame")

local function cloneDefaults()
    if GPX.DeepCopy then
        return GPX:DeepCopy(defaultConfig)
    end

    return {
        enabled = defaultConfig.enabled,
        showBags = defaultConfig.showBags,
        point = {
            anchor = defaultConfig.point.anchor,
            relativeTo = defaultConfig.point.relativeTo,
            relativePoint = defaultConfig.point.relativePoint,
            x = defaultConfig.point.x,
            y = defaultConfig.point.y,
        },
        scale = defaultConfig.scale,
        alpha = defaultConfig.alpha,
    }
end

local function ensureConfig()
    if not GPX.db then
        return nil
    end

    GPX.db.ui = GPX.db.ui or {}
    GPX.db.ui.actionButtons = GPX.db.ui.actionButtons or cloneDefaults()

    local cfg = GPX.db.ui.actionButtons
    if cfg.enabled == nil then cfg.enabled = defaultConfig.enabled end
    if cfg.showBags == nil then cfg.showBags = defaultConfig.showBags end
    cfg.point = cfg.point or cloneDefaults().point
    if cfg.scale == nil then cfg.scale = defaultConfig.scale end
    if cfg.alpha == nil then cfg.alpha = defaultConfig.alpha end

    return cfg
end

local function applyPoint(frame, cfg)
    frame:ClearAllPoints()

    if GPX.VisualBar and GPX.VisualBar.frame and GPX.VisualBar.frame:IsShown() then
        frame:SetPoint("BOTTOMLEFT", GPX.VisualBar.frame, "TOPRIGHT", 8, 8)
        return
    end

    local p = cfg.point or defaultConfig.point
    frame:SetPoint(p.anchor or "BOTTOMRIGHT", UIParent, p.relativePoint or "BOTTOM", p.x or 320, p.y or 64)
end

function Buttons:CreateFrame()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "WoWXUtilityButtonsFrame", UIParent)
    frame:SetWidth(42)
    frame:SetHeight(42)

    local button = CreateFrame("CheckButton", "WoWXUtilityBagButton", frame, "SecureActionButtonTemplate")
    button:SetAllPoints(frame)
    button:RegisterForClicks("LeftButtonUp")
    button:SetAttribute("type1", "macro")
    button:SetAttribute("macrotext1", "/click MainMenuBarBackpackButton\n/click CharacterBag0Slot\n/click CharacterBag1Slot\n/click CharacterBag2Slot\n/click CharacterBag3Slot")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetAllPoints(button)
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")

    local key = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    key:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
    key:SetText("Bags")

    button:SetScript("OnEnter", function(selfBtn)
        GameTooltip:SetOwner(selfBtn, "ANCHOR_TOP")
        GameTooltip:SetText("WoWX Bags", 1, 0.82, 0.2)
        GameTooltip:AddLine("Left-click opens backpack and bag slots.", 0.86, 0.9, 1.0)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.frame = frame
    self.bagButton = button
end

function Buttons:UpdateAll()
    local cfg = ensureConfig()
    if not cfg then
        return
    end

    self:CreateFrame()

    if InCombatLockdown() then
        self.pendingRefresh = true
        return
    end

    local enabled = GPX.db and GPX.db.enabled
    local controllerEnabled = GPX.IsControllerEnabled and GPX:IsControllerEnabled()
    local show = enabled and controllerEnabled and cfg.enabled and cfg.showBags

    if show then
        self.frame:SetScale(cfg.scale or 1.0)
        self.frame:SetAlpha(cfg.alpha or 1.0)
        applyPoint(self.frame, cfg)
        self.frame:Show()
    else
        self.frame:Hide()
    end

    self.pendingRefresh = nil
end

function Buttons:Slash(msg)
    local arg = string.lower((msg or ""):match("^%s*(.-)%s*$"))
    local cfg = ensureConfig()
    if not cfg then
        GPX:Print("ActionButtons unavailable (database not ready).")
        return
    end

    if arg == "" or arg == "status" then
        GPX:Print("Bags action button: " .. ((cfg.enabled and cfg.showBags) and "ON" or "OFF"))
        return
    end

    if arg == "on" or arg == "enable" or arg == "1" then
        cfg.enabled = true
        cfg.showBags = true
    elseif arg == "off" or arg == "disable" or arg == "0" then
        cfg.showBags = false
    elseif arg == "toggle" then
        cfg.showBags = not (cfg.showBags == true)
    elseif arg == "reset" then
        cfg.point = cloneDefaults().point
        cfg.scale = defaultConfig.scale
        cfg.alpha = defaultConfig.alpha
    else
        GPX:Print("Usage: /wowx bags [on|off|toggle|status|reset]")
        return
    end

    self:UpdateAll()
    GPX:Print("Bags action button: " .. ((cfg.enabled and cfg.showBags) and "ON" or "OFF"))
end

updateFrame:RegisterEvent("PLAYER_LOGIN")
updateFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
updateFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
updateFrame:SetScript("OnEvent", function(_, event)
    if not GPX.ActionButtons then
        return
    end

    if event == "PLAYER_REGEN_ENABLED" and not GPX.ActionButtons.pendingRefresh then
        return
    end

    GPX.ActionButtons:UpdateAll()
end)
