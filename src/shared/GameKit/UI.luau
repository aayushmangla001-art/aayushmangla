-- UI (client)
-- Builds every new menu in the same style (rounded, bold outlined text, bright
-- colours) and keeps it a good size on phones, tablets and PCs.
--   UI.screen("Name")                         a ScreenGui that scales with the screen
--   UI.panel(parent, size, position)          a rounded panel
--   UI.button(parent, text, color, onClick)   a bouncy button with a click sound
--   UI.label(parent, text, size, position)    outlined text
--   UI.notify(text, color)                    small message at the top of the screen
--   UI.popup({...})                           centred pop-up with buttons
--   UI.money(n) / UI.time(seconds)            "$1.2K" / "3h 12m"

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameKit = script.Parent
local Config = require(GameKit:WaitForChild("Config"))
local Sfx = require(GameKit:WaitForChild("Sfx"))
local Vfx = require(GameKit:WaitForChild("Vfx"))

local Theme = Config.Theme
local player = Players.LocalPlayer

local UI = {}
UI.Theme = Theme

-- ============================ scaling ============================
-- Everything is designed for a 1280x720 screen and scaled to fit the real one.
local scales: { UIScale } = {}
local function currentScale(): number
	local camera = Workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
	return math.clamp(math.min(size.X / 1280, size.Y / 720), 0.55, 1.4)
end
local function rescale()
	local s = currentScale()
	for _, scale in ipairs(scales) do
		scale.Scale = s
	end
end
local function watchCamera()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
	rescale()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

-- A ScreenGui holding one full-screen "Root" frame that is scaled. Put things in Root.
function UI.screen(name: string, displayOrder: number?): (ScreenGui, Frame)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder or 5
	gui.Parent = player:WaitForChild("PlayerGui")
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	-- the root is sized in "design pixels" so the UIScale can shrink/grow it evenly
	local scale = Instance.new("UIScale")
	scale.Parent = root
	table.insert(scales, scale)
	local function fit()
		local s = currentScale()
		scale.Scale = s
		root.Size = UDim2.fromOffset(gui.AbsoluteSize.X / s, gui.AbsoluteSize.Y / s)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	return gui, root
end

-- ============================ building blocks ============================
function UI.corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 14)
	c.Parent = parent
	return c
end

function UI.stroke(parent: Instance, thickness: number?, color: Color3?)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 3
	s.Color = color or Theme.Outline
	s.ApplyStrokeMode = parent:IsA("TextLabel") and Enum.ApplyStrokeMode.Contextual or Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

-- light-to-dark shine used on every button and panel
function UI.shine(parent: Instance)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))
	g.Parent = parent
	return g
end

function UI.panel(parent: Instance, size: UDim2, position: UDim2?, color: Color3?): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = position or UDim2.fromScale(0.5, 0.5)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BackgroundColor3 = color or Theme.Panel
	f.BorderSizePixel = 0
	UI.corner(f, 18)
	UI.stroke(f, 4)
	f.Parent = parent
	return f
end

function UI.label(parent: Instance, text: string, size: UDim2, position: UDim2?, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position or UDim2.new()
	l.Font = Theme.Font
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = color or Theme.Text
	l.RichText = true
	local s = Instance.new("UIStroke")
	s.Thickness = 2
	s.Color = Theme.Outline
	s.Parent = l
	l.Parent = parent
	return l
end

function UI.button(parent: Instance, text: string, color: Color3, onClick: (() -> ())?): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Text = ""
	b.Size = UDim2.fromOffset(160, 50)
	b:SetAttribute("ClickSfx", true) -- plays its own click (Effects skips it)
	UI.corner(b, 12)
	UI.stroke(b, 3)
	UI.shine(b)
	local l = UI.label(b, text, UDim2.new(1, -12, 1, -10), UDim2.fromOffset(6, 5))
	l.Name = "Label"
	local scale = Instance.new("UIScale")
	scale.Name = "PopScale"
	scale.Parent = b
	b.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.06 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	b.Activated:Connect(function()
		Sfx.play("Click")
		Vfx.pop(b)
		if onClick then
			onClick()
		end
	end)
	b.Parent = parent
	return b
end

function UI.setText(button: GuiObject, text: string)
	local l = button:FindFirstChild("Label") :: TextLabel?
	if l then
		l.Text = text
	end
end

-- show / hide a panel with a bounce and a swoosh
function UI.open(frame: GuiObject)
	if frame.Visible then
		return
	end
	frame.Visible = true
	Sfx.play("Open")
	Vfx.pop(frame)
end

function UI.close(frame: GuiObject)
	if not frame.Visible then
		return
	end
	frame.Visible = false
	Sfx.play("Close")
end

function UI.toggle(frame: GuiObject)
	if frame.Visible then
		UI.close(frame)
	else
		UI.open(frame)
	end
end

-- ============================ side menu ============================
-- One column of round menu buttons on the right edge of the screen, shared by
-- every new feature, so the buttons never overlap each other.
local sideColumn: Frame? = nil
local function getSideColumn(): Frame
	if sideColumn and sideColumn.Parent then
		return sideColumn
	end
	local _, root = UI.screen("SideMenu", 7)
	local column = Instance.new("Frame")
	column.Name = "Column"
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(1, 0.5)
	column.Position = UDim2.new(1, -12, 0.45, 0)
	column.Size = UDim2.fromOffset(86, 330)
	column.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = column
	sideColumn = column
	return column
end

-- adds a big round button with an icon and a caption to the side menu
function UI.sideButton(icon: string, caption: string, color: Color3, order: number, onClick: () -> ()): TextButton
	local b = UI.button(getSideColumn(), "", color, onClick)
	b.Size = UDim2.fromOffset(78, 78)
	b.LayoutOrder = order
	local corner = b:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0.5, 0)
	end
	local label = b:FindFirstChild("Label") :: TextLabel
	label.Text = icon
	label.Size = UDim2.new(1, -16, 0.6, 0)
	label.Position = UDim2.fromOffset(8, 6)
	local text = UI.label(b, caption, UDim2.new(1, 0, 0.3, 0), UDim2.new(0, 0, 0.64, 0))
	text.Name = "Caption"
	return b
