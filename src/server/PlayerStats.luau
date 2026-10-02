-- PlayerStats (server)
-- Saves the extra things the new systems need to remember about each player:
-- playtime, free revive used, rewards claimed, friends already rewarded for,
-- Robux items bought but not used yet, and handled purchase receipts.
-- Playtime is also shown as the player attribute "Playtime" (seconds).
--
--   local PlayerStats = require(game.ServerScriptService.PlayerStats)
--   local data = PlayerStats.Wait(player)   -- nil if their data couldn't load
--   data.GroupClaimed = true
--   PlayerStats.Save(player)                 -- returns true if it saved

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local AUTOSAVE_SECONDS = 120

export type Data = {
	Playtime: number,
	FreeReviveUsed: boolean,
	GroupClaimed: boolean,
	LikeClaimed: boolean,
	InvitedFriends: { [string]: boolean },
	Credits: { [string]: number },
	Receipts: { string },
}

local function defaults(): Data
	return {
		Playtime = 0,
		FreeReviveUsed = false,
		GroupClaimed = false,
		LikeClaimed = false,
		InvitedFriends = {},
		Credits = {},
		Receipts = {},
	}
end

local store = DataStoreService:GetDataStore("PlayerStats_v1")
local data: { [Player]: Data } = {}
local canSave: { [Player]: boolean } = {}
local ready: { [Player]: BindableEvent } = {}
local finished: { [Player]: boolean } = {} -- loading is over (worked or not)

local PlayerStats = {}

local function keyFor(player: Player): string
	return "Stats_" .. player.UserId
end

local function readyEvent(player: Player): BindableEvent
	local e = ready[player]
	if not e then
		e = Instance.new("BindableEvent")
		ready[player] = e
	end
	return e
end

-- the player's data, or nil if it hasn't loaded (or couldn't load)
function PlayerStats.Get(player: Player): Data?
	return data[player]
end

-- waits up to 15 seconds for the player's data
function PlayerStats.Wait(player: Player): Data?
	if data[player] or finished[player] or not player.Parent then
		return data[player]
	end
	local e = readyEvent(player)
	local done = false
	task.delay(15, function()
		if not done then
			e:Fire()
		end
	end)
	e.Event:Wait()
	done = true
	return data[player]
end

function PlayerStats.Save(player: Player): boolean
	local d = data[player]
	if not d then
		return false
	end
	if not canSave[player] then
		-- Studio without API access: pretend it saved so things can be tested
		return RunService:IsStudio()
	end
	local ok, err = pcall(function()
		store:SetAsync(keyFor(player), d)
	end)
	if not ok then
		warn("[PlayerStats] Could not save " .. player.Name .. ": " .. tostring(err))
	end
	return ok
end

local function load(player: Player)
	for attempt = 1, 3 do
		local ok, saved = pcall(function()
			return store:GetAsync(keyFor(player))
		end)
		if ok then
			if not player.Parent then
				return
			end
			local d = defaults()
			if type(saved) == "table" then
				for k, v in pairs(saved) do
					if (d :: any)[k] ~= nil and type(v) == type((d :: any)[k]) then
						(d :: any)[k] = v
					end
				end
			end
			data[player] = d
			canSave[player] = true
			player:SetAttribute("Playtime", d.Playtime)
			finished[player] = true
			readyEvent(player):Fire()
			return
		end
		task.wait(attempt)
	end
	if RunService:IsStudio() then
		-- Studio usually can't reach DataStores: use fresh data that isn't saved
		data[player] = defaults()
		player:SetAttribute("Playtime", 0)
		warn("[PlayerStats] Using unsaved test data for " .. player.Name .. " (Studio has no DataStore access)")
	else
		warn("[PlayerStats] Could not load " .. player.Name .. "'s stats; rewards are paused for them this session")
	end
	finished[player] = true
	readyEvent(player):Fire()
end

local started = false
function PlayerStats.init()
	if started then
		return
	end
	started = true
	Players.PlayerAdded:Connect(load)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(load, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		PlayerStats.Save(player)
		data[player] = nil
		canSave[player] = nil
		finished[player] = nil
		local e = ready[player]
		ready[player] = nil
		if e then
			e:Fire()
			e:Destroy()
		end
	end)

	-- playtime: +1 every second while in the game
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local d = data[player]
				if d then
					d.Playtime += 1
					player:SetAttribute("Playtime", d.Playtime)
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(PlayerStats.Save, player)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for _, player in ipairs(Players:GetPlayers()) do
			pending += 1
			task.spawn(function()
				PlayerStats.Save(player)
				pending -= 1
			end)
		end
		local waited = 0
		while pending > 0 and waited < 25 do
			waited += task.wait(0.2)
		end
	end)
end

PlayerStats.init()

return PlayerStats
