-- Universal Roblox Aimbot + ESP + Hitbox Script (Updated - November 2025)
-- Features: Instant Aimbot (through walls, no smooth), Transparent Red Hitbox ESP (using Highlight for through walls).
-- Toggle Aimbot 'Q', ESP 'E'. Works on most FPS games. Use at own risk - not TOS violation.
-- Aimbot now 100% lock-on: Instant, ignores walls, large FOV.
-- ESP: Transparent red fill on characters (hitbox style, visible through walls).

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
local WallCheck = false  -- Now false for through walls aimbot
local AimPart = "Head"  -- "Head", "HumanoidRootPart", "Torso"
local FOV = 1000  -- Large FOV for better lock-on
local Smoothness = 0  -- 0 for instant aim (100% lock)
local ESPFillColor = Color3.fromRGB(255, 0, 0)  -- Red
local ESPFillTransparency = 0.7  -- Transparent
local ESPOutlineColor = Color3.fromRGB(255, 255, 255)  -- White outline
local ESPOutlineTransparency = 0  -- Solid outline

-- ESP table (using Highlights)
local ESPHighlights = {}

-- Function to check valid target
local function isValidTarget(player)
    if player == LocalPlayer then return false end
    if TeamCheck and player.Team == LocalPlayer.Team then return false end
    if not player.Character or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then return false end
    return true
end

-- Get screen position
local function getScreenPos(part)
    local vector, onScreen = Camera:WorldToViewportPoint(part.Position)
    return Vector2.new(vector.X, vector.Y), onScreen
end

-- Wall check (raycast)
local function wallCheck(targetPos)
    local ray = Ray.new(Camera.CFrame.Position, (targetPos - Camera.CFrame.Position).Unit * 5000)
    local hit, pos = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character, Camera})
    return (pos - targetPos).Magnitude < 1
end

-- Get nearest target
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

-- Aim function (instant if Smoothness=0)
local function aimAt(target)
    if not target then return end
    local targetCFrame = CFrame.new(Camera.CFrame.Position, target.Position)
    if Smoothness == 0 then
        Camera.CFrame = targetCFrame  -- Instant
    else
        local tweenInfo = TweenInfo.new(Smoothness, Enum.EasingStyle.Linear)
        local tween = TweenService:Create(Camera, tweenInfo, {CFrame = targetCFrame})
        tween:Play()
    end
end

-- Create ESP Highlight
local function createESP(player)
    if not isValidTarget(player) or ESPHighlights[player] then return end
    local char = player.Character
    local highlight = Instance.new("Highlight")
    highlight.Parent = char
    highlight.FillColor = ESPFillColor
    highlight.FillTransparency = ESPFillTransparency
    highlight.OutlineColor = ESPOutlineColor
    highlight.OutlineTransparency = ESPOutlineTransparency
    highlight.Enabled = ESPEnabled
    ESPHighlights[player] = highlight
end

-- Update ESP (toggle enabled)
local function updateESP()
    for player, highlight in pairs(ESPHighlights) do
        if isValidTarget(player) and player.Character then
            highlight.Enabled = ESPEnabled
            highlight.Parent = player.Character
        else
            if highlight then highlight:Destroy() end
            ESPHighlights[player] = nil
        end
    end
end

-- Add ESP for new players/characters
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(char)
        createESP(player)
    end)
end)

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
        print("Aimbot:", AimbotEnabled and "ON" or "OFF")
    elseif input.KeyCode == Enum.KeyCode.E then
        ESPEnabled = not ESPEnabled
        print("ESP:", ESPEnabled and "ON" or "OFF")
        updateESP()  -- Immediate update
    end
end)

-- Main loop
RunService.RenderStepped:Connect(function()
    updateESP()
    if AimbotEnabled then
        local target = getNearestTarget()
        if target then
            aimAt(target)
        end
    end
end)

print("Updated Aimbot + ESP Loaded! Instant aimbot (through walls). Transparent red hitbox ESP. Q: Aimbot, E: ESP.")
