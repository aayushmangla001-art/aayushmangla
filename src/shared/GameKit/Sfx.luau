-- Sfx (client)
-- Plays the sounds listed in Config.Sounds.
--   Sfx.play("Click")                      -- on your screen
--   Sfx.playAt("GlassBreak", position)     -- in the world, quieter further away

local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Config = require(script.Parent:WaitForChild("Config"))

local Sfx = {}

local templates: { [string]: Sound } = {}

local function template(name: string): Sound?
	local info = Config.Sounds[name]
	if not info or (info.Volume or 1) <= 0 then
		return nil
	end
	local sound = templates[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "Sfx_" .. name
		sound.SoundId = info.Id
		sound.Volume = info.Volume or 0.5
		sound.PlaybackSpeed = info.Speed or 1
		templates[name] = sound
	end
	return sound
end

-- plays on the player's screen (not in the world)
function Sfx.play(name: string, speedMultiplier: number?)
	local base = template(name)
	if not base then
		return
	end
	local sound = base:Clone()
	sound.PlaybackSpeed = base.PlaybackSpeed * (speedMultiplier or 1)
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 8)
end

-- plays at a point in the world
function Sfx.playAt(name: string, position: Vector3, speedMultiplier: number?)
	local base = template(name)
	if not base then
		return
	end
	local holder = Instance.new("Part")
	holder.Name = "SfxPoint"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.CFrame = CFrame.new(position)
	local sound = base:Clone()
	sound.PlaybackSpeed = base.PlaybackSpeed * (speedMultiplier or 1)
	sound.RollOffMinDistance = 15
	sound.RollOffMaxDistance = 150
	sound.Parent = holder
	holder.Parent = workspace
	sound:Play()
	Debris:AddItem(holder, 8)
end

-- every sound id, for the loading screen to preload
function Sfx.allIds(): { string }
	local list = {}
	for _, info in pairs(Config.Sounds) do
		table.insert(list, info.Id)
	end
	return list
end

return Sfx
