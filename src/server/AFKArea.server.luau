-- AFKArea (server)
-- Standing inside the AFK arena pays $5 every second.
-- Players inside can't touch each other, and players outside can't push in,
-- so nobody can be pushed out. Players inside get the attribute "InAFK" = true:
-- a slap tool added later should ignore anyone with InAFK.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local Money = require(script.Parent:WaitForChild("Money"))

local PAY = 5 -- per second
local CHECK_EVERY = 0.2

-- the inside of the arena = the floor's footprint, from the floor up to the ceiling
local arena = workspace:WaitForChild("afk arena")
local floor = arena:WaitForChild("AFK base")
local half = floor.Size / 2
local MIN = Vector3.new(floor.Position.X - half.X, floor.Position.Y + half.Y - 1, floor.Position.Z - half.Z)
local MAX = Vector3.new(floor.Position.X + half.X, floor.Position.Y + half.Y + 33, floor.Position.Z + half.Z)

local function inside(pos)
	return pos.X >= MIN.X and pos.X <= MAX.X and pos.Y >= MIN.Y and pos.Y <= MAX.Y and pos.Z >= MIN.Z and pos.Z <= MAX.Z
end

-- collision groups: everyone is "Players"; inside the arena you're "AFKPlayers",
-- which touches nobody (inside or outside) but still stands on the floor
pcall(function() PhysicsService:RegisterCollisionGroup("Players") end)
pcall(function() PhysicsService:RegisterCollisionGroup("AFKPlayers") end)
PhysicsService:CollisionGroupSetCollidable("AFKPlayers", "AFKPlayers", false)
PhysicsService:CollisionGroupSetCollidable("AFKPlayers", "Players", false)

local function setGroup(character, group)
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") then d.CollisionGroup = group end
	end
end

local function onCharacter(player, character)
	player:SetAttribute("InAFK", false)
	setGroup(character, "Players")
	-- accessories / tools that load later get the right group too
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = player:GetAttribute("InAFK") and "AFKPlayers" or "Players"
		end
	end)
end

local function setup(player)
	player:SetAttribute("InAFK", false)
	player:SetAttribute("AFKEarned", 0)
	player.CharacterAdded:Connect(function(c) onCharacter(player, c) end)
	if player.Character then onCharacter(player, player.Character) end
end
Players.PlayerAdded:Connect(setup)
for _, p in ipairs(Players:GetPlayers()) do setup(p) end

-- who is inside? (checked often so the no-push rule kicks in right at the door)
task.spawn(function()
	while true do
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local now = root ~= nil and humanoid ~= nil and humanoid.Health > 0 and inside(root.Position)
			if now ~= player:GetAttribute("InAFK") then
				player:SetAttribute("InAFK", now)
				if character then setGroup(character, now and "AFKPlayers" or "Players") end
				if not now then player:SetAttribute("AFKEarned", 0) end
			end
		end
		task.wait(CHECK_EVERY)
	end
end)

-- pay everyone inside once per second
while true do
	task.wait(1)
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("InAFK") then
			Money.Add(player, PAY)
			player:SetAttribute("AFKEarned", (player:GetAttribute("AFKEarned") or 0) + PAY)
		end
	end
end
