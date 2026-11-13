-- Compat.lua
-- Fills in legacy global APIs that modern-engine clients (WoW Forever) may have
-- removed in favour of C_* namespaces. Each shim is only installed when the
-- legacy global is missing, so clients that still ship them are unaffected.

local function missing(name)
    return _G[name] == nil
end

if missing("GetMouseFocus") and type(_G.GetMouseFoci) == "function" then
    _G.GetMouseFocus = function()
        local foci = _G.GetMouseFoci()
        return foci and foci[1] or nil
    end
end

-- ============================================================
-- Capture of transient failures (protected-action popups, uncaught Lua errors)
-- so nobody has to transcribe a dialog. Everything is bounded and deduplicated.
--   WoWXBlockedActions : ADDON_ACTION_BLOCKED/FORBIDDEN + MACRO_ACTION_* (all addons)
--   WoWXRuntimeErrors  : also receives uncaught Lua errors that mention WoWX
-- Persisted in WoWXDB.captures (current session); the previous session's copy is kept in
-- WoWXDB.previousCaptures. Listed by /wowx diag dump.
-- ============================================================
local MAX_CAPTURES = 40
local memCaptures = { blocked = {}, errors = {} }
local capturesRotated = false

local function captureStore()
    local db = _G.WoWXDB
    if type(db) ~= "table" then return memCaptures end
    if type(db.captures) ~= "table" then
        db.captures = { blocked = {}, errors = {} }
    end
    db.captures.blocked = db.captures.blocked or {}
    db.captures.errors = db.captures.errors or {}
    if memCaptures then
        for _, e in ipairs(memCaptures.blocked) do db.captures.blocked[#db.captures.blocked + 1] = e end
        for _, e in ipairs(memCaptures.errors) do db.captures.errors[#db.captures.errors + 1] = e end
        memCaptures = nil
    end
    return db.captures
end

local function pushCapture(list, entry, keyField)
    for _, existing in ipairs(list) do
        if existing[keyField] == entry[keyField] then
            existing.count = (existing.count or 1) + 1
            existing.last = entry.time
            return existing, false
        end
    end
    entry.count = 1
    entry.last = entry.time
    list[#list + 1] = entry
    while #list > MAX_CAPTURES do table.remove(list, 1) end
    return entry, true
end

local function nowStamp()
    return date and date("%H:%M:%S") or "?"
end

local function modifierString()
    local m = {}
    if IsShiftKeyDown and IsShiftKeyDown() then m[#m + 1] = "SHIFT" end
    if IsAltKeyDown and IsAltKeyDown() then m[#m + 1] = "ALT" end
    if IsControlKeyDown and IsControlKeyDown() then m[#m + 1] = "CTRL" end
    return table.concat(m, "+")
end

local blockedFrame = CreateFrame("Frame")
for _, ev in ipairs({ "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "MACRO_ACTION_BLOCKED", "MACRO_ACTION_FORBIDDEN", "PLAYER_LOGIN" }) do
    pcall(blockedFrame.RegisterEvent, blockedFrame, ev)
end
blockedFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
    local ok, err = pcall(function()
        if event == "PLAYER_LOGIN" then
            local db = _G.WoWXDB
            if not capturesRotated and type(db) == "table" then
                capturesRotated = true
                local prev = db.captures
                if type(prev) == "table" and ((prev.blocked and #prev.blocked > 0) or (prev.errors and #prev.errors > 0)) then
                    db.previousCaptures = prev
                    local msg = string.format("|cffff5555[WoWX]|r last session captured %d blocked-action and %d error entries; run /wowx diag dump",
                        #(prev.blocked or {}), #(prev.errors or {}))
                    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(msg) end
                else
                    db.previousCaptures = nil
                end
                db.captures = nil
            end
            captureStore()
            return
        end

        local stack
        if debugstack then
            local okStack, s = pcall(debugstack, 2, 12, 0)
            if okStack and type(s) == "string" then stack = s:sub(1, 900) end
        end
        local addon, func = tostring(arg1), tostring(arg2)
        local entry = {
            time = nowStamp(), event = event, addon = addon, func = func,
            combat = InCombatLockdown and InCombatLockdown() and true or false,
            mods = modifierString(), stack = stack,
        }
        entry.key = event .. "|" .. addon .. "|" .. func
        local store = captureStore()
        local stored, isNew = pushCapture(store.blocked, entry, "key")
        _G.WoWXBlockedActions = store.blocked
        if isNew and addon:lower():find("wowx", 1, true) and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffff5555[WoWX BLOCKED]|r %s: %s tried %s (combat=%s mods=%s)  see /wowx diag dump",
                event, addon, func, tostring(entry.combat), entry.mods ~= "" and entry.mods or "-"))
        end
    end)
    if not ok and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[WoWX]|r capture handler failed: " .. tostring(err))
    end
end)

-- The ADDON_ACTION_* events were NOT seen by the handler above during a user-visible popup
-- on Forever. Two extra capture paths so the next popup is recorded whatever it is:
--  1) hook the popup itself (StaticPopup_Show / C_StaticPopup.Show) and record any popup whose
--     name looks addon/taint related, with the text arguments Blizzard passes (addon, function);
--  2) /wowx diag probe: a temporary all-events listener that records event names matching
--     BLOCK/FORBID/TAINT/PROTECT/ADDON_ACTION/SECRET, to discover what the client really fires.
local function recordPopup(which, a, b)
    pcall(function()
        local name = tostring(which)
        local up = name:upper()
        if not (up:find("ADDON", 1, true) or up:find("BLOCK", 1, true) or up:find("FORBID", 1, true)
            or up:find("TAINT", 1, true) or up:find("PROTECT", 1, true)) then
            return
        end
        local addon, func = tostring(a), tostring(b)
        local stack
        if debugstack then
            local okStack, s = pcall(debugstack, 2, 12, 0)
            if okStack and type(s) == "string" then stack = s:sub(1, 900) end
        end
        local entry = {
            time = nowStamp(), event = "POPUP:" .. name, addon = addon, func = func,
            combat = InCombatLockdown and InCombatLockdown() and true or false,
            mods = modifierString(), stack = stack,
        }
        entry.key = entry.event .. "|" .. addon .. "|" .. func
        local store = captureStore()
        local _, isNew = pushCapture(store.blocked, entry, "key")
        _G.WoWXBlockedActions = store.blocked
        if isNew and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffff5555[WoWX POPUP]|r %s (%s / %s) combat=%s  see /wowx diag dump",
                name, addon, func, tostring(entry.combat)))
        end
    end)
end
if type(_G.StaticPopup_Show) == "function" then
    pcall(hooksecurefunc, "StaticPopup_Show", function(which, text1, text2) recordPopup(which, text1, text2) end)
end
if type(_G.C_StaticPopup) == "table" and type(_G.C_StaticPopup.Show) == "function" then
    pcall(hooksecurefunc, _G.C_StaticPopup, "Show", function(which, text1, text2) recordPopup(which, text1, text2) end)
end

local probeFrame
local probePattern = { "BLOCK", "FORBID", "TAINT", "PROTECT", "ADDON_ACTION", "SECRET" }
function _G.WoWXSetEventProbe(on)
    if not probeFrame then
        probeFrame = CreateFrame("Frame")
        probeFrame:SetScript("OnEvent", function(_, event, a1, a2, a3)
            if event == "PLAYER_LOGIN" then return end
            local hit
            for _, p in ipairs(probePattern) do
                if event:find(p, 1, true) then hit = true break end
            end
            if not hit then return end
            pcall(function()
                local entry = {
                    time = nowStamp(), event = "PROBE:" .. event, addon = tostring(a1), func = tostring(a2),
                    combat = InCombatLockdown and InCombatLockdown() and true or false,
                    mods = modifierString(),
                }
                entry.key = entry.event .. "|" .. entry.addon .. "|" .. entry.func
                local store = captureStore()
                pushCapture(store.blocked, entry, "key")
                _G.WoWXBlockedActions = store.blocked
            end)
        end)
    end
    if on then
        probeFrame:RegisterAllEvents()
    else
        probeFrame:UnregisterAllEvents()
    end
    _G.WoWXEventProbeOn = on and true or false
    return _G.WoWXEventProbeOn
end

-- Chain the global Lua error handler: record anything mentioning WoWX, then defer to the
-- previous handler unchanged (Blizzard's popup / BugSack still run).
if type(_G.seterrorhandler) == "function" and type(_G.geterrorhandler) == "function" then
    local previous = _G.geterrorhandler()
    local inHandler = false
    _G.seterrorhandler(function(msg)
        if not inHandler then
            inHandler = true
            pcall(function()
                local text = tostring(msg)
                if text:lower():find("wowx", 1, true) then
                    local entry = {
                        time = nowStamp(), source = "LuaError", event = "errorhandler",
                        err = text:sub(1, 400), combat = InCombatLockdown and InCombatLockdown() and true or false,
                        mods = modifierString(),
                    }
                    entry.key = text:sub(1, 200)
                    local store = captureStore()
                    pushCapture(store.errors, entry, "key")
                    local live = _G.WoWXRuntimeErrors
                    if not live then live = {}; _G.WoWXRuntimeErrors = live end
                    local dup
                    for _, e in ipairs(live) do
                        if e.key == entry.key then
                            e.count = (e.count or 1) + 1
                            dup = true
                            break
                        end
                    end
                    if not dup then
                        live[#live + 1] = { time = entry.time, source = "LuaError", event = "errorhandler",
                            err = entry.err, key = entry.key, count = 1 }
                        while #live > 50 do table.remove(live, 1) end
                    end
                end
            end)
            inHandler = false
        end
        if previous then return previous(msg) end
    end)
end

-- Secret values (modern clients): in combat / restricted state the cooldown, charge,
-- usable and aura APIs return opaque values that insecure code cannot compare, branch
-- on, or do arithmetic with (it throws). WoWX must only PASS them to widget APIs.
_G.WoWXIsSecret = function(value)
    return type(_G.issecretvalue) == "function" and _G.issecretvalue(value) == true or false
end

-- Removed on modern clients (VisualBar 3881: "attempt to call a nil value").
if missing("CooldownFrame_SetTimer") then
    _G.CooldownFrame_SetTimer = function(cooldown, start, duration, enable)
        if not cooldown then return end
        if WoWXIsSecret(start) or WoWXIsSecret(duration) or WoWXIsSecret(enable) then
            -- Cannot inspect; hand straight to the widget, which accepts secrets.
            if cooldown.SetCooldown then
                local ok, err = pcall(cooldown.SetCooldown, cooldown, start, duration)
                if not ok then _G.WoWXLastCooldownError = tostring(err) end
            end
            return
        end
        if enable and enable ~= 0 and duration and duration > 0 and start and start > 0 then
            if cooldown.SetCooldown then cooldown:SetCooldown(start, duration) end
        elseif cooldown.Clear then
            cooldown:Clear()
        elseif cooldown.SetCooldown then
            cooldown:SetCooldown(0, 0)
        end
    end
end

if C_Spell then
    if missing("GetSpellInfo") and C_Spell.GetSpellInfo then
        _G.GetSpellInfo = function(spell)
            if spell == nil then return nil end
            local info = C_Spell.GetSpellInfo(spell)
            if not info then return nil end
            return info.name, nil, info.iconID, info.castTime, info.minRange, info.maxRange, info.spellID, info.originalIconID
        end
    end
    if missing("GetSpellTexture") and C_Spell.GetSpellTexture then
        _G.GetSpellTexture = function(spell)
            return C_Spell.GetSpellTexture(spell)
        end
    end
    if missing("GetSpellCooldown") and C_Spell.GetSpellCooldown then
        _G.GetSpellCooldown = function(spell)
            local info = C_Spell.GetSpellCooldown(spell)
            if not info then return 0, 0, 1 end
            return info.startTime, info.duration, (info.isEnabled == false) and 0 or 1, info.modRate
        end
    end
    if missing("IsSpellOverlayed") and C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed then
        _G.IsSpellOverlayed = function(spell)
            return C_SpellActivationOverlay.IsSpellOverlayed(spell)
        end
    end
    if missing("GetSpellCharges") and C_Spell.GetSpellCharges then
        _G.GetSpellCharges = function(spell)
            local info = C_Spell.GetSpellCharges(spell)
            if not info then return nil end
            return info.currentCharges, info.maxCharges, info.cooldownStartTime, info.cooldownDuration, info.chargeModRate
        end
    end
end

if missing("GetWatchedFactionInfo") and C_Reputation and C_Reputation.GetWatchedFactionData then
    _G.GetWatchedFactionInfo = function()
        local data = C_Reputation.GetWatchedFactionData()
        if not data or not data.name or data.factionID == 0 then return nil end
        return data.name, data.reaction, data.currentReactionThreshold, data.nextReactionThreshold, data.currentStanding, data.factionID
    end
end

if C_Item and missing("GetItemInfo") and C_Item.GetItemInfo then
    _G.GetItemInfo = function(item)
        return C_Item.GetItemInfo(item)
    end
end

if C_CurrencyInfo and missing("GetBackpackCurrencyInfo") and C_CurrencyInfo.GetBackpackCurrencyInfo then
    _G.GetBackpackCurrencyInfo = function(index)
        local info = C_CurrencyInfo.GetBackpackCurrencyInfo(index)
        if not info then return nil end
        return info.name, info.quantity, info.iconFileID, info.currencyTypesID
    end
end

if C_Container then
    local C = C_Container
    if missing("GetContainerNumSlots") and C.GetContainerNumSlots then
        _G.GetContainerNumSlots = C.GetContainerNumSlots
    end
    if missing("GetContainerNumFreeSlots") and C.GetContainerNumFreeSlots then
        _G.GetContainerNumFreeSlots = C.GetContainerNumFreeSlots
    end
    if missing("GetContainerItemLink") and C.GetContainerItemLink then
        _G.GetContainerItemLink = C.GetContainerItemLink
    end
    if missing("GetContainerItemID") and C.GetContainerItemID then
        _G.GetContainerItemID = C.GetContainerItemID
    end
    if missing("GetContainerItemCooldown") and C.GetContainerItemCooldown then
        _G.GetContainerItemCooldown = C.GetContainerItemCooldown
    end
    if missing("PickupContainerItem") and C.PickupContainerItem then
        _G.PickupContainerItem = C.PickupContainerItem
    end
    if missing("SplitContainerItem") and C.SplitContainerItem then
        _G.SplitContainerItem = C.SplitContainerItem
    end
    if missing("UseContainerItem") and C.UseContainerItem then
        _G.UseContainerItem = C.UseContainerItem
    end
    if missing("GetContainerItemInfo") and C.GetContainerItemInfo then
        _G.GetContainerItemInfo = function(bag, slot)
            local info = C.GetContainerItemInfo(bag, slot)
            if not info then return nil end
            return info.iconFileID, info.stackCount, info.isLocked, info.quality,
                info.isReadable, info.hasLoot, info.hyperlink, info.isFiltered,
                info.hasNoValue, info.itemID, info.isBound
        end
    end
end

if C_UnitAuras and C_UnitAuras.GetDebuffDataByIndex and missing("UnitDebuff") then
    _G.UnitDebuff = function(unit, index)
        -- Aura data is secret in combat while tainted; report "no aura" instead of erroring.
        local ok, aura = pcall(C_UnitAuras.GetDebuffDataByIndex, unit, index)
        if not ok or not aura or WoWXIsSecret(aura.name) then return nil end
        return aura.name, nil, aura.icon, aura.applications, aura.dispelName, aura.duration,
            aura.expirationTime, aura.sourceUnit, aura.isStealable, nil, aura.spellId
    end
end

if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex and missing("UnitBuff") then
    _G.UnitBuff = function(unit, index)
        local ok, aura = pcall(C_UnitAuras.GetBuffDataByIndex, unit, index)
        if not ok or not aura or WoWXIsSecret(aura.name) then return nil end
        return aura.name, nil, aura.icon, aura.applications, aura.dispelName, aura.duration,
            aura.expirationTime, aura.sourceUnit, aura.isStealable, nil, aura.spellId
    end
end
