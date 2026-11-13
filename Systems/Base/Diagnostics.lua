-- Systems/Base/Diagnostics.lua
-- /wowx diag       : self-test suite; failed checks attempt a repair, then re-test.
-- /wowx diag dump  : same, plus the full state dump in the pinned, selectable output window.

local GPX = GamePadX
if not GPX then
    return
end

local Diag = {}
GPX.Diag = Diag

local function safe(fn, ...)
    local ok, a = pcall(fn, ...)
    if ok then
        return true, a
    end
    return false, tostring(a)
end

local function getDB()
    return GPX.db
end

local function addonEnabled()
    local db = getDB()
    return db and db.enabled and true or false
end

local function trunc(text, max)
    text = tostring(text or "")
    if #text > max then
        return text:sub(1, max) .. "..."
    end
    return text
end

local function countKeys(t)
    local n = 0
    for _ in pairs(t or {}) do
        n = n + 1
    end
    return n
end

-- Each check: name, test() -> ok(true/false/nil=info), detail ; optional fix().
local function buildChecks()
    local Bar = GPX.VisualBar
    local checks = {}
    local function add(name, test, fix)
        checks[#checks + 1] = { name = name, test = test, fix = fix }
    end

    add("Saved data loaded", function()
        return type(getDB()) == "table", "WoWXDB " .. type(getDB())
    end)

    add("Addon enabled for this character", function()
        local db = getDB()
        local on = db and db.enabled
        local detail = "enabled=" .. tostring(on) .. " optIn=" .. tostring(db and db.characterOptIn)
        if not on then
            detail = detail .. "  -> type /wowx enable (opt-in is per character), then /reload"
        end
        return on and true or false, detail
    end)

    add("No captured runtime errors", function()
        local errs = _G.WoWXRuntimeErrors
        if not errs or #errs == 0 then
            return true, "none"
        end
        local last = errs[#errs]
        return false, #errs .. " captured; last [" .. tostring(last.time) .. "] " .. tostring(last.source)
            .. " (" .. tostring(last.event) .. "): " .. trunc(last.err, 220)
    end)

    add("No blocked protected actions (WoWX)", function()
        local list = (_G.WoWXDB and _G.WoWXDB.captures and _G.WoWXDB.captures.blocked) or _G.WoWXBlockedActions or {}
        local mine = {}
        for _, e in ipairs(list) do
            if tostring(e.addon):lower():find("wowx", 1, true) then mine[#mine + 1] = e end
        end
        if #mine == 0 then
            return true, "none this session (all addons: " .. #list .. ")"
        end
        local last = mine[#mine]
        return false, #mine .. " distinct; last [" .. tostring(last.last) .. "] " .. tostring(last.event) .. " "
            .. tostring(last.func) .. " combat=" .. tostring(last.combat) .. " x" .. tostring(last.count)
    end)

    add("Modules loaded", function()
        local missing = {}
        for _, key in ipairs({ "Pager", "ClickTransport", "VisualBar", "UIMode" }) do
            if not GPX[key] then
                missing[#missing + 1] = key
            end
        end
        if #missing > 0 then
            return false, "missing: " .. table.concat(missing, ", ")
        end
        return true, "Pager ClickTransport VisualBar UIMode"
    end)

    add("Legacy API shims present", function()
        local missing = {}
        local names = { "GetSpellInfo", "GetMouseFocus", "GetSpellCharges", "GetWatchedFactionInfo",
            "GetContainerNumSlots", "GetContainerItemInfo", "UseContainerItem", "UnitBuff", "CooldownFrame_SetTimer" }
        for _, name in ipairs(names) do
            if type(_G[name]) ~= "function" then
                missing[#missing + 1] = name
            end
        end
        if #missing > 0 then
            return false, "missing: " .. table.concat(missing, ", ")
        end
        return true, #names .. " present"
    end)

    local systemIds = { "core", "ui", "transport", "gamepad", "keyboard", "unitframes", "cues" }
    add("System toggles (config checkboxes)", function()
        local off = {}
        for _, id in ipairs(systemIds) do
            if not GPX:IsSystemEnabled(id) then
                off[#off + 1] = id
            end
        end
        if #off > 0 then
            return false, "disabled: " .. table.concat(off, ", ")
        end
        return true, "all enabled"
    end, function()
        for _, id in ipairs(systemIds) do
            if not GPX:IsSystemEnabled(id) then
                GPX:SetSystemEnabled(id, true)
            end
        end
    end)

    add("Visual bar enabled (config)", function()
        local db = getDB()
        local cfg = db and db.ui and db.ui.visualBar
        local on = cfg and cfg.enabled
        return on and true or false, "ui.visualBar.enabled=" .. tostring(on)
    end, function()
        local db = getDB()
        if not db then return end
        db.ui = db.ui or {}
        db.ui.visualBar = db.ui.visualBar or {}
        db.ui.visualBar.enabled = true
        if Bar then Bar:UpdateAll() end
    end)

    add("VisualBar:UpdateAll runs without error", function()
        if not Bar then
            return false, "VisualBar module missing"
        end
        local ok, err = safe(Bar.UpdateAll, Bar)
        if ok then
            return true, "ok"
        end
        if WoWXLogRuntimeError then
            WoWXLogRuntimeError("Diag", "VisualBar:UpdateAll", err)
        end
        return false, trunc(err, 300)
    end)

    add("Bar frame created", function()
        local frame = Bar and Bar.frame
        return frame ~= nil, frame and ("WoWXVisualBarFrame parent=" .. tostring(frame:GetParent() and frame:GetParent():GetName())) or "Bar.frame is nil"
    end, function()
        if Bar then Bar:UpdateAll() end
    end)

    add("Bar visible on screen", function()
        local frame = Bar and Bar.frame
        if not frame then
            return false, "no frame"
        end
        local w, h = frame:GetWidth() or 0, frame:GetHeight() or 0
        local alpha = frame.GetEffectiveAlpha and frame:GetEffectiveAlpha() or frame:GetAlpha()
        local scale = frame:GetEffectiveScale() or 0
        local l, r, b, t = frame:GetLeft(), frame:GetRight(), frame:GetBottom(), frame:GetTop()
        local problems = {}
        if not addonEnabled() then problems[#problems + 1] = "addon disabled" end
        if not frame:IsShown() then problems[#problems + 1] = "not shown" end
        if w < 2 or h < 2 then problems[#problems + 1] = "zero size" end
        if (alpha or 0) <= 0.01 then problems[#problems + 1] = "alpha 0" end
        if scale <= 0 then problems[#problems + 1] = "scale 0" end
        local sw = UIParent:GetWidth() * UIParent:GetEffectiveScale()
        local sh = UIParent:GetHeight() * UIParent:GetEffectiveScale()
        if not l then
            problems[#problems + 1] = "no anchor"
        else
            if r * scale < 0 or l * scale > sw or t * scale < 0 or b * scale > sh then
                problems[#problems + 1] = "off screen"
            end
        end
        local detail = string.format("shown=%s size=%.0fx%.0f alpha=%.2f scale=%.2f pos=L%s B%s screen=%.0fx%.0f",
            tostring(frame:IsShown()), w, h, alpha or 0, scale, l and string.format("%.0f", l * scale) or "nil",
            b and string.format("%.0f", b * scale) or "nil", sw, sh)
        if #problems > 0 then
            detail = table.concat(problems, ", ") .. " | " .. detail
        end
        return #problems == 0, detail
    end, function()
        if Bar then Bar:UpdateAll() end
    end)

    add("Action buttons (12) built", function()
        local exist, shown, typed = 0, 0, 0
        for i = 1, 12 do
            local b = _G["WoWXActionButton" .. i]
            if b then
                exist = exist + 1
                if b:IsShown() then shown = shown + 1 end
                if b.GetAttribute and b:GetAttribute("type") == "action" then typed = typed + 1 end
            end
        end
        local cvar = GetCVar and GetCVar("ActionButtonUseKeyDown")
        local b1 = _G.WoWXActionButton1
        local uk = b1 and b1.GetAttribute and b1:GetAttribute("useOnKeyDown")
        return exist == 12 and typed > 0 and uk ~= nil, string.format("exist=%d shown=%d secure-action=%d cvarKeyDown=%s btn1.useOnKeyDown=%s", exist, shown, typed, tostring(cvar), tostring(uk))
    end, function()
        if GPX.ClickTransport then
            for i = 1, 12 do
                local b = _G["WoWXActionButton" .. i]
                if b then GPX.ClickTransport:ConfigureClicks(b) end
            end
            GPX.ClickTransport:SyncClickMode()
        end
        if Bar then Bar:UpdateAll() end
    end)

    add("Pager active", function()
        local pager = GPX.Pager
        if not pager or not pager.GetCurrentPage then
            return false, "Pager missing"
        end
        local ok, page = safe(pager.GetCurrentPage, pager)
        if not ok then
            return false, page
        end
        local reg = countKeys(pager.registered)
        local detail = string.format("page=%s slot1=%s registered=%d", tostring(page), tostring(pager:GetSlot(1)), reg)
        return (not addonEnabled()) or reg > 0, detail
    end, function()
        if GPX.Pager and GPX.Pager.Refresh then GPX.Pager:Refresh() end
        if Bar then Bar:UpdateAll() end
    end)

    add("Click-transport proxy buttons", function()
        local CT = GPX.ClickTransport
        local n = CT and CT.GetProxyButtonCount and CT:GetProxyButtonCount() or 0
        return n > 0, n .. " proxies (expect ~60)"
    end, function()
        if Bar then Bar:UpdateBindingProxyButtons() end
    end)

    add("Key bindings routed to WoWX", function()
        if not addonEnabled() then
            return nil, "skipped (addon disabled)"
        end
        local a, b = GetBindingAction("1") or "", GetBindingAction("SHIFT-1") or ""
        local good = a:find("WoWX", 1, true) ~= nil or b:find("WoWX", 1, true) ~= nil
        return good, "1 -> " .. (a ~= "" and a or "(none)") .. " | SHIFT-1 -> " .. (b ~= "" and b or "(none)")
    end, function()
        GPX:ClearBindings(true)
        GPX:ApplyBindings(true)
    end)

    add("Blizzard / native bars handled", function()
        local main = _G.MainActionBar or _G.MainMenuBar
        local pad = _G.GamepadMainActionBarFrame
        local detail = "MainActionBar parent=" .. tostring(main and main:GetParent() and main:GetParent():GetName() or "nil")
            .. " shown=" .. tostring(main and main:IsShown())
            .. " | GamepadMainActionBarFrame=" .. (pad and ("shown=" .. tostring(pad:IsShown())) or "absent")
            .. " | controllerMode=" .. tostring(GPX:IsControllerEnabled())
        local ok = true
        if addonEnabled() and GPX:IsControllerEnabled() and pad and pad:IsShown() then
            ok = false
        end
        return ok, detail
    end, function()
        if Bar then Bar:UpdateBlizzardBars() end
    end)

    add("Native bags / micro menu", function()
        local micro, bags = _G.MicroMenu, _G.BagsBar
        local function pname(f)
            local p = f and f:GetParent()
            return f and (p and (p:GetName() or "?") or "nil") or "absent"
        end
        local detail = "MicroMenu parent=" .. pname(micro) .. " shown=" .. tostring(micro and micro:IsShown())
            .. " | BagsBar parent=" .. pname(bags) .. " shown=" .. tostring(bags and bags:IsShown())
            .. " | WoWXMicroMenuFrame=" .. tostring(Bar and Bar.microMenuFrame and Bar.microMenuFrame:IsShown() or false)
        if not addonEnabled() then
            return nil, detail .. " (addon disabled)"
        end
        local ok = true
        if micro and (pname(micro) == "WoWXHiddenBarParent" or not micro:IsShown()) then
            ok = false
        end
        if bags and pname(bags) == "WoWXHiddenBarParent" then
            ok = false
        end
        return ok, detail
    end, function()
        if Bar then Bar:UpdateBlizzardBars() end
    end)

    add("Vehicle exit button is native", function()
        local btn
        for _, name in ipairs({ "MainMenuBarVehicleLeaveButton", "VehicleMenuBarLeaveButton", "OverrideActionBarLeaveFrameLeaveButton" }) do
            if _G[name] then btn = _G[name] break end
        end
        if not btn then
            return nil, "no native leave button frame found"
        end
        local p = btn:GetParent()
        local pname = p and (p:GetName() or "?") or "nil"
        local detail = (btn:GetName() or "?") .. " parent=" .. pname .. " shown=" .. tostring(btn:IsShown())
            .. " visible=" .. tostring(btn:IsVisible())
            .. " canExit=" .. tostring(CanExitVehicle and CanExitVehicle() or false)
            .. " | WoWXVehicleHostFrame=" .. tostring(Bar and Bar.vehicleFrame and Bar.vehicleFrame:IsShown() or false)
        local ok = pname ~= "WoWXHiddenBarParent" and pname ~= "WoWXVehicleHostFrame"
        if CanExitVehicle and CanExitVehicle() and not btn:IsVisible() then
            ok = false
        end
        return ok, detail
    end, function()
        if Bar then Bar:UpdateBlizzardBars() end
    end)

    add("Capture hooks (info)", function()
        return nil, "popupHook=" .. tostring(_G.StaticPopup_Show ~= nil or (_G.C_StaticPopup ~= nil))
            .. " eventProbe=" .. tostring(_G.WoWXEventProbeOn == true) .. " (/wowx diag probe toggles it)"
    end)

    add("Hold-to-target buttons", function()
        if not C_GamepadTargeting then
            return nil, "C_GamepadTargeting API absent"
        end
        local f, h = _G.WoWXTargetFriendly, _G.WoWXTargetHostile
        return (f and h) and true or false, "friendly=" .. tostring(f ~= nil) .. " hostile=" .. tostring(h ~= nil)
    end)

    add("Action slot probe (info; run while a spell is on cooldown)", function()
        if InCombatLockdown() then
            return nil, "skipped in combat (cooldown values are secret)"
        end
        local parts = {}
        for slot = 1, 60 do
            local t, id = GetActionInfo(slot)
            if t then
                local name = (t == "spell" and GetSpellInfo and GetSpellInfo(id)) or tostring(id)
                local s, d = GetActionCooldown(slot)
                if type(s) == "table" then s, d = s.startTime, s.duration end
                local ss, sd = 0, 0
                if t == "spell" and GetSpellCooldown then ss, sd = GetSpellCooldown(id) end
                local ov = ""
                if t == "spell" and C_Spell and C_Spell.GetOverrideSpell then
                    local o = C_Spell.GetOverrideSpell(id)
                    if o and o ~= id then ov = " ovr=" .. tostring(o) end
                end
                local us, oom = IsUsableAction(slot)
                parts[#parts + 1] = string.format("[%d %s:%s id=%s actCD=%.1f spCD=%.1f usable=%s oom=%s%s]",
                    slot, t, tostring(name), tostring(id), d or 0, sd or 0, tostring(us), tostring(oom), ov)
            end
        end
        return nil, #parts == 0 and "no actions" or table.concat(parts, " ")
    end)

    add("Combat cooldown path (info; check after a fight)", function()
        local VB = GPX.VisualBar
        local cd = _G.WoWXActionButton1 and _G.WoWXActionButton1.cooldown
        return nil, string.format("GetActionCooldownDuration=%s SetCooldownFromDurationObject=%s lastPath=%s lastErr=%s settimerErr=%s",
            tostring(C_ActionBar and C_ActionBar.GetActionCooldownDuration ~= nil),
            tostring(cd and cd.SetCooldownFromDurationObject ~= nil),
            tostring(VB and VB._cdLastPath), tostring(VB and VB._cdLastErr), tostring(_G.WoWXLastCooldownError))
    end)

    add("Native gamepad UI (info)", function()
        local on = C_GamePad and C_GamePad.IsEnabled and C_GamePad.IsEnabled()
        return nil, "C_GamePad.IsEnabled=" .. tostring(on)
    end)

    return checks
end

local function runCheck(check)
    local ok, result, detail = pcall(check.test)
    if not ok then
        return false, "check crashed: " .. trunc(result, 250)
    end
    return result, detail
end

function Diag:RunChecks()
    local results = {}
    local combat = InCombatLockdown()
    for _, check in ipairs(buildChecks()) do
        local ok, detail = runCheck(check)
        local entry = { name = check.name, ok = ok, detail = tostring(detail or "") }
        if ok == nil then
            entry.status = "INFO"
        elseif ok then
            entry.status = "PASS"
        else
            entry.status = "FAIL"
            if check.fix and not combat then
                local fixOk, fixErr = pcall(check.fix)
                if not fixOk then
                    entry.detail = entry.detail .. " | repair crashed: " .. trunc(fixErr, 200)
                else
                    local ok2, detail2 = runCheck(check)
                    if ok2 then
                        entry.status = "FIXED"
                        entry.detail = "repaired (was: " .. trunc(entry.detail, 160) .. ")"
                    else
                        entry.detail = tostring(detail2 or entry.detail) .. " | repair attempted"
                    end
                end
            elseif check.fix and combat then
                entry.detail = entry.detail .. " | repair skipped (in combat)"
            end
        end
        results[#results + 1] = entry
    end
    return results
end

local COLORS = { PASS = "|cff55dd55", FIXED = "|cffffcc33", FAIL = "|cffff5555", INFO = "|cff88aacc" }

function Diag:Run(dump)
    if not GPX.db then
        GPX:Print("Diag: saved data not loaded yet.")
        return
    end

    local results = self:RunChecks()
    local counts = { PASS = 0, FIXED = 0, FAIL = 0, INFO = 0 }
    for _, r in ipairs(results) do
        counts[r.status] = counts[r.status] + 1
    end

    GPX:Print(string.format("Diag: %d pass, %d fixed, %d FAIL, %d info", counts.PASS, counts.FIXED, counts.FAIL, counts.INFO))
    for _, r in ipairs(results) do
        if r.status == "FAIL" or r.status == "FIXED" then
            GPX:Print(string.format("%s[%s]|r %s - %s", COLORS[r.status], r.status, r.name, r.detail))
        end
    end
    if counts.FAIL == 0 then
        GPX:Print("|cff55dd55All checks OK.|r Use /wowx diag dump for the full report.")
    end

    local lines = {}
    lines[#lines + 1] = string.format("Self-test: %d pass, %d fixed, %d FAIL, %d info   (%s)",
        counts.PASS, counts.FIXED, counts.FAIL, counts.INFO, date("%Y-%m-%d %H:%M:%S"))
    local _, class = UnitClass("player")
    lines[#lines + 1] = string.format("Player: %s (%s)  combat=%s", tostring(UnitName("player")), tostring(class), tostring(InCombatLockdown()))
    lines[#lines + 1] = ""
    for _, r in ipairs(results) do
        lines[#lines + 1] = string.format("[%s] %s - %s", r.status, r.name, r.detail)
    end

    local errs = _G.WoWXRuntimeErrors
    lines[#lines + 1] = ""
    lines[#lines + 1] = "== Runtime errors (" .. tostring(errs and #errs or 0) .. ") =="
    for _, e in ipairs(errs or {}) do
        lines[#lines + 1] = string.format("[%s] %s (%s)%s: %s", tostring(e.time), tostring(e.source), tostring(e.event),
            (e.count and e.count > 1) and (" x" .. e.count) or "", tostring(e.err))
    end

    local function addCaptureLines(title, cap)
        if type(cap) ~= "table" then return end
        lines[#lines + 1] = ""
        lines[#lines + 1] = "== " .. title .. " =="
        for _, b in ipairs(cap.blocked or {}) do
            lines[#lines + 1] = string.format("[%s..%s] %s addon=%s func=%s combat=%s mods=%s x%s",
                tostring(b.time), tostring(b.last), tostring(b.event), tostring(b.addon), tostring(b.func),
                tostring(b.combat), (b.mods and b.mods ~= "") and b.mods or "-", tostring(b.count))
            if b.stack then
                for stackLine in tostring(b.stack):gmatch("[^\r\n]+") do
                    lines[#lines + 1] = "      " .. stackLine
                end
            end
        end
        for _, e in ipairs(cap.errors or {}) do
            lines[#lines + 1] = string.format("[%s..%s] LuaError combat=%s mods=%s x%s: %s",
                tostring(e.time), tostring(e.last), tostring(e.combat),
                (e.mods and e.mods ~= "") and e.mods or "-", tostring(e.count), tostring(e.err))
        end
    end
    local db0 = _G.WoWXDB
    addCaptureLines("Blocked actions / Lua errors (this session)", db0 and db0.captures)
    addCaptureLines("Blocked actions / Lua errors (previous session)", db0 and db0.previousCaptures)

    lines[#lines + 1] = ""
    lines[#lines + 1] = "== Full state =="
    local okState, state = pcall(GPX.CollectDiagnosticsLines, GPX)
    if okState and type(state) == "table" then
        for _, l in ipairs(state) do
            lines[#lines + 1] = tostring(l)
        end
    else
        lines[#lines + 1] = "CollectDiagnosticsLines failed: " .. tostring(state)
    end

    local db = GPX.db
    db.diagRuns = db.diagRuns or {}
    local run = { at = date("%Y-%m-%d %H:%M:%S"), label = "diag-" .. date("%Y%m%d-%H%M%S"), lines = lines }
    table.insert(db.diagRuns, run)
    while #db.diagRuns > 10 do
        table.remove(db.diagRuns, 1)
    end
    db.lastDiagRun = run

    if dump then
        GPX:SetOutputWindowLines(lines, "WoWX diag dump", true)
        GPX:Print("Report is in the output window (pinned, selected). Ctrl+C to copy.")
    end
end
