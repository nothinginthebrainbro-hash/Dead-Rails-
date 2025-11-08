-- Dead Rails Ultimate Bond Collector Script v5 (Combined Edition - November 2025)
-- Combines all previous versions: Tweening + Pathfinding, enhanced detection, server hop, auto-end, lobby handler, remote collection, humanization.
-- Bond variants: "Bond", "TreasuryBond", "Bonus", "TreasuryBonus", "CollectibleBond", "BondCalculated", any with "bond" in name.
-- Speed: 45-55 studs/sec (variable for undetectability), proximity 5 studs.
-- Searches Workspace.RuntimeItems > Bonds or full descendants fallback.
-- Collects via ActivateObjectClient:FireServer(bond) or touch.
-- Auto self-kill after collection, hop if no bonds >20s, anti-AFK.
-- Lobby auto-join if in lobby (PlaceId 116495829188952), game PlaceId 70876832253163.
-- Fallbacks: Direct position if path fails, Promise remote handling.
-- Execute as LocalScript in executor.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Game elements
local RuntimeItems = Workspace:FindFirstChild("RuntimeItems")
local Packages = ReplicatedStorage:FindFirstChild("Packages")
local ActivateObjectClient = Packages and Packages:FindFirstChild("ActivateObjectClient")
local EndDecision = ReplicatedStorage:FindFirstChild("EndDecision")
local Promise = Packages and Packages:FindFirstChild("Promise")

-- Config
local BOND_NAMES = {"Bond", "TreasuryBond", "Bonus", "TreasuryBonus", "CollectibleBond", "BondCalculated"}
local SPEED_MIN = 45
local SPEED_MAX = 55
local PROXIMITY = 5
local SCAN_DELAY = 0.3
local OFFSET_RANDOM = 3
local PAUSE_MIN = 0.2
local PAUSE_MAX = 0.8
local HOP_TIMEOUT = 20
local FALLBACK_DIRECT = true
local LOBBY_PLACE_ID = 116495829188952
local GAME_PLACE_ID = 70876832253163
local NO_BOND_TIMEOUT = 30
local SCAN_INTERVAL = 0.5
local RANDOM_OFFSET = 2
local SCAN_STEPS = 10

-- Remote fire with Promise fallback
local function fireRemote(remote, ...)
    pcall(function()
        if Promise and remote:IsA("RemoteFunction") then
            remote:InvokeServer(...)
        else
            remote:FireServer(...)
        end
    end)
end

-- Update character
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = newChar:WaitForChild("Humanoid")
    rootPart = newChar:WaitForChild("HumanoidRootPart")
end)

-- Enhanced bond scan with variants
local function findBonds()
    local bonds = {}
    local searchFolder = RuntimeItems or Workspace
    local searchMethod = if RuntimeItems then searchFolder.GetChildren else game.Workspace.GetDescendants
    local descendants = searchMethod(searchFolder)
    for _, obj in ipairs(descendants) do
        if (obj:IsA("BasePart") or obj:IsA("Model")) and obj.Parent then
            local name = obj.Name
            if table.find(BOND_NAMES, name) or string.find(name:lower(), "bond") then
                table.insert(bonds, obj)
            end
        end
    end
    -- Sort by distance
    table.sort(bonds, function(a, b)
        local posA = (a:IsA("Model") and a:FindFirstChild("Part") and a.Part.Position) or a.Position
        local posB = (b:IsA("Model") and b:FindFirstChild("Part") and b.Part.Position) or b.Position
        return (rootPart.Position - posA).Magnitude < (rootPart.Position - posB).Magnitude
    end)
    return bonds
end

-- Humanized tween
local function tweenToPosition(targetPos)
    local distance = (rootPart.Position - targetPos).Magnitude
    local speed = math.random(SPEED_MIN, SPEED_MAX)
    local time = distance / speed
    targetPos = targetPos + Vector3.new(
        math.random(-RANDOM_OFFSET, RANDOM_OFFSET),
        math.random(0, 1),
        math.random(-RANDOM_OFFSET, RANDOM_OFFSET)
    )
    local tweenInfo = TweenInfo.new(
        math.max(time, 0.05),
        Enum.EasingStyle.Quint,
        Enum.EasingDirection.InOut
    )
    local tween = TweenService:Create(rootPart, tweenInfo, {CFrame = CFrame.new(targetPos)})
    tween:Play()
    tween.Completed:Wait()
end

