-- Leaderboards (server)
-- Three global leaderboards (all servers, saved forever): Most Money, Most Playtime
-- and Most Wins. They refresh on their own every minute.
--
-- WHERE THEY GO: make a Folder in Workspace called "Leaderboards" with three
-- anchored Parts called "MoneyBoard", "PlaytimeBoard" and "WinsBoard". Each board is
-- drawn on its part's Front face. If the folder isn't there, the boards are built
-- next to the spawn plate automatically (Config.Leaderboards.AutoOffset).

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("GameKit"):WaitForChild("Config"))
local Money = require(script.Parent:WaitForChild("Money"))
local Wins = require(script.Parent:WaitForChild("Wins"))
local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))

local Settings = Config.Leaderboards
local Theme = Config.Theme

local function formatMoney(n: number): string
	local units = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
	for _, u in ipairs(units) do
		if n >= u[1] then
			local v = n / u[1]
			local s = v >= 100 and string.format("%d", v) or string.format("%.1f", v)
			s = s:gsub("%.0$", "")
			return "$" .. s .. u[2]
		end
	end
	return "$" .. tostring(math.floor(n))
end

local function formatTime(seconds: number): string
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	if h > 0 then
		return string.format("%dh %dm", h, m)
	end
	return string.format("%dm", m)
end

type Board = {
	Name: string,
	Title: string,
	Color: Color3,
	Store: OrderedDataStore,
	Value: (Player) -> number?, -- nil = don't save (data not loaded)
	Format: (number) -> string,
	Rows: { Frame }?,
}

local boards: { Board } = {
	{
		Name = "MoneyBoard",
		Title = "💰 MOST MONEY",
		Color = Theme.Green,
		Store = DataStoreService:GetOrderedDataStore("LB_Money_v1"),
		Value = function(player)
			return Money.IsLoaded(player) and Money.Get(player) or nil
		end,
		Format = formatMoney,
	},
	{
		Name = "PlaytimeBoard",
		Title = "⏱️ MOST PLAYTIME",
		Color = Theme.Blue,
		Store = DataStoreService:GetOrderedDataStore("LB_Playtime_v1"),
		Value = function(player)
			local data = PlayerStats.Get(player)
			return data and data.Playtime or nil
		end,
		Format = formatTime,
	},
	{
		Name = "WinsBoard",
		Title = "🏆 MOST WINS",
		Color = Theme.Yellow,
		Store = DataStoreService:GetOrderedDataStore("LB_Wins_v1"),
		Value = function(player)
			return Wins.IsLoaded(player) and Wins.Get(player) or nil
		end,
		Format = function(n)
			return tostring(math.floor(n))
		end,
	},
}

-- ============================ the board parts ============================
local function findOrBuildParts(): { [string]: BasePart }
	local parts = {}
	local folder = workspace:FindFirstChild("Leaderboards")
	if folder then
		for _, board in ipairs(boards) do
			local part = folder:FindFirstChild(board.Name)
			if part and part:IsA("BasePart") then
				parts[board.Name] = part
			end
		end
		if next(parts) then
			return parts
		end
	end

	-- nothing placed: build three boards near the spawn plate, facing it
	local spawnPad = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local center = spawnPad and spawnPad.Position or Vector3.zero
	local base = center + Settings.AutoOffset
	local look = Vector3.new(center.X - base.X, 0, center.Z - base.Z)
	if look.Magnitude < 0.1 then
		look = Vector3.new(0, 0, -1)
	end
	local facing = CFrame.lookAt(base, base + look.Unit)
	local model = Instance.new("Model")
	model.Name = "Leaderboards"
	for i, board in ipairs(boards) do
		local part = Instance.new("Part")
		part.Name = board.Name
		part.Anchored = true
		part.Size = Vector3.new(14, 18, 1)
		part.Color = Theme.PanelDark
		part.Material = Enum.Material.SmoothPlastic
		part.CFrame = facing * CFrame.new((i - 2) * 16, 11, 0)
		part.Parent = model
		local post = Instance.new("Part")
		post.Name = "Post"
		post.Anchored = true
		post.Size = Vector3.new(1.5, 3, 1.5)
		post.Color = Theme.Outline
		post.CFrame = part.CFrame * CFrame.new(0, -10.5, 0)
		post.Parent = model
		parts[board.Name] = part
	end
	model.Parent = workspace
	return parts
end

