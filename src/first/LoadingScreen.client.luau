-- LoadingScreen (client, ReplicatedFirst)
-- Shows a loading screen the moment a player joins, loads the game's images,
-- sounds and meshes first (with a progress bar), then fades into the game.
-- A "Skip" button appears if loading takes a while.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- defaults (replaced by GameKit.Config.Loading once the game has loaded)
local settings = {
	Title = "GLASS BRIDGE",
	MinSeconds = 2,
	SkipAfterSeconds = 8,
	MaxSeconds = 25,
	Tips = { "Only one glass in each row is safe. Choose wisely!" },
}

local FONT = Enum.Font.FredokaOne
local OUTLINE = Color3.fromRGB(25, 25, 40)
local YELLOW = Color3.fromRGB(255, 200, 40)
local GREEN = Color3.fromRGB(70, 210, 90)

-- ============================ build the screen ============================
local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.Parent = playerGui
ReplicatedFirst:RemoveDefaultLoadingScreen()

local canvas = Instance.new("CanvasGroup")
canvas.Size = UDim2.fromScale(1, 1)
canvas.BackgroundColor3 = Color3.new(1, 1, 1)
canvas.BorderSizePixel = 0
canvas.Parent = gui
local bg = Instance.new("UIGradient")
bg.Rotation = 90
bg.Color = ColorSequence.new(Color3.fromRGB(40, 60, 140), Color3.fromRGB(90, 40, 140))
bg.Parent = canvas

local function text(parent: Instance, value: string, size: UDim2, position: UDim2, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Size = size
	l.Position = position
	l.Font = FONT
	l.Text = value
	l.TextScaled = true
	l.TextColor3 = color or Color3.new(1, 1, 1)
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = OUTLINE
	s.Parent = l
	l.Parent = parent
	return l
end

local title = text(canvas, settings.Title, UDim2.fromScale(0.8, 0.14), UDim2.fromScale(0.5, 0.28), YELLOW)
local titleScale = Instance.new("UIScale")
titleScale.Parent = title
TweenService:Create(titleScale, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.05 }):Play()

-- a row of glass tiles that light up one by one
local tiles = Instance.new("Frame")
tiles.BackgroundTransparency = 1
tiles.AnchorPoint = Vector2.new(0.5, 0.5)
tiles.Size = UDim2.fromScale(0.5, 0.08)
tiles.Position = UDim2.fromScale(0.5, 0.45)
tiles.Parent = canvas
local tileRatio = Instance.new("UIAspectRatioConstraint")
tileRatio.AspectRatio = 8
tileRatio.Parent = tiles
local tileLayout = Instance.new("UIListLayout")
tileLayout.FillDirection = Enum.FillDirection.Horizontal
tileLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tileLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tileLayout.Padding = UDim.new(0.02, 0)
tileLayout.Parent = tiles
local glass = {}
for i = 1, 6 do
	local t = Instance.new("Frame")
	t.Size = UDim2.fromScale(0.14, 0.9)
	t.BackgroundColor3 = Color3.fromRGB(170, 220, 255)
	t.BackgroundTransparency = 0.5
	t.LayoutOrder = i
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.15, 0)
	c.Parent = t
	local s = Instance.new("UIStroke")
	s.Thickness = 2
	s.Color = Color3.new(1, 1, 1)
	s.Parent = t
	t.Parent = tiles
	glass[i] = t
end

-- progress bar
local barBack = Instance.new("Frame")
barBack.AnchorPoint = Vector2.new(0.5, 0.5)
barBack.Size = UDim2.fromScale(0.5, 0.045)
barBack.Position = UDim2.fromScale(0.5, 0.6)
barBack.BackgroundColor3 = Color3.fromRGB(20, 22, 40)
barBack.Parent = canvas
local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(1, 0)
barCorner.Parent = barBack
local barStroke = Instance.new("UIStroke")
barStroke.Thickness = 3
barStroke.Color = OUTLINE
barStroke.Parent = barBack
local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = GREEN
barFill.Parent = barBack
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = barFill
local percent = text(barBack, "0%", UDim2.fromScale(0.3, 0.8), UDim2.fromScale(0.5, 0.5))

local status = text(canvas, "Loading...", UDim2.fromScale(0.5, 0.04), UDim2.fromScale(0.5, 0.67))
local tip = text(canvas, "", UDim2.fromScale(0.7, 0.045), UDim2.fromScale(0.5, 0.85), Color3.fromRGB(220, 230, 255))

