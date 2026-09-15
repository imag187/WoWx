-- Camera.lua: Auto mouselook for controller mode
-- Simplified from ConsolePort - only active when controller enabled

local GPX = WoWX

local Camera = CreateFrame("Frame", "WoWXCamera")
local cameraActive = false
local blockCamera = false

-- State tracking
local function IsControllerMode()
    return GPX.db and GPX.db.ui and GPX.db.ui.controller and GPX.db.ui.controller.enabled
end

local function ShouldBlockCamera()
    return SpellIsTargeting() or  -- Placing AoE/reticle spell
           GetCursorInfo() or      -- Holding item
           blockCamera             -- Temporary block (interact)
end

-- Camera control
local function StartCamera()
    if not IsControllerMode() then return end
    if ShouldBlockCamera() then return end
    if GetMouseFocus() ~= WorldFrame then return end
    
    if not cameraActive and not IsMouselooking() then
        MouselookStart()
        cameraActive = true
    end
end

local function StopCamera()
    if cameraActive and IsMouselooking() then
        MouselookStop()
        cameraActive = false
    end
end

-- Movement hooks - trigger camera when moving with WASD
local function OnMovementStart()
    if IsControllerMode() then
        StartCamera()
    end
end

local movementFunctions = {
    "MoveForwardStart",
    "MoveBackwardStart",
    "StrafeLeftStart",
    "StrafeRightStart",
    "TurnLeftStart",
    "TurnRightStart",
}
for _, functionName in ipairs(movementFunctions) do
    if type(_G[functionName]) == "function" then
        hooksecurefunc(functionName, OnMovementStart)
    end
end

-- Stop camera when interacting on clients that expose the legacy helper.
if type(InteractUnit) == "function" then
    hooksecurefunc("InteractUnit", function()
        blockCamera = true
        StopCamera()
        C_Timer.After(0.5, function() blockCamera = false end)
    end)
end

-- Update loop - stop camera when conditions change
Camera:SetScript("OnUpdate", function(self, elapsed)
    if not IsControllerMode() then
        if cameraActive then
            StopCamera()
        end
        return
    end
    
    -- Stop camera if blocking conditions appear
    if cameraActive and ShouldBlockCamera() then
        StopCamera()
    end
end)

-- Disable when controller mode toggles off
function GPX:OnControllerModeChanged()
    if not IsControllerMode() then
        StopCamera()
    end
end

GPX.Camera = Camera
