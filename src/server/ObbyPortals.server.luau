-- ObbyPortals (server)
-- Portals (Workspace > Obby Portals): touching a portal's glowing Gate sends you to
-- the spot stored on it (TeleportPos / TeleportLook).
--  * EASY / MEDIUM / HARD portals start a run of that obby.
--  * While you're on a run, dying or falling (invisible catcher under each obby)
--    puts you back at the start of THAT obby, not the spawn.
--  * The small chest at the end pays its reward and sends you back to the obby hub.
--  * Leaving through an "OBBY CHOOSER" / "BACK" portal ends the run.
--  * Anti-farm: if you fly on the magic carpet during a run, the chest won't pay.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Money = require(script.Parent:WaitForChild("Money"))

local remote = ReplicatedStorage:FindFirstChild("PortalRemote") or Instance.new("RemoteEvent")
remote.Name = "PortalRemote"
remote.Parent = ReplicatedStorage

local folder = workspace:WaitForChild("Obby Portals")
local busy = {}
local run = {} -- [player] = { obby, startPos, startLook, flew }

local function teleport(player, pos, look, color)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return end
	remote:FireClient(player, "Fade", color)
	pcall(function() player:RequestStreamAroundAsync(pos, 3) end)
	task.wait(0.15)
	if not root.Parent then return end
	humanoid:UnequipTools()
	for _, name in ipairs({ "FlightSpin", "FlightPower", "FlightHold" }) do
		local f = root:FindFirstChild(name)
		if f then f:Destroy() end
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = CFrame.lookAt(pos, pos + Vector3.new(look.X, 0, look.Z))
end

local function playerFromHit(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	return character and Players:GetPlayerFromCharacter(character)
end

-- portals
for _, gate in ipairs(folder:GetDescendants()) do
	if gate:IsA("BasePart") and gate:GetAttribute("TeleportPos") then
		gate.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if not player or busy[player] then return end
			busy[player] = true
			local pos, look = gate:GetAttribute("TeleportPos"), gate:GetAttribute("TeleportLook")
			if gate:GetAttribute("PortalKind") == "Obby" then
				run[player] = { obby = gate:GetAttribute("PortalName"), startPos = pos, startLook = look, flew = false }
			else
				run[player] = nil
			end
			teleport(player, pos, look, gate.Color)
			task.wait(1.5)
			busy[player] = nil
		end)
	end
end

-- end-of-obby chests
for _, chest in ipairs(folder:GetChildren()) do
	if chest:IsA("BasePart") and chest:GetAttribute("ObbyReward") then
		local reward = chest:GetAttribute("ObbyReward")
		local name = chest:GetAttribute("ObbyName")
		chest.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if not player or busy[player] then return end
			busy[player] = true
			local r = run[player]
			if r and r.obby == name and not r.flew then
				run[player] = nil
				Money.Add(player, reward)
				remote:FireClient(player, "Reward", name, reward, chest)
				task.wait(1.6)
				teleport(player, chest:GetAttribute("ReturnPos"), chest:GetAttribute("ReturnLook"), chest.Color)
			elseif r and r.obby == name and r.flew then
				remote:FireClient(player, "NoReward", name, "flew")
			else
				remote:FireClient(player, "NoReward", name, "portal")
			end
			task.wait(1.5)
			busy[player] = nil
		end)
	end
end

-- falling under an obby: back to its start (no dying, no waiting)
for _, catcher in ipairs(folder:GetChildren()) do
	if catcher:IsA("BasePart") and catcher:GetAttribute("CatchObby") then
		catcher.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if not player or busy[player] then return end
			busy[player] = true
			local r = run[player]
			if r then
				r.flew = false -- fresh attempt
				teleport(player, r.startPos, r.startLook, Color3.new(1, 1, 1))
			else
				local pos = catcher:GetAttribute("StartPos")
				teleport(player, pos, Vector3.new(-1, 0, 0), Color3.new(1, 1, 1))
			end
			task.wait(1)
			busy[player] = nil
		end)
	end
end

-- watch for carpet flying during a run
task.spawn(function()
	while true do
		for player, r in pairs(run) do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and root:FindFirstChild("FlightHold") then r.flew = true end
		end
		task.wait(0.25)
	end
end)

-- dying during a run: respawn at the start of that obby
local function setup(player)
	player.CharacterAdded:Connect(function(character)
		local r = run[player]
		if not r then return end
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root then return end
		task.wait(0.1)
		r.flew = false
		pcall(function() player:RequestStreamAroundAsync(r.startPos, 3) end)
		root.CFrame = CFrame.lookAt(r.startPos, r.startPos + Vector3.new(r.startLook.X, 0, r.startLook.Z))
	end)
end
Players.PlayerAdded:Connect(setup)
for _, p in ipairs(Players:GetPlayers()) do setup(p) end
Players.PlayerRemoving:Connect(function(player)
	run[player] = nil
	busy[player] = nil
end)
