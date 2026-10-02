-- Money (server)
-- Keeps each player's money in the player attribute "Money" (the on-screen label reads it),
-- saves it to a DataStore, and gives other scripts a simple API:
--
--   local Money = require(game.ServerScriptService.Money)
--   Money.Add(player, 100)      -- give money
--   Money.Spend(player, 50)     -- take money, returns false if they can't afford it
--   Money.Get(player)           -- current amount
--   Money.Set(player, 0)        -- set an exact amount

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local STORE_NAME = "PlayerMoney_v1"
local START_MONEY = 0
local AUTOSAVE_SECONDS = 60
local MAX_MONEY = 9e15 -- largest amount that stays exact

local store = DataStoreService:GetDataStore(STORE_NAME)
local canSave = {} -- [player] = true once their saved data loaded (never overwrite unloaded data)

local Money = {}

local function clean(amount)
	amount = math.floor(tonumber(amount) or 0)
	return math.clamp(amount, 0, MAX_MONEY)
end

function Money.Get(player)
	return player:GetAttribute("Money") or 0
end

function Money.Set(player, amount)
	player:SetAttribute("Money", clean(amount))
end

function Money.Add(player, amount)
	local total = clean(Money.Get(player) + (tonumber(amount) or 0))
	player:SetAttribute("Money", total)
	return total
end

function Money.Spend(player, amount)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 or Money.Get(player) < amount then
		return false
	end
	Money.Set(player, Money.Get(player) - amount)
	return true
end

local function keyFor(player)
	return "Player_" .. player.UserId
end

local function load(player)
	for attempt = 1, 3 do
		local ok, saved = pcall(function()
			return store:GetAsync(keyFor(player))
		end)
		if ok then
			if not player.Parent then
				return
			end
			-- keep anything earned while the data was loading
			player:SetAttribute("Money", clean(clean(saved or START_MONEY) + Money.Get(player)))
			canSave[player] = true
			return
		end
		task.wait(attempt)
	end
	warn("[Money] Could not load " .. player.Name .. "'s money, so it won't be saved this session")
end

local function save(player)
	if not canSave[player] then
		return
	end
	local amount = Money.Get(player)
	local ok, err = pcall(function()
		store:SetAsync(keyFor(player), amount)
	end)
	if not ok then
		warn("[Money] Could not save " .. player.Name .. ": " .. tostring(err))
	end
end

local function onPlayerAdded(player)
	player:SetAttribute("Money", START_MONEY)
	load(player)
end

function Money.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player)
		canSave[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(save, player)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for _, player in ipairs(Players:GetPlayers()) do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		local waited = 0
		while pending > 0 and waited < 25 do
			task.wait(0.2)
			waited += 0.2
		end
	end)
end

return Money
