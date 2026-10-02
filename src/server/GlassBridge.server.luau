-- GlassBridge (server)
-- Every row of the bridge has a left and a right tile. Each server picks, at
-- random, which one is safe. The answer only lives here on the server.
-- Your tiles keep their own look; nothing about them is restyled.
--
--  * Wrong tile: the tile AND its frame shatter, you die, and it grows back
--    after 30 seconds. Respawning is quick (2 seconds).
--  * Right tile: turns green (only on your screen) with a green "ghost" of the
--    tile rising out of it, and pays $100 - once per tile per try.
--  * Falling off: an invisible catcher under the bridge sends you straight back
--    to the spawn plate (no dying, no respawn wait). Falling or dying starts a
--    new try: your green tiles reset and can pay again. A tile can't pay the
--    same player twice within 20 seconds, so nobody can farm the first row.
--  * Tiles that lead to the side path (toward the cash area) are always safe.
--  * Breaking a tile or falling tells BridgeState, so the revive script can offer
--    to put the player back on the last safe tile they reached.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Money = require(script.Parent:WaitForChild("Money"))
local BridgeState = require(script.Parent:WaitForChild("BridgeState"))
local remote = ReplicatedStorage:WaitForChild("GlassBridgeRemote")

local REWARD = 100
local REGROW_TIME = 30
local REWARD_COOLDOWN = 20

-- ======================= find the tiles =======================
local folder
for _, child in ipairs(workspace:GetChildren()) do
	if child.Name:lower():gsub("^%s+", ""):gsub("%s+$", "") == "all tiles" then folder = child end
end
assert(folder, "GlassBridge: 'all tiles' folder not found")

local function isCentre(p)
	-- tiles are labelled in Studio: BridgeTile (main bridge) / SidePathTile (path to the cash area)
	return p:IsA("BasePart") and (p:GetAttribute("BridgeTile") == true or p:GetAttribute("SidePathTile") == true)
end

local mainTiles, sideTiles = {}, {}
for _, d in ipairs(folder:GetDescendants()) do
	if isCentre(d) then
		if math.abs(d.Position.X) <= 15 then
			table.insert(mainTiles, d)
		else
			sideTiles[d] = true
		end
	end
end

local function leadsToSidePath(tile)
	for _, d in ipairs(tile.Parent:GetDescendants()) do
		if sideTiles[d] then return true end
	end
	return false
end

