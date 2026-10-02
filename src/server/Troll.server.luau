-- Troll (server)
-- Kill / Fling / Push another player in the server (Robux, see Config.Products).
-- Spectating is done on the player's own screen and is free.
-- Checked here so nobody can cheat it:
--  * the target must be someone else in this server, alive, and not in the AFK area
--  * one action every few seconds per player (Config.Troll.Cooldown)
--  * nothing happens without paying (or a saved credit from an earlier purchase)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local GameKit = ReplicatedStorage:WaitForChild("GameKit")
local Config = require(GameKit:WaitForChild("Config"))
local Net = require(GameKit:WaitForChild("Net"))
local Purchases = require(script.Parent:WaitForChild("Purchases"))

local remote = Net.event("Troll")
local Settings = Config.Troll

local lastUse: { [Player]: number } = {}
local busy: { [Player]: boolean } = {}

local KEYS = { Kill = "TrollKill", Fling = "TrollFling", Push = "TrollPush" }

local function targetParts(target: Player): (Humanoid?, BasePart?)
	local character = target.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and root and humanoid.Health > 0 then
		return humanoid, root
	end
	return nil, nil
end

local function validTarget(actor: Player, target: any): boolean
	if typeof(target) ~= "Instance" or not target:IsA("Player") or target == actor or target.Parent ~= Players then
		return false
	end
	if target:GetAttribute("InAFK") then
		return false
	end
	local humanoid = targetParts(target)
	return humanoid ~= nil
end

-- a short, strong shove (the same way the slap gloves knock players back)
local function shove(root: BasePart, humanoid: Humanoid, velocity: Vector3, spin: boolean, stunSeconds: number)
	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
	bv.Velocity = velocity
	bv.Parent = root
	Debris:AddItem(bv, 0.2)
	if spin then
		local av = Instance.new("BodyAngularVelocity")
		av.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
		av.AngularVelocity = Vector3.new(math.random(-30, 30), math.random(-30, 30), math.random(-30, 30))
		av.Parent = root
		Debris:AddItem(av, 0.4)
	end
	humanoid.PlatformStand = true
	task.delay(stunSeconds, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
		end
	end)
end

local function doAction(actor: Player, action: string, target: Player): boolean
	if not validTarget(actor, target) then
		return false
	end
	local humanoid, root = targetParts(target)
	if not humanoid or not root then
		return false
	end
	local position = root.Position
	if action == "Kill" then
		humanoid.Health = 0
	elseif action == "Fling" then
		local angle = math.random() * math.pi * 2
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		shove(root, humanoid, dir * Settings.FlingPower + Vector3.new(0, Settings.FlingPower * 0.8, 0), true, 2.5)
	elseif action == "Push" then
		local actorRoot = actor.Character and actor.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local dir = actorRoot and (position - actorRoot.Position) * Vector3.new(1, 0, 1) or Vector3.zero
		dir = dir.Magnitude > 0.1 and dir.Unit or root.CFrame.LookVector
		shove(root, humanoid, dir * Settings.PushPower + Vector3.new(0, 25, 0), false, 1)
	else
		return false
	end
	lastUse[actor] = os.clock()
	remote:FireAllClients("Done", actor, target, action, position)
	return true
end

remote.OnServerEvent:Connect(function(actor, action, target)
	local key = type(action) == "string" and KEYS[action]
	if not key or busy[actor] then
		return
	end
	if os.clock() - (lastUse[actor] or 0) < Settings.Cooldown then
		remote:FireClient(actor, "Status", "Cooldown")
		return
	end
	busy[actor] = true
	local status = Purchases.useOrBuy(actor, key, function(p)
		return validTarget(p, target)
	end, function(p)
		return doAction(p, action, target)
	end)
	remote:FireClient(actor, "Status", status)
	task.wait(0.5)
	busy[actor] = nil
end)

Players.PlayerRemoving:Connect(function(player)
	lastUse[player] = nil
	busy[player] = nil
end)
