-- BridgeRevive (server)
-- When a player breaks a wrong glass tile or falls off the glass bridge, they're
-- offered a revive that puts them back on the last safe tile they reached.
--  * The first revive ever is free (saved, so rejoining doesn't reset it).
--  * After that a revive costs Robux (Config.Products.Revive).
--  * Only bridge failures give an offer. Other deaths (troll kills, Kill All,
--    resetting, obbies) never do.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameKit = ReplicatedStorage:WaitForChild("GameKit")
local Config = require(GameKit:WaitForChild("Config"))
local Net = require(GameKit:WaitForChild("Net"))
local BridgeState = require(script.Parent:WaitForChild("BridgeState"))
local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))
local Purchases = require(script.Parent:WaitForChild("Purchases"))

local remote = Net.event("BridgeRevive")

type Offer = { tile: BasePart, try: any, expires: number }
local offers: { [Player]: Offer } = {}
local busy: { [Player]: boolean } = {}

local function aliveCharacter(player: Player, waitSeconds: number): (Model?, BasePart?)
	local deadline = os.clock() + waitSeconds
	while player.Parent and os.clock() < deadline do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if character and humanoid and root and humanoid.Health > 0 then
			return character, root
		end
		task.wait(0.1)
	end
	return nil, nil
end

-- puts the player back on their last safe tile; true if it worked
local function revive(player: Player, offer: Offer): boolean
	if offers[player] ~= offer or not offer.tile.Parent then
		return false
	end
	offers[player] = nil
	-- if they died on a wrong tile, wait for them to respawn first
	local character, root = aliveCharacter(player, Players.RespawnTime + 5)
	if not character or not root then
		return false
	end
	task.wait(0.25) -- let the bridge script finish its respawn reset first
	if not root.Parent then
		return false
	end
	local tile = offer.tile
	local position = tile.Position + Vector3.new(0, tile.Size.Y / 2 + 3.5, 0)
	pcall(function()
		player:RequestStreamAroundAsync(position, 3)
	end)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:UnequipTools()
	end
	for _, name in ipairs({ "FlightSpin", "FlightPower", "FlightHold" }) do
		local f = root:FindFirstChild(name)
		if f then
			f:Destroy()
		end
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = CFrame.lookAt(position, position + Vector3.new(0, 0, -1)) -- facing along the bridge
	BridgeState.resumeTry(player, offer.try, tile)
	remote:FireAllClients("Revived", player, position)
	return true
end

BridgeState.onFail(function(player, _kind, lastTile, try)
	if not lastTile then
		return -- they hadn't reached a safe tile yet: nothing to go back to
	end
	local data = PlayerStats.Get(player)
	if not data then
		return
	end
	offers[player] = { tile = lastTile, try = try, expires = os.clock() + Config.Revive.OfferSeconds + 1 }
	remote:FireClient(player, "Offer", {
		Free = not data.FreeReviveUsed,
		Seconds = Config.Revive.OfferSeconds,
		Price = Config.Products.Revive.Price,
	})
end)

remote.OnServerEvent:Connect(function(player, action)
	if busy[player] then
		return
	end
	local offer = offers[player]
	if action == "Decline" then
		if offer then
			offers[player] = nil
		end
		return
	end
	if action ~= "Accept" or not offer or os.clock() > offer.expires then
		return
	end
	local data = PlayerStats.Get(player)
	if not data then
		return
	end
	busy[player] = true
	if not data.FreeReviveUsed then
		data.FreeReviveUsed = true
		if revive(player, offer) then
			task.spawn(PlayerStats.Save, player)
		else
			data.FreeReviveUsed = false
			remote:FireClient(player, "Status", "Invalid")
		end
	else
		-- paying: give them time to finish the Robux pop-up
		offer.expires = os.clock() + 120
		local status = Purchases.useOrBuy(player, "Revive", function()
			return offers[player] == offer
		end, function(p)
			return revive(p, offer)
		end)
		if status ~= "Used" and status ~= "Prompted" then
			remote:FireClient(player, "Status", status)
		end
	end
	busy[player] = nil
end)

Players.PlayerRemoving:Connect(function(player)
	offers[player] = nil
	busy[player] = nil
end)