table.sort(mainTiles, function(a, b) return a.Position.Z > b.Position.Z end)
local rows = {}
for _, t in ipairs(mainTiles) do
	local last = rows[#rows]
	if last and math.abs(last[1].Position.Z - t.Position.Z) < 3 then
		table.insert(last, t)
	else
		table.insert(rows, { t })
	end
end

local function frameOf(tile)
	local list = {}
	for _, d in ipairs(tile.Parent:GetDescendants()) do
		if d:IsA("BasePart") and not isCentre(d) then
			local off = d.Position - tile.Position
			local reach = math.max(tile.Size.X, tile.Size.Z) / 2 + 1.5
			if d:GetAttribute("BridgeFrame") and math.abs(off.X) <= reach and math.abs(off.Z) <= reach and math.abs(off.Y) < 1 then
				table.insert(list, d)
			end
		end
	end
	return list
end

Players.RespawnTime = 2 -- quick respawn after stepping on a wrong tile

local info = {} -- [tile] = { correct, broken, frame = {parts}, transparency = {[part] = n} }
local rng = Random.new()
for _, row in ipairs(rows) do
	local connector
	for _, t in ipairs(row) do
		if leadsToSidePath(t) then connector = t end
	end
	local safe = connector or row[rng:NextInteger(1, #row)]
	for _, t in ipairs(row) do
		t.CanTouch = true
		local frame = frameOf(t)
		local transparency = { [t] = t.Transparency }
		for _, f in ipairs(frame) do transparency[f] = f.Transparency end
		info[t] = { correct = (t == safe), broken = false, frame = frame, transparency = transparency }
	end
end

-- share the layout with the revive / bridge-button scripts (server only)
do
	local minX, maxX, minZ, maxZ, lowestY = math.huge, -math.huge, math.huge, -math.huge, math.huge
	for _, row in ipairs(rows) do
		for _, t in ipairs(row) do
			minX, maxX = math.min(minX, t.Position.X), math.max(maxX, t.Position.X)
			minZ, maxZ = math.min(minZ, t.Position.Z), math.max(maxZ, t.Position.Z)
			lowestY = math.min(lowestY, t.Position.Y)
			if info[t].correct then table.insert(BridgeState.safeTiles, t) end
		end
	end
	BridgeState.rows = rows
	BridgeState.minX, BridgeState.maxX = minX, maxX
	BridgeState.minZ, BridgeState.maxZ = minZ, maxZ
	BridgeState.lowestY = lowestY
end

-- ======================= tries (falls / deaths) =======================
local rewardedThisTry = {} -- [player] = { [tile] = true }
local lastPaid = {} -- [player] = { [tile] = time }

local function newTry(player)
	rewardedThisTry[player] = {}
	BridgeState.lastSafe[player] = nil
	remote:FireClient(player, "Reset")
end

-- tell the revive script what the player had reached, before it's reset
local function failed(player, kind)
	BridgeState.fireFail(player, kind, BridgeState.lastSafe[player], rewardedThisTry[player])
end

function BridgeState.resumeTry(player, try, tile)
	if not player.Parent then return end
	rewardedThisTry[player] = try or {}
	BridgeState.lastSafe[player] = tile
end

local function setup(player)
	lastPaid[player] = {}
	rewardedThisTry[player] = {}
	player.CharacterAdded:Connect(function() newTry(player) end)
end
Players.PlayerAdded:Connect(setup)
for _, p in ipairs(Players:GetPlayers()) do setup(p) end
Players.PlayerRemoving:Connect(function(player)
	rewardedThisTry[player] = nil
	lastPaid[player] = nil
	BridgeState.lastSafe[player] = nil
end)

-- ======================= stepping on tiles =======================
local function breakTile(tile)
	local data = info[tile]
	if data.broken then return end
	data.broken = true
	for part in pairs(data.transparency) do
		part.CanCollide = false
		part.Transparency = 1
	end
	remote:FireAllClients("Break", tile)
	task.delay(REGROW_TIME, function()
		data.broken = false
		remote:FireAllClients("Restore", tile)
		task.wait(0.55) -- let the pieces fly back into place on screens first
		for part, t in pairs(data.transparency) do
			part.Transparency = t
			part.CanCollide = true
		end
	end)
end

local function correctStep(player, tile)
	local try = rewardedThisTry[player]
	if not try then return end
	BridgeState.lastSafe[player] = tile
	if try[tile] then return end
	try[tile] = true
	local paid = false
	local now = os.clock()
	local last = lastPaid[player][tile]
	if not last or now - last >= REWARD_COOLDOWN then
		lastPaid[player][tile] = now
		Money.Add(player, REWARD)
		paid = true
	end
	remote:FireClient(player, "Correct", tile, paid)
end

for tile, data in pairs(info) do
	tile.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then return end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then return end
		if data.correct then
			correctStep(player, tile)
		else
			breakTile(tile)
			failed(player, "Glass")
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				root.AssemblyLinearVelocity = Vector3.new(0, -10, 0) -- just drop, no fling
				root.AssemblyAngularVelocity = Vector3.zero
			end
			humanoid.Health = 0
		end
	end)
end

-- ======================= fall catcher =======================
-- an invisible area under the whole bridge (and the side path + finish area):
-- touching it sends you to the spawn plate instead of dying
local spawnPad = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
local catcher = workspace:FindFirstChild("BridgeFallCatcher") or Instance.new("Part")
catcher.Name = "BridgeFallCatcher"
catcher.Anchored = true
catcher.CanCollide = false
catcher.CanQuery = false
catcher.CanTouch = true
catcher.Transparency = 1
catcher.CastShadow = false
-- covers x -130..35 and z -28..-645, a little below the bridge
catcher.Size = Vector3.new(165, 8, 617)
catcher.CFrame = CFrame.new(-47.5, -32, -336.5)
catcher.Parent = workspace

local catching = {}
catcher.Touched:Connect(function(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player or catching[player] then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return end
	catching[player] = true
	-- put any flying carpet away first so its forces don't fight the teleport
	humanoid:UnequipTools()
	for _, name in ipairs({ "FlightSpin", "FlightPower", "FlightHold" }) do
		local f = root:FindFirstChild(name)
		if f then f:Destroy() end
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	if spawnPad then
		root.CFrame = spawnPad.CFrame * CFrame.new(math.random(-4, 4), spawnPad.Size.Y / 2 + 4, math.random(-4, 4))
	end
	failed(player, "Fall")
	newTry(player)
	remote:FireClient(player, "Caught")
	task.delay(1, function() catching[player] = nil end)
end)

BridgeState.ready = true

local safe = 0
for _, d in pairs(info) do if d.correct then safe += 1 end end
print(string.format("[GlassBridge] %d rows, %d safe tiles (new random pattern this server)", #rows, safe))
