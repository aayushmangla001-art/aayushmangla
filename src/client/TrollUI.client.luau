-- TrollUI (client)
-- The Troll menu: pick a player in the server, spectate them, or Kill / Fling /
-- Push them (Robux). The server checks every action (see Troll.server).

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
local Theme = Config.Theme
local Products = Config.Products
local remote = Net.event("Troll")

local selected: Player? = nil
local spectating: Player? = nil

-- ============================ menu ============================
local _, root = UI.screen("TrollMenu", 8)
local panel = UI.panel(root, UDim2.fromOffset(600, 400), UDim2.fromScale(0.5, 0.5))
panel.Visible = false

local title = UI.label(panel, "😈 TROLL MENU", UDim2.new(1, -120, 0, 46), UDim2.fromOffset(20, 12), Theme.Yellow)
title.TextXAlignment = Enum.TextXAlignment.Left
local closeButton = UI.button(panel, "X", Theme.Red, function()
	UI.close(panel)
end)
closeButton.Size = UDim2.fromOffset(46, 46)
closeButton.Position = UDim2.new(1, -60, 0, 12)

-- player list (left)
local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(0, 270, 1, -84)
list.Position = UDim2.fromOffset(18, 70)
list.BackgroundColor3 = Theme.PanelDark
list.BorderSizePixel = 0
list.ScrollBarThickness = 8
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = panel
UI.corner(list, 12)
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.Name
listLayout.Parent = list
local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 6)
listPadding.PaddingLeft = UDim.new(0, 6)
listPadding.PaddingRight = UDim.new(0, 14)
listPadding.Parent = list
local emptyText = UI.label(list, "Nobody else is here yet", UDim2.new(1, 0, 0, 30), UDim2.new())

-- selected player + actions (right)
local side = Instance.new("Frame")
side.BackgroundTransparency = 1
side.Size = UDim2.new(1, -324, 1, -84)
side.Position = UDim2.fromOffset(306, 70)
side.Parent = panel

local avatar = Instance.new("ImageLabel")
avatar.BackgroundColor3 = Theme.PanelDark
avatar.Size = UDim2.fromOffset(80, 80)
avatar.Position = UDim2.fromOffset(0, 0)
avatar.Image = ""
avatar.Parent = side
UI.corner(avatar, 40)
UI.stroke(avatar, 3, Theme.Yellow)
local selectedLabel = UI.label(side, "Pick a player", UDim2.new(1, -92, 0, 34), UDim2.fromOffset(92, 6))
selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
local selectedSub = UI.label(side, "from the list", UDim2.new(1, -92, 0, 26), UDim2.fromOffset(92, 44), Color3.fromRGB(190, 200, 230))
selectedSub.TextXAlignment = Enum.TextXAlignment.Left

local actionButtons: { TextButton } = {}
local function actionButton(text: string, color: Color3, y: number, onClick: () -> ()): TextButton
	local b = UI.button(side, text, color, onClick)
	b.Size = UDim2.new(1, 0, 0, 48)
	b.Position = UDim2.fromOffset(0, y)
	table.insert(actionButtons, b)
	return b
end

-- ============================ spectating ============================
local spectateBar = UI.panel(root, UDim2.fromOffset(420, 64), UDim2.new(0.5, 0, 1, -110), Theme.PanelDark)
spectateBar.Visible = false
local spectateText = UI.label(spectateBar, "", UDim2.new(1, -150, 1, -20), UDim2.fromOffset(14, 10))
spectateText.TextXAlignment = Enum.TextXAlignment.Left

local function setCameraTo(target: Player?)
	local camera = Workspace.CurrentCamera
	local character = (target or player).Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if camera and humanoid then
		camera.CameraSubject = humanoid
	end
end

local spectateButton: TextButton
local function stopSpectating()
	if not spectating then
		return
	end
	spectating = nil
	setCameraTo(nil)
	spectateBar.Visible = false
	UI.setText(spectateButton, "👀 SPECTATE")
end

local stopButton = UI.button(spectateBar, "STOP", Theme.Red, stopSpectating)
stopButton.Size = UDim2.fromOffset(120, 44)
stopButton.Position = UDim2.new(1, -132, 0, 10)

local function startSpectating(target: Player)
	spectating = target
	setCameraTo(target)
	spectateText.Text = "👀 Spectating " .. target.DisplayName
	spectateBar.Visible = true
	Vfx.pop(spectateBar)
	UI.setText(spectateButton, "🔙 STOP SPECTATING")
end

-- keep watching them after they respawn; stop if they leave
Players.PlayerRemoving:Connect(function(p)
	if p == spectating then
		stopSpectating()
		UI.notify(p.DisplayName .. " left the game", Theme.Blue)
	end
end)
task.spawn(function()
	while true do
		task.wait(0.5)
		if spectating then
			local camera = Workspace.CurrentCamera
			local character = spectating.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if camera and humanoid and camera.CameraSubject ~= humanoid then
				camera.CameraSubject = humanoid
			end
		end
	end
end)
player.CharacterAdded:Connect(function()
	-- respawning resets the camera to yourself
	if spectating then
		task.wait(0.2)
		setCameraTo(spectating)
	end
end)

