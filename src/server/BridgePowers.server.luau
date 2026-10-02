-- BridgePowers (server)
-- The three buttons under the glass bridge progress bar (Robux, see Config.Products):
--  * Skip to End - teleports you to the end of the bridge, in front of the finish chest
--  * Show Path   - shows you (only you) the safe tile of every row for a few minutes
--  * Kill All    - eliminates everyone else currently standing on the bridge
-- Everything is checked here, so the buttons can't be used without paying.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameKit = ReplicatedStorage:WaitForChild("GameKit")
local Config = require(GameKit:WaitForChild("Config"))
local Net = require(GameKit:WaitForChild("Net"))
local BridgeState = require(script.Parent:WaitForChild("BridgeState"))
local Purchases = require(script.Parent:WaitForChild("Purchases"))

local remote = Net.event("BridgePowers")
local busy: { [Player]: boolean } = {}

BridgeState.waitReady()

-- the spot in front of the finish chest (the same end point the progress bar uses)
local chest = workspace:WaitForChild("everything in finish area"):WaitForChild("finish line modals")
	:WaitForChild("finish chest"):WaitForChild("Chest") :: BasePart
local function endPosition(): Vector3
	local above = Vector3.new(chest.Position.X, chest.Position.Y + 25, chest.Position.Z + 12)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(above, Vector3.new(0, -60, 0), params)
	if hit then
		return hit.Position + Vector3.new(0, 3.5, 0)
	end
	return Vector3.new(chest.Position.X, chest.Position.Y + 3, chest.Position.Z + 12)
end

local function alive(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and root and humanoid.Health > 0 then
		return humanoid, root
	end
	return nil, nil
end

-- players Kill All would hit: everyone else alive and standing on the bridge
local function victimsOf(buyer: Player): { Player }
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= buyer and not p:GetAttribute("InAFK") then
			local _, root = alive(p)
			local progress = p:GetAttribute("BridgeProgress") or 0
			if root and progress > 0 and progress < 0.995 and BridgeState.isOnBridge(root.Position) then
				table.insert(list, p)
			end
		end
	end
	return list
end

local function canAct(player: Player): boolean
	local humanoid = alive(player)
	return humanoid ~= nil and not player:GetAttribute("InAFK")
end

local actions = {}

actions.SkipToEnd = {
	check = canAct,
	use = function(player: Player): boolean
		local humanoid, root = alive(player)
		if not humanoid or not root then
			return false
		end
		local position = endPosition()
		pcall(function()
			player:RequestStreamAroundAsync(position, 3)
		end)
		humanoid:UnequipTools()
		for _, name in ipairs({ "FlightSpin", "FlightPower", "FlightHold" }) do
			local f = root:FindFirstChild(name)
			if f then
				f:Destroy()
			end
		end
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.CFrame = CFrame.lookAt(position, position + Vector3.new(0, 0, -1))
		BridgeState.clearProgress(player)
		remote:FireAllClients("Teleported", player, position)
		return true
	end,
}

actions.ShowPath = {
	check = function(player: Player): boolean
		return player.Parent ~= nil
	end,
	use = function(player: Player): boolean
		remote:FireClient(player, "ShowPath", BridgeState.safeTiles, Config.BridgePowers.ShowPathSeconds)
		return true
	end,
}

actions.KillAll = {
	check = function(player: Player): boolean
		return #victimsOf(player) > 0
	end,
	use = function(player: Player): boolean
		local victims = victimsOf(player)
		if #victims == 0 then
			return false
		end
		local positions = {}
		for _, victim in ipairs(victims) do
			local humanoid, root = alive(victim)
			if humanoid and root then
				table.insert(positions, root.Position)
				humanoid.Health = 0
			end
		end
		remote:FireAllClients("KillAll", player, positions, #victims)
		return true
	end,
}

remote.OnServerEvent:Connect(function(player, action)
	local entry = type(action) == "string" and actions[action]
	if not entry or busy[player] then
		return
	end
	busy[player] = true
	local status = Purchases.useOrBuy(player, action, entry.check, entry.use)
	remote:FireClient(player, "Status", action, status)
	task.wait(1)
	busy[player] = nil
end)

Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
end)
