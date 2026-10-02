-- ItemGiver
-- Gives a power-up only if the player doesn't already own it.
-- If they do, it shows the "You already own this item" popup instead.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local InsertService = game:GetService("InsertService")

local Notice = ReplicatedStorage:WaitForChild("ItemNotice")

local NOTICE_COOLDOWN = 2.5 -- seconds between popups for one player
local GRACE_AFTER_GIVING = 3 -- no popup right after they just picked it up

local ItemGiver = {}

local lastNotice = {} -- [player] = time of last popup
local grace = {} -- [player] = { [itemName] = time until popup allowed }

Players.PlayerRemoving:Connect(function(player)
	lastNotice[player] = nil
	grace[player] = nil
end)

local function owns(player, itemName)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack and backpack:FindFirstChild(itemName) then
		return true
	end
	local character = player.Character
	if character and character:FindFirstChild(itemName) then
		return true -- currently held
	end
	local gear = player:FindFirstChild("StarterGear")
	if gear and gear:FindFirstChild(itemName) then
		return true -- kept for respawns
	end
	return false
end

ItemGiver.owns = owns

-- Give an item right away (no touch needed). Returns false if they already own it.
function ItemGiver.give(player, itemName, makeItem)
	if owns(player, itemName) then
		return false
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local tool = makeItem()
	if not tool or not backpack then
		if tool then tool:Destroy() end
		return false
	end
	tool.Name = itemName
	local handle = tool:FindFirstChild("Handle")
	if handle then
		handle.Anchored = false
	end
	tool.Parent = backpack
	return true
end

-- Returns a function that builds a fresh copy of a catalog tool
function ItemGiver.fromAsset(assetId)
	return function()
		local ok, model = pcall(function()
			return InsertService:LoadAsset(assetId)
		end)
		if not ok or not model then
			warn("ItemGiver: could not load asset " .. tostring(assetId))
			return nil
		end
		local tool = model:GetChildren()[1]
		if not tool then
			model:Destroy()
			return nil
		end
		tool.Parent = nil
		model:Destroy()
		return tool
	end
end

-- Returns a function that clones a tool stored in ServerStorage
function ItemGiver.fromStorage(toolName)
	return function()
		local source = ServerStorage:FindFirstChild(toolName)
		if not source then
			warn("ItemGiver: ServerStorage." .. toolName .. " is missing")
			return nil
		end
		return source:Clone()
	end
end

-- giverPart   : the part players step on
-- itemName    : the tool's Name (used to check ownership)
-- displayName : friendly name shown in the popup
-- makeItem    : function that returns a new tool
function ItemGiver.setup(giverPart, itemName, displayName, makeItem)
	local busy = {}

	giverPart.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player or busy[player] then
			return
		end
		busy[player] = true

		if owns(player, itemName) then
			local now = os.clock()
			local graceUntil = grace[player] and grace[player][itemName] or 0
			local lastShown = lastNotice[player] or 0
			if now >= graceUntil and now - lastShown >= NOTICE_COOLDOWN then
				lastNotice[player] = now
				Notice:FireClient(player, displayName)
			end
		else
			local tool = makeItem()
			local backpack = player:FindFirstChildOfClass("Backpack")
			if tool and backpack and not owns(player, itemName) then
				tool.Name = itemName
				local handle = tool:FindFirstChild("Handle")
				if handle then
					handle.Anchored = false
				end
				tool.Parent = backpack
				grace[player] = grace[player] or {}
				grace[player][itemName] = os.clock() + GRACE_AFTER_GIVING
			elseif tool then
				tool:Destroy()
			end
		end

		task.wait(0.5)
		busy[player] = nil
	end)
end

return ItemGiver
