if not GamePadX then return end

local GPX = GamePadX
local Ring = {}

GPX.SpellRing = Ring

Ring.buttonPrefix = "GamePadXSpellRingButton"
Ring.appliedKeys = {}
Ring.buttons = {}
Ring.pendingRebuild = false

local ringFrame = CreateFrame("Frame", "GamePadXSpellRingFrame")
ringFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

local function trim(text)
    if not text then return "" end
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

function Ring:GetRings()
    local profile = GPX:GetProfile()
    if not profile.spellRings then
        profile.spellRings = {}
    end
    return profile.spellRings
end

function Ring:GetRing(index)
    index = tonumber(index)
    if not index then return nil end
    return self:GetRings()[index], index
end

function Ring:BuildMacroText(ring)
    if not ring or not ring.spells or #ring.spells == 0 then
        return nil
    end

    local reset = tonumber(ring.resetSeconds) or 5
    return "/castsequence reset=" .. reset .. " " .. table.concat(ring.spells, ", ")
end

function Ring:GetButtonName(index)
    return self.buttonPrefix .. tostring(index)
end

function Ring:EnsureButton(index)
    local name = self:GetButtonName(index)
    local button = self.buttons[index]
    if button then
        return button, name
    end

    button = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    button:Hide()
    self.buttons[index] = button
    return button, name
end

function Ring:ClearBindings()
    for key in pairs(self.appliedKeys) do
        SetBinding(key, nil)
        self.appliedKeys[key] = nil
        GPX.appliedBindings[key] = nil
    end
end

function Ring:ApplyBindings()
    self:ClearBindings()

    if InCombatLockdown() then
        self.pendingRebuild = true
        GPX:Print("SpellRing changes queued until combat ends.")
        return
    end

    local rings = self:GetRings()
    local applied = 0
    local skipped = 0

    for index, ring in ipairs(rings) do
        local key = ring.key and strupper(trim(ring.key)) or nil
        local macroText = self:BuildMacroText(ring)

        if key and key ~= "" and macroText then
            local button, buttonName = self:EnsureButton(index)
            button:SetAttribute("type", "macro")
            button:SetAttribute("macrotext", macroText)

            if SetBindingClick(key, buttonName) then
                self.appliedKeys[key] = true
                GPX.appliedBindings[key] = "CLICK " .. buttonName
                ring.key = key
                applied = applied + 1
            else
                GPX:Print("|cffff4444SpellRing bind failed:|r " .. key .. " -> " .. (ring.name or ("Ring " .. index)))
                skipped = skipped + 1
            end
        elseif key and key ~= "" then
            skipped = skipped + 1
        end
    end

    self.pendingRebuild = false

    if applied > 0 then
        GPX:Print("SpellRing active: " .. applied .. " ring binding(s) applied.")
    elseif skipped > 0 then
        GPX:Print("SpellRing found bindings with no spells; nothing was applied.")
    end
end

function Ring:Reapply()
    if GPX.db and GPX.db.enabled then
        self:ApplyBindings()
    else
        self:ClearBindings()
    end
end

function Ring:ListRings()
    local rings = self:GetRings()
    if #rings == 0 then
        GPX:Print("No SpellRings configured. Use /wowx ring new <name>.")
        return
    end

    GPX:Print("SpellRings — profile: " .. (GPX.db.profile or "default"))
    for index, ring in ipairs(rings) do
        local key = ring.key or "(unbound)"
        local count = ring.spells and #ring.spells or 0
        local reset = tonumber(ring.resetSeconds) or 5
        GPX:Print(string.format("  %d. %s  [%s]  spells=%d  reset=%ss", index, ring.name or ("Ring " .. index), key, count, reset))
    end
end

function Ring:ShowRing(index)
    local ring = self:GetRing(index)
    if not ring then
        GPX:Print("SpellRing not found: " .. tostring(index))
        return
    end

    GPX:Print(string.format("Ring %d: %s", index, ring.name or ("Ring " .. index)))
    GPX:Print("  Key: " .. (ring.key or "(unbound)"))
    GPX:Print("  Reset: " .. tostring(tonumber(ring.resetSeconds) or 5) .. "s")

    if not ring.spells or #ring.spells == 0 then
        GPX:Print("  Spells: (empty)")
        return
    end

    for spellIndex, spellName in ipairs(ring.spells) do
        GPX:Print("  " .. spellIndex .. ". " .. spellName)
    end
end

