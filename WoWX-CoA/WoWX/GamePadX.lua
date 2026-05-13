-- ============================================================
-- GamePadX.lua  (WoWX core, WotLK 3.3.5a)
-- Modernized couch-play bindings and UI helpers — no account sync
-- ============================================================
--
-- QUICK START:
--   1. Install AntiMicroX on Linux and map your controller buttons to keys.
--      Recommended defaults (all F-keys, safe to not conflict with common binds):
--        Face:    A=F1   B=F2    X=F3   Y=F4
--        Bumpers: LB=F5  RB=F6
--        Triggers to act as WoW modifiers:
--                 LT=Shift  RT=Alt   (set in AntiMicroX as "Shift key" / "Alt key")
--                 If your controller has both bumpers AND triggers free,
--                 you can also output LT=F7 RT=F8 and use Ctrl for a 4th page.
--        D-Pad:   Up=F9  Down=F10  Left=F11  Right=F12
--        Menu:    Start=F13  Select=F14
--
--   2. In WoW on your controller machine: /wowx enable
--      On your keyboard machines: leave it disabled (or don't install it).
--
--   3. The addon binds your controller keys to WoW action bar commands.
--      Spells stay wherever you put them on your bars — the addon just
--      tells WoW "when F1 is pressed, fire ActionButton1."
--
--   4. Bindings are ONLY applied in memory (SaveBindings() is never called).
--      They live only for the current WoW session and are re-applied at login
--      from your LOCAL SavedVariables (WTF folder on this machine only).
--      Your keyboard machine's WTF is untouched.
--
-- BAR LAYOUT (what each modifier page maps to):
--   Normal       -> Main action bar      (ACTIONBUTTON1–12)
--   + Shift held -> Bottom Left bar      (MULTIACTIONBAR2BUTTON1–12)
--   + Alt held   -> Bottom Right bar     (MULTIACTIONBAR1BUTTON1–12)
--   + Ctrl held  -> Right bar 1          (MULTIACTIONBAR4BUTTON1–12)
--   (all extra bars must be enabled in the Blizzard Interface Options)
--
-- SLASH COMMANDS:
--   /wowx  (legacy aliases still accepted)
-- ============================================================

-- Protect against double-load
if GamePadX then return end

GamePadX = {}
local GPX = GamePadX
local mainFrame
GPX.version = "1.0.0"
GPX.brand = "WoWX"
GPX.inputStyles = {
    keyboard = {
        id = "keyboard",
        name = "Keyboard / Mouse",
        slotLabels = { "Action 1", "Action 2", "Action 3", "Action 4", "Action 5", "Action 6", "Action 7", "Action 8", "Action 9", "Action 10", "Action 11", "Action 12" },
        combatSlotLabels = { "Action 1", "Action 2", "Action 3", "Action 4", "Action 5", "Action 6", "Action 7", "Action 8", "Action 9", "Action 10", "Action 11", "Action 12" },
        modifierLabels = { "Modifier 1", "Modifier 2", "Modifier 3" },
        confirmLabel = "Jump / Confirm",
    },
    xbox = {
        id = "xbox",
        name = "Xbox",
        slotLabels = { "A", "B", "X", "Y", "D-Up", "D-Right", "D-Down", "D-Left", "LB", "RB", "L3", "R3" },
        combatSlotLabels = { "X", "Y", "B", "Back", "Start", "D-Left", "D-Up", "D-Down" },
        combatDisplayLabels = { "X", "Y", "B", "<|", "|>", "<-", "/|\\", "\\|/" },
        modifierLabels = { "L1 / LB", "R1 / RB", "R3 / Click" },
        confirmLabel = "A",
    },
    playstation = {
        id = "playstation",
        name = "PlayStation",
        slotLabels = { "Cross", "Circle", "Square", "Triangle", "D-Up", "D-Right", "D-Down", "D-Left", "L1", "R1", "L3", "R3" },
        combatSlotLabels = { "Square", "Triangle", "Circle", "Share", "Options", "D-Left", "D-Up", "D-Down" },
        combatDisplayLabels = { "Square", "Triangle", "Circle", "<|", "|>", "<-", "/|\\", "\\|/" },
        modifierLabels = { "L1", "R1", "R3" },
        confirmLabel = "Cross",
    },
    switch = {
        id = "switch",
        name = "Switch Pro",
        slotLabels = { "B", "A", "Y", "X", "D-Up", "D-Right", "D-Down", "D-Left", "L", "R", "L3", "R3" },
        combatSlotLabels = { "Y", "X", "A", "Minus", "Plus", "D-Left", "D-Up", "D-Down" },
        combatDisplayLabels = { "Y", "X", "A", "<|", "|>", "<-", "/|\\", "\\|/" },
        modifierLabels = { "L", "R", "R-Stick" },
        confirmLabel = "B",
    },
    generic = {
        id = "generic",
        name = "Generic Bluetooth",
        slotLabels = { "Btn 1", "Btn 2", "Btn 3", "Btn 4", "Btn 5", "Btn 6", "Btn 7", "Btn 8", "Btn 9", "Btn 10", "Btn 11", "Btn 12" },
        combatSlotLabels = { "Btn 1", "Btn 2", "Btn 3", "Btn 4", "Btn 5", "Btn 6", "Btn 7", "Btn 8" },
        modifierLabels = { "Modifier 1", "Modifier 2", "Modifier 3" },
        confirmLabel = "Jump / Confirm",
    },
}

-- ============================================================
-- DEFAULT CONFIGURATION
-- The bindings table uses WoW's own binding-command strings.
-- You can look these up in-game: Escape -> Key Bindings panel.
-- ============================================================
GPX.defaults = {
    enabled     = true,
    machineNote = "",     -- label stored in notes: /wowx note "Gaming Rig"
    profile     = "default",
    bindingSync = {
        enabled = false,
        scope = "character", -- character or account
    },
    diagnostics = {
        autoCapture = false,
    },
    ui = {
        visualBar = {
            enabled = true,
            locked = true,
            buttonLocked = true,
            replaceBlizzard = true,
            modifierPages = true,
            keepBags = false,
            keepMicroMenu = false,
            keepStanceBar = true,
            keepPetBar = true,
            showBagBar = true,
            showProgress = true,
            progressLocked = true,
            scale = 1.0,
            layout = {
                main = {
                    buttonCount = 12,
                    buttonWidth = 56,
                    buttonHeight = 90,
                    buttonSpacing = 6,
                    padding = 16,
                    alpha = 1.0,
                },
                bag = {
                    buttonSize = 22,
                    buttonSpacing = 8,
                    padding = 6,
                    alpha = 1.0,
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
            },
            point = { anchor = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", x = 0, y = 48 },
            progressPoint = { anchor = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", x = 0, y = 170 },
            bagPoint = { anchor = "BOTTOMRIGHT", relativeTo = "UIParent", relativePoint = "BOTTOM", x = -220, y = 64 },
            microPoint = { anchor = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", x = 0, y = 26 },
            modifierPoint = { anchor = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", x = 0, y = 150 },
            stancePoint = { anchor = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", x = 250, y = 120 },
            petPoint = { anchor = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", x = 0, y = 120 },
            vehiclePoint = { anchor = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", x = 240, y = 120 },
            microScale = 1.0,
            modifierScale = 1.0,
            stanceScale = 1.0,
            petScale = 1.0,
            vehicleScale = 1.0,
        },
        minimapButton = {
            enabled = true,
            angle = 210,
        },
        controller = {
            enabled = false,
            autoMouseLookOnMove = true,
            centerCursorOnMove = true,
            mouseLookDelayMs = 1000,
        },
        bindingEngine = {
            transport = "click", -- direct | click | override
            claimModifiers = true,
            claimCombo = true,
            useSetupKeys = true,
            bindMenu = true,
            overrideFallback = true,
            stickyPage = "", -- "" | SHIFT | ALT | CTRL | SHIFT-ALT
        },
    },
    profiles = {
        default = {
            name = "AntiMicroX F-Key Layout",
            -- key (WoW key string)  ->  command (WoW binding command)
            bindings = {
                -- ── Normal press  →  Main action bar slots 1-12 ──────────
                F1  = "ACTIONBUTTON1",
                F2  = "ACTIONBUTTON2",
                F3  = "ACTIONBUTTON3",
                F4  = "ACTIONBUTTON4",
                F5  = "ACTIONBUTTON5",
                F6  = "ACTIONBUTTON6",
                F7  = "ACTIONBUTTON7",
                F8  = "ACTIONBUTTON8",
                F9  = "ACTIONBUTTON9",
                F10 = "ACTIONBUTTON10",
                F11 = "ACTIONBUTTON11",
                F12 = "ACTIONBUTTON12",

                -- ── Shift held   →  Bottom Left bar slots 1-12 ──────────
                -- In AntiMicroX: configure LT trigger to output the Shift key
                ["SHIFT-F1"]  = "MULTIACTIONBAR2BUTTON1",
                ["SHIFT-F2"]  = "MULTIACTIONBAR2BUTTON2",
                ["SHIFT-F3"]  = "MULTIACTIONBAR2BUTTON3",
                ["SHIFT-F4"]  = "MULTIACTIONBAR2BUTTON4",
                ["SHIFT-F5"]  = "MULTIACTIONBAR2BUTTON5",
                ["SHIFT-F6"]  = "MULTIACTIONBAR2BUTTON6",
                ["SHIFT-F7"]  = "MULTIACTIONBAR2BUTTON7",
                ["SHIFT-F8"]  = "MULTIACTIONBAR2BUTTON8",
                ["SHIFT-F9"]  = "MULTIACTIONBAR2BUTTON9",
                ["SHIFT-F10"] = "MULTIACTIONBAR2BUTTON10",
                ["SHIFT-F11"] = "MULTIACTIONBAR2BUTTON11",
                ["SHIFT-F12"] = "MULTIACTIONBAR2BUTTON12",

                -- ── Alt held     →  Bottom Right bar slots 1-12 ─────────
                -- In AntiMicroX: configure RT trigger to output the Alt key
                ["ALT-F1"]  = "MULTIACTIONBAR1BUTTON1",
                ["ALT-F2"]  = "MULTIACTIONBAR1BUTTON2",
                ["ALT-F3"]  = "MULTIACTIONBAR1BUTTON3",
                ["ALT-F4"]  = "MULTIACTIONBAR1BUTTON4",
                ["ALT-F5"]  = "MULTIACTIONBAR1BUTTON5",
                ["ALT-F6"]  = "MULTIACTIONBAR1BUTTON6",
                ["ALT-F7"]  = "MULTIACTIONBAR1BUTTON7",
                ["ALT-F8"]  = "MULTIACTIONBAR1BUTTON8",
                ["ALT-F9"]  = "MULTIACTIONBAR1BUTTON9",
                ["ALT-F10"] = "MULTIACTIONBAR1BUTTON10",
                ["ALT-F11"] = "MULTIACTIONBAR1BUTTON11",
                ["ALT-F12"] = "MULTIACTIONBAR1BUTTON12",

                -- ── Ctrl held    →  Right bar 1 slots 1-12 ─────────────
                -- In AntiMicroX: configure a spare button to output Ctrl
                ["CTRL-F1"]  = "MULTIACTIONBAR4BUTTON1",
                ["CTRL-F2"]  = "MULTIACTIONBAR4BUTTON2",
                ["CTRL-F3"]  = "MULTIACTIONBAR4BUTTON3",
                ["CTRL-F4"]  = "MULTIACTIONBAR4BUTTON4",
                ["CTRL-F5"]  = "MULTIACTIONBAR4BUTTON5",
                ["CTRL-F6"]  = "MULTIACTIONBAR4BUTTON6",
                ["CTRL-F7"]  = "MULTIACTIONBAR4BUTTON7",
                ["CTRL-F8"]  = "MULTIACTIONBAR4BUTTON8",
                ["CTRL-F9"]  = "MULTIACTIONBAR4BUTTON9",
                ["CTRL-F10"] = "MULTIACTIONBAR4BUTTON10",
                ["CTRL-F11"] = "MULTIACTIONBAR4BUTTON11",
                ["CTRL-F12"] = "MULTIACTIONBAR4BUTTON12",
            },
            spellRings = {
                -- Added via: /wowx ring new <name>
                -- Example default ring (starts empty, user fills it in):
                -- [1] = { name = "Cooldowns", key = "CTRL-F13", spells = {} },
            },
        },
    },
}

-- ============================================================
-- SAVED VARIABLES
-- WoWXDB is SavedVariablesPerCharacter.
-- File location: WTF/Account/.../CharacterName/SavedVariables/WoWX.lua
-- This file is ONLY on the machine you're playing on.
-- It does NOT follow your account to other machines.
-- ============================================================
function GPX:InitDB()
    if not WoWXDB and GamePadXDB then
        WoWXDB = GamePadXDB
    end
    if not WoWXDB then
        WoWXDB = {}
    end
    GamePadXDB = WoWXDB
    local db = WoWXDB

    -- Stamp any fields that are missing (first-time or upgrade)
    db = self:StampDefaults(db, self.defaults)

    -- Variant builds are intended for A/B testing; force engine/page defaults
    -- from the variant file so previous SavedVariables do not mask behavior.
    local addonName = self.addonName or "WoWX"
    local title = GetAddOnMetadata and (GetAddOnMetadata(addonName, "Title") or GetAddOnMetadata("WoWX", "Title") or GetAddOnMetadata("GamePadX", "Title")) or nil
    local isVariantBuild = title and string.find(string.lower(title), "variant", 1, true)
    if isVariantBuild then
        db.ui = db.ui or {}
        db.ui.visualBar = db.ui.visualBar or self:DeepCopy(self.defaults.ui.visualBar)
        db.ui.bindingEngine = self:DeepCopy(self.defaults.ui.bindingEngine)
        db.ui.visualBar.modifierPages = self.defaults.ui.visualBar.modifierPages
        db._variantDefaultsApplied = tostring(title)
    end

    -- First install bootstrap: default to enabled unless the user has already been bootstrapped.
    if db._bootstrapped == nil then
        db.enabled = true
        db._bootstrapped = true
    end

    -- Migration: default to WoWX-only HUD by hiding Blizzard micro menu and bag bar unless user re-enables.
    db.ui = db.ui or {}
    db.ui.visualBar = db.ui.visualBar or {}
    if db._visualBarDefaultsV2 == nil then
        db.ui.visualBar.keepBags = false
        db.ui.visualBar.keepMicroMenu = false
        db._visualBarDefaultsV2 = true
    end

    -- Migration: default modifier behavior to page switching.
    if db._visualBarDefaultsV3 == nil then
        db.ui.visualBar.modifierPages = true
        db._visualBarDefaultsV3 = true
    end

    -- Migration: move existing installs to WoWX-owned click transport.
    db.ui.bindingEngine = db.ui.bindingEngine or {}
    if db._bindingEngineDefaultsV2 == nil then
        db.ui.bindingEngine.transport = "click"
        db._bindingEngineDefaultsV2 = true
    end

    self.db = db
end

function GPX:DeepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[self:DeepCopy(k)] = self:DeepCopy(v)
    end
    return setmetatable(copy, getmetatable(orig))
end

function GPX:StampDefaults(target, defaults)
    if type(defaults) ~= "table" then
        return target
    end

    if type(target) ~= "table" then
        target = {}
    end

    for key, value in pairs(defaults) do
        if type(value) == "table" then
            target[key] = self:StampDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end

    return target
end

function GPX:GetProfile()
    local name = self.db.profile or "default"
    return self.db.profiles[name] or self.db.profiles["default"]
end

function GPX:GetInputStyle(styleId)
    return self.inputStyles[styleId] or self.inputStyles.keyboard
end

function GPX:GetCombatSlotLabels(styleId)
    local style = self:GetInputStyle(styleId)
    return style.combatSlotLabels or style.slotLabels or {}
end

function GPX:GetCombatDisplayLabels(styleId)
    local style = self:GetInputStyle(styleId)
    return style.combatDisplayLabels or style.combatSlotLabels or style.slotLabels or {}
end

function GPX:GetConfirmLabel(styleId)
    local style = self:GetInputStyle(styleId)
    return style.confirmLabel or "Jump / Confirm"
end

function GPX:GetConfiguredActionButtonCount(setup)
    local configured = tonumber(setup and setup.actionButtonCount)
    local labels = self:GetCombatSlotLabels(setup and setup.deviceId)

    if self:IsControllerEnabled() and #labels > 0 then
        if configured and configured > 0 then
            return math.min(configured, #labels)
        end
        return #labels
    end

    if configured and configured > 0 then
        return configured
    end

    return 12
end

function GPX:GetActionKeyBaseSlot(setup)
    local baseSlot = tonumber(setup and setup.actionKeyBaseSlot)
    if baseSlot and baseSlot >= 1 then
        return baseSlot
    end

    if self:IsControllerEnabled() then
        return 1
    end

    return 2
end

function GPX:GetActionKeyArrayIndex(setup, slotIndex)
    local baseSlot = self:GetActionKeyBaseSlot(setup)
    local arrayIndex = tonumber(slotIndex) and (tonumber(slotIndex) - baseSlot + 1) or nil
    if not arrayIndex or arrayIndex < 1 then
        return nil
    end

    return arrayIndex
end

function GPX:GetSetupActionKey(setup, slotIndex)
    local arrayIndex = self:GetActionKeyArrayIndex(setup, slotIndex)
    if not arrayIndex or not setup or not setup.actionKeys then
        return nil
    end

    return setup.actionKeys[arrayIndex]
end

function GPX:SetSetupActionKey(setup, slotIndex, value)
    local arrayIndex = self:GetActionKeyArrayIndex(setup, slotIndex)
    if not arrayIndex or not setup then
        return
    end

    setup.actionKeys = setup.actionKeys or {}
    setup.actionKeys[arrayIndex] = value
end

function GPX:HasCalibratedSetup(profile)
    profile = profile or self:GetProfile()
    local setup = profile and profile.setup or nil
    if not setup then
        return false
    end

    if not setup.jumpKey or setup.jumpKey == "" then
        return false
    end

    if not setup.modifiers or #setup.modifiers < 3 then
        return false
    end

    local firstActionSlot = self:GetActionKeyBaseSlot(setup)
    local lastActionSlot = self:GetConfiguredActionButtonCount(setup)
    for slotIndex = firstActionSlot, lastActionSlot do
        local key = self:GetSetupActionKey(setup, slotIndex)
        if not key or key == "" then
            return false
        end
    end

    return true
end

function GPX:BuildModifiedKey(modifiers, key)
    if not modifiers or #modifiers == 0 then
        return key
    end

    return table.concat(modifiers, "-") .. "-" .. key
end

function GPX:BuildBindingsFromSetup(setup)
    local bindings = {}
    if not setup then
        return bindings
    end

    local jumpKey = setup.jumpKey
    local firstActionSlot = self:GetActionKeyBaseSlot(setup)
    local lastActionSlot = self:GetConfiguredActionButtonCount(setup)
    local modifiers = { "SHIFT", "ALT", "CTRL" }
    local modifierPages = {
        { modifiers = { modifiers[1] }, bar = "MULTIACTIONBAR2BUTTON" },
        { modifiers = { modifiers[2] }, bar = "MULTIACTIONBAR1BUTTON" },
        { modifiers = { modifiers[3] }, bar = "MULTIACTIONBAR4BUTTON" },
        { modifiers = { modifiers[1], modifiers[2] }, bar = "MULTIACTIONBAR3BUTTON" },
        { modifiers = { modifiers[1], modifiers[3] }, bar = "MULTICASTBUTTON" },
    }

    if firstActionSlot > 1 and jumpKey and jumpKey ~= "" then
        bindings[jumpKey] = "ACTIONBUTTON1"
    end

    if setup.menuKey and setup.menuKey ~= "" then
        bindings[setup.menuKey] = "TOGGLEGAMEMENU"
    end

    if setup.lookKey and setup.lookKey ~= "" then
        bindings[setup.lookKey] = "CAMERAORSELECTORMOVE"
    end

    for slotIndex = firstActionSlot, lastActionSlot do
        local key = self:GetSetupActionKey(setup, slotIndex)
        if key and key ~= "" then
            bindings[key] = "ACTIONBUTTON" .. slotIndex
        end
    end

    for _, page in ipairs(modifierPages) do
        local valid = true
        local parts = {}
        for _, modifierKey in ipairs(page.modifiers) do
            if modifierKey and modifierKey ~= "" then
                parts[#parts + 1] = modifierKey
            else
                valid = false
            end
        end

        if valid and #parts > 0 and page.bar then
            if firstActionSlot > 1 and jumpKey and jumpKey ~= "" then
                bindings[self:BuildModifiedKey(parts, jumpKey)] = page.bar .. "1"
                if #parts == 2 then
                    bindings[self:BuildModifiedKey({ parts[2], parts[1] }, jumpKey)] = page.bar .. "1"
                end
            end

            for slotIndex = firstActionSlot, lastActionSlot do
                local key = self:GetSetupActionKey(setup, slotIndex)
                if key and key ~= "" then
                    bindings[self:BuildModifiedKey(parts, key)] = page.bar .. slotIndex
                    if #parts == 2 then
                        bindings[self:BuildModifiedKey({ parts[2], parts[1] }, key)] = page.bar .. slotIndex
                    end
                end
            end
        end
    end

    return bindings
end

function GPX:IsControllerEnabled()
    return self.db and self.db.ui and self.db.ui.controller and self.db.ui.controller.enabled == true
end

function GPX:GetControllerConfig()
    self.db.ui = self.db.ui or {}
    self.db.ui.controller = self.db.ui.controller or {}

    local cfg = self.db.ui.controller
    if cfg.enabled == nil then
        cfg.enabled = false
    end
    if cfg.autoMouseLookOnMove == nil then
        cfg.autoMouseLookOnMove = true
    end
    if cfg.centerCursorOnMove == nil then
        cfg.centerCursorOnMove = true
    end
    if tonumber(cfg.mouseLookDelayMs) == nil then
        cfg.mouseLookDelayMs = 1000
    end

    return cfg
end

function GPX:SetControllerEnabled(enabled)
    local cfg = self:GetControllerConfig()
    cfg.enabled = enabled and true or false

    if not cfg.enabled then
        self.controllerMovePending = nil
        self.controllerMoveStartedAt = nil
        self:StopControllerMouseLook()
    end
end

function GPX:ShouldUseControllerMouseLook()
    local cfg = self:GetControllerConfig()
    if not cfg.autoMouseLookOnMove then
        return false
    end
    if not self:IsControllerEnabled() or not (self.db and self.db.enabled) then
        return false
    end
    if self.UIMode and self.UIMode.activeContext then
        return false
    end
    return true
end

function GPX:CenterControllerCursor()
    local cfg = self:GetControllerConfig()
    if not cfg.centerCursorOnMove then
        return false
    end

    if MoveCursorToCenter then
        local ok = pcall(MoveCursorToCenter)
        return ok
    end

    return false
end

function GPX:StartControllerMouseLook()
    if self.controllerMouseLookActive or not self:ShouldUseControllerMouseLook() then
        return
    end

    self:CenterControllerCursor()

    if MouselookStart then
        MouselookStart()
        self.controllerMouseLookActive = true
        return
    end

    if CameraOrSelectOrMoveStart then
        CameraOrSelectOrMoveStart()
        self.controllerMouseLookActive = true
    end
end

function GPX:StopControllerMouseLook()
    if not self.controllerMouseLookActive then
        return
    end

    if MouselookStop then
        MouselookStop()
    elseif CameraOrSelectOrMoveStop then
        CameraOrSelectOrMoveStop()
    end

    self.controllerMouseLookActive = nil
end

function GPX:SetControllerMovementState(isMoving)
    if isMoving then
        if not self:ShouldUseControllerMouseLook() then
            return
        end

        if self.controllerMouseLookActive then
            return
        end

        self.controllerMoveStartedAt = GetTime()
        self.controllerMovePending = true
        if mainFrame then
            mainFrame:SetScript("OnUpdate", function()
                if not GPX.controllerMovePending then
                    if mainFrame then
                        mainFrame:SetScript("OnUpdate", nil)
                    end
                    return
                end

                local cfg = GPX:GetControllerConfig()
                local delay = math.max(0, tonumber(cfg.mouseLookDelayMs) or 0) / 1000
                if (GetTime() - (GPX.controllerMoveStartedAt or 0)) >= delay then
                    GPX.controllerMovePending = nil
                    GPX.controllerMoveStartedAt = nil
                    GPX:StartControllerMouseLook()
                    if mainFrame then
                        mainFrame:SetScript("OnUpdate", nil)
                    end
                end
            end)
        end
        return
    end

    self.controllerMovePending = nil
    self.controllerMoveStartedAt = nil
    if mainFrame then
        mainFrame:SetScript("OnUpdate", nil)
    end
    self:StopControllerMouseLook()
end

function GPX:ApplySetup(setup)
    local profile = self:GetProfile()
    if not profile then
        return
    end

    profile.setup = self:DeepCopy(setup)
    profile.inputStyle = setup.deviceId
    profile.name = self.brand .. " " .. self:GetInputStyle(setup.deviceId).name
    profile.bindings = self:BuildBindingsFromSetup(setup)

    self.db.enabled = true
    self:ClearBindings()
    self:ApplyBindings()
    if self.VisualBar then
        self.VisualBar:UpdateAll()
    end
    if self.SettingsUI then
        self.SettingsUI:Refresh()
    end
end

function GPX:OpenSetupWizard(mode)
    if ChatFrameEditBox and ChatFrameEditBox:IsShown() and ChatEdit_DeactivateChat then
        ChatEdit_DeactivateChat(ChatFrameEditBox)
    end

    if self.SettingsUI and self.SettingsUI.frame and self.SettingsUI.frame:IsShown() then
        self.SettingsUI.frame:Hide()
    end
    if self.SpellbookUI and self.SpellbookUI.frame and self.SpellbookUI.frame:IsShown() then
        self.SpellbookUI.frame:Hide()
    end
    if self.UIMode then
        self.UIMode:Exit()
    end

    if self.SetupWizard then
            self:Print("Opening setup wizard.")
        local ok, err = pcall(function()
            self.SetupWizard:Open(mode or "init")
        end)
        if not ok then
                self:LogError("Setup wizard failed to open: " .. tostring(err))
        elseif self.db then
            self.db.lastError = ""
        end
    else
        self:Print("Setup wizard module not loaded.")
    end
end

function GPX:OpenMenuNav(returnContext)
    if self.MenuNav then
        local ok, err = pcall(function()
            self.MenuNav:Open(returnContext)
        end)
        if not ok then
                self:LogError("Menu navigator failed to open: " .. tostring(err))
        end
    else
        self:Print("Menu navigation module not loaded.")
    end
end

function GPX:OpenSettings()
    if self.SetupWizard and self.SetupWizard.frame and self.SetupWizard.frame:IsShown() then
        self.SetupWizard.frame:Hide()
    end

    if self.SettingsUI then
        self:Print("Opening settings.")
        local ok, err = pcall(function()
            self.SettingsUI:Open()
        end)
        if not ok then
                self:LogError("Settings failed to open: " .. tostring(err))
        end
    else
        self:Print("Settings window module not loaded.")
    end
end

function GPX:GetOrCreateSetup(profile)
    profile = profile or self:GetProfile()
    profile.setup = profile.setup or {
        deviceId = "keyboard",
        movement = {},
        modifiers = {},
        jumpKey = nil,
        menuKey = nil,
        lookKey = nil,
        actionKeys = {},
        actionKeyBaseSlot = 2,
        actionButtonCount = 12,
    }
    profile.setup.movement = profile.setup.movement or {}
    profile.setup.modifiers = profile.setup.modifiers or {}
    profile.setup.actionKeys = profile.setup.actionKeys or {}
    profile.setup.deviceId = profile.setup.deviceId or profile.inputStyle or "keyboard"
    profile.setup.actionKeyBaseSlot = tonumber(profile.setup.actionKeyBaseSlot) or 2
    profile.setup.actionButtonCount = tonumber(profile.setup.actionButtonCount) or 12
    return profile.setup
end

function GPX:ApplySetupFromProfile(profile, opts)
    profile = profile or self:GetProfile()
    opts = opts or {}
    if not profile or not profile.setup then
        return false, "No setup available yet."
    end

    profile.inputStyle = profile.setup.deviceId or profile.inputStyle or "keyboard"
    profile.name = self.brand .. " " .. self:GetInputStyle(profile.inputStyle).name
    profile.bindings = self:BuildBindingsFromSetup(profile.setup)

    if self.db and self.db.enabled and not opts.deferBindings then
        self:ClearBindings()
        self:ApplyBindings()
    end
    if self.VisualBar then
        self.VisualBar:UpdateAll()
    end
    if self.SettingsUI then
        self.SettingsUI:Refresh()
    end
    return true
end

function GPX:PrintDiagnostics()
    local lines = self:CollectDiagnosticsLines()
    for _, line in ipairs(lines) do
        self:Print(line)
    end
end

function GPX:GetDiagnosticsConfig()
    self.db.diagnostics = self.db.diagnostics or {}
    if self.db.diagnostics.autoCapture == nil then
        self.db.diagnostics.autoCapture = false
    end
    return self.db.diagnostics
end

function GPX:CollectDiagnosticsLines()
    local lines = {}
    local function add(msg)
        lines[#lines + 1] = tostring(msg)
    end

    local function append(source)
        for _, line in ipairs(source or {}) do
            add(line)
        end
    end

    local function sanitizeBindingAction(text)
        if not text then
            return ""
        end
        local s = tostring(text)
        if s == "" then
            return ""
        end
        if string.find(s, "UNKNOWN", 1, true) then
            return ""
        end
        return s
    end

    local function frameState(module, frameName)
        if not module then
            return "module missing"
        end
        local frame = module.frame
        if not frame then
            return "frame not created"
        end
        return frame:IsShown() and (frameName .. " shown") or (frameName .. " hidden")
    end

    add("Diagnostics:")
    add("  BuildTag: 2026-05-08-conditional-bonusbar-route-v1")
    add("  Enabled: " .. tostring(self.db and self.db.enabled))
    add("  Slash: /wowx registered (legacy aliases active)")
    add("  SetupWizard: " .. frameState(self.SetupWizard, "wizard"))
    add("  SettingsUI: " .. frameState(self.SettingsUI, "settings"))
    add("  MenuNav: " .. frameState(self.MenuNav, "menu"))
    add("  VisualBar: " .. frameState(self.VisualBar, "bar"))
    add("  InCombat: " .. tostring(InCombatLockdown() and true or false))
    if self.db and self.db.ui and self.db.ui.visualBar then
        local modPages = self.db.ui.visualBar.modifierPages == true
        add("  ModifierPages: " .. (modPages and "ON" or "OFF (same-slot modifiers)"))
    end
    if self.GetBindingEngineConfig then
        local ecfg = self:GetBindingEngineConfig()
        add("  EngineCfg: transport=" .. tostring(ecfg.transport)
            .. " useSetupKeys=" .. tostring(ecfg.useSetupKeys)
            .. " claimModifiers=" .. tostring(ecfg.claimModifiers)
            .. " claimCombo=" .. tostring(ecfg.claimCombo))
    end
    if self.VisualBar and self.VisualBar.GetCurrentState then
        add("  ActiveModifierState: " .. tostring(self.VisualBar:GetCurrentState() or ""))
    end
    add("  ActionPage: page=" .. tostring(GetActionBarPage and GetActionBarPage() or "n/a")
        .. " bonusOffset=" .. tostring(GetBonusBarOffset and GetBonusBarOffset() or "n/a")
        .. " hasBonus=" .. tostring(HasBonusActionBar and HasBonusActionBar() or false)
        .. " hasOverride=" .. tostring(HasOverrideActionBar and HasOverrideActionBar() or false))
    do
        local overrideFrames = {
            "OverrideActionBar",
            "OverrideActionBarFrame",
            "OverrideActionBarArtFrame",
            "OverrideActionBarLeaveFrame",
            "BonusActionBarFrame",
            "PossessBarFrame",
            "ShapeshiftBarFrame",
        }
        local frameParts = {}
        for _, name in ipairs(overrideFrames) do
            local frame = _G[name]
            if frame then
                local shown = frame.IsShown and frame:IsShown() or false
                frameParts[#frameParts + 1] = name .. "=" .. (shown and "shown" or "hidden")
            else
                frameParts[#frameParts + 1] = name .. "=missing"
            end
        end
        add("  OverrideFrames: " .. table.concat(frameParts, " | "))

        local buttonParts = {}
        for index = 1, 12 do
            local button = _G["OverrideActionBarButton" .. index]
            if button then
                local action = button.action or "nil"
                local shown = button.IsShown and button:IsShown() or false
                buttonParts[#buttonParts + 1] = tostring(index) .. "=" .. tostring(action) .. "/" .. (shown and "shown" or "hidden")
            end
        end
        if #buttonParts > 0 then
            add("  OverrideButtons: " .. table.concat(buttonParts, " | "))
        end
    end
    if self.VisualBar and self.VisualBar.frame and self.VisualBar.frame.buttons and self.VisualBar.frame.buttons[2] then
        local button = self.VisualBar.frame.buttons[2]
        local dtype = button.GetAttribute and button:GetAttribute("type") or nil
        local action = button.GetAttribute and button:GetAttribute("action") or nil
        local dtype1 = button.GetAttribute and button:GetAttribute("type1") or nil
        local action1 = button.GetAttribute and button:GetAttribute("action1") or nil
        local macrotext1 = button.GetAttribute and button:GetAttribute("macrotext1") or nil
        local shiftAction = button.GetAttribute and button:GetAttribute("shift-action") or nil
        local altAction = button.GetAttribute and button:GetAttribute("alt-action") or nil
        local ctrlAction = button.GetAttribute and button:GetAttribute("ctrl-action") or nil
        local comboAction = button.GetAttribute and (button:GetAttribute("shift-alt-action") or button:GetAttribute("alt-shift-action")) or nil
        local slot = button.display and button.display.slot or nil
        add("  BarSlot2 attr(type/action): " .. tostring(dtype) .. "/" .. tostring(action) .. "  displaySlot=" .. tostring(slot))
        add("  BarSlot2 attr(type1/action1/macro1): " .. tostring(dtype1) .. "/" .. tostring(action1) .. "/" .. tostring(macrotext1))
        add("  BarSlot2 mod actions: shift=" .. tostring(shiftAction) .. " alt=" .. tostring(altAction) .. " ctrl=" .. tostring(ctrlAction) .. " shift+alt=" .. tostring(comboAction))
    end
    add("  Keybind 1: " .. tostring(GetBindingAction("1") or ""))
    add("  Keybind SHIFT-1: " .. tostring(GetBindingAction("SHIFT-1") or ""))
    add("  Keybind ALT-1: " .. tostring(GetBindingAction("ALT-1") or ""))
    add("  Keybind CTRL-1: " .. tostring(GetBindingAction("CTRL-1") or ""))
    local profile = self:GetProfile()
    local setup = profile and profile.setup or nil
    local slot4Key = setup and setup.actionKeys and setup.actionKeys[3] or "4"
    add("  Slot4 keybind: " .. tostring(slot4Key) .. "=" .. tostring(GetBindingAction(slot4Key) or ""))
    add("  Slot4 shift bind: SHIFT-" .. tostring(slot4Key) .. "=" .. tostring(GetBindingAction("SHIFT-" .. slot4Key) or ""))
    local actionButton1 = _G.ActionButton1
    if actionButton1 then
        local liveActionParts = {}
        for index = 1, 12 do
            local actionButton = _G["ActionButton" .. index]
            liveActionParts[#liveActionParts + 1] = tostring(index) .. "=" .. tostring(actionButton and actionButton.action or "nil")
        end
        add("  LiveActionButton slots: " .. table.concat(liveActionParts, " | "))
    end

    local quickKeys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" }
    local quickPrefixes = { "", "SHIFT-", "ALT-", "CTRL-", "SHIFT-ALT-" }
    for _, prefix in ipairs(quickPrefixes) do
        local parts = {}
        for _, key in ipairs(quickKeys) do
            local bind = sanitizeBindingAction(GetBindingAction(prefix .. key))
            parts[#parts + 1] = key .. "=" .. tostring(bind or "")
        end
        local label = (prefix == "") and "base" or string.lower(prefix)
        add("  KeyMatrix " .. label .. ": " .. table.concat(parts, " | "))
    end

    -- Deterministic key sweep for 1..= without trying to auto-fire protected actions.
    -- This captures what each key combination is currently wired to and the secure action slot on WoWX buttons.
    local modifierAttrMap = {
        [""] = "action",
        ["SHIFT-"] = "shift-action",
        ["ALT-"] = "alt-action",
        ["CTRL-"] = "ctrl-action",
        ["SHIFT-ALT-"] = "shift-alt-action",
    }
    if self.VisualBar and self.VisualBar.frame and self.VisualBar.frame.buttons then
        add("  KeySweep 1..=:")
        for _, prefix in ipairs(quickPrefixes) do
            for idx, key in ipairs(quickKeys) do
                local bindAction = sanitizeBindingAction(GetBindingAction(prefix .. key))
                local btn = self.VisualBar.frame.buttons[idx]
                local attrName = modifierAttrMap[prefix]
                local secureSlot = nil
                local secureType1 = nil
                local secureAction1 = nil
                local secureMacro1 = nil
                if btn and btn.GetAttribute then
                    if prefix == "SHIFT-ALT-" then
                        secureSlot = btn:GetAttribute("shift-alt-action") or btn:GetAttribute("alt-shift-action")
                        secureType1 = btn:GetAttribute("shift-alt-type1") or btn:GetAttribute("alt-shift-type1")
                        secureAction1 = btn:GetAttribute("shift-alt-action1") or btn:GetAttribute("alt-shift-action1")
                        secureMacro1 = btn:GetAttribute("shift-alt-macrotext1") or btn:GetAttribute("alt-shift-macrotext1")
                    else
                        secureSlot = btn:GetAttribute(attrName)
                        if prefix == "" then
                            secureType1 = btn:GetAttribute("type1")
                            secureAction1 = btn:GetAttribute("action1")
                            secureMacro1 = btn:GetAttribute("macrotext1")
                        elseif prefix == "SHIFT-" then
                            secureType1 = btn:GetAttribute("shift-type1")
                            secureAction1 = btn:GetAttribute("shift-action1")
                            secureMacro1 = btn:GetAttribute("shift-macrotext1")
                        elseif prefix == "ALT-" then
                            secureType1 = btn:GetAttribute("alt-type1")
                            secureAction1 = btn:GetAttribute("alt-action1")
                            secureMacro1 = btn:GetAttribute("alt-macrotext1")
                        elseif prefix == "CTRL-" then
                            secureType1 = btn:GetAttribute("ctrl-type1")
                            secureAction1 = btn:GetAttribute("ctrl-action1")
                            secureMacro1 = btn:GetAttribute("ctrl-macrotext1")
                        end
                    end
                end
                local label = (prefix == "") and key or (prefix .. key)
                local displaySlot = btn and btn.display and btn.display.slot or nil
                add("    " .. label .. " => bind='" .. tostring(bindAction) .. "' displaySlot=" .. tostring(displaySlot)
                    .. " secureSlot=" .. tostring(secureSlot)
                    .. " type1=" .. tostring(secureType1)
                    .. " action1=" .. tostring(secureAction1)
                    .. " macro1=" .. tostring(secureMacro1))
            end
        end
    end

    if self.VisualBar and self.VisualBar.frame and self.VisualBar.frame.buttons then
        for i = 1, 12 do
            local btn = self.VisualBar.frame.buttons[i]
            if btn then
                local bType = btn.GetAttribute and btn:GetAttribute("type") or nil
                local bAction = btn.GetAttribute and btn:GetAttribute("action") or nil
                local bShift = btn.GetAttribute and btn:GetAttribute("shift-action") or nil
                local bAlt = btn.GetAttribute and btn:GetAttribute("alt-action") or nil
                local bCtrl = btn.GetAttribute and btn:GetAttribute("ctrl-action") or nil
                local bCombo = btn.GetAttribute and (btn:GetAttribute("shift-alt-action") or btn:GetAttribute("alt-shift-action")) or nil
                local bType1 = btn.GetAttribute and btn:GetAttribute("type1") or nil
                local bAction1 = btn.GetAttribute and btn:GetAttribute("action1") or nil
                local bMacro1 = btn.GetAttribute and btn:GetAttribute("macrotext1") or nil
                local displaySlot = btn.display and btn.display.slot or nil
                local displayCmd = btn.display and btn.display.command or nil
                add("  Btn" .. i .. " attr=" .. tostring(bType) .. "/" .. tostring(bAction)
                    .. " type1=" .. tostring(bType1) .. "/" .. tostring(bAction1)
                    .. " macro1=" .. tostring(bMacro1)
                    .. " shift=" .. tostring(bShift)
                    .. " alt=" .. tostring(bAlt)
                    .. " ctrl=" .. tostring(bCtrl)
                    .. " combo=" .. tostring(bCombo)
                    .. " displaySlot=" .. tostring(displaySlot)
                    .. " displayCmd=" .. tostring(displayCmd))
            end
        end
    end

    if self.appliedBindings then
        local keys = {}
        for key in pairs(self.appliedBindings) do
            keys[#keys + 1] = key
        end
        table.sort(keys)
        add("  AppliedBindings count: " .. tostring(#keys))
        for _, key in ipairs(keys) do
            local info = self.appliedBindings[key]
            local mode = type(info) == "table" and info.mode or "legacy"
            local cmd = type(info) == "table" and info.command or tostring(info)
            add("    " .. key .. " -> " .. tostring(cmd) .. " [" .. tostring(mode) .. "]")
        end
    end

    if self.db and self.db.lastError and self.db.lastError ~= "" then
        add("  LastError: " .. self.db.lastError)
    end

    append(self:CollectStanceDiagnosticsLines())

    return lines
end

function GPX:CollectStanceDiagnosticsLines()
    local lines = {}
    local function add(msg)
        lines[#lines + 1] = tostring(msg)
    end

    local function frameName(frame, fallback)
        if not frame then
            return fallback or "nil"
        end
        if frame.GetName then
            local name = frame:GetName()
            if name and name ~= "" then
                return name
            end
        end
        return fallback or "anonymous"
    end

    local className, classFile = UnitClass("player")
    add("StanceDiag:")
    add("  PlayerClass: " .. tostring(className or "") .. " (" .. tostring(classFile or "") .. ")")

    local formCount = GetNumShapeshiftForms and (GetNumShapeshiftForms() or 0) or 0
    local currentForm = GetShapeshiftForm and (GetShapeshiftForm() or 0) or 0
    add("  ShapeshiftForms: count=" .. tostring(formCount) .. " current=" .. tostring(currentForm))

    local frameNames = { "StanceBarFrame", "ShapeshiftBarFrame", "PossessBarFrame" }
    for _, name in ipairs(frameNames) do
        local frame = _G[name]
        if frame then
            local parent = frame.GetParent and frame:GetParent() or nil
            add("  Frame " .. name
                .. ": shown=" .. tostring(frame.IsShown and frame:IsShown() or false)
                .. " alpha=" .. tostring(frame.GetAlpha and frame:GetAlpha() or "n/a")
                .. " parent=" .. frameName(parent, "nil"))
        else
            add("  Frame " .. name .. ": missing")
        end
    end

    for index = 1, math.max(12, formCount) do
        local button = _G["ShapeshiftButton" .. index] or _G["StanceButton" .. index] or _G["PossessButton" .. index]
        if button then
            local parent = button.GetParent and button:GetParent() or nil
            local icon, name, active, castable = nil, nil, nil, nil
            if GetShapeshiftFormInfo then
                icon, name, active, castable = GetShapeshiftFormInfo(index)
            end
            add("  Button" .. index
                .. ": shown=" .. tostring(button.IsShown and button:IsShown() or false)
                .. " alpha=" .. tostring(button.GetAlpha and button:GetAlpha() or "n/a")
                .. " parent=" .. frameName(parent, "nil")
                .. " formName=" .. tostring(name or "")
                .. " active=" .. tostring(active)
                .. " castable=" .. tostring(castable)
                .. " icon=" .. tostring(icon))
        elseif index <= formCount then
            add("  Button" .. index .. ": missing despite formCount")
        end
    end

    return lines
end

function GPX:RunDiagnosticSpeedRun(label)
    if not self.db then
        return
    end
    self.db.diagRuns = self.db.diagRuns or {}

    if self.VisualBar then
        self.VisualBar:UpdateAll()
    end

    local lines = self:CollectDiagnosticsLines()
    local stamp = date("%Y%m%d-%H%M%S")
    local cleanLabel = label and label ~= "" and label or "diag"
    local run = {
        at = date("%Y-%m-%d %H:%M:%S"),
        label = cleanLabel .. "-" .. stamp,
        lines = lines,
    }

    table.insert(self.db.diagRuns, run)
    while #self.db.diagRuns > 25 do
        table.remove(self.db.diagRuns, 1)
    end
    self.db.lastDiagRun = run

    self:Print("Diag captured " .. tostring(#lines) .. " lines.")
    self:Print("Stored in SavedVariables: WoWXDB.diagRuns (WTF/Account/.../CharacterName/SavedVariables/WoWX.lua).")
end

function GPX:RunAutomaticDiagnosticCapture(trigger)
    if not self.db then
        return
    end

    local cfg = self:GetDiagnosticsConfig()
    if cfg.autoCapture == false then
        return
    end

    self._autoDiagSeen = self._autoDiagSeen or {}
    if self._autoDiagSeen[trigger] then
        return
    end
    self._autoDiagSeen[trigger] = true

    local label = "auto-" .. tostring(trigger or "event")
    self:RunDiagnosticSpeedRun(label)
    self:Print("Auto diag captured: " .. label)
end

function GPX:PrintLastDiagnosticRun()
    local run = self.db and self.db.lastDiagRun or nil
    if not run or not run.lines then
        self:Print("No saved diag run. Use /wowx diag verbose first.")
        return
    end

    self:Print("Diag run: " .. tostring(run.at) .. "  label=" .. tostring(run.label))
    for _, line in ipairs(run.lines) do
        self:Print(line)
    end
end

function GPX:BuildDiagText(lines, runTitle)
    local out = {}
    out[#out + 1] = self.brand .. " Diagnostics"
    if runTitle and runTitle ~= "" then
        out[#out + 1] = runTitle
    end
    out[#out + 1] = ""
    for _, line in ipairs(lines or {}) do
        out[#out + 1] = tostring(line)
    end
    return table.concat(out, "\n")
end

function GPX:EnsureDiagWindow()
    if self.diagWindow then
        return self.diagWindow
    end

    local frame = CreateFrame("Frame", "WoWXDiagWindow", UIParent)
    frame:SetWidth(900)
    frame:SetHeight(560)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 24,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.95)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
    title:SetText(self.brand .. " Debug Window")

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Use Capture to snapshot current state. Scroll and inspect without chat spam.")

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

    local captureButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    captureButton:SetWidth(100)
    captureButton:SetHeight(22)
    captureButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -44)
    captureButton:SetText("Capture")

    local refreshButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refreshButton:SetWidth(100)
    refreshButton:SetHeight(22)
    refreshButton:SetPoint("LEFT", captureButton, "RIGHT", 8, 0)
    refreshButton:SetText("Refresh")

    local clearButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clearButton:SetWidth(100)
    clearButton:SetHeight(22)
    clearButton:SetPoint("LEFT", refreshButton, "RIGHT", 8, 0)
    clearButton:SetText("Clear")

    local copyButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    copyButton:SetWidth(100)
    copyButton:SetHeight(22)
    copyButton:SetPoint("LEFT", clearButton, "RIGHT", 8, 0)
    copyButton:SetText("Select All")

    local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("LEFT", copyButton, "RIGHT", 12, 0)
    statusText:SetText("")
    statusText:SetTextColor(0.8, 0.9, 1.0)

    local contentBorder = CreateFrame("Frame", nil, frame)
    contentBorder:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -72)
    contentBorder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 14)
    contentBorder:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    contentBorder:SetBackdropColor(0.02, 0.03, 0.05, 0.95)
    contentBorder:SetBackdropBorderColor(0.2, 0.34, 0.52, 0.85)

    local scroll = CreateFrame("ScrollFrame", "WoWXDiagScrollFrame", contentBorder, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", contentBorder, "TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", contentBorder, "BOTTOMRIGHT", -28, 8)

    local edit = CreateFrame("EditBox", "WoWXDiagTextBox", scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:EnableMouse(true)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(840)
    edit:SetTextInsets(4, 4, 4, 4)
    edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    local function getDiagEditHeight(box)
        if box and box.GetStringHeight then
            local ok, measured = pcall(box.GetStringHeight, box)
            if ok and measured and measured > 0 then
                return measured + 24
            end
        end

        local text = (box and box.GetText and box:GetText()) or ""
        local lineCount = 1
        for _ in string.gmatch(text, "\n") do
            lineCount = lineCount + 1
        end

        local _, fontHeight = (box and box.GetFont and box:GetFont())
        local rowHeight = tonumber(fontHeight) or 12
        local fallback = (lineCount * rowHeight) + 24
        if fallback < 1 then
            fallback = 1
        end
        return fallback
    end

    edit:SetScript("OnTextChanged", function(self)
        self:SetHeight(getDiagEditHeight(self))
    end)
    scroll:SetScrollChild(edit)

    local function renderLatest()
        local run = GPX.db and GPX.db.lastDiagRun or nil
        if run and run.lines then
            local header = "Run: " .. tostring(run.at or "") .. "  label=" .. tostring(run.label or "")
            edit:SetText(GPX:BuildDiagText(run.lines, header))
            statusText:SetText("Loaded latest run.")
        else
            edit:SetText(GPX:BuildDiagText({ "No diagnostic run captured yet.", "Use Capture or /wowx diag verbose." }, ""))
            statusText:SetText("No run captured yet.")
        end
        edit:SetCursorPosition(0)
        scroll:SetVerticalScroll(0)
    end

    captureButton:SetScript("OnClick", function()
        GPX:RunDiagnosticSpeedRun("window")
        renderLatest()
    end)

    refreshButton:SetScript("OnClick", function()
        renderLatest()
    end)

    clearButton:SetScript("OnClick", function()
        edit:SetText("")
        statusText:SetText("Cleared window text.")
    end)

    copyButton:SetScript("OnClick", function()
        edit:SetFocus()
        local text = edit:GetText() or ""
        edit:HighlightText(0, string.len(text))
        statusText:SetText("Text selected. Press Ctrl+C.")
    end)

    frame._wowxDiagRenderLatest = renderLatest
    frame._wowxDiagEdit = edit
    frame._wowxDiagStatus = statusText

    self.diagWindow = frame
    return frame
end

function GPX:ShowDiagWindow()
    local frame = self:EnsureDiagWindow()
    frame:Show()
    if frame._wowxDiagRenderLatest then
        frame._wowxDiagRenderLatest()
    end
    frame:Raise()
end

function GPX:ToggleDiagWindow()
    local frame = self:EnsureDiagWindow()
    if frame:IsShown() then
        frame:Hide()
    else
        self:ShowDiagWindow()
    end
end

-- ============================================================
-- BINDING ENGINE
-- WoWX uses session override-click bindings to its secure bar buttons.
-- This avoids rewriting the player's Blizzard keybind table.
-- On next login PLAYER_LOGIN re-applies WoWX overrides when enabled.
-- ============================================================
GPX.appliedBindings = {}   -- track what we set so we can clean up
GPX.previousBindings = {}  -- key -> command that existed before WoWX remap

local baseActionKeys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" }
local baseActionPages = {
    { prefix = "", page = "ACTIONBUTTON" },
    { prefix = "SHIFT-", page = "MULTIACTIONBAR2BUTTON" },
    { prefix = "ALT-", page = "MULTIACTIONBAR1BUTTON" },
    { prefix = "CTRL-", page = "MULTIACTIONBAR4BUTTON" },
    { prefix = "SHIFT-ALT-", page = "MULTIACTIONBAR3BUTTON" },
}
local blizzardPageCommands = {
    "ACTIONPAGE1",
    "ACTIONPAGE2",
    "ACTIONPAGE3",
    "ACTIONPAGE4",
    "ACTIONPAGE5",
    "ACTIONPAGE6",
    "NEXTACTIONPAGE",
    "PREVACTIONPAGE",
}

local blizzardCombatUiCommands = {
    -- Battleground/world-state scoreboard and related minimap toggles can
    -- conflict with held-modifier combat input on CoA.
    "TOGGLEWORLDSTATESCORES",
    "TOGGLEBATTLEFIELDMINIMAP",
    "TOGGLEBATTLEFIELD",
}

function GPX:IsSpecialActionStateActive()
    if CanExitVehicle and CanExitVehicle() then
        return true, "vehicle"
    end
    if UnitHasVehicleUI and UnitHasVehicleUI("player") then
        return true, "vehicle"
    end
    if HasVehicleActionBar and HasVehicleActionBar() then
        return true, "vehicle"
    end
    if HasOverrideActionBar and HasOverrideActionBar() then
        return true, "override"
    end
    if HasBonusActionBar and HasBonusActionBar() then
        return true, "bonus"
    end
    if GetBonusBarOffset and (GetBonusBarOffset() or 0) > 0 then
        return true, "bonus"
    end

    local possessFrame = _G.PossessBarFrame
    if possessFrame and possessFrame.IsShown and possessFrame:IsShown() then
        return true, "possess"
    end

    return false, nil
end

function GPX:ShouldSuspendForSpecialActionState(reason)
    local engine = self:GetBindingEngineConfig()
    if reason == "override" and self:IsStaleOverrideActionState() then
        return false
    end
    if reason == "bonus" then
        return false
    end
    return engine.transport == "click" or engine.transport == "override"
end

function GPX:HasVisibleOverrideUI()
    local frames = {
        "OverrideActionBar",
        "OverrideActionBarFrame",
        "OverrideActionBarArtFrame",
        "OverrideActionBarLeaveFrame",
    }

    for _, name in ipairs(frames) do
        local frame = _G[name]
        if frame and frame.IsShown and frame:IsShown() then
            return true
        end
    end

    for index = 1, 12 do
        local button = _G["OverrideActionBarButton" .. index]
        if button and button.IsShown and button:IsShown() then
            return true
        end
    end

    return false
end

function GPX:IsStaleOverrideActionState()
    if not (HasOverrideActionBar and HasOverrideActionBar()) then
        return false
    end

    return not self:HasVisibleOverrideUI()
end

function GPX:RefreshActionStateSafety(silent)
    if not self.db or not self.db.enabled then
        return
    end

    local active, reason = self:IsSpecialActionStateActive()
    local shouldSuspend = active and self:ShouldSuspendForSpecialActionState(reason)

    if shouldSuspend then
        self.actionStateSuspended = true
        self.actionStateReason = reason
        if next(self.appliedBindings) then
            self:ClearBindings(true)
        end
        if self.VisualBar then
            self.VisualBar:UpdateAll()
        end
        if self.SettingsUI and self.SettingsUI.frame and self.SettingsUI.frame:IsShown() then
            self.SettingsUI:Refresh()
        end
        if not silent and self.lastSafetyNotice ~= reason then
            self.lastSafetyNotice = reason
            self:Print("WoWX bindings paused for native " .. reason .. " actions.")
        end
        return
    end

    self.lastSafetyNotice = nil
    local wasSuspended = self.actionStateSuspended
    self.actionStateSuspended = nil
    self.actionStateReason = nil

    if wasSuspended then
        if InCombatLockdown() then
            self.pendingSafetyResume = true
        else
            self:ApplyBindings(true)
        end
        if self.VisualBar then
            self.VisualBar:UpdateAll()
        end
        if self.SettingsUI and self.SettingsUI.frame and self.SettingsUI.frame:IsShown() then
            self.SettingsUI:Refresh()
        end
        if not silent then
            self:Print("WoWX bindings restored.")
        end
    end
end

function GPX:GetOverrideOwner()
    if not self.overrideOwner then
        self.overrideOwner = CreateFrame("Frame", "WoWXOverrideOwner", UIParent)
        self.overrideOwner:Show()
    end
    return self.overrideOwner
end

function GPX:GetBindingEngineConfig()
    self.db.ui = self.db.ui or {}
    self.db.ui.bindingEngine = self.db.ui.bindingEngine or {}

    local cfg = self.db.ui.bindingEngine
    if self.db._bindingEngineDefaultsV2 == nil then
        cfg.transport = "click"
        self.db._bindingEngineDefaultsV2 = true
    end
    if cfg.transport ~= "direct" and cfg.transport ~= "click" and cfg.transport ~= "override" then
        cfg.transport = "click"
    end
    if cfg.claimModifiers == nil then
        cfg.claimModifiers = true
    end
    if cfg.claimCombo == nil then
        cfg.claimCombo = true
    end
    if cfg.useSetupKeys == nil then
        cfg.useSetupKeys = true
    end
    if cfg.bindMenu == nil then
        cfg.bindMenu = true
    end
    if cfg.overrideFallback == nil then
        cfg.overrideFallback = true
    end
    if cfg.stickyPage == nil then
        cfg.stickyPage = ""
    end
    if cfg.stickyPage ~= "" and cfg.stickyPage ~= "SHIFT" and cfg.stickyPage ~= "ALT" and cfg.stickyPage ~= "CTRL" and cfg.stickyPage ~= "SHIFT-ALT" then
        cfg.stickyPage = ""
    end
    return cfg
end

function GPX:GetBindingSyncConfig()
    self.db.bindingSync = self.db.bindingSync or {}
    if self.db.bindingSync.enabled == nil then
        self.db.bindingSync.enabled = false
    end
    self.db.bindingSync.scope = self.db.bindingSync.scope or "character"
    return self.db.bindingSync
end

function GPX:GetBindingScopeId()
    local cfg = self:GetBindingSyncConfig()
    local scope = string.lower(tostring(cfg.scope or "character"))
    if scope == "account" then
        return ACCOUNT_BINDINGS or 1
    end
    return CHARACTER_BINDINGS or 2
end

function GPX:PersistBindings(reason)
    if not self.db then
        return
    end

    local cfg = self:GetBindingSyncConfig()
    if not cfg.enabled then
        return
    end

    if InCombatLockdown() then
        self.pendingBindingSave = true
        self:Print("Binding save queued until combat ends.")
        return
    end

    local scopeId = self:GetBindingScopeId()
    local ok, result = pcall(SaveBindings, scopeId)
    if ok and result then
        local scopeText = (scopeId == (ACCOUNT_BINDINGS or 1)) and "account" or "character"
        self:Print("Bindings saved to " .. scopeText .. (reason and (" (" .. reason .. ")") or "") .. ".")
    else
        self:Print("|cffff4444Binding save failed.|r")
    end
end

function GPX:ApplyBaseActionBindings()
    local applied = 0

    for _, page in ipairs(baseActionPages) do
        for index, key in ipairs(baseActionKeys) do
            local bindKey = page.prefix .. key
            if self.previousBindings[bindKey] == nil then
                self.previousBindings[bindKey] = GetBindingAction(bindKey) or ""
            end

            local command = page.page .. index
            if SetBinding(bindKey, command) then
                self.appliedBindings[bindKey] = command
                applied = applied + 1
            else
                self:Print("|cffff4444Bind failed:|r " .. bindKey .. " -> " .. command)
            end
        end
    end

    self:Print("Applied " .. applied .. " base keyboard action bindings.")
    self:PersistBindings("apply")
end

function GPX:ApplyBindings(silent)
    if not self.db or not self.db.enabled then return end

    -- Prevent redundant binding applications (e.g., during controller setup)
    if self.isApplyingBindings then
        return
    end

    local engine = self:GetBindingEngineConfig()
    local controllerEnabled = self:IsControllerEnabled()
    local useSetupKeys = engine.useSetupKeys and controllerEnabled

    -- Skip clear if no bindings were previously applied
    if next(self.appliedBindings) then
        self:ClearBindings(true)  -- Use silent mode to avoid spam during setup
    end

    local profile = self:GetProfile()
    local needsCalibration = useSetupKeys
    if needsCalibration and not self:HasCalibratedSetup(profile) then
        if next(self.appliedBindings) then
            self:ClearBindings()
        end
        self:Print("WoWX is enabled, but no calibration is active yet. Run /wowx init to capture your layout.")
        if self.VisualBar then
            self.VisualBar:UpdateAll()
        end
        if self.SettingsUI then
            self.SettingsUI:Refresh()
        end
        return
    end

    if InCombatLockdown() then
        if not silent then
            self:Print("Cannot apply WoWX key overrides in combat.")
        end
        return
    end

    local specialActive, reason = self:IsSpecialActionStateActive()
    if specialActive and self:ShouldSuspendForSpecialActionState(reason) then
        self.actionStateSuspended = true
        self.actionStateReason = reason
        if not silent then
            self:Print("WoWX bindings paused for native " .. reason .. " actions.")
        end
        if self.VisualBar then
            self.VisualBar:UpdateAll()
        end
        return
    end

    self.isApplyingBindings = true

    if self.VisualBar and self.VisualBar.CreateFrame then
        self.VisualBar:CreateFrame()
    end

    local owner = self:GetOverrideOwner()
    ClearOverrideBindings(owner)
    self.appliedBindings = {}

    local setup = profile and profile.setup or nil
    local ok, fail = 0, 0
    local useModifierPages = self.db and self.db.ui and self.db.ui.visualBar and self.db.ui.visualBar.modifierPages == true
    local numberRowKeys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" }
    local stickyPage = (not useSetupKeys) and (engine.stickyPage or "") or ""

    local function rememberPrevious(key)
        if self.previousBindings[key] == nil then
            self.previousBindings[key] = GetBindingAction(key) or ""
        end
    end

    local function getDirectClickTarget(command)
        local index = tonumber(command and command:match("(%d+)$"))
        if not index then
            return nil
        end

        if command:find("^ACTIONBUTTON") then
            return "ActionButton" .. index
        end
        if command:find("^MULTIACTIONBAR1BUTTON") then
            return "MultiBarBottomLeftButton" .. index
        end
        if command:find("^MULTIACTIONBAR2BUTTON") then
            return "MultiBarBottomRightButton" .. index
        end
        if command:find("^MULTIACTIONBAR3BUTTON") then
            return "MultiBarRightButton" .. index
        end
        if command:find("^MULTIACTIONBAR4BUTTON") then
            return "MultiBarLeftButton" .. index
        end

        if command:find("^MULTICASTBUTTON") then
            return "MultiCastButton" .. index
        end

        return nil
    end

    local function applyDirectBinding(key, command)
        rememberPrevious(key)

        if SetBinding(key, command) then
            self.appliedBindings[key] = { mode = "binding", command = command }
            ok = ok + 1
            return true
        end
        self:Print("|cffff4444Bind failed:|r " .. key .. " → " .. command)
        fail = fail + 1
        return false
    end

    local function suppressBlizzardPageSwitchBinds()
        for _, command in ipairs(blizzardPageCommands) do
            local keys = { GetBindingKey(command) }
            for _, key in ipairs(keys) do
                if key and key ~= "" then
                    rememberPrevious(key)
                    if SetBinding(key, nil) then
                        self.appliedBindings[key] = { mode = "binding", command = "(cleared " .. command .. ")" }
                    end
                end
            end
        end
    end

    local function suppressBlizzardCombatUiBinds()
        for _, command in ipairs(blizzardCombatUiCommands) do
            local keys = { GetBindingKey(command) }
            for _, key in ipairs(keys) do
                if key and key ~= "" then
                    rememberPrevious(key)
                    if SetBinding(key, nil) then
                        self.appliedBindings[key] = { mode = "binding", command = "(cleared " .. command .. ")" }
                    end
                end
            end
        end
    end

    local function applySingleBinding(key, command, slotIndex)
        if not key or key == "" then
            return false
        end

        if self.appliedBindings[key] then
            return true
        end

        if engine.transport == "direct" then
            return applyDirectBinding(key, command)
        end

        local buttonName = nil
        local isBaseCommand = type(command) == "string" and command:find("^ACTIONBUTTON%d+$")
        if not isBaseCommand and self.VisualBar and self.VisualBar.GetBindingProxyButtonName then
            buttonName = self.VisualBar:GetBindingProxyButtonName(command)
        end
        if not buttonName or buttonName == "" then
            buttonName = "WoWXActionButton" .. tostring(slotIndex or "")
        end
        if not _G[buttonName] then
            self:Print("|cffff4444Missing button:|r " .. buttonName)
            fail = fail + 1
            return false
        end

        if engine.transport == "override" then
            if SetOverrideBindingClick(owner, true, key, buttonName, "LeftButton") then
                self.appliedBindings[key] = { mode = "override", command = "CLICK " .. buttonName }
                ok = ok + 1
                return true
            end
            if not engine.overrideFallback then
                self:Print("|cffff4444Override bind failed:|r " .. key .. " → " .. buttonName)
                fail = fail + 1
                return false
            end
        end

        rememberPrevious(key)
        if SetBindingClick(key, buttonName, "LeftButton") then
            self.appliedBindings[key] = { mode = "binding", command = "CLICK " .. buttonName }
            ok = ok + 1
            return true
        end
        self:Print("|cffff4444Bind failed:|r " .. key .. " → " .. buttonName)
        fail = fail + 1
        return false
    end

    local function bindToButton(key, slotIndex)
        if not key or key == "" then
            return
        end

        local baseCommand = "ACTIONBUTTON" .. slotIndex
        local modifiers = { "SHIFT", "ALT", "CTRL" }
        local bindings = {
            { key = key, command = baseCommand, slotIndex = slotIndex },
        }

        if engine.claimModifiers and modifiers[1] and modifiers[1] ~= "" then
            bindings[#bindings + 1] = {
                key = self:BuildModifiedKey({ modifiers[1] }, key),
                command = useModifierPages and ("MULTIACTIONBAR2BUTTON" .. slotIndex) or baseCommand,
                slotIndex = slotIndex,
            }
        end
        if engine.claimModifiers and modifiers[2] and modifiers[2] ~= "" then
            bindings[#bindings + 1] = {
                key = self:BuildModifiedKey({ modifiers[2] }, key),
                command = useModifierPages and ("MULTIACTIONBAR1BUTTON" .. slotIndex) or baseCommand,
                slotIndex = slotIndex,
            }
        end
        if engine.claimModifiers and modifiers[3] and modifiers[3] ~= "" then
            bindings[#bindings + 1] = {
                key = self:BuildModifiedKey({ modifiers[3] }, key),
                command = useModifierPages and ("MULTIACTIONBAR4BUTTON" .. slotIndex) or baseCommand,
                slotIndex = slotIndex,
            }
        end
        if engine.claimModifiers and engine.claimCombo and modifiers[1] and modifiers[1] ~= "" and modifiers[2] and modifiers[2] ~= "" then
            bindings[#bindings + 1] = {
                key = self:BuildModifiedKey({ modifiers[1], modifiers[2] }, key),
                command = useModifierPages and ("MULTIACTIONBAR3BUTTON" .. slotIndex) or baseCommand,
                slotIndex = slotIndex,
            }
            bindings[#bindings + 1] = {
                key = self:BuildModifiedKey({ modifiers[2], modifiers[1] }, key),
                command = useModifierPages and ("MULTIACTIONBAR3BUTTON" .. slotIndex) or baseCommand,
                slotIndex = slotIndex,
            }
        end

        local seen = {}
        for _, entry in ipairs(bindings) do
            if entry.key and entry.key ~= "" and not seen[entry.key] then
                seen[entry.key] = true
                applySingleBinding(entry.key, entry.command, entry.slotIndex)
            end
        end
    end

    local function commandForStickyPage(slotIndex, page)
        if page == "SHIFT" then
            return "MULTIACTIONBAR2BUTTON" .. slotIndex
        elseif page == "ALT" then
            return "MULTIACTIONBAR1BUTTON" .. slotIndex
        elseif page == "CTRL" then
            return "MULTIACTIONBAR4BUTTON" .. slotIndex
        elseif page == "SHIFT-ALT" then
            return "MULTIACTIONBAR3BUTTON" .. slotIndex
        end
        return "ACTIONBUTTON" .. slotIndex
    end

    if useSetupKeys then
        local firstActionSlot = self:GetActionKeyBaseSlot(setup)
        local lastActionSlot = self:GetConfiguredActionButtonCount(setup)

        if firstActionSlot > 1 then
            bindToButton(setup and setup.jumpKey, 1)
        end

        for slotIndex = firstActionSlot, lastActionSlot do
            bindToButton(self:GetSetupActionKey(setup, slotIndex), slotIndex)
        end
    else
        if stickyPage ~= "" then
            for index = 1, 12 do
                applySingleBinding(numberRowKeys[index], commandForStickyPage(index, stickyPage), index)
            end
        else
            for index = 1, 12 do
                bindToButton(numberRowKeys[index], index)
            end
        end
    end

    suppressBlizzardPageSwitchBinds()
    suppressBlizzardCombatUiBinds()

    if engine.bindMenu and self:IsControllerEnabled() and setup and setup.menuKey and setup.menuKey ~= "" then
        if engine.transport == "override" then
            if SetOverrideBinding(owner, true, setup.menuKey, "TOGGLEGAMEMENU") then
                self.appliedBindings[setup.menuKey] = { mode = "override", command = "TOGGLEGAMEMENU" }
                ok = ok + 1
            elseif engine.overrideFallback then
                applyDirectBinding(setup.menuKey, "TOGGLEGAMEMENU")
            else
                self:Print("|cffff4444Override bind failed:|r " .. setup.menuKey .. " → TOGGLEGAMEMENU")
                fail = fail + 1
            end
        else
            applyDirectBinding(setup.menuKey, "TOGGLEGAMEMENU")
        end
    end

    if self:IsControllerEnabled() and setup and setup.lookKey and setup.lookKey ~= "" then
        if engine.transport == "override" then
            if SetOverrideBinding(owner, true, setup.lookKey, "CAMERAORSELECTORMOVE") then
                self.appliedBindings[setup.lookKey] = { mode = "override", command = "CAMERAORSELECTORMOVE" }
                ok = ok + 1
            elseif engine.overrideFallback then
                applyDirectBinding(setup.lookKey, "CAMERAORSELECTORMOVE")
            else
                self:Print("|cffff4444Override bind failed:|r " .. setup.lookKey .. " → CAMERAORSELECTORMOVE")
                fail = fail + 1
            end
        else
            applyDirectBinding(setup.lookKey, "CAMERAORSELECTORMOVE")
        end
    end

    -- SpellRing bindings (click-type, set after normal bindings)
    if GPX.SpellRing then
        GPX.SpellRing:ApplyBindings()
    end

    local msg = string.format("|cff00ff00" .. self.brand .. " ON|r — [%s] — %d bindings (engine=%s)", profile.name or "default", ok, engine.transport)
    if fail > 0 then
        msg = msg .. string.format("  |cffff4444(%d failed)|r", fail)
    end
    if not silent then
        self:Print(msg)
    end

    self.isApplyingBindings = false
end

function GPX:ClearBindings(silent)
    if not InCombatLockdown() then
        if self.overrideOwner then
            ClearOverrideBindings(self.overrideOwner)
        end
    end

    if self.SpellRing then
        self.SpellRing:ClearBindings()
    end

    for key, info in pairs(self.appliedBindings) do
        if type(info) == "table" and info.mode == "binding" then
            local previous = self.previousBindings[key]
            if previous ~= nil then
                if previous == "" then
                    SetBinding(key, nil)
                else
                    SetBinding(key, previous)
                end
            end
        end
        self.previousBindings[key] = nil
    end

    self.appliedBindings = {}
    if not silent then
        self:Print("|cffffaa00" .. self.brand .. " override bindings cleared for this session.|r")
    end
    if self.VisualBar then
        self.VisualBar:UpdateAll()
    end
end

-- ============================================================
-- SLASH COMMANDS  (/wowx primary; legacy aliases supported)
-- ============================================================
function GPX:RegisterSlash()
    SLASH_GAMEPADX1 = "/gamepadx"
    SLASH_GAMEPADX2 = "/gpx"
    SLASH_GAMEPADX3 = "/wowx"
    SlashCmdList["GAMEPADX"] = function(msg)
        local ok, err = pcall(function()
            GPX:Slash(msg)
        end)
        if not ok then
            GPX:Print("Slash command failed: " .. tostring(err))
        end

        if ChatFrameEditBox and ChatFrameEditBox:IsShown() and ChatEdit_DeactivateChat then
            ChatEdit_DeactivateChat(ChatFrameEditBox)
        end
    end
end

function GPX:Slash(msg)
    local cmd, rest = msg:match("^(%S+)%s*(.*)")
    cmd = (cmd or ""):lower()

    if cmd == "enable" then
        self.db.enabled = true
        self:ApplyBindings()

    elseif cmd == "disable" then
        self.db.enabled = false
        self:ClearBindings()

    elseif cmd == "toggle" then
        if self.db.enabled then
            self.db.enabled = false
            self:ClearBindings()
        else
            self.db.enabled = true
            self:ApplyBindings()
        end

    elseif cmd == "reload" then
        self:ClearBindings()
        self:ApplyBindings()

    elseif cmd == "status" then
        self:PrintStatus()

    elseif cmd == "init" or cmd == "recal" or cmd == "setup" then
        self:OpenSetupWizard(cmd)

    elseif cmd == "config" or cmd == "options" then
        self:OpenSettings()

    elseif cmd == "menu" then
        self:OpenMenuNav("settings")

    elseif cmd == "edit" or cmd == "layout" then
        if GPX.VisualBar then
            GPX.VisualBar:Slash((GPX.VisualBar:IsLocked() and "unlock") or "lock")
        else
            self:Print("Visual bar module not loaded.")
        end

    elseif cmd == "unlock" then
        if GPX.VisualBar then
            GPX.VisualBar:Slash("unlock")
        else
            self:Print("Visual bar module not loaded.")
        end

    elseif cmd == "lock" then
        if GPX.VisualBar then
            GPX.VisualBar:Slash("lock")
        else
            self:Print("Visual bar module not loaded.")
        end

    elseif cmd == "place" then
        if GPX.VisualBar then
            GPX.VisualBar:Slash("place")
        else
            self:Print("Visual bar module not loaded.")
        end

    elseif cmd == "manual" then
        self:PrintManualPlacementGuide()

    elseif cmd == "controller" then
        local arg = string.lower((rest or ""):match("^%s*(.-)%s*$"))
        if arg == "on" or arg == "enable" or arg == "1" then
            self:SetControllerEnabled(true)
        elseif arg == "off" or arg == "disable" or arg == "0" then
            self:SetControllerEnabled(false)
        else
            self:SetControllerEnabled(not self:IsControllerEnabled())
        end
        self:Print("Controller mode: " .. (self:IsControllerEnabled() and "Enabled" or "Disabled"))
        if self.db and self.db.enabled then
            self:ClearBindings()
            self:ApplyBindings()
        end
        if self.VisualBar then
            self.VisualBar:UpdateAll()
        end
        if self.SettingsUI and self.SettingsUI.frame and self.SettingsUI.frame:IsShown() then
            self.SettingsUI:Refresh()
        end

    elseif cmd == "util" then
        self:Print("/wowx util is deprecated. Main bar clicks are now action-only for reliability.")
        self:Print("Use /wowx controller on and /wowx config for controller verification.")

    elseif cmd == "engine" then
        local arg = string.lower((rest or ""):match("^%s*(.-)%s*$"))
        local cfg = self:GetBindingEngineConfig()

        if arg == "" or arg == "status" then
            self:Print("Engine: transport=" .. cfg.transport
                .. " claimModifiers=" .. tostring(cfg.claimModifiers)
                .. " claimCombo=" .. tostring(cfg.claimCombo)
                .. " useSetupKeys=" .. tostring(cfg.useSetupKeys)
                .. " bindMenu=" .. tostring(cfg.bindMenu)
                .. " overrideFallback=" .. tostring(cfg.overrideFallback))
        elseif arg == "direct" or arg == "click" or arg == "override" then
            cfg.transport = arg
            self:Print("Engine transport set to " .. arg)
            if self.db.enabled then
                self:ClearBindings()
                self:ApplyBindings()
            end
        elseif arg == "mods on" then
            cfg.claimModifiers = true
            self:Print("Engine modifiers claim: ON")
        elseif arg == "mods off" then
            cfg.claimModifiers = false
            self:Print("Engine modifiers claim: OFF")
        elseif arg == "combo on" then
            cfg.claimCombo = true
            self:Print("Engine combo claim: ON")
        elseif arg == "combo off" then
            cfg.claimCombo = false
            self:Print("Engine combo claim: OFF")
        elseif arg == "setupkeys on" then
            cfg.useSetupKeys = true
            self:Print("Engine key source: setup keys")
        elseif arg == "setupkeys off" then
            cfg.useSetupKeys = false
            self:Print("Engine key source: number row")
        elseif arg == "menu on" then
            cfg.bindMenu = true
            self:Print("Engine menu bind: ON")
        elseif arg == "menu off" then
            cfg.bindMenu = false
            self:Print("Engine menu bind: OFF")
        elseif arg == "fallback on" then
            cfg.overrideFallback = true
            self:Print("Engine override fallback: ON")
        elseif arg == "fallback off" then
            cfg.overrideFallback = false
            self:Print("Engine override fallback: OFF")
        else
            self:Print("Usage: /wowx engine [status|direct|click|override|mods on|mods off|combo on|combo off|setupkeys on|setupkeys off|menu on|menu off|fallback on|fallback off]")
        end

    elseif cmd == "page" then
        local arg = string.upper((rest or ""):match("^%s*(.-)%s*$"))
        local cfg = self:GetBindingEngineConfig()
        if arg == "" or arg == "STATUS" then
            self:Print("Keyboard page mode: " .. (cfg.stickyPage ~= "" and cfg.stickyPage or "HOLD"))
            return
        end
        if arg == "HOLD" or arg == "BASE" then
            cfg.stickyPage = ""
            self:Print("Keyboard page mode: HOLD modifiers (base mapping)")
        elseif arg == "SHIFT" or arg == "ALT" or arg == "CTRL" or arg == "SHIFT-ALT" or arg == "COMBO" then
            cfg.stickyPage = (arg == "COMBO") and "SHIFT-ALT" or arg
            self:Print("Keyboard page mode: " .. cfg.stickyPage .. " locked on number row")
        else
            self:Print("Usage: /wowx page [hold|base|shift|alt|ctrl|combo|status]")
            return
        end
        if self.db and self.db.enabled then
            self:ClearBindings()
            self:ApplyBindings()
        end

    elseif cmd == "selfcast" then
        local arg = string.lower((rest or ""):match("^%s*(.-)%s*$"))
        local current = GetCVar("autoSelfCast") == "1"
        local desired = current

        if arg == "on" or arg == "1" then
            desired = true
        elseif arg == "off" or arg == "0" then
            desired = false
        else
            desired = not current
        end

        SetCVar("autoSelfCast", desired and "1" or "0")
        self:Print("Auto Self Cast: " .. (desired and "ON" or "OFF"))

    elseif cmd == "bindsync" then
        local arg = string.lower((rest or ""):match("^%s*(.-)%s*$"))
        local cfg = self:GetBindingSyncConfig()

        if arg == "" or arg == "status" then
            self:Print("Binding sync: " .. (cfg.enabled and "ON" or "OFF") .. " (scope: " .. cfg.scope .. ")")
        elseif arg == "on" or arg == "enable" or arg == "1" then
            cfg.enabled = true
            self:Print("Binding sync enabled (scope: " .. cfg.scope .. ").")
            self:PersistBindings("manual")
        elseif arg == "off" or arg == "disable" or arg == "0" then
            cfg.enabled = false
            self:Print("Binding sync disabled.")
        elseif arg == "account" then
            cfg.scope = "account"
            self:Print("Binding sync scope set to account.")
            self:PersistBindings("scope")
        elseif arg == "character" or arg == "char" then
            cfg.scope = "character"
            self:Print("Binding sync scope set to character.")
            self:PersistBindings("scope")
        elseif arg == "now" or arg == "save" then
            self:PersistBindings("manual")
        else
            self:Print("Usage: /wowx bindsync [on|off|account|character|now|status]")
        end

    elseif cmd == "diag" then
        local arg = string.lower((rest or ""):match("^%s*(.-)%s*$"))
        if arg == "" or arg == "now" then
            self:PrintDiagnostics()
        elseif arg == "window" or arg == "win" or arg == "ui" then
            self:ShowDiagWindow()
        elseif arg == "stance" or arg == "aura" or arg == "forms" then
            local lines = self:CollectStanceDiagnosticsLines()
            for _, line in ipairs(lines) do
                self:Print(line)
            end
        elseif arg == "verbose" or arg == "save" or arg == "run" then
            self:RunDiagnosticSpeedRun("verbose")
            self:PrintLastDiagnosticRun()
        else
            self:Print("Usage: /wowx diag [stance|verbose|window]")
        end

    elseif cmd == "diagshow" then
        self:PrintLastDiagnosticRun()

    elseif cmd == "diagwin" or cmd == "diagwindow" then
        self:ToggleDiagWindow()

    elseif cmd == "diagauto" then
        local arg = string.lower((rest or ""):match("^%s*(.-)%s*$"))
        local cfg = self:GetDiagnosticsConfig()
        if arg == "" or arg == "status" then
            self:Print("Auto diagnostics on login/state changes: " .. (cfg.autoCapture and "ON" or "OFF"))
        elseif arg == "on" or arg == "enable" or arg == "1" then
            cfg.autoCapture = true
            self:Print("Auto diagnostics on login/state changes: ON")
        elseif arg == "off" or arg == "disable" or arg == "0" then
            cfg.autoCapture = false
            self:Print("Auto diagnostics on login/state changes: OFF")
        else
            self:Print("Usage: /wowx diagauto [on|off|status]")
        end

    elseif cmd == "bar" then
        if GPX.VisualBar then
            GPX.VisualBar:Slash(rest)
        else
            self:Print("Visual bar module not loaded.")
        end

    elseif cmd == "note" then
        -- /wowx note Gaming PC
        self.db.machineNote = rest
        self:Print("Machine label: " .. rest)

    elseif cmd == "profile" then
        -- /wowx profile default
        local p = rest:match("^(%S+)")
        if p and self.db.profiles[p] then
            self.db.profile = p
            if self.db.enabled then
                self:ClearBindings()
                self:ApplyBindings()
            end
            self:Print("Profile: " .. p)
        else
            self:Print("Profile not found: " .. (p or "(none)"))
            self:ListProfiles()
        end

    elseif cmd == "profiles" then
        self:ListProfiles()

    elseif cmd == "bind" then
        -- /wowx bind F1 ACTIONBUTTON1
        local key, command = rest:match("^(%S+)%s+(%S+)")
        if key and command then
            self:AddBinding(key:upper(), command:upper())
        else
            self:Print("Usage: /wowx bind <KEY> <COMMAND>")
            self:Print("  e.g.  /wowx bind F1 ACTIONBUTTON1")
            self:Print("  e.g.  /wowx bind SHIFT-F1 MULTIACTIONBAR2BUTTON1")
        end

    elseif cmd == "unbind" then
        -- /wowx unbind F1
        local key = rest:match("^(%S+)")
        if key then
            self:RemoveBinding(key:upper())
        else
            self:Print("Usage: /wowx unbind <KEY>")
        end

    elseif cmd == "bindings" or cmd == "list" then
        self:ListBindings()

    elseif cmd == "ring" then
        if GPX.SpellRing then
            GPX.SpellRing:Slash(rest)
        else
            self:Print("SpellRing module not loaded.")
        end

    elseif cmd == "help" or cmd == "" then
        self:PrintHelp()

    else
        self:Print("Unknown command: " .. cmd)
        self:PrintHelp()
    end
end

function GPX:PrintHelp()
    local c = "|cff88ccff"
    local r = "|r"
    self:Print("|cffffcc00" .. self.brand .. " v" .. self.version .. " — Commands:|r")
    self:Print("  "..c.."/wowx enable"..r.."             Activate WoWX mode on this machine")
    self:Print("  "..c.."/wowx disable"..r.."            Deactivate (keyboard machine safe)")
    self:Print("  "..c.."/wowx toggle"..r.."             Toggle on/off")
    self:Print("  "..c.."/wowx reload"..r.."             Re-apply bindings now")
    self:Print("  "..c.."/wowx status"..r.."             Show status, profile, binding count")
    self:Print("  "..c.."/wowx init"..r.."               Open the visual setup wizard")
    self:Print("  "..c.."/wowx recal"..r.."              Re-run controller or keyboard calibration")
    self:Print("  "..c.."/wowx config"..r.."             Open the WoWX control center")
    self:Print("  "..c.."/wowx menu"..r.."               Open WoWX menu navigation")
    self:Print("  "..c.."/wowx edit"..r.."               Toggle layout edit mode (unlock/lock)")
    self:Print("  "..c.."/wowx unlock"..r.."             Enable layout edit mode")
    self:Print("  "..c.."/wowx lock"..r.."               Disable layout edit mode")
    self:Print("  "..c.."/wowx place"..r.."              Toggle all-pages placement panel")
    self:Print("  "..c.."/wowx manual"..r.."             Show categorical placement workflow")
    self:Print("  "..c.."/wowx controller [on|off]"..r.." Toggle controller verification mode")
    self:Print("  "..c.."/wowx engine ..."..r.."         Binding engine mode/options")
    self:Print("  "..c.."/wowx page ..."..r.."           Keyboard bar switch mode (hold/shift/alt/ctrl/combo)")
    self:Print("  "..c.."/wowx selfcast [on|off]"..r.."  Toggle or set auto self-cast")
    self:Print("  "..c.."/wowx bindsync ..."..r.."       Save WoWX binding changes (on/off/account/character/now)")
    self:Print("  "..c.."/wowx diag"..r.."               Quick on-the-spot diagnostics in chat")
    self:Print("  "..c.."/wowx diag stance"..r.."        Print aura/stance frame and button diagnostics")
    self:Print("  "..c.."/wowx diag verbose"..r.."       Save a new timestamped diag + print it now")
    self:Print("  "..c.."/wowx diag window"..r.."        Open scrollable in-game diagnostics window")
    self:Print("  "..c.."/wowx diagshow"..r.."           Print the most recent saved diagnostic run")
    self:Print("  "..c.."/wowx diagwin"..r.."            Toggle diagnostics window")
    self:Print("  "..c.."/wowx diagauto [on|off]"..r.."   Toggle auto diagnostics on login/state changes")
    self:Print("  "..c.."/wowx bar toggle"..r.."         Show or hide the visual WoWX bar")
    self:Print("  "..c.."/wowx bar bagbar"..r.."         Toggle compact WoWX bag bar")
    self:Print("  "..c.."/wowx bar progress"..r.."       Toggle XP/Rep tracker strip")
    self:Print("  "..c.."/wowx bar progresslock"..r.."   Lock/unlock XP/Rep bar placement")
    self:Print("  "..c.."/wowx bar keepmenu"..r.."       Keep/hide Blizzard micro menu")
    self:Print("  "..c.."/wowx bar keepbags"..r.."       Keep/hide Blizzard bag buttons")
    self:Print("  "..c.."/wowx bar keepstance"..r.."     Keep/hide Blizzard stance bars")
    self:Print("  "..c.."/wowx bar keeppet"..r.."        Keep/hide Blizzard pet bar")
    self:Print("  "..c.."/wowx bar microbigger|microsmaller"..r.." Resize detached micro menu")
    self:Print("  "..c.."/wowx bar stancebigger|stancesmaller"..r.." Resize detached stance bar")
    self:Print("  "..c.."/wowx bar petbigger|petsmaller"..r.." Resize detached pet bar")
    self:Print("  "..c.."/wowx bar modpages"..r.."       Toggle modifier pages vs same-slot modifiers")
    self:Print("  "..c.."/wowx bar smaller|bigger"..r.." Resize visual bar")
    self:Print("  "..c.."/wowx note <text>"..r.."        Label this machine (stored locally)")
    self:Print("  "..c.."/wowx profile <name>"..r.."     Switch binding profile")
    self:Print("  "..c.."/wowx profiles"..r.."           List available profiles")
    self:Print("  "..c.."/wowx bind <KEY> <CMD>"..r.."   Add or change one binding")
    self:Print("  "..c.."/wowx unbind <KEY>"..r.."       Remove one binding")
    self:Print("  "..c.."/wowx bindings"..r.."           List all bindings in current profile")
    self:Print("  "..c.."/wowx ring help"..r.."          SpellRing commands")
    self:Print("  "..c.."Build"..r..": setup-capture-v3 / secure-action-v1")
    self:Print("|cff888888NOTE: binding behavior depends on /wowx engine mode (direct/click/override).|r")
    self:Print("|cff888888POLICY: accessibility surface only. No aim assist, no gameplay automation.|r")
    self:Print("|cff888888On keyboard machines just leave the addon disabled.|r")
end

function GPX:PrintManualPlacementGuide()
    self:Print("Manual placement modes:")
    self:Print("  1) Drag mode: hold modifier and place directly on the bar to write that page slot.")
    self:Print("  2) Place mode: /wowx place, then drop on Base/Shift/Alt/Ctrl/Combo slot.")
    self:Print("  3) Categories:")
    self:Print("     Spells: open spellbook and drag to slot.")
    self:Print("     Items: open bags/equipment and drag to slot.")
    self:Print("     Macros: open /macro and drag to slot.")
    self:Print("     Utility commands: /wowx bind <KEY> <COMMAND>.")
end

function GPX:PrintStatus()
    local profile  = self:GetProfile()
    local bindCount = 0
    if profile and profile.bindings then
        for _ in pairs(profile.bindings) do bindCount = bindCount + 1 end
    end
    local activeCount = 0
    for _ in pairs(self.appliedBindings) do activeCount = activeCount + 1 end

    local state = self.db.enabled and "|cff00ff00ENABLED|r" or "|cffff4444DISABLED|r"
    self:Print("Status: " .. state)
    if self.db.machineNote and self.db.machineNote ~= "" then
        self:Print("  Machine: " .. self.db.machineNote)
    end
    self:Print("  Profile: " .. (self.db.profile or "default") .. "  (" .. bindCount .. " bindings defined)")
    self:Print("  Controller mode: " .. (self:IsControllerEnabled() and "enabled" or "disabled (base-first)"))
    local engineCfg = self:GetBindingEngineConfig()
    self:Print("  Engine: " .. engineCfg.transport .. " (mods=" .. tostring(engineCfg.claimModifiers) .. ", combo=" .. tostring(engineCfg.claimCombo) .. ")")
    local syncCfg = self:GetBindingSyncConfig()
    self:Print("  Binding sync: " .. (syncCfg.enabled and "ON" or "OFF") .. " (" .. syncCfg.scope .. ")")
    self:Print("  Calibrated: " .. (self:HasCalibratedSetup(profile) and "yes" or "no"))
    self:Print("  Active this session: " .. activeCount .. " bindings")
    if GPX.SpellRing then
        local ringProfile = self:GetProfile()
        local ringCount = (ringProfile and ringProfile.spellRings) and #ringProfile.spellRings or 0
        self:Print("  SpellRings: " .. ringCount .. " configured")
    end
end

function GPX:ListProfiles()
    self:Print("Profiles:")
    for name, profile in pairs(self.db.profiles) do
        local cur = (name == self.db.profile) and " |cff00ff00(current)|r" or ""
        self:Print("  " .. name .. " — " .. (profile.name or name) .. cur)
    end
end

function GPX:ListBindings()
    local profile = self:GetProfile()
    if not profile or not profile.bindings then
        self:Print("No bindings in current profile.")
        return
    end
    self:Print("Bindings — profile: " .. (self.db.profile or "default"))
    local keys = {}
    for k in pairs(profile.bindings) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        self:Print("  " .. k .. "  →  " .. profile.bindings[k])
    end
end

function GPX:AddBinding(key, command)
    local profile = self:GetProfile()
    if not profile then return end
    if not profile.bindings then profile.bindings = {} end

    local old = profile.bindings[key]
    profile.bindings[key] = command

    if self.db.enabled and self:IsControllerEnabled() then
        if self.previousBindings[key] == nil then
            self.previousBindings[key] = GetBindingAction(key) or ""
        end
        SetBinding(key, command)
        self.appliedBindings[key] = command
    end

    if old then
        self:Print("Updated: " .. key .. " → " .. command .. "  (was: " .. old .. ")")
    else
        self:Print("Bound: " .. key .. " → " .. command)
    end
    self:PersistBindings("bind")
end

function GPX:RemoveBinding(key)
    local profile = self:GetProfile()
    if not profile or not profile.bindings then return end

    if profile.bindings[key] then
        profile.bindings[key] = nil
        if self.appliedBindings[key] then
            local previous = self.previousBindings[key]
            if previous ~= nil and previous ~= "" then
                SetBinding(key, previous)
            else
                SetBinding(key, nil)
            end
            self.previousBindings[key] = nil
            self.appliedBindings[key] = nil
        end
        self:Print("Removed binding: " .. key)
        self:PersistBindings("unbind")
    else
        self:Print("No binding found for: " .. key)
    end
end

-- ============================================================
-- UTILITY
-- ============================================================
function GPX:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff6699ff" .. self.brand .. ":|r " .. tostring(msg))
end

function GPX:LogError(msg)
    local text = tostring(msg)
    if self.db then
        self.db.lastError = text
    end
    self:Print("|cffff4444" .. text .. "|r")
end

-- ============================================================
-- MAIN FRAME / EVENT HANDLER
-- ============================================================
mainFrame = CreateFrame("Frame", "GamePadXMainFrame")
mainFrame:RegisterEvent("ADDON_LOADED")
mainFrame:RegisterEvent("PLAYER_LOGIN")
mainFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
mainFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
mainFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
mainFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
mainFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
mainFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
mainFrame:RegisterEvent("UPDATE_STEALTH")
mainFrame:RegisterEvent("PLAYER_AURAS_CHANGED")
mainFrame:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
mainFrame:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
mainFrame:RegisterEvent("UPDATE_POSSESS_BAR")
mainFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
mainFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
mainFrame:RegisterEvent("PLAYER_CONTROL_GAINED")
mainFrame:RegisterEvent("PLAYER_CONTROL_LOST")
mainFrame:RegisterEvent("PLAYER_STARTED_MOVING")
mainFrame:RegisterEvent("PLAYER_STOPPED_MOVING")

local function isThisAddon(addonName)
    if not addonName then
        return false
    end
    local name = string.lower(tostring(addonName))
    return name == "gamepadx" or name == "wowx"
end

local function ensureInitialized()
    if GPX.db then
        return
    end
    GPX:InitDB()
    GPX:RegisterSlash()
end

mainFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if isThisAddon(addonName) then
            GPX.addonName = addonName
            ensureInitialized()
        end

    elseif event == "PLAYER_LOGIN" then
        ensureInitialized()
        if GPX.db then
            if GPX.db.enabled then
                GPX:ApplyBindings()
                GPX:RefreshActionStateSafety(true)
            else
                -- Just a friendly reminder — not annoying if you know what you did
                local note = GPX.db.machineNote
                local label = (note and note ~= "") and (" [" .. note .. "]") or ""
                GPX:Print(GPX.brand .. " mode is OFF" .. label ..
                    ".  Type |cff88ccff/wowx enable|r to activate on this machine.")
            end
            if GPX.VisualBar then
                GPX.VisualBar:UpdateAll()
            end
            if GPX.SettingsUI then
                GPX.SettingsUI:Refresh()
            end
            if GPX.MinimapButton then
                GPX.MinimapButton:Refresh()
            end
            GPX:RunAutomaticDiagnosticCapture("player_login")
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        ensureInitialized()
        GPX:SetControllerMovementState(false)
        GPX:RefreshActionStateSafety(true)
        GPX:RunAutomaticDiagnosticCapture("entering_world")
    elseif event == "PLAYER_REGEN_ENABLED" then
        if GPX.pendingBindingSave then
            GPX.pendingBindingSave = nil
            GPX:PersistBindings("post-combat")
        end
        if GPX.pendingSafetyResume then
            GPX.pendingSafetyResume = nil
            GPX:ApplyBindings(true)
        end
        GPX:RefreshActionStateSafety(true)
    elseif event == "PLAYER_STARTED_MOVING" then
        GPX:SetControllerMovementState(true)
    elseif event == "PLAYER_STOPPED_MOVING" then
        GPX:SetControllerMovementState(false)
    elseif event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
        local unit = ...
        if unit == "player" then
            GPX:SetControllerMovementState(false)
            GPX:RefreshActionStateSafety()
        end
    elseif event == "ACTIONBAR_PAGE_CHANGED"
        or event == "UPDATE_BONUS_ACTIONBAR"
        or event == "UPDATE_SHAPESHIFT_FORM"
        or event == "UPDATE_SHAPESHIFT_FORMS"
        or event == "UPDATE_STEALTH"
        or event == "PLAYER_AURAS_CHANGED"
        or event == "UPDATE_VEHICLE_ACTIONBAR"
        or event == "UPDATE_OVERRIDE_ACTIONBAR"
        or event == "UPDATE_POSSESS_BAR"
        or event == "PLAYER_CONTROL_GAINED"
        or event == "PLAYER_CONTROL_LOST" then
        if event == "PLAYER_CONTROL_LOST" then
            GPX:SetControllerMovementState(false)
        end
        GPX:RefreshActionStateSafety(true)
        GPX:RunAutomaticDiagnosticCapture(string.lower(event))
    end
end)
