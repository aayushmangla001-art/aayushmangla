-- SlapSwing (client)
-- Plays the slap: the right arm lifts out to the side and swings across in front,
-- like a real slap, instead of chopping downwards. Every player's screen animates
-- it locally, so it looks smooth for everyone. Works for R6 and R15 avatars.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameKit = ReplicatedStorage:WaitForChild("GameKit")
local Net = require(GameKit:WaitForChild("Net"))

local remote = Net.event("SlapSwing")

local RAISE = CFrame.Angles(0, 0, math.rad(90)) -- arm straight out to the side
local WIND_UP = math.rad(-35) -- pulled back a little
local FOLLOW = math.rad(110) -- swung across the front

local swinging: { [Motor6D]: boolean } = {}

local function shoulderOf(character: Model): Motor6D?
	local r15 = character:FindFirstChild("RightUpperArm")
	local joint = r15 and r15:FindFirstChild("RightShoulder")
	if not joint then
		local torso = character:FindFirstChild("Torso")
		joint = torso and torso:FindFirstChild("Right Shoulder")
	end
	return joint and joint:IsA("Motor6D") and joint or nil
end

-- the shoulder's C0 turned by a rotation measured in the torso's own directions
local function rotated(base: CFrame, rotation: CFrame): CFrame
	return CFrame.new(base.Position) * rotation * base.Rotation
end

-- 0..1 progress along the swing -> arm rotation
local function poseAt(t: number): CFrame
	local sweep
	if t < 0.3 then
		sweep = WIND_UP * (t / 0.3) -- lift and pull back
	elseif t < 0.55 then
		local k = (t - 0.3) / 0.25
		sweep = WIND_UP + (FOLLOW - WIND_UP) * (1 - (1 - k) ^ 3) -- fast slap
	else
		sweep = FOLLOW
	end
	return CFrame.Angles(0, sweep, 0) * RAISE
end

local function swing(character: Model)
	local joint = shoulderOf(character)
	if not joint or swinging[joint] then
		return
	end
	swinging[joint] = true
	local base = joint.C0
	local duration = 0.4
	local back = 0.2
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if not joint.Parent then
			connection:Disconnect()
			swinging[joint] = nil
			return
		end
		local elapsed = os.clock() - start
		if elapsed < duration then
			joint.C0 = rotated(base, poseAt(elapsed / duration))
		elseif elapsed < duration + back then
			-- ease the arm back down to where it was
			local k = (elapsed - duration) / back
			joint.C0 = rotated(base, poseAt(1)):Lerp(base, k)
		else
			joint.C0 = base
			connection:Disconnect()
			swinging[joint] = nil
		end
	end)
end

remote.OnClientEvent:Connect(function(character)
	if typeof(character) == "Instance" and character:IsA("Model") then
		swing(character)
	end
end)
