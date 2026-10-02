-- Vfx (client)
-- A small set of effects reused everywhere, so the whole game feels consistent.
--   Vfx.burst(position, color)        sparkle burst
--   Vfx.ring(position, color)         glowing ring that grows and fades
--   Vfx.pillar(position, color)       beam of light (revives, teleports)
--   Vfx.flash(color)                  quick screen flash
--   Vfx.confetti()                    confetti falling over the screen
--   Vfx.floatText(text, color)        "+$100" style text that floats up the screen
--   Vfx.pop(guiObject)                bouncy pop for a button/panel

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(script.Parent:WaitForChild("Config"))

local Vfx = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local function anchorAt(position: Vector3): Part
	local part = Instance.new("Part")
	part.Name = "VfxPoint"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.CFrame = CFrame.new(position)
	part.Parent = workspace
	return part
end

function Vfx.burst(position: Vector3, color: Color3?, amount: number?)
	local holder = anchorAt(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE
	emitter.Rate = 0
	emitter.Color = ColorSequence.new(color or Config.Theme.Yellow)
	emitter.LightEmission = 1
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(12, 24)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 5
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	emitter.Parent = holder
	emitter:Emit(amount or 30)
	Debris:AddItem(holder, 1.5)
end

function Vfx.ring(position: Vector3, color: Color3?, size: number?)
	local ring = Instance.new("Part")
	ring.Name = "VfxRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = color or Config.Theme.Yellow
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.3, 2, 2)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	local final = size or 16
	TweenService:Create(ring, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, final, final),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.7)
end

function Vfx.pillar(position: Vector3, color: Color3?)
	local beam = Instance.new("Part")
	beam.Name = "VfxPillar"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.Material = Enum.Material.Neon
	beam.Color = color or Config.Theme.Green
	beam.Transparency = 0.3
	beam.Size = Vector3.new(6, 40, 6)
	beam.Shape = Enum.PartType.Cylinder
	beam.CFrame = CFrame.new(position + Vector3.new(0, 18, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = workspace
	TweenService:Create(beam, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(40, 0.2, 0.2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(beam, 0.9)
	Vfx.ring(position - Vector3.new(0, 2.5, 0), color, 14)
	Vfx.burst(position, color, 25)
end

-- screen effects live in one ScreenGui on top of everything
local overlay: ScreenGui? = nil
local function getOverlay(): ScreenGui
	if overlay and overlay.Parent then
		return overlay
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "VfxOverlay"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	overlay = gui
	return gui
end

function Vfx.flash(color: Color3?, strength: number?)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = color or Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 1 - (strength or 0.35)
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = 10
	frame.Parent = getOverlay()
	TweenService:Create(frame, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
	Debris:AddItem(frame, 0.5)
end

local CONFETTI_COLORS = {
	Config.Theme.Red, Config.Theme.Yellow, Config.Theme.Green,
	Config.Theme.Blue, Config.Theme.Purple, Config.Theme.Pink,
}

function Vfx.confetti(amount: number?)
	local gui = getOverlay()
	local rng = Random.new()
	for _ = 1, amount or 60 do
		local piece = Instance.new("Frame")
		piece.BorderSizePixel = 0
		piece.BackgroundColor3 = CONFETTI_COLORS[rng:NextInteger(1, #CONFETTI_COLORS)]
		piece.Size = UDim2.fromOffset(rng:NextInteger(8, 14), rng:NextInteger(12, 20))
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = UDim2.new(rng:NextNumber(0, 1), 0, 0, -20)
		piece.Rotation = rng:NextInteger(0, 360)
		piece.ZIndex = 9
		piece.Parent = gui
		local time = rng:NextNumber(1.6, 2.8)
		TweenService:Create(piece, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(piece.Position.X.Scale + rng:NextNumber(-0.15, 0.15), 0, 1.1, 0),
			Rotation = piece.Rotation + rng:NextInteger(-540, 540),
		}):Play()
		Debris:AddItem(piece, time + 0.1)
	end
end

function Vfx.floatText(text: string, color: Color3?, position: UDim2?)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = position or UDim2.fromScale(0.5, 0.42)
	label.Size = UDim2.fromScale(0.4, 0.07)
	label.Font = Config.Theme.Font
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color or Config.Theme.Green
	label.ZIndex = 11
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Config.Theme.Outline
	stroke.Parent = label
	label.Parent = getOverlay()
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = label
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(label, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = label.Position - UDim2.fromScale(0, 0.1),
		TextTransparency = 1,
	}):Play()
	TweenService:Create(stroke, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	Debris:AddItem(label, 1.3)
end

function Vfx.pop(object: GuiObject)
	local scale = object:FindFirstChild("PopScale") :: UIScale?
	if not scale then
		local newScale = Instance.new("UIScale")
		newScale.Name = "PopScale"
		newScale.Parent = object
		scale = newScale
	end
	assert(scale)
	scale.Scale = 0.85
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

return Vfx