-- Pathfinding move with humanization
local function moveToTarget(targetPos)
    local path = PathfindingService:CreatePath({
        AgentRadius = 2.5,
        AgentHeight = 5.5,
        AgentCanJump = true,
        WaypointSpacing = math.random(2, 6),
        Costs = {Water = 100, Lava = 100}
    })
    local success = pcall(function()
        path:ComputeAsync(rootPart.Position, targetPos)
    end)
    if success and path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        for i, waypoint in ipairs(waypoints) do
            if waypoint.Action == Enum.PathWaypointAction.Jump then
                humanoid.Jump = true
                wait(0.1 + math.random() * 0.2)
            end
            if math.random(1, 4) == 1 then
                wait(math.random(0.05, 0.3))
            end
            tweenToPosition(waypoint.Position)
            humanoid:MoveTo(waypoint.Position)
        end
    else
        if FALLBACK_DIRECT then
            rootPart.CFrame = CFrame.new(targetPos + Vector3.new(0, 5, 0))
            wait(0.2)
        else
            tweenToPosition(targetPos)
        end
    end
end

-- Collect function
local function collectBond(bond)
    local pos = (bond:IsA("Model") and bond:FindFirstChild("Part") and bond.Part.Position) or bond.Position
    if (rootPart.Position - pos).Magnitude <= PROXIMITY then
        if ActivateObjectClient then
            fireRemote(ActivateObjectClient, bond)
        end
        print("Collected " .. bond.Name)
        return true
    end
    return false
end

-- Self-damage end round
local function selfDamageAndEnd()
    pcall(function()
        humanoid.Health = 0
        if EndDecision then
            fireRemote(EndDecision, "EndRound")
        end
        print("Round ended via self-damage")
    end)
end

-- Server hop
local function serverHop()
    print("Hopping to new server...")
    local servers = {}
    local cursor = ""
    repeat
        local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
        if cursor ~= "" then url = url .. "&cursor=" .. cursor end
        local success, response = pcall(HttpService.JSONDecode, HttpService, game:HttpGet(url))
        if success then
            for _, server in ipairs(response.data) do
                table.insert(servers, server)
            end
            cursor = response.nextPageCursor or ""
        else
            break
        end
    until cursor == ""
    if #servers > 1 then
        local randServer
        repeat
            randServer = servers[math.random(1, #servers)]
        until randServer.id ~= game.JobId
        TeleportService:TeleportToPlaceInstance(game.PlaceId, randServer.id, player)
    end
end

-- Lobby auto-join
if game.PlaceId == LOBBY_PLACE_ID then
    local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
    local CreatePartyClient = Shared:WaitForChild("CreatePartyClient", 10)
    task.spawn(function()
        while true do
            pcall(function()
                for _, zone in ipairs(Workspace:WaitForChild("TeleportZones"):GetChildren()) do
                    if zone.Name == "TeleportZone" and zone:FindFirstChild("BillboardGui") and zone.BillboardGui:FindFirstChild("StateLabel") and zone.BillboardGui.StateLabel.Text:find("Waiting") then
                        rootPart.CFrame = zone:FindFirstChild("ZoneContainer").CFrame
                        wait(1)
                        if CreatePartyClient then
                            CreatePartyClient:FireServer({maxPlayers = 1})
                        end
                        break
                    end
                end
            end)
            wait(2)
        end
    end)
end

-- Main loop
local lastBondTime = tick()
task.spawn(function()
    while true do
        pcall(function()
            local bonds = findBonds()
            if #bonds > 0 then
                lastBondTime = tick()
                for _, bond in ipairs(bonds) do
                    if bond and bond.Parent then
                        local targetPos = ((bond:IsA("Model") and bond:FindFirstChild("Part") and bond.Part.Position) or bond.Position) + Vector3.new(0, 4, 0)
                        print("Moving to " .. bond.Name .. " at", targetPos)
                        moveToTarget(targetPos)
                        collectBond(bond)
                        wait(math.random() * (PAUSE_MAX - PAUSE_MIN) + PAUSE_MIN)
                    end
                end
                if #findBonds() == 0 then
                    selfDamageAndEnd()
                    wait(5)
                end
            else
                print("No bonds found, scanning...")
                if tick() - lastBondTime > HOP_TIMEOUT then
                    serverHop()
                end
                wait(SCAN_INTERVAL)
            end
        end)
        wait(0.05)
    end
end)

-- Anti-AFK
task.spawn(function()
    while true do
        wait(math.random(30, 60))
        humanoid:Move(Vector3.new(math.random(-1,1), 0, math.random(-1,1)), true)
        wait(0.5)
    end
end)

print("Ultimate Bond Collector v5 loaded! All features combined. Speed: " .. SPEED_MIN .. "-" .. SPEED_MAX .. " studs/sec. Detecting variants...")
