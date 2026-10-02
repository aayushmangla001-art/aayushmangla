-- SpinWheel (server)
-- Players standing in the white ring pay $1,000 to spin. The server picks the
-- prize (the client can't choose), spins the wheel for everyone, and gives the
-- prize when the wheel stops.
--
-- Normal odds: average payout is about $820 per $1,000 spin, so players lose
-- money on average. It's a luck game, not a money farm.
-- Beginner's luck: each player's first 3 spins EVER use better odds (no $10,000
-- and no Magic Carpet). The spin count is saved, so rejoining doesn't reset it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Money = require(ServerScriptService:WaitForChild("Money"))
local ItemGiver = require(ServerScriptService:WaitForChild("ItemGiver"))
local remote = ReplicatedStorage:WaitForChild("SpinWheelRemote")

local SPIN_COST = 1000
local SPIN_TIME = 5.5 -- seconds (the client uses the same number)
local EXTRA_TURNS = 5
local BEGINNER_SPINS = 3

local PRIZES = {
	Cash100   = { Kind = "Money", Amount = 100 },
	Cash500   = { Kind = "Money", Amount = 500 },
	Cash1000  = { Kind = "Money", Amount = 1000 },
	Cash2000  = { Kind = "Money", Amount = 2000 },
	Cash5000  = { Kind = "Money", Amount = 5000 },
	Cash10000 = { Kind = "Money", Amount = 10000 },
	Gravity   = { Kind = "Item", ItemName = "GravityCoil", Make = ItemGiver.fromAsset(16688968) },
	Carpet    = { Kind = "Item", ItemName = "RainbowMagicCarpet", Make = ItemGiver.fromStorage("RainbowMagicCarpet") },
}
-- If they win an item they already own, they get their $1,000 back instead.

-- Chances in percent (each list adds up to 100). The wheel shows NORMAL_ODDS.
local NORMAL_ODDS = {
	{ "Cash100", 30 }, { "Cash500", 40 }, { "Cash1000", 20 }, { "Cash2000", 4.4 },
	{ "Cash5000", 4 }, { "Cash10000", 1 }, { "Gravity", 0.4 }, { "Carpet", 0.2 },
}
local BEGINNER_ODDS = {
	{ "Cash100", 10 }, { "Cash500", 25 }, { "Cash1000", 30 }, { "Cash2000", 25 },
	{ "Cash5000", 10 }, { "Cash10000", 0 }, { "Gravity", 0 }, { "Carpet", 0 },
}

-- ======================== spin count (saved) ========================
local store = DataStoreService:GetDataStore("SpinWheel_v1")
local spinCount = {} -- [player] = number of spins ever
local countLoaded = {}

local function loadCount(player)
	for attempt = 1, 3 do
		local ok, saved = pcall(function() return store:GetAsync("Spins_" .. player.UserId) end)
		if ok then
			spinCount[player] = tonumber(saved) or 0
			countLoaded[player] = true
			return
		end
		task.wait(attempt)
	end
	-- Couldn't load: in Studio (where saving is usually off) treat them as new so
	-- you can test; in the real game give no beginner's luck, so it can't be abused.
	spinCount[player] = RunService:IsStudio() and 0 or BEGINNER_SPINS
end

local function saveCount(player)
	if not countLoaded[player] then return end
	local count = spinCount[player]
	pcall(function() store:SetAsync("Spins_" .. player.UserId, count) end)
end

Players.PlayerAdded:Connect(loadCount)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(loadCount, p) end
Players.PlayerRemoving:Connect(function(player)
	saveCount(player)
	spinCount[player] = nil
	countLoaded[player] = nil
end)
game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do task.spawn(saveCount, p) end
	task.wait(2)
end)

-- ======================== wheel parts ========================
local wheel = workspace:WaitForChild("wheel")
local hub
local spinParts = {}
local slices = {} -- [prizeId] = slice model
for _, d in ipairs(wheel:GetDescendants()) do
	if d:GetAttribute("SpinHub") then hub = d end
	if d:GetAttribute("PrizeId") then slices[d:GetAttribute("PrizeId")] = d end
