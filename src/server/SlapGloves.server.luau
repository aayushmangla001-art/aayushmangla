-- SlapGloves (server)
-- Makes every tool with the attribute "SlapPower" work as a slap glove.
-- The tools themselves have no scripts; everything is checked here on the server.
--   SlapPower    = how hard the slap knocks players back
--   SlapCooldown = seconds between slaps
--   SlapColor    = colour of the hit sparks (Rainbow = true for rainbow sparks)
-- Players in the AFK area (attribute InAFK) can't slap or be slapped.

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 50)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(70, 230, 100)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(70, 160, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 80, 255)),
})

local function hitSparks(position, tool)
	local a = Instance.new("Part")
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.Transparency = true, false, false, false, 1
	a.Size = Vector3.new(1, 1, 1)
	a.CFrame = CFrame.new(position)
	a.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.Color = tool:GetAttribute("Rainbow") and RAINBOW or ColorSequence.new(tool:GetAttribute("SlapColor") or Color3.new(1, 1, 1))
	e.LightEmission = 1
	e.Lifetime = NumberRange.new(0.3, 0.6)
	e.Speed = NumberRange.new(14, 26)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 4
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = a
	e:Emit(math.floor(12 + (tool:GetAttribute("SlapPower") or 40) / 4))
	Debris:AddItem(a, 1)
end

local function findVictim(player, character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local box = root.CFrame * CFrame.new(0, 0, -3.5)
	local best, bestDist
	for _, part in ipairs(workspace:GetPartBoundsInBox(box, Vector3.new(6, 7, 7), params)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local victim = model and Players:GetPlayerFromCharacter(model)
		local hum = model and model:FindFirstChildOfClass("Humanoid")
		local vRoot = model and model:FindFirstChild("HumanoidRootPart")
		if victim and victim ~= player and hum and hum.Health > 0 and vRoot and not victim:GetAttribute("InAFK") then
			local d = (vRoot.Position - root.Position).Magnitude
			if not bestDist or d < bestDist then best, bestDist = model, d end
		end
	end
	return best
end

local function slap(player, character, tool)
	local root = character:FindFirstChild("HumanoidRootPart")
	local victim = findVictim(player, character)
	if not root or not victim then return end
	local vRoot = victim.HumanoidRootPart
	local vHum = victim:FindFirstChildOfClass("Humanoid")
	local power = tool:GetAttribute("SlapPower") or 40
	local dir = (vRoot.Position - root.Position) * Vector3.new(1, 0, 1)
	dir = dir.Magnitude > 0.1 and dir.Unit or root.CFrame.LookVector
	-- knock back (and a little up)
	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
	bv.Velocity = dir * power + Vector3.new(0, power * 0.35, 0)
	bv.Parent = vRoot
	Debris:AddItem(bv, 0.18)
	vHum.PlatformStand = true
	task.delay(0.7, function()
		if vHum.Parent then vHum.PlatformStand = false end
	end)
	local tag = Instance.new("ObjectValue")
	tag.Name = "creator"
	tag.Value = player
	tag.Parent = vHum
	Debris:AddItem(tag, 3)
	hitSparks(vRoot.Position, tool)
	local handle = tool:FindFirstChild("Handle")
	local smack = handle and handle:FindFirstChild("Smack")
	if smack and smack:IsA("Sound") then pcall(function() smack:Play() end) end
end

local hooked = setmetatable({}, { __mode = "k" })
local function hook(tool)
	if hooked[tool] or not tool:IsA("Tool") or not tool:GetAttribute("SlapPower") then return end
	hooked[tool] = true
	local last = 0
	tool.Activated:Connect(function()
		local character = tool.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player or player:GetAttribute("InAFK") then return end
		local now = os.clock()
		if now - last < (tool:GetAttribute("SlapCooldown") or 1) then return end
		last = now
		-- Roblox's built-in swing animation (works for every avatar and morph)
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = "Slash"
		anim.Parent = tool
		Debris:AddItem(anim, 1)
		task.delay(0.12, function()
			if tool.Parent == character then slap(player, character, tool) end
		end)
	end)
end

-- tools get hooked the moment they're equipped (they move into the character)
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("Tool") then hook(d) end
end)
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("Tool") then hook(d) end
end
