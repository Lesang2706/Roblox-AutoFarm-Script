local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

-- Paths
local BarrelsFolder = workspace:WaitForChild("Barrels"):WaitForChild("Barrels")

-- Settings
local HIGH_ALTITUDE = 500
local HORIZ_STEP = 50
local HORIZ_DELAY = 0.02
local VERT_STEP = 2
local VERT_DELAY = 0.01
local CLICK_OFFSET = 2
local CLICK_RETRIES = 3
local COOLDOWN = 15
local TARGET_TIMEOUT = 5 -- max seconds per target

local barrelCooldowns = {}
local autoFarmEnabled = true -- starts on

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

-- PC toggle: press F
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.F then
            autoFarmEnabled = not autoFarmEnabled
            notify("Auto-farm toggled: " .. (autoFarmEnabled and "ON" or "OFF"), true)
            -- Update button appearance
            button.BackgroundColor3 = autoFarmEnabled and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
            button.Text = autoFarmEnabled and "AutoFarm: ON" or "AutoFarm: OFF"
        end
    end
end)

-- Mobile / GUI toggle button
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoFarmToggleGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 160, 0, 60)
frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 2
frame.BorderColor3 = Color3.fromRGB(100, 100, 100)
frame.Parent = screenGui

local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 140, 0, 40)
button.Position = UDim2.new(0.5, -70, 0.5, -20)
button.BackgroundColor3 = autoFarmEnabled and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
button.TextColor3 = Color3.fromRGB(255, 255, 255)
button.Text = autoFarmEnabled and "AutoFarm: ON" or "AutoFarm: OFF"
button.TextScaled = true
button.Font = Enum.Font.SourceSansBold
button.Parent = frame

button.MouseButton1Click:Connect(function()
    autoFarmEnabled = not autoFarmEnabled
    button.BackgroundColor3 = autoFarmEnabled and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
    button.Text = autoFarmEnabled and "AutoFarm: ON" or "AutoFarm: OFF"
    notify("Auto-farm toggled: " .. (autoFarmEnabled and "ON" or "OFF"), true)
end)

-- Handle character respawn
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = newChar:WaitForChild("Humanoid")
    hrp = newChar:WaitForChild("HumanoidRootPart")
    notify("Character respawned, auto-farm resuming.", true)
end)

-- Move horizontally high above map
local function moveHighTo(targetPos)
    if not character or not humanoid or humanoid.Health <= 0 then return false end
    local startPos = hrp.Position
    local startHigh = Vector3.new(startPos.X, HIGH_ALTITUDE, startPos.Z)
    local targetHigh = Vector3.new(targetPos.X, HIGH_ALTITUDE, targetPos.Z)
    local direction = (targetHigh - startHigh).Unit
    local distance = (targetHigh - startHigh).Magnitude
    local steps = math.floor(distance / HORIZ_STEP)
    for i = 1, steps do
        if not autoFarmEnabled or humanoid.Health <= 0 then return false end
        local stepPos = startHigh + direction * (i * HORIZ_STEP)
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
    local targetY = targetPos.Y + CLICK_OFFSET
    local startTime = tick()
    while hrp.Position.Y > targetY do
        if not autoFarmEnabled or humanoid.Health <= 0 then return false end
        if tick() - startTime > TARGET_TIMEOUT then
            notify("Timed out descending to target.", false)
            return false
        end
        hrp.CFrame = CFrame.new(hrp.Position.X, math.max(hrp.Position.Y - VERT_STEP, targetY), hrp.Position.Z)
        RunService.Heartbeat:Wait()
    end
    return true
end

-- Click target safely with retries
local function clickTarget(target)
    if not target or not target:IsA("BasePart") or not character or not humanoid or humanoid.Health <= 0 then return end
    local lastClick = barrelCooldowns[target] or 0
    if tick() - lastClick < COOLDOWN then return end

    local targetPos = target.Position

    -- Move high
    if not moveHighTo(targetPos) then return end

    -- Descend
    if not descendToTarget(targetPos) then return end

    -- Attempt clicks
    local clickDetector = target:FindFirstChildOfClass("ClickDetector")
    if clickDetector then
        for i = 1, CLICK_RETRIES do
            if not autoFarmEnabled or humanoid.Health <= 0 then return end
            pcall(function()
                fireclickdetector(clickDetector, 0)
            end)
            RunService.Heartbeat:Wait()
        end
        barrelCooldowns[target] = tick()
        notify("Clicked barrel at " .. tostring(targetPos), true)
    else
        notify("No ClickDetector found on barrel.", false)
    end
end

-- Auto-farm function in a coroutine
local function autoFarm()
    while true do
        if autoFarmEnabled and character and humanoid and humanoid.Health > 0 then
            for _, barrel in ipairs(BarrelsFolder:GetChildren()) do
                if not autoFarmEnabled or humanoid.Health <= 0 then break end
                clickTarget(barrel)
            end
        end
        RunService.Heartbeat:Wait()
    end
end

-- Start auto-farm
coroutine.wrap(autoFarm)()
notify("Auto-farm script started. Press F or click button to toggle.", true)