end
assert(hub, "SpinWheel: hub not found")
table.insert(spinParts, hub)
for _, slice in pairs(slices) do
	for _, p in ipairs(slice:GetDescendants()) do
		if p:IsA("BasePart") then table.insert(spinParts, p) end
	end
end

local ring = wheel:WaitForChild("SpinRing")
local RING_CENTER = ring:GetAttribute("Center")
local RING_RADIUS = ring:GetAttribute("Radius")

local function inRing(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local d = root.Position - RING_CENTER
	return Vector3.new(d.X, 0, d.Z).Magnitude <= RING_RADIUS + 2 and math.abs(d.Y) < 12
end

local rng = Random.new()
local function pickPrize(odds)
	local roll = rng:NextNumber(0, 100)
	local total = 0
	for _, entry in ipairs(odds) do
		total += entry[2]
		if entry[2] > 0 and roll <= total then return entry[1] end
	end
	return odds[1][1]
end

-- clockwise angle (as seen from the front) of a slice, 0 = straight up at the pointer.
-- Measured against the WORLD's up direction: the hub's own axes spin with the wheel.
local FACING = hub.CFrame.LookVector
local FIXED_UP = Vector3.yAxis
local FIXED_RIGHT = (-FACING):Cross(FIXED_UP).Unit
local function sliceAngle(slice)
	-- CenterAngle = the slice's exact centre on the wheel face (measured once in Studio);
	-- add how far the wheel itself has turned
	local u = hub.CFrame.UpVector
	local wheelTurn = math.deg(math.atan2(u:Dot(FIXED_RIGHT), u:Dot(FIXED_UP)))
	return (slice:GetAttribute("CenterAngle") + wheelTurn) % 360
end

local function giveReward(player, prizeId)
	local prize = PRIZES[prizeId]
	if prize.Kind == "Money" then
		Money.Add(player, prize.Amount)
		return prizeId, prize.Amount
	end
	if ItemGiver.give(player, prize.ItemName, prize.Make) then
		return prizeId, 0
	end
	Money.Add(player, SPIN_COST)
	return "Refund", SPIN_COST
end

-- ======================== spinning ========================
local spinning = false
local busy = {}

remote.OnServerEvent:Connect(function(player, action)
	if action ~= "Spin" or busy[player] then return end
	busy[player] = true
	task.delay(0.5, function() busy[player] = nil end)

	if spinning then
		remote:FireClient(player, "Busy")
		return
	end
	if not inRing(player) or spinCount[player] == nil then
		return
	end
	if not Money.Spend(player, SPIN_COST) then
		remote:FireClient(player, "NoMoney")
		return
	end
	spinning = true

	local beginner = spinCount[player] < BEGINNER_SPINS
	spinCount[player] += 1
	if spinCount[player] == BEGINNER_SPINS then task.spawn(saveCount, player) end

	local prizeId = pickPrize(beginner and BEGINNER_ODDS or NORMAL_ODDS)
	local current = sliceAngle(slices[prizeId])
	local offset = rng:NextNumber(-16, 16)
	local turn = ((360 - current) % 360) + offset + 360 * EXTRA_TURNS

	local startCF = hub.CFrame
	local relatives = {}
	for i, p in ipairs(spinParts) do relatives[i] = startCF:ToObjectSpace(p.CFrame) end

	remote:FireAllClients("Spin", { Spinner = player, Turn = turn, Duration = SPIN_TIME, PrizeId = prizeId })

	task.wait(SPIN_TIME + 0.15)

	local finalCF = CFrame.new(startCF.Position) * CFrame.fromAxisAngle(FACING, -math.rad(turn)) * (startCF - startCF.Position)
	for i, p in ipairs(spinParts) do p.CFrame = finalCF * relatives[i] end

	if player.Parent then
		local resultId, amount = giveReward(player, prizeId)
		remote:FireAllClients("Result", { Spinner = player, PrizeId = resultId, Amount = amount })
	end
	spinning = false
end)

Players.PlayerRemoving:Connect(function(player) busy[player] = nil end)