local skip = Instance.new("TextButton")
skip.AnchorPoint = Vector2.new(0.5, 0.5)
skip.Size = UDim2.fromScale(0.14, 0.07)
skip.Position = UDim2.fromScale(0.5, 0.75)
skip.BackgroundColor3 = Color3.fromRGB(60, 150, 255)
skip.Text = ""
skip.Visible = false
skip.Parent = canvas
local skipRatio = Instance.new("UIAspectRatioConstraint")
skipRatio.AspectRatio = 3
skipRatio.Parent = skip
local skipCorner = Instance.new("UICorner")
skipCorner.CornerRadius = UDim.new(0.25, 0)
skipCorner.Parent = skip
local skipStroke = Instance.new("UIStroke")
skipStroke.Thickness = 3
skipStroke.Color = OUTLINE
skipStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
skipStroke.Parent = skip
text(skip, "SKIP", UDim2.fromScale(0.8, 0.7), UDim2.fromScale(0.5, 0.5))

local skipped = false
skip.Activated:Connect(function()
	skipped = true
end)

-- ============================ animations ============================
local running = true
task.spawn(function()
	local i = 0
	while running do
		i = i % #glass + 1
		local t = glass[i]
		t.BackgroundColor3 = GREEN
		t.BackgroundTransparency = 0.1
		TweenService:Create(t, TweenInfo.new(0.6), {
			BackgroundColor3 = Color3.fromRGB(170, 220, 255),
			BackgroundTransparency = 0.5,
		}):Play()
		task.wait(0.18)
	end
end)

task.spawn(function()
	local n = 0
	while running do
		local list = settings.Tips
		if #list > 0 then
			n = n % #list + 1
			tip.Text = "TIP: " .. list[n]
		end
		task.wait(4)
	end
end)

local shown = 0
local function setProgress(p: number)
	p = math.clamp(p, 0, 1)
	if p < shown then
		return
	end
	shown = p
	TweenService:Create(barFill, TweenInfo.new(0.25), { Size = UDim2.fromScale(p, 1) }):Play()
	percent.Text = math.floor(p * 100) .. "%"
end

-- ============================ loading ============================
local startTime = os.clock()
local function elapsed(): number
	return os.clock() - startTime
end

task.spawn(function()
	while running do
		if elapsed() >= settings.SkipAfterSeconds and not skip.Visible then
			skip.Visible = true
		end
		task.wait(0.25)
	end
end)

status.Text = "Joining the game..."
if not game:IsLoaded() then
	game.Loaded:Wait()
end
setProgress(0.1)

-- the real settings and sound list
local GameKit = ReplicatedStorage:WaitForChild("GameKit", 10)
local soundIds = {}
if GameKit then
	local okConfig, Config = pcall(function()
		return require(GameKit:WaitForChild("Config", 5) :: ModuleScript) :: any
	end)
	if okConfig and Config then
		for k, v in pairs(Config.Loading) do
			(settings :: any)[k] = v
		end
		title.Text = settings.Title
		for _, info in pairs(Config.Sounds) do
			table.insert(soundIds, info.Id)
		end
	end
end

-- everything worth loading before the player sees the game
status.Text = "Loading assets..."
local assets: { any } = {}
local function collect(root: Instance)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("ImageLabel") or d:IsA("ImageButton") or d:IsA("Decal") or d:IsA("Sound")
			or d:IsA("MeshPart") or d:IsA("SpecialMesh") or d:IsA("ParticleEmitter") or d:IsA("Animation") then
			table.insert(assets, d)
		end
	end
end
collect(playerGui)
collect(workspace)
collect(ReplicatedStorage)
for _, id in ipairs(soundIds) do
	table.insert(assets, id)
end

local BATCH = 25
local total = math.max(#assets, 1)
local done = 0
local finished = false
task.spawn(function()
	for i = 1, #assets, BATCH do
		if skipped then
			break
		end
		local batch = {}
		for j = i, math.min(i + BATCH - 1, #assets) do
			table.insert(batch, assets[j])
		end
		pcall(function()
			ContentProvider:PreloadAsync(batch)
		end)
		done += #batch
		setProgress(0.1 + 0.8 * done / total)
	end
	finished = true
end)

while not finished and not skipped and elapsed() < settings.MaxSeconds do
	task.wait(0.1)
end

status.Text = "Getting ready..."
setProgress(0.95)
local waitedForCharacter = 0
while not player.Character and not skipped and waitedForCharacter < 10 do
	waitedForCharacter += task.wait(0.1)
end
while elapsed() < settings.MinSeconds and not skipped do
	task.wait(0.1)
end
setProgress(1)
status.Text = "Let's go!"
task.wait(0.3)

-- ============================ fade into the game ============================
skip.Visible = false
TweenService:Create(title, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
	Position = UDim2.fromScale(0.5, -0.2),
}):Play()
local fade = TweenService:Create(canvas, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
	GroupTransparency = 1,
})
fade:Play()
fade.Completed:Wait()
running = false
gui:Destroy()
