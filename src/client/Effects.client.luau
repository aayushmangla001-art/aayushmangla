-- Effects (client)
-- Adds sounds and visual effects to the game's existing systems by listening to
-- the signals they already send. Each group can be switched off in Config.Effects.
--  * Glass bridge: safe step, glass breaking, falling, landing, finishing the bridge
--  * Wins, spin wheel ticks and prizes, portals, obby/maze chests
--  * Entering/leaving the AFK area, money gained/spent, button clicks

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameKit = ReplicatedStorage:WaitForChild("GameKit")
local Config = require(GameKit:WaitForChild("Config"))
local UI = require(GameKit:WaitForChild("UI"))
local Sfx = require(GameKit:WaitForChild("Sfx"))
local Vfx = require(GameKit:WaitForChild("Vfx"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Theme = Config.Theme
local On = Config.Effects

local GLASS_BLUE = Color3.fromRGB(170, 220, 255)

local function myRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- runs handler for a remote in ReplicatedStorage once it exists
local function listen(name: string, handler: (...any) -> ())
	task.spawn(function()
		local remote = ReplicatedStorage:WaitForChild(name, 60)
		if remote and remote:IsA("RemoteEvent") then
			remote.OnClientEvent:Connect(handler)
		end
	end)
end

-- ============================ glass bridge ============================
if On.GlassBridge then
	listen("GlassBridgeRemote", function(kind, tile, paid)
		if kind == "Correct" and typeof(tile) == "Instance" and tile:IsA("BasePart") then
			local top = tile.Position + Vector3.new(0, tile.Size.Y / 2 + 0.5, 0)
			Sfx.playAt("GlassSafe", top)
			Vfx.burst(top, Theme.Green, paid and 18 or 8)
		elseif kind == "Break" and typeof(tile) == "Instance" and tile:IsA("BasePart") then
			Sfx.playAt("GlassBreak", tile.Position)
			Vfx.burst(tile.Position, GLASS_BLUE, 40)
			local root = myRoot()
			if root and (root.Position - tile.Position).Magnitude < 10 then
				Sfx.play("Fall")
				Vfx.flash(Theme.Red, 0.3)
			end
		elseif kind == "Caught" then
			Sfx.play("Land")
			Vfx.flash(Color3.new(1, 1, 1), 0.4)
			task.delay(0.1, function()
				local root = myRoot()
				if root then
					Vfx.ring(root.Position - Vector3.new(0, 2.8, 0), Color3.new(1, 1, 1), 12)
				end
			end)
		end
	end)

	-- reaching the end of the bridge (the progress bar hits 100%)
	local finished = false
	player:GetAttributeChangedSignal("BridgeProgress"):Connect(function()
		local progress = player:GetAttribute("BridgeProgress") or 0
		if progress >= 0.99 and not finished then
			finished = true
			Sfx.play("Victory")
			Vfx.confetti(80)
			Vfx.flash(Theme.Yellow, 0.3)
			UI.notify("🎉 YOU CROSSED THE GLASS BRIDGE!", Theme.Green, 4)
			local root = myRoot()
			if root then
				Vfx.pillar(root.Position, Theme.Yellow)
			end
		elseif progress < 0.5 then
			finished = false
		end
	end)
end

-- ============================ wins ============================
if On.Wins then
	listen("WinRemote", function(kind)
		if kind == "Win" then
			Sfx.play("Victory")
			Vfx.confetti(60)
			local root = myRoot()
			if root then
				Vfx.burst(root.Position, Theme.Yellow, 50)
				Vfx.ring(root.Position - Vector3.new(0, 2.8, 0), Theme.Yellow, 20)
			end
		end
	end)
end

-- ============================ spin wheel ============================
if On.SpinWheel then
	local function wheelCenter(): Vector3?
		local wheel = workspace:FindFirstChild("wheel")
		if not wheel then
			return nil
		end
		if wheel:IsA("PVInstance") then
			return wheel:GetPivot().Position
		end
		local ring = wheel:FindFirstChild("SpinRing")
		return ring and ring:IsA("BasePart") and ring.Position or nil
	end
	listen("SpinWheelRemote", function(kind, info)
		if kind == "Spin" and type(info) == "table" then
			local center = wheelCenter()
			local turn = tonumber(info.Turn) or 1800
			local duration = tonumber(info.Duration) or 5.5
			-- one tick per slice passing the pointer, slowing down like the wheel
			local ticks = math.floor(turn / 45)
			task.spawn(function()
				local start = os.clock()
				for k = 1, ticks do
					local p = k / ticks
					local at = duration * (1 - math.sqrt(1 - p)) -- inverse of the wheel's ease-out
					local waitFor = start + at - os.clock()
					if waitFor > 0 then
						task.wait(waitFor)
					end
					if center then
						Sfx.playAt("WheelTick", center)
					end
				end
			end)
			if info.Spinner == player then
				Sfx.play("Purchase")
			end
		elseif kind == "Result" and type(info) == "table" then
			local center = wheelCenter()
			if center then
				Vfx.burst(center, Theme.Yellow, 45)
				Vfx.ring(center, Theme.Yellow, 24)
			end
			if info.Spinner == player then
				Sfx.play("Reward")
				local amount = tonumber(info.Amount) or 0
				if amount >= 2000 or info.PrizeId == "Gravity" or info.PrizeId == "Carpet" then
					Sfx.play("Victory")
					Vfx.confetti(60)
				end
			end
		end
	end)
end

-- ============================ portals & chests ============================
if On.Portals then
	listen("PortalRemote", function(kind, a, b, c)
		if kind == "Fade" then
			local color = typeof(a) == "Color3" and a or Theme.Purple
			Sfx.play("Portal")
			task.delay(0.2, function()
				local root = myRoot()
				if root then
					Vfx.pillar(root.Position, color)
				end
			end)
		elseif kind == "Reward" and On.Chests then
			Sfx.play("Victory")
			Vfx.confetti(50)
			local chest = c
			if typeof(chest) == "Instance" and chest:IsA("BasePart") then
				Vfx.burst(chest.Position, Theme.Yellow, 50)
			end
		elseif kind == "NoReward" then
			Sfx.play("Error")
		end
	end)
end

if On.Chests then
	listen("MazeChestRemote", function(kind)
		if kind == "Claimed" then
			Sfx.play("Reward")
			local root = myRoot()
			if root then
				Vfx.burst(root.Position, Theme.Yellow, 45)
			end
		elseif kind == "Wait" then
			Sfx.play("Error")
		end
	end)
end

-- ============================ AFK area ============================
if On.AFKArea then
	local wasInside = player:GetAttribute("InAFK") == true
	player:GetAttributeChangedSignal("InAFK"):Connect(function()
		local inside = player:GetAttribute("InAFK") == true
		if inside == wasInside then
			return
		end
		wasInside = inside
		Sfx.play("Area", inside and 1.2 or 0.9)
		local root = myRoot()
		if root then
			Vfx.ring(root.Position - Vector3.new(0, 2.8, 0), inside and Theme.Green or Theme.Blue, 14)
		end
	end)
end

-- ============================ money ============================
if On.MoneyPopups then
	local last = player:GetAttribute("Money") or 0
	local loadedAt = os.clock() + 8 -- don't celebrate the saved money loading in
	player:GetAttributeChangedSignal("Money"):Connect(function()
		local now = player:GetAttribute("Money") or 0
		local change = now - last
		last = now
		if os.clock() < loadedAt or change == 0 then
			return
		end
		if change > 0 then
			-- the AFK area pays every second: keep that quiet
			if player:GetAttribute("InAFK") and change <= 10 then
				return
			end
			Sfx.play("Cash")
			Vfx.floatText("+" .. UI.money(change), Theme.Green, UDim2.fromScale(0.15, 0.55))
		else
			Sfx.play("Purchase")
			Vfx.floatText("-" .. UI.money(-change), Theme.Red, UDim2.fromScale(0.15, 0.55))
		end
	end)
end

-- ============================ button clicks ============================
if On.ButtonClicks then
	local hooked = setmetatable({}, { __mode = "k" })
	local function hook(d: Instance)
		if d:IsA("GuiButton") and not hooked[d] and not d:GetAttribute("ClickSfx") then
			hooked[d] = true
			d.Activated:Connect(function()
				if not d:GetAttribute("ClickSfx") then
					Sfx.play("Click")
				end
			end)
		end
	end
	for _, d in ipairs(playerGui:GetDescendants()) do
		hook(d)
	end
	playerGui.DescendantAdded:Connect(function(d)
		task.defer(hook, d) -- after our own scripts have marked their buttons
	end)
end
