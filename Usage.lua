-- Universal Roblox Aimbot + ESP + Hitbox Expander Script (Client-Side, for Testing Purposes)
-- Features: Silent Aimbot (FOV-based, wallcheck optional), ESP Boxes (through walls), Hitbox Expander (client-side visual/size tweak).
-- Toggle Aimbot with 'Q', ESP with 'E'. Adjust config below.
-- Works on most FPS/Combat games with default R6/R15 characters. Use at own risk - against Roblox TOS.
-- Inspired by common open-source scripts like AirHub/Exunys.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Config
local AimbotEnabled = false
local ESPEnabled = true
local TeamCheck = true  -- Ignore teammates
local WallCheck = true  -- Don't aim through walls
local AimPart = "Head"  -- "Head", "HumanoidRootPart", "Torso"
local FOV = 300  -- Field of View radius for aimbot
local Smoothness = 0.2  -- 0 = instant, 1 = very smooth
local HitboxSize = Vector3.new(10, 10, 10)  -- Expanded hitbox size (visual/client-side)
local HitboxTransparency = 0.7  -- For ESP hitbox
local ESPColor = Color3.fromRGB(255, 0, 0)  -- Red for enemies
local FOVCircle = Drawing.new("Circle")  -- Visual FOV

FOVCircle.Radius = FOV
FOVCircle.Thickness = 1
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Visible = false
FOVCircle.Position = Vector2.new(Mouse.X, Mouse.Y + 36)  -- GUI inset

-- ESP table
local ESPBoxes = {}

-- Function to check if player is valid target
local function isValidTarget(player)
    if player == LocalPlayer then return false end
    if TeamCheck and player.Team == LocalPlayer.Team then return false end
    if not player.Character or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then return false end
    return true
end

-- Function to get screen position
local function getScreenPos(part)
    local vector, onScreen = Camera:WorldToViewportPoint(part.Position)
    return Vector2.new(vector.X, vector.Y), onScreen
end

-- Function to check wall between
local function wallCheck(targetPos)
    local ray = Ray.new(Camera.CFrame.Position, (targetPos - Camera.CFrame.Position).Unit * 5000)
    local hit, pos = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character, Camera})
    return (pos - targetPos).Magnitude < 1  -- If hit is near target, visible
end

-- Find nearest target within FOV
local function getNearestTarget()
    local nearest = nil
    local minDist = FOV
    local mousePos = Vector2.new(Mouse.X, Mouse.Y + 36)
    
    for _, player in ipairs(Players:GetPlayers()) do
        if isValidTarget(player) then
            local char = player.Character
            local part = char:FindFirstChild(AimPart) or char:FindFirstChild("HumanoidRootPart")
            if part then
                local screenPos, onScreen = getScreenPos(part)
                if onScreen then
                    local dist = (screenPos - mousePos).Magnitude
                    if dist < minDist then
                        if not WallCheck or wallCheck(part.Position) then
                            minDist = dist
                            nearest = part
                        end
                    end
                end
            end
        end
    end
    return nearest
end

-- Aimbot function (smooth camera tween)
local function aimAt(target)
    if not target then return end
    local targetCFrame = CFrame.new(Camera.CFrame.Position, target.Position)
    local tweenInfo = TweenInfo.new(Smoothness, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(Camera, tweenInfo, {CFrame = targetCFrame})
    tween:Play()
end

-- ESP function
local function createESP(player)
    if not isValidTarget(player) or ESPBoxes[player] then return end
    local char = player.Character
    
    -- ESP Box
    local box = Drawing.new("Square")
    box.Thickness = 2
    box.Color = ESPColor
    box.Filled = false
    box.Transparency = 1
    
    -- Hitbox expander (client-side visual)
    local head = char:FindFirstChild("Head")
    if head then
        head.Size = HitboxSize
        head.Transparency = HitboxTransparency
        head.CanCollide = false  -- Optional
    end
    
    ESPBoxes[player] = {box = box, char = char}
end

local function updateESP()
    for player, data in pairs(ESPBoxes) do
        if isValidTarget(player) and data.char then
            local hrp = data.char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local vector, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                data.box.Visible = onScreen and ESPEnabled
                if onScreen then
                    local headPos = Camera:WorldToViewportPoint(data.char.Head.Position)
                    local legPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                    data.box.Size = Vector2.new(2000 / vector.Z, headPos.Y - legPos.Y)
                    data.box.Position = Vector2.new(vector.X - data.box.Size.X / 2, headPos.Y)
                end
            else
                data.box.Visible = false
            end
        else
            data.box:Remove()
            ESPBoxes[player] = nil
        end
    end
end

-- Add ESP for new players
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        createESP(player)
    end)
end)

-- Initial ESP setup
for _, player in ipairs(Players:GetPlayers()) do
    if player.Character then
        createESP(player)
    end
    player.CharacterAdded:Connect(function()
        createESP(player)
    end)
end

-- Toggles
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Q then
        AimbotEnabled = not AimbotEnabled
        FOVCircle.Visible = AimbotEnabled
        print("Aimbot:", AimbotEnabled and "ON" or "OFF")
    elseif input.KeyCode == Enum.KeyCode.E then
        ESPEnabled = not ESPEnabled
        print("ESP:", ESPEnabled and "ON" or "OFF")
    end
end)

-- Main loop
RunService.RenderStepped:Connect(function()
    updateESP()
    FOVCircle.Position = Vector2.new(Mouse.X, Mouse.Y + 36)
    
    if AimbotEnabled then
        local target = getNearestTarget()
        if target then
            aimAt(target)
        end
    end
end)

print("Universal Aimbot + ESP + Hitbox Loaded! Q to toggle Aimbot, E for ESP.")
