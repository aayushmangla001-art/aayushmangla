-- BridgeProgress (server)
-- Works out how far along the glass bridge each player is (0 = start of the
-- tiles, 1 = at the finish chest) and stores it on the player as the attribute
-- "BridgeProgress". The progress bar at the top of the screen reads it.

local Players = game:GetService("Players")

local UPDATE_EVERY = 0.1

-- start of the bridge: the tile closest to the spawn
local tiles
for _, child in ipairs(workspace:GetChildren()) do
	if child.Name:lower():gsub("^%s+", ""):gsub("%s+$", "") == "all tiles" then tiles = child end
end
assert(tiles, "BridgeProgress: 'all tiles' folder not found")
local startZ = -math.huge
for _, d in ipairs(tiles:GetDescendants()) do
	if d:IsA("BasePart") then startZ = math.max(startZ, d.Position.Z) end
end

-- end: just in front of the finish chest (where players stand to open it)
local chest = workspace:WaitForChild("everything in finish area"):WaitForChild("finish line modals")
	:WaitForChild("finish chest"):WaitForChild("Chest")
local endZ = chest.Position.Z + 12

local length = startZ - endZ -- the bridge runs toward -Z

-- share the start/end with clients so they can place nearby players instantly
local ReplicatedStorage = game:GetService("ReplicatedStorage")
ReplicatedStorage:SetAttribute("BridgeStartZ", startZ)
ReplicatedStorage:SetAttribute("BridgeEndZ", endZ)

while true do
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local t = math.clamp((startZ - root.Position.Z) / length, 0, 1)
			t = math.floor(t * 500 + 0.5) / 500 -- small steps only, so we don't spam updates
			if player:GetAttribute("BridgeProgress") ~= t then
				player:SetAttribute("BridgeProgress", t)
			end
		end
	end
	task.wait(UPDATE_EVERY)
end