-- ============================ selecting ============================
local rows: { [Player]: TextButton } = {}

local function updateSelected()
	for p, rowButton in pairs(rows) do
		local stroke = rowButton:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = p == selected and Theme.Yellow or Theme.Outline
			stroke.Thickness = p == selected and 4 or 2
		end
	end
	if selected then
		avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. selected.UserId .. "&w=150&h=150"
		selectedLabel.Text = selected.DisplayName
		selectedSub.Text = "@" .. selected.Name
	else
		avatar.Image = ""
		selectedLabel.Text = "Pick a player"
		selectedSub.Text = "from the list"
	end
	for _, b in ipairs(actionButtons) do
		b.BackgroundTransparency = selected and 0 or 0.5
	end
end

local function addRow(p: Player)
	if p == player or rows[p] then
		return
	end
	local rowButton = Instance.new("TextButton")
	rowButton.Name = p.DisplayName:lower()
	rowButton.AutoButtonColor = true
	rowButton.Text = ""
	rowButton.Size = UDim2.new(1, 0, 0, 48)
	rowButton:SetAttribute("ClickSfx", true)
	rowButton.BackgroundColor3 = Theme.Panel
	UI.corner(rowButton, 10)
	UI.stroke(rowButton, 2)
	local face = Instance.new("ImageLabel")
	face.BackgroundTransparency = 1
	face.Size = UDim2.fromOffset(40, 40)
	face.Position = UDim2.fromOffset(4, 4)
	face.Image = "rbxthumb://type=AvatarHeadShot&id=" .. p.UserId .. "&w=48&h=48"
	face.Parent = rowButton
	UI.corner(face, 20)
	local name = UI.label(rowButton, p.DisplayName, UDim2.new(1, -60, 0, 30), UDim2.fromOffset(52, 9))
	name.TextXAlignment = Enum.TextXAlignment.Left
	rowButton.Activated:Connect(function()
		Sfx.play("Click")
		selected = p
		updateSelected()
	end)
	rowButton.Parent = list
	rows[p] = rowButton
	emptyText.Visible = false
end

local function removeRow(p: Player)
	local rowButton = rows[p]
	if rowButton then
		rowButton:Destroy()
		rows[p] = nil
	end
	if selected == p then
		selected = nil
		updateSelected()
	end
	emptyText.Visible = next(rows) == nil
end

for _, p in ipairs(Players:GetPlayers()) do
	addRow(p)
end
Players.PlayerAdded:Connect(addRow)
Players.PlayerRemoving:Connect(removeRow)

-- ============================ actions ============================
local function needTarget(): Player?
	if not selected or selected.Parent ~= Players then
		Sfx.play("Error")
		UI.notify("Pick a player first", Theme.Red)
		return nil
	end
	return selected
end

spectateButton = actionButton("👀 SPECTATE", Theme.Blue, 92, function()
	if spectating then
		stopSpectating()
		return
	end
	local target = needTarget()
	if target then
		startSpectating(target)
		UI.close(panel)
	end
end)
actionButton("💀 KILL  R$" .. Products.TrollKill.Price, Theme.Red, 148, function()
	local target = needTarget()
	if target then
		remote:FireServer("Kill", target)
	end
end)
actionButton("🌀 FLING  R$" .. Products.TrollFling.Price, Theme.Purple, 204, function()
	local target = needTarget()
	if target then
		remote:FireServer("Fling", target)
	end
end)
actionButton("👊 PUSH  R$" .. Products.TrollPush.Price, Theme.Pink, 260, function()
	local target = needTarget()
	if target then
		remote:FireServer("Push", target)
	end
end)
updateSelected()

UI.sideButton("😈", "TROLL", Theme.Red, 3, function()
	UI.toggle(panel)
end)

-- ============================ results ============================
local VERBS = { Kill = "killed", Fling = "flung", Push = "pushed" }
local COLORS = { Kill = Theme.Red, Fling = Theme.Purple, Push = Theme.Pink }

remote.OnClientEvent:Connect(function(kind, a, b, c, d)
	if kind == "Status" then
		if a == "Cooldown" then
			Sfx.play("Error")
			UI.notify("Slow down! Wait a few seconds", Theme.Red)
		elseif a == "Invalid" then
			Sfx.play("Error")
			UI.notify("You can't troll them right now (AFK or respawning)", Theme.Red)
		elseif a == "NotSetUp" then
			UI.notify("Coming soon!", Theme.Purple)
		elseif a == "NoData" then
			UI.notify("Your data is still loading - try again in a moment", Theme.Red)
		end
	elseif kind == "Done" then
		local actor: Player, target: Player, action: string, position: Vector3 = a, b, c, d
		local color = COLORS[action] or Theme.Red
		Vfx.burst(position, color, 35)
		Vfx.ring(position, color, 16)
		Sfx.playAt(action, position)
		if target == player then
			Vfx.flash(color, 0.35)
			UI.notify(string.format("%s %s you!", actor.DisplayName, VERBS[action] or "trolled"), color)
		elseif actor == player then
			Sfx.play("Purchase")
			UI.notify(string.format("You %s %s!", VERBS[action] or "trolled", target.DisplayName), color)
		end
	end
end)
