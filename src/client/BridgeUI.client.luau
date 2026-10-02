-- BridgeUI (client)
-- * The "Revive?" pop-up after breaking a wrong tile / falling off the bridge
-- * The Skip to End / Show Path / Kill All buttons under the bridge progress bar
-- * Showing the safe path, and the effects for revives, skips and Kill All

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameKit = ReplicatedStorage:WaitForChild("GameKit")
local Config = require(GameKit:WaitForChild("Config"))
local Net = require(GameKit:WaitForChild("Net"))
local UI = require(GameKit:WaitForChild("UI"))
local Sfx = require(GameKit:WaitForChild("Sfx"))
local Vfx = require(GameKit:WaitForChild("Vfx"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Theme = Config.Theme
local Products = Config.Products

local reviveRemote = Net.event("BridgeRevive")
local powersRemote = Net.event("BridgePowers")

local function statusMessage(status: string, invalidText: string?)
	if status == "NotSetUp" then
		UI.notify("Coming soon!", Theme.Purple)
	elseif status == "NoData" then
		UI.notify("Your data is still loading - try again in a moment", Theme.Red)
	elseif status == "Invalid" then
		Sfx.play("Error")
		UI.notify(invalidText or "You can't do that right now", Theme.Red)
	end
end

-- ============================ revive ============================
local closeRevive: (() -> ())? = nil

reviveRemote.OnClientEvent:Connect(function(kind, a, b)
	if kind == "Offer" then
		local info = a
		if closeRevive then
			closeRevive()
		end
		local buttonText = info.Free and "FREE REVIVE" or ("REVIVE  R$" .. info.Price)
		closeRevive = UI.popup({
			Title = "REVIVE?",
			Body = info.Free and "Go back to your last safe glass.\nYour first revive is FREE!"
				or "Go back to your last safe glass and keep going!",
			Buttons = {
				{
					Text = buttonText,
					Color = info.Free and Theme.Green or Theme.Robux,
					OnClick = function()
						reviveRemote:FireServer("Accept")
					end,
				},
				{
					Text = "NO THANKS",
					Color = Theme.Red,
					OnClick = function()
						reviveRemote:FireServer("Decline")
					end,
				},
			},
			Seconds = info.Seconds,
			OnTimeout = function()
				reviveRemote:FireServer("Decline")
			end,
		})
	elseif kind == "Revived" then
		local who: Player, position: Vector3 = a, b
		Vfx.pillar(position, Theme.Green)
		Sfx.playAt("Revive", position)
		if who == player then
			Sfx.play("Reward")
			Vfx.flash(Theme.Green, 0.4)
			UI.notify("REVIVED! Keep going!", Theme.Green)
		end
	elseif kind == "Status" then
		statusMessage(a, "That revive has run out")
	end
end)

-- ============================ the three buttons ============================
local _, root = UI.screen("BridgeButtons", 6)
local row = Instance.new("Frame")
row.Name = "Row"
row.BackgroundTransparency = 1
row.AnchorPoint = Vector2.new(0.5, 0)
row.Size = UDim2.fromOffset(500, 50)
row.Position = UDim2.new(0.5, 0, 0, 70)
row.Parent = root
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = row

local function priceText(key: string): string
	return "R$" .. Products[key].Price
end

local buttons: { [string]: TextButton } = {}
local function addButton(key: string, text: string, color: Color3, order: number)
	local b = UI.button(row, text, color, function()
		powersRemote:FireServer(key)
	end)
	b.Size = UDim2.fromOffset(160, 50)
	b.LayoutOrder = order
	local label = b:FindFirstChild("Label") :: TextLabel
	label.Size = UDim2.new(1, -12, 0.62, 0)
	label.Position = UDim2.new(0, 6, 0, 3)
	local price = UI.label(b, priceText(key), UDim2.new(1, -12, 0.36, 0), UDim2.new(0, 6, 0.6, -2), Theme.Yellow)
	price.Name = "Price"
	buttons[key] = b
end
addButton("SkipToEnd", "⏩ SKIP TO END", Theme.Blue, 1)
addButton("ShowPath", "👁 SHOW PATH", Theme.Green, 2)
addButton("KillAll", "💀 KILL ALL", Theme.Red, 3)

-- sit right under the existing progress bar (found by name), or near the top
local function findProgressBar(): GuiObject?
	local best: GuiObject? = nil
	for _, d in ipairs(playerGui:GetDescendants()) do
		if d:IsA("GuiObject") and d.Name:lower():find("progress") and d.AbsoluteSize.X > 150 and d.Visible
			and not d:IsDescendantOf(root) then
			local gui = d:FindFirstAncestorWhichIsA("ScreenGui")
			if gui and gui.Enabled and (not best or d.AbsoluteSize.X > best.AbsoluteSize.X) then
				best = d
			end
		end
	end
	return best
end

local scale = root:FindFirstChildOfClass("UIScale")
task.spawn(function()
	while true do
		local bar = findProgressBar()
		local s = scale and scale.Scale or 1
		if bar then
			local bottom = bar.AbsolutePosition.Y + bar.AbsoluteSize.Y + 8
			local centerX = bar.AbsolutePosition.X + bar.AbsoluteSize.X / 2
			row.Position = UDim2.fromOffset(centerX / s, bottom / s)
		else
			row.Position = UDim2.new(0.5, 0, 0, 70)
		end
		task.wait(2)
	end
end)

-- ============================ show path ============================
local pathFolder: Folder? = nil
local pathEndsAt = 0

local function clearPath()
	if pathFolder then
		pathFolder:Destroy()
		pathFolder = nil
	end
	UI.setText(buttons.ShowPath, "👁 SHOW PATH")
end

local function showPath(tiles: { BasePart }, seconds: number)
	clearPath()
	local folder = Instance.new("Folder")
	folder.Name = "SafePath"
	folder.Parent = Workspace.CurrentCamera
	pathFolder = folder
	for _, tile in ipairs(tiles) do
		if tile and tile.Parent then
			local box = Instance.new("SelectionBox")
			box.Adornee = tile
			box.Color3 = Theme.Green
			box.LineThickness = 0.15
			box.SurfaceColor3 = Theme.Green
			box.SurfaceTransparency = 0.55
			box.Parent = folder
		end
	end
	Sfx.play("Reward")
	Vfx.flash(Theme.Green, 0.3)
	UI.notify("The safe path is glowing GREEN!", Theme.Green)
	pathEndsAt = os.clock() + seconds
	task.spawn(function()
		while pathFolder == folder do
			local left = math.ceil(pathEndsAt - os.clock())
			if left <= 0 then
				clearPath()
				UI.notify("The safe path has faded", Theme.Blue)
				break
			end
			UI.setText(buttons.ShowPath, string.format("👁 %d:%02d", left // 60, left % 60))
			task.wait(0.5)
		end
	end)
end

local INVALID = {
	SkipToEnd = "You can't skip right now",
	ShowPath = "You can't use that right now",
	KillAll = "Nobody else is on the bridge right now",
}

powersRemote.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "Status" then
		statusMessage(b, INVALID[a])
	elseif kind == "ShowPath" then
		showPath(a, b)
	elseif kind == "Teleported" then
		local who: Player, position: Vector3 = a, b
		Vfx.pillar(position, Theme.Blue)
		Sfx.playAt("Teleport", position)
		if who == player then
			Vfx.flash(Theme.Blue, 0.5)
			Sfx.play("Teleport")
			UI.notify("Skipped to the end!", Theme.Blue)
		end
	elseif kind == "KillAll" then
		local who: Player, positions: { Vector3 }, count: number = a, b, c
		for _, position in ipairs(positions) do
			Vfx.burst(position, Theme.Red, 40)
			Vfx.ring(position, Theme.Red, 18)
			Sfx.playAt("Kill", position)
		end
		Vfx.flash(Theme.Red, 0.25)
		local name = who == player and "You" or who.DisplayName
		UI.notify(string.format("💀 %s used KILL ALL! (%d eliminated)", name, count), Theme.Red, 4)
	end
end)
