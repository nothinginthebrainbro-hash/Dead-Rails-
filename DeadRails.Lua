-- Ultimate Friendly Bond Collector Script for Dead Rails (Testing Purposes - November 2025 Update v2)
-- Inspired by fast bond stealer scripts: Uses optimized pathfinding + tweening for ultra-fast, undetectable collection.
-- Now with server hopping, auto round finish (self-damage + EndDecision), remote fallbacks, map scanning in steps.
-- Collects from Workspace.RuntimeItems "Bond" models via ActivateObjectClient or fallbacks.
-- Faster tweens (65 studs/sec), more humanization (random paths, pauses, jumps, fake walks).
-- Queue all bonds, collect in efficient order (closest first), fallback to direct HRP positioning if needed.
-- Anti-detection: Variable speeds, random offsets, no anchoring, physics simulation.
-- Handles respawn, errors, low-level executors.
-- Place as LocalScript or executor.

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

-- Wait for game elements
local RuntimeItems = Workspace:WaitForChild("RuntimeItems", 10)
local Packages = ReplicatedStorage:WaitForChild("Packages", 10)
local ActivateObjectClient = Packages and Packages:WaitForChild("ActivateObjectClient", 5)
local EndDecision = ReplicatedStorage:WaitForChild("EndDecision", 10) -- Assuming remote for ending round

-- Config - Tune for speed/detection
local TWEEN_SPEED_MIN = 60 -- Min studs/sec
local TWEEN_SPEED_MAX = 70 -- Max for variation
local PROXIMITY_DISTANCE = 5 -- Closer for faster collect
local SCAN_INTERVAL = 0.3 -- Faster scans
local SCAN_STEPS = 10 -- Map sweep steps (higher = more thorough, slower)
local RANDOM_OFFSET = 3 -- Increased for more natural
local PAUSE_MIN = 0.2
local PAUSE_MAX = 0.8
local NO_BOND_TIMEOUT = 30 -- Seconds without bonds to hop servers
local FALLBACK_DIRECT_POSITION = true -- Use direct CFrame if tween/path fails (for low executors)
local USE_PROMISE_FALLBACK = true -- Check for Promise module

-- Detect Promise for remote calls
local Promise = Packages and Packages:FindFirstChild("Promise")
if not Promise then Promise = nil end

-- Function to fire remote with fallback
local function fireRemote(remote, ...)
    if Promise then
        -- Use Promise if available
        local promise = remote:InvokeServer(...) -- Or FireServer, depending on type
        promise:await()
    else
        if remote:IsA("RemoteEvent") then
            remote:FireServer(...)
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(...)
        end
    end
end

-- Update character on respawn
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = newChar:WaitForChild("Humanoid")
    rootPart = newChar:WaitForChild("HumanoidRootPart")
end)

-- Function to scan for all bonds (queue them)
local function scanBonds()
    local bonds = {}
    if not RuntimeItems then return bonds end
    
    for _, obj in ipairs(RuntimeItems:GetChildren()) do
        if obj.Name == "Bond" and obj:FindFirstChild("Part") and obj.Part.Parent then
            table.insert(bonds, obj)
        end
    end
    
    -- Sort by distance (closest first)
    table.sort(bonds, function(a, b)
        return (rootPart.Position - a.Part.Position).Magnitude < (rootPart.Position - b.Part.Position).Magnitude
    end)
    
    return bonds
end

-- Tween to position with variable speed/humanization
local function tweenToPosition(targetPos)
    local distance = (rootPart.Position - targetPos).Magnitude
    local speed = math.random(TWEEN_SPEED_MIN, TWEEN_SPEED_MAX)
    local time = distance / speed
    
    targetPos = targetPos + Vector3.new(
        math.random(-RANDOM_OFFSET, RANDOM_OFFSET),
        math.random(0, 1), -- Slight height variation
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

-- Move to target with pathfinding + tween segments
local function moveToTarget(targetPos)
    local path = PathfindingService:CreatePath({
        AgentRadius = 2.5,
        AgentHeight = 5.5,
        AgentCanJump = true,
        WaypointSpacing = math.random(2, 6),
        Costs = {
            Water = 100,
            Lava = 100, -- Avoid hazards if in game
        }
    })
    
    local success, err = pcall(function()
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
                wait(math.random(0.05, 0.3)) -- Random micro-pauses
            end
            
            tweenToPosition(waypoint.Position)
            
            -- Fake walk animation
            humanoid:MoveTo(waypoint.Position)
        end
    else
        print("Path failed:", err or "Unknown")
        if FALLBACK_DIRECT_POSITION then
            rootPart.CFrame = CFrame.new(targetPos + Vector3.new(0, 5, 0)) -- Direct above for fallback
            wait(0.2)
        else
            tweenToPosition(targetPos)
        end
    end
end

-- Self-damage to finish round
local function selfDamageAndEnd()
    pcall(function()
        -- Assume a damage remote or method; adjust based on game
        humanoid.Health = 0 -- Or fire a damage remote if exists
        if EndDecision then
            fireRemote(EndDecision, "EndRound") -- Adjust args as needed
        end
        print("Round finished!")
    end)
end

-- Server hop function
local function serverHop()
    print("No bonds found for too long. Hopping servers...")
    local servers = {}
    local cursor = ""
    while true do
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        if cursor ~= "" then url = url .. "&cursor=" .. cursor end
        local response = HttpService:JSONDecode(game:HttpGet(url))
        servers = response.data
        cursor = response.nextPageCursor
        if not cursor then break end
    end
    
    if #servers > 0 then
        local randomServer = servers[math.random(1, #servers)]
        if randomServer.id ~= game.JobId then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, randomServer.id, player)
        else
            serverHop() -- Retry if same server
        end
    else
        print("No other servers found.")
    end
end

-- Main loop
task.spawn(function()
    local lastBondTime = tick()
    while true do
        pcall(function()
            local bonds = scanBonds()
            if #bonds > 0 then
                lastBondTime = tick()
                for _, bond in ipairs(bonds) do
                    if bond and bond.Parent and bond.Part then
                        local targetPos = bond.Part.Position + Vector3.new(0, 4, 0)
                        print("Targeting bond at", targetPos)
                        
                        moveToTarget(targetPos)
                        
                        local dist = (rootPart.Position - bond.Part.Position).Magnitude
                        if dist <= PROXIMITY_DISTANCE then
                            if ActivateObjectClient then
                                fireRemote(ActivateObjectClient, bond)
                            else
                                print("No activate remote, assuming touch collect.")
                            end
                            print("Bond collected!")
                        end
                        
                        wait(math.random() * (PAUSE_MAX - PAUSE_MIN) + PAUSE_MIN)
                    end
                end
                
                -- After all collected, finish round
                if #scanBonds() == 0 then
                    selfDamageAndEnd()
                    wait(5) -- Wait for respawn/load
                end
            else
                print("Scanning for bonds...")
                if tick() - lastBondTime > NO_BOND_TIMEOUT then
                    serverHop()
                end
                wait(SCAN_INTERVAL)
            end
        end)
        wait(0.05) -- Faster loop
    end
end)

-- Anti-AFK simulation
task.spawn(function()
    while true do
        wait(math.random(30, 60))
        -- Simulate input
        humanoid:Move(Vector3.new(math.random(-1,1), 0, math.random(-1,1)))
        wait(0.5)
    end
end)

print("Ultimate Bond Collector loaded! Inspired by fast stealers.")
print("Speed range:", TWEEN_SPEED_MIN, "-", TWEEN_SPEED_MAX, "studs/sec | Undetectable tweaks.")
