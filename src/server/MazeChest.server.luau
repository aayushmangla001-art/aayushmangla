-- MazeChest (server)
-- Hold E at the chest at the maze exit to get $500. Then that player has to wait
-- 5 minutes before claiming again. Each player has their own timer, and it's saved,
-- so leaving and rejoining doesn't reset it.
-- Reward / cooldown are attributes on the chest (Reward, CooldownSeconds).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Money = require(script.Parent:WaitForChild("Money"))

local chest = workspace:WaitForChild("Maze Reward Chest")
local prompt = chest:WaitForChild("ClaimPrompt")
local REWARD = chest:GetAttribute("Reward") or 500
local COOLDOWN = chest:GetAttribute("CooldownSeconds") or 300

local remote = ReplicatedStorage:FindFirstChild("MazeChestRemote") or Instance.new("RemoteEvent")
remote.Name = "MazeChestRemote"
remote.Parent = ReplicatedStorage

local store = DataStoreService:GetDataStore("MazeChest_v1")
local readyAt = {} -- [player] = unix time when they can claim again
local busy = {}

-- after claiming, the player is sent back to the spawn plate
local spawnPad = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
local function sendToSpawn(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 or not spawnPad then return end
	-- the same flash the portals use (PortalFX listens for it)
	local portalRemote = ReplicatedStorage:FindFirstChild("PortalRemote")
	if portalRemote then portalRemote:FireClient(player, "Fade", Color3.fromRGB(255, 220, 90)) end
	pcall(function() player:RequestStreamAroundAsync(spawnPad.Position, 3) end)
	task.wait(0.15)
	if not root.Parent then return end
	-- put a flying carpet away first so its forces don't pull the player back
	humanoid:UnequipTools()
	for _, name in ipairs({ "FlightSpin", "FlightPower", "FlightHold" }) do
		local f = root:FindFirstChild(name)
		if f then f:Destroy() end
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = spawnPad.CFrame * CFrame.new(math.random(-4, 4), spawnPad.Size.Y / 2 + 4, math.random(-4, 4))
end

local function setReady(player, t)
	readyAt[player] = t
	player:SetAttribute("MazeChestReadyAt", t) -- the sign on each player's screen reads this
end

local function onJoin(player)
	setReady(player, 0)
	local ok, saved = pcall(function() return store:GetAsync("Ready_" .. player.UserId) end)
	if ok and tonumber(saved) and player.Parent then
		setReady(player, math.max(readyAt[player] or 0, tonumber(saved)))
	end
end
Players.PlayerAdded:Connect(onJoin)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onJoin, p) end
Players.PlayerRemoving:Connect(function(player)
	readyAt[player] = nil
	busy[player] = nil
end)

prompt.Triggered:Connect(function(player)
	if busy[player] then return end
	busy[player] = true
	local now = os.time()
	local ready = readyAt[player] or 0
	if now < ready then
		remote:FireClient(player, "Wait", ready)
	else
		Money.Add(player, REWARD)
		local nextTime = now + COOLDOWN
		setReady(player, nextTime)
		remote:FireClient(player, "Claimed", REWARD)
		task.spawn(function()
			pcall(function() store:SetAsync("Ready_" .. player.UserId, nextTime) end)
		end)
		task.wait(1.5) -- let them see the confetti, then back to spawn
		sendToSpawn(player)
	end
	task.wait(0.5)
	busy[player] = nil
end)
