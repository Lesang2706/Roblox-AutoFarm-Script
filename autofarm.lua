--[[
	WARNING: Heads up! This script has not been verified by ScriptBlox. Use at your own risk!
]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")

-- Paths
local BarrelsFolder = workspace:WaitForChild("Barrels"):WaitForChild("Barrels")

-- Settings
local SETTINGS = {
    HIGH_ALTITUDE = 500, -- Altitude to move above map
    HORIZ_STEP = 50, -- Horizontal movement step size
    HORIZ_DELAY = 0.02, -- Delay between horizontal steps
    VERT_STEP = 2, -- Vertical movement step size
    VERT_DELAY = 0.01, -- Delay between vertical steps
    CLICK_OFFSET = 2, -- Offset above barrel for clicking
    CLICK_RETRIES = 3, -- Number of click attempts per barrel
    COOLDOWN = 15, -- Cooldown per barrel in seconds
    TARGET_TIMEOUT = 5, -- Max seconds to spend on a single target
    CHECK_INTERVAL = 0.1, -- Interval to check for new barrels
}

local barrelCooldowns = {}
local autoFarmEnabled = true -- Starts enabled
local isProcessing = false -- Prevent overlapping coroutines

-- Notify user with on-screen messages
local function notify(message, color)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "AutoFarm",
            Text = message,
            Duration = 3,
            Icon = "",
            Button1 = color and "OK" or nil
        })
    end)
end

-- Handle character reset or death
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = newChar:WaitForChild("Humanoid")
    hrp = newChar:WaitForChild("HumanoidRootPart")
    notify("Character respawned, auto-farm resuming.", true)
end)

-- PC toggle: press F
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.F then
        autoFarmEnabled = not autoFarmEnabled
        notify("Auto-farm toggled: " .. (autoFarmEnabled and "ON" or "OFF"), true)
        button.Text = autoFarmEnabled and "AutoFarm: ON" or "AutoFarm: OFF"
    end
end)

-- Mobile / GUI toggle button
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoFarmToggleGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 150, 0, 50)
button.Position = UDim2.new(0, 20, 0, 20)
button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
button.TextColor3 = Color3.fromRGB(255, 255, 255)
button.Text = autoFarmEnabled and "AutoFarm: ON" or "AutoFarm: OFF"
button.TextScaled = true
button.Parent = screenGui

button.MouseButton1Click:Connect(function()
    autoFarmEnabled = not autoFarmEnabled
    notify("Auto-farm toggled: " .. (autoFarmEnabled and "ON" or "OFF"), true)
    button.Text = autoFarmEnabled and "AutoFarm: ON" or "AutoFarm: OFF"
end)

-- Clean up old cooldowns to prevent memory buildup
local function cleanCooldowns()
    local currentTime = tick()
    for barrel, lastClick in pairs(barrelCooldowns) do
        if currentTime - lastClick > SETTINGS.COOLDOWN then
            barrelCooldowns[barrel] = nil
        end
    end
end

-- Move horizontally high above map
local function moveHighTo(targetPos)
    if not character or not humanoid or humanoid.Health <= 0 then return false end
    local startPos = hrp.Position
    local startHigh = Vector3.new(startPos.X, SETTINGS.HIGH_ALTITUDE, startPos.Z)
    local targetHigh = Vector3.new(targetPos.X, SETTINGS.HIGH_ALTITUDE, targetPos.Z)
    local direction = (targetHigh - startHigh).Unit
    local distance = (targetHigh - startHigh).Magnitude
    local steps = math.floor(distance / SETTINGS.HORIZ_STEP)

    for i = 1, steps do
        if not autoFarmEnabled or humanoid.Health <= 0 then return false end
        local stepPos = startHigh + direction * (i * SETTINGS.HORIZ_STEP)
        hrp.CFrame = CFrame.new(stepPos)
        RunService.Heartbeat:Wait()
    end
    if autoFarmEnabled and humanoid.Health > 0 then
        hrp.CFrame = CFrame.new(targetHigh)
        return true
    end
    return false
end

-- Descend slowly above target
local function descendToTarget(targetPos)
    if not character or not humanoid or humanoid.Health <= 0 then return false end
    local targetY = targetPos.Y + SETTINGS.CLICK_OFFSET
    local startTime = tick()
    while hrp.Position.Y > targetY do
        if not autoFarmEnabled or humanoid.Health <= 0 then return false end
        if tick() - startTime > SETTINGS.TARGET_TIMEOUT then
            notify("Timed out descending to target.", false)
            return false
        end
        hrp.CFrame = CFrame.new(hrp.Position.X, math.max(hrp.Position.Y - SETTINGS.VERT_STEP, targetY), hrp.Position.Z)
        RunService.Heartbeat:Wait()
    end
    return true
end

-- Click target safely with retries
local function clickTarget(target)
    if not target or not target:IsA("BasePart") or not character or not humanoid or humanoid.Health <= 0 then
        return false
    end
    local lastClick = barrelCooldowns[target] or 0
    if tick() - lastClick < SETTINGS.COOLDOWN then
        return false
    end

    local targetPos = target.Position

    -- Move high
    if not moveHighTo(targetPos) then return false end

    -- Descend
    if not descendToTarget(targetPos) then return false end

    -- Attempt clicks
    local clickDetector = target:FindFirstChildOfClass("ClickDetector")
    if clickDetector then
        for i = 1, SETTINGS.CLICK_RETRIES do
            if not autoFarmEnabled or humanoid.Health <= 0 then return false end
            pcall(function()
                fireclickdetector(clickDetector, 0)
            end)
            RunService.Heartbeat:Wait()
        end
        barrelCooldowns[target] = tick()
        notify("Clicked barrel at " .. tostring(targetPos), true)
        return true
    else
        notify("No ClickDetector found on barrel.", false)
        return false
    end
end

-- Auto-farm function in a coroutine
local function autoFarm()
    while true do
        if autoFarmEnabled and not isProcessing and character and humanoid and humanoid.Health > 0 then
            isProcessing = true
            cleanCooldowns() -- Clean up expired cooldowns
            local barrels = BarrelsFolder:GetChildren()
            for _, barrel in ipairs(barrels) do
                if not autoFarmEnabled or humanoid.Health <= 0 then break end
                if barrel:IsA("BasePart") then
                    clickTarget(barrel)
                end
            end
            isProcessing = false
        end
        RunService.Heartbeat:Wait() -- More precise than wait(0.1)
    end
end

-- Start auto-farm
coroutine.wrap(autoFarm)()

-- Notify user on script start
notify("Auto-farm script started. Press F or use GUI to toggle.", true)