end

-- ============================ text helpers ============================
function UI.money(n: number): string
	n = math.floor(n)
	local units = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
	for _, u in ipairs(units) do
		if n >= u[1] then
			local v = n / u[1]
			return "$" .. (v >= 100 and string.format("%d", v) or string.format("%.1f", v):gsub("%.0$", "")) .. u[2]
		end
	end
	return "$" .. tostring(n)
end

function UI.time(seconds: number): string
	seconds = math.floor(seconds)
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	if h > 0 then
		return string.format("%dh %dm", h, m)
	end
	return string.format("%dm", m)
end

-- ============================ notifications ============================
local notifyHolder: Frame? = nil
local function getNotifyHolder(): Frame
	if notifyHolder and notifyHolder.Parent then
		return notifyHolder
	end
	local _, root = UI.screen("GameNotifications", 40)
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 130)
	holder.Size = UDim2.fromOffset(520, 300)
	holder.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder
	notifyHolder = holder
	return holder
end

local notifyCount = 0
function UI.notify(text: string, color: Color3?, seconds: number?)
	local holder = getNotifyHolder()
	notifyCount += 1
	local box = Instance.new("Frame")
	box.LayoutOrder = notifyCount
	box.Size = UDim2.fromOffset(500, 44)
	box.BackgroundColor3 = color or Theme.Blue
	box.BorderSizePixel = 0
	UI.corner(box, 12)
	UI.stroke(box, 3)
	UI.shine(box)
	UI.label(box, text, UDim2.new(1, -20, 1, -10), UDim2.fromOffset(10, 5))
	box.Parent = holder
	Sfx.play("Notify")
	Vfx.pop(box)
	task.delay(seconds or 3.5, function()
		local fade = TweenInfo.new(0.3)
		for _, d in ipairs(box:GetDescendants()) do
			if d:IsA("TextLabel") then
				TweenService:Create(d, fade, { TextTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, fade, { Transparency = 1 }):Play()
			end
		end
		TweenService:Create(box, fade, { BackgroundTransparency = 1 }):Play()
		task.wait(0.3)
		box:Destroy()
	end)
end

-- ============================ pop-ups ============================
export type PopupButton = { Text: string, Color: Color3, OnClick: (() -> ())? }
export type PopupOptions = {
	Title: string,
	Body: string?,
	Color: Color3?,
	Buttons: { PopupButton },
	Seconds: number?, -- closes itself after this long (shows a countdown bar)
	OnTimeout: (() -> ())?,
}

local popupGui: Frame? = nil
local function getPopupRoot(): Frame
	if popupGui and popupGui.Parent then
		return popupGui
	end
	local _, root = UI.screen("GamePopups", 45)
	popupGui = root
	return root
end

-- returns a function that closes the pop-up
function UI.popup(options: PopupOptions): () -> ()
	local root = getPopupRoot()
	local panel = UI.panel(root, UDim2.fromOffset(440, 250), UDim2.fromScale(0.5, 0.5), options.Color or Theme.Panel)
	local title = UI.label(panel, options.Title, UDim2.new(1, -30, 0, 50), UDim2.fromOffset(15, 14))
	title.TextColor3 = Theme.Yellow
	if options.Body then
		UI.label(panel, options.Body, UDim2.new(1, -40, 0, 64), UDim2.fromOffset(20, 72))
	end
	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		panel:Destroy()
	end
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -30, 0, 56)
	row.Position = UDim2.new(0, 15, 1, -78)
	row.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 14)
	layout.Parent = row
	local width = math.min(190, (410 - 14 * (#options.Buttons - 1)) / #options.Buttons)
	for _, info in ipairs(options.Buttons) do
		local b = UI.button(row, info.Text, info.Color, function()
			close()
			if info.OnClick then
				info.OnClick()
			end
		end)
		b.Size = UDim2.fromOffset(width, 54)
	end
	if options.Seconds then
		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = Theme.Yellow
		bar.Position = UDim2.new(0, 18, 1, -14)
		bar.Size = UDim2.new(1, -36, 0, 6)
		UI.corner(bar, 3)
		bar.Parent = panel
		TweenService:Create(bar, TweenInfo.new(options.Seconds, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 6) }):Play()
		task.delay(options.Seconds, function()
			if not closed then
				close()
				if options.OnTimeout then
					options.OnTimeout()
				end
			end
		end)
	end
	Sfx.play("Popup")
	Vfx.pop(panel)
	return close
end

return UI