function Ring:NewRing(name)
    name = trim(name)
    if name == "" then
        GPX:Print("Usage: /wowx ring new <name>")
        return
    end

    local rings = self:GetRings()
    rings[#rings + 1] = {
        name = name,
        key = nil,
        spells = {},
        resetSeconds = 5,
    }

    GPX:Print("Created SpellRing " .. #rings .. ": " .. name)
end

function Ring:DeleteRing(index)
    local rings = self:GetRings()
    index = tonumber(index)
    if not index or not rings[index] then
        GPX:Print("SpellRing not found: " .. tostring(index))
        return
    end

    local name = rings[index].name or ("Ring " .. index)
    table.remove(rings, index)
    self:Reapply()
    GPX:Print("Deleted SpellRing: " .. name)
end

function Ring:BindRing(index, key)
    local ring = self:GetRing(index)
    key = key and strupper(trim(key)) or ""
    if not ring then
        GPX:Print("SpellRing not found: " .. tostring(index))
        return
    end
    if key == "" then
        GPX:Print("Usage: /wowx ring bind <index> <KEY>")
        return
    end

    ring.key = key
    self:Reapply()
    GPX:Print("SpellRing " .. index .. " bound to " .. key)
end

function Ring:SetReset(index, seconds)
    local ring = self:GetRing(index)
    seconds = tonumber(seconds)
    if not ring then
        GPX:Print("SpellRing not found: " .. tostring(index))
        return
    end
    if not seconds or seconds < 0 then
        GPX:Print("Usage: /wowx ring reset <index> <seconds>")
        return
    end

    ring.resetSeconds = seconds
    self:Reapply()
    GPX:Print("SpellRing " .. index .. " reset set to " .. seconds .. " seconds")
end

function Ring:AddSpell(index, spellName)
    local ring = self:GetRing(index)
    spellName = trim(spellName)
    if not ring then
        GPX:Print("SpellRing not found: " .. tostring(index))
        return
    end
    if spellName == "" then
        GPX:Print("Usage: /wowx ring add <index> <spell name>")
        return
    end

    if not ring.spells then
        ring.spells = {}
    end

    ring.spells[#ring.spells + 1] = spellName
    self:Reapply()

    if not GetSpellInfo(spellName) then
        GPX:Print("Added to SpellRing " .. index .. ": " .. spellName .. "  (spell not found yet; check spelling if needed)")
    else
        GPX:Print("Added to SpellRing " .. index .. ": " .. spellName)
    end
end

function Ring:RemoveSpell(index, spellIndex)
    local ring = self:GetRing(index)
    spellIndex = tonumber(spellIndex)
    if not ring then
        GPX:Print("SpellRing not found: " .. tostring(index))
        return
    end
    if not spellIndex or not ring.spells or not ring.spells[spellIndex] then
        GPX:Print("Usage: /wowx ring remove <index> <spell number>")
        return
    end

    local spellName = ring.spells[spellIndex]
    table.remove(ring.spells, spellIndex)
    self:Reapply()
    GPX:Print("Removed from SpellRing " .. index .. ": " .. spellName)
end

function Ring:RenameRing(index, name)
    local ring = self:GetRing(index)
    name = trim(name)
    if not ring then
        GPX:Print("SpellRing not found: " .. tostring(index))
        return
    end
    if name == "" then
        GPX:Print("Usage: /wowx ring rename <index> <name>")
        return
    end

    ring.name = name
    GPX:Print("SpellRing " .. index .. " renamed to " .. name)
end

function Ring:PrintHelp()
    GPX:Print("SpellRing commands:")
    GPX:Print("  /wowx ring list")
    GPX:Print("  /wowx ring show <index>")
    GPX:Print("  /wowx ring new <name>")
    GPX:Print("  /wowx ring rename <index> <name>")
    GPX:Print("  /wowx ring delete <index>")
    GPX:Print("  /wowx ring bind <index> <KEY>")
    GPX:Print("  /wowx ring reset <index> <seconds>")
    GPX:Print("  /wowx ring add <index> <spell name>")
    GPX:Print("  /wowx ring remove <index> <spell number>")
    GPX:Print("Example: /wowx ring new Cooldowns")
    GPX:Print("Example: /wowx ring bind 1 CTRL-F13")
    GPX:Print("Example: /wowx ring add 1 Divine Protection")
end

function Ring:Slash(msg)
    local cmd, rest = msg:match("^(%S+)%s*(.*)")
    cmd = cmd and strlower(cmd) or ""
    rest = rest or ""

    if cmd == "" or cmd == "help" then
        self:PrintHelp()

    elseif cmd == "list" then
        self:ListRings()

    elseif cmd == "show" then
        self:ShowRing(rest:match("^(%d+)"))

    elseif cmd == "new" then
        self:NewRing(rest)

    elseif cmd == "rename" then
        local index, name = rest:match("^(%d+)%s+(.+)$")
        self:RenameRing(index, name)

    elseif cmd == "delete" then
        self:DeleteRing(rest:match("^(%d+)"))

    elseif cmd == "bind" then
        local index, key = rest:match("^(%d+)%s+(%S+)$")
        self:BindRing(index, key)

    elseif cmd == "reset" then
        local index, seconds = rest:match("^(%d+)%s+(%d+)$")
        self:SetReset(index, seconds)

    elseif cmd == "add" then
        local index, spellName = rest:match("^(%d+)%s+(.+)$")
        self:AddSpell(index, spellName)

    elseif cmd == "remove" then
        local index, spellIndex = rest:match("^(%d+)%s+(%d+)$")
        self:RemoveSpell(index, spellIndex)

    else
        GPX:Print("Unknown SpellRing command: " .. cmd)
        self:PrintHelp()
    end
end

ringFrame:SetScript("OnEvent", function()
    if Ring.pendingRebuild and GPX.db and GPX.db.enabled then
        Ring:ApplyBindings()
    end
end)