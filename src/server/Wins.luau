-- Wins (server)
-- Keeps each player's wins in the player attribute "Wins" (the wins bar reads it)
-- and saves them. Other scripts:
--   local Wins = require(game.ServerScriptService.Wins)
--   Wins.Add(player, 1)   -- adds wins and plays the win celebration on that player's screen

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local store = DataStoreService:GetDataStore("PlayerWins_v1")
local canSave = {} -- only save after a successful load (never wipe real data)

local Wins = {}
local remote -- created in init

function Wins.Get(player)
	return player:GetAttribute("Wins") or 0
end

-- true once the player's saved wins have loaded
function Wins.IsLoaded(player)
	return canSave[player] == true
end

local function save(player)
	if not canSave[player] then return end
	local value = Wins.Get(player)
	pcall(function() store:SetAsync("Wins_" .. player.UserId, value) end)
end

function Wins.Add(player, amount)
	amount = math.floor(tonumber(amount) or 1)
	player:SetAttribute("Wins", Wins.Get(player) + amount)
	if remote then remote:FireClient(player, "Win", amount) end
	task.spawn(save, player)
end

local function onJoin(player)
	player:SetAttribute("Wins", 0)
	for attempt = 1, 3 do
		local ok, saved = pcall(function() return store:GetAsync("Wins_" .. player.UserId) end)
		if ok then
			if player.Parent then
				-- keep any wins earned while loading
				player:SetAttribute("Wins", (tonumber(saved) or 0) + Wins.Get(player))
				canSave[player] = true
			end
			return
		end
		task.wait(attempt)
	end
end

function Wins.init()
	remote = ReplicatedStorage:FindFirstChild("WinRemote") or Instance.new("RemoteEvent")
	remote.Name = "WinRemote"
	remote.Parent = ReplicatedStorage
	Players.PlayerAdded:Connect(onJoin)
	for _, p in ipairs(Players:GetPlayers()) do task.spawn(onJoin, p) end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		canSave[player] = nil
	end)
	game:BindToClose(function()
		for _, p in ipairs(Players:GetPlayers()) do task.spawn(save, p) end
		task.wait(2)
	end)
end

return Wins
