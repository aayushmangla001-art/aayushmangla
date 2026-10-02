-- SlapShop (server)
-- Sammy's shop: buying, owning and saving items (ReplicatedStorage > ShopConfig).
-- Everything is checked here, so a player can't get an item without paying.
-- Owned items are saved, given back every time you join, and kept through respawns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Money = require(script.Parent:WaitForChild("Money"))
local ITEMS = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local shelf = ServerStorage:WaitForChild("ShopItems")

local byId = {}
for _, item in ipairs(ITEMS) do byId[item.Id] = item end

local remote = ReplicatedStorage:FindFirstChild("ShopRemote") or Instance.new("RemoteFunction")
remote.Name = "ShopRemote"
remote.Parent = ReplicatedStorage

local store = DataStoreService:GetDataStore("ShopOwned_v1")
local owned = {} -- [player] = { [id] = true }
local loaded = {} -- only save after a successful load (never wipe real data)

local function publish(player)
	local list = {}
	for id in pairs(owned[player] or {}) do table.insert(list, id) end
	player:SetAttribute("OwnedItems", HttpService:JSONEncode(list))
end

local function give(player, item)
	local template = shelf:FindFirstChild(item.Tool)
	if not template then return end
	local gear = player:FindFirstChild("StarterGear")
	if gear and not gear:FindFirstChild(item.Tool) then template:Clone().Parent = gear end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	if backpack and not backpack:FindFirstChild(item.Tool) and not (character and character:FindFirstChild(item.Tool)) then
		template:Clone().Parent = backpack
	end
end

local function save(player)
	if not loaded[player] then return end
	local list = {}
	for id in pairs(owned[player]) do table.insert(list, id) end
	pcall(function() store:SetAsync("Owned_" .. player.UserId, list) end)
end

local function onJoin(player)
	owned[player] = {}
	publish(player)
	for attempt = 1, 3 do
		local ok, data = pcall(function() return store:GetAsync("Owned_" .. player.UserId) end)
		if ok then
			for _, id in ipairs(data or {}) do
				if byId[id] then owned[player][id] = true end
			end
			loaded[player] = true
			break
		end
		task.wait(attempt)
	end
	if not player.Parent then return end
	publish(player)
	if not player.Character then player.CharacterAdded:Wait() end
	for id in pairs(owned[player]) do give(player, byId[id]) end
end
Players.PlayerAdded:Connect(onJoin)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onJoin, p) end
Players.PlayerRemoving:Connect(function(player)
	owned[player] = nil
	loaded[player] = nil
end)

remote.OnServerInvoke = function(player, action, id)
	local item = byId[id]
	if not item or not owned[player] then return false, "Unknown" end
	if action == "Buy" then
		if owned[player][id] then
			give(player, item)
			return true, "Owned"
		end
		if not Money.Spend(player, item.Price) then
			return false, "NoMoney"
		end
		owned[player][id] = true
		publish(player)
		give(player, item)
		task.spawn(save, player)
		return true, "Bought"
	elseif action == "Equip" then
		if not owned[player][id] then return false, "NotOwned" end
		give(player, item)
		return true, "Equipped"
	end
	return false, "Unknown"
end
