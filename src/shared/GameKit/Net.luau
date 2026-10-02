-- Net (shared)
-- The remotes used by the new systems, kept together in ReplicatedStorage.GameRemotes.
-- The server creates them; clients wait for them.
--   Net.event("BridgeRevive")      -> RemoteEvent
--   Net.func("Rewards")            -> RemoteFunction

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()

local function getFolder(): Instance
	if not IS_SERVER then
		return ReplicatedStorage:WaitForChild("GameRemotes")
	end
	local existing = ReplicatedStorage:FindFirstChild("GameRemotes")
	if existing then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "GameRemotes"
	created.Parent = ReplicatedStorage
	return created
end
local folder = getFolder()

local function get(name: string, className: string): Instance
	if IS_SERVER then
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing
		end
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name)
end

local Net = {}

function Net.event(name: string): RemoteEvent
	return get(name, "RemoteEvent") :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	return get(name, "RemoteFunction") :: RemoteFunction
end

return Net
