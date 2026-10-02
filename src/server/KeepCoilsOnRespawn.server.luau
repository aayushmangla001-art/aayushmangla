-- KeepCoilsOnRespawn
-- Any coil or carpet a player receives (from a giver, a command, anything)
-- is copied into their StarterGear. Roblox re-adds StarterGear to the Backpack
-- every time the player respawns, so the item stays until they leave the game.

local Players = game:GetService("Players")

-- Tools whose name contains one of these words are kept (case-insensitive)
local KEEP_KEYWORDS = { "coil", "carpet" }

local function shouldKeep(item)
	if not item:IsA("Tool") then
		return false
	end
	local lowerName = string.lower(item.Name)
	for _, word in ipairs(KEEP_KEYWORDS) do
		if string.find(lowerName, word, 1, true) then
			return true
		end
	end
	return false
end

local function keepTool(player, tool)
	if not shouldKeep(tool) then
		return
	end
	local gear = player:FindFirstChild("StarterGear")
	if gear and not gear:FindFirstChild(tool.Name) then
		local copy = tool:Clone()
		copy.Parent = gear
	end
end

local function watchBackpack(player, backpack)
	for _, item in ipairs(backpack:GetChildren()) do
		keepTool(player, item)
	end
	backpack.ChildAdded:Connect(function(item)
		keepTool(player, item)
	end)
end

local function onPlayerAdded(player)
	-- The Backpack is recreated on every respawn, so watch each new one
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			watchBackpack(player, child)
		end
	end)

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		watchBackpack(player, backpack)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