local function makeText(parent: Instance, text: string, size: UDim2, position: UDim2, align: Enum.TextXAlignment?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.Font = Theme.Font
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = Theme.Text
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = Theme.Outline
	s.Parent = l
	l.Parent = parent
	return l
end

local function buildGui(board: Board, part: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LeaderboardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = part

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Theme.PanelDark
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 10
	stroke.Color = board.Color
	stroke.Parent = bg

	local header = Instance.new("Frame")
	header.Size = UDim2.fromScale(1, 0.12)
	header.BackgroundColor3 = board.Color
	header.BorderSizePixel = 0
	header.Parent = bg
	makeText(header, board.Title, UDim2.fromScale(0.92, 0.8), UDim2.fromScale(0.04, 0.1))

	local rows = {}
	local rowHeight = 0.86 / Settings.Size
	for i = 1, Settings.Size do
		local row = Instance.new("Frame")
		row.Name = "Row" .. i
		row.Size = UDim2.new(0.94, 0, rowHeight, -6)
		row.Position = UDim2.new(0.03, 0, 0.13 + (i - 1) * rowHeight, 0)
		row.BackgroundColor3 = i % 2 == 0 and Theme.Panel or Color3.fromRGB(50, 55, 85)
		row.BorderSizePixel = 0
		row.Visible = false
		row.Parent = bg
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.2, 0)
		corner.Parent = row
		local rankColor = i == 1 and Theme.Yellow or i == 2 and Color3.fromRGB(210, 220, 235)
			or i == 3 and Color3.fromRGB(230, 150, 90) or Theme.Text
		local rank = makeText(row, "#" .. i, UDim2.fromScale(0.12, 0.8), UDim2.fromScale(0.01, 0.1))
		rank.TextColor3 = rankColor
		local avatar = Instance.new("ImageLabel")
		avatar.Name = "Avatar"
		avatar.BackgroundTransparency = 1
		avatar.Size = UDim2.fromScale(0.11, 0.9)
		avatar.Position = UDim2.fromScale(0.14, 0.05)
		avatar.Parent = row
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.Parent = avatar
		local name = makeText(row, "", UDim2.fromScale(0.42, 0.7), UDim2.fromScale(0.26, 0.15), Enum.TextXAlignment.Left)
		name.Name = "PlayerName"
		local value = makeText(row, "", UDim2.fromScale(0.3, 0.7), UDim2.fromScale(0.68, 0.15), Enum.TextXAlignment.Right)
		value.Name = "Value"
		value.TextColor3 = board.Color
		rows[i] = row
	end
	board.Rows = rows
end

-- ============================ saving & refreshing ============================
local names: { [number]: string } = {}
local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and name then
		names[userId] = name
		return name
	end
	return "Player"
end

local function savePlayer(player: Player)
	for _, board in ipairs(boards) do
		local value = board.Value(player)
		if value and value > 0 then
			pcall(function()
				board.Store:SetAsync(tostring(player.UserId), math.floor(value))
			end)
		end
	end
end

local function refresh(board: Board)
	local rows = board.Rows
	if not rows then
		return
	end
	local ok, page = pcall(function()
		return board.Store:GetSortedAsync(false, Settings.Size):GetCurrentPage()
	end)
	if not ok then
		return
	end
	for i, row in ipairs(rows) do
		local entry = page[i]
		if entry then
			local userId = tonumber(entry.key) or 0
			local nameLabel = row:FindFirstChild("PlayerName") :: TextLabel
			local valueLabel = row:FindFirstChild("Value") :: TextLabel
			local avatar = row:FindFirstChild("Avatar") :: ImageLabel
			nameLabel.Text = nameOf(userId)
			valueLabel.Text = board.Format(entry.value)
			avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. userId .. "&w=150&h=150"
			row.Visible = true
		else
			row.Visible = false
		end
	end
end

local parts = findOrBuildParts()
for _, board in ipairs(boards) do
	local part = parts[board.Name]
	if part then
		buildGui(board, part)
	end
end

Players.PlayerRemoving:Connect(savePlayer)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(savePlayer, player)
	end
	task.wait(2)
end)

task.spawn(function()
	while true do
		task.wait(Settings.SaveSeconds)
		for _, player in ipairs(Players:GetPlayers()) do
			savePlayer(player)
			task.wait(0.5) -- spread the requests out
		end
	end
end)

task.wait(10) -- give the first players time to load
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(savePlayer, player)
end
task.wait(3)
while true do
	for _, board in ipairs(boards) do
		task.spawn(refresh, board)
	end
	task.wait(Settings.RefreshSeconds)
end
