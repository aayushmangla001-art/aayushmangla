-- Rewards (server)
-- * Invite friends: when one of your Roblox friends joins your server, you get a
--   pop-up to claim $2,000. Each friend only ever pays once (saved), so leaving and
--   rejoining doesn't work, and brand-new alt accounts don't count.
-- * Group reward: members of the game's group (Config.Group.GroupId) can claim once.
-- * Like reward: a Speed Coil, claimable once. Roblox doesn't let games check likes,
--   so the player has to open the like instructions and wait a few seconds first.
--   The coil is given back every time they join.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local GroupService = game:GetService("GroupService")

local GameKit = ReplicatedStorage:WaitForChild("GameKit")
local Config = require(GameKit:WaitForChild("Config"))
local Net = require(GameKit:WaitForChild("Net"))
local Money = require(script.Parent:WaitForChild("Money"))
local ItemGiver = require(script.Parent:WaitForChild("ItemGiver"))
local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))

local events = Net.event("Rewards")
local requests = Net.func("RewardsRequest")

local pendingInvites: { [Player]: { [number]: boolean } } = {}
local likeStarted: { [Player]: number } = {}
local busy: { [Player]: boolean } = {}

-- ============================ invites ============================
local function offerInvite(host: Player, friend: Player)
	local data = PlayerStats.Wait(host)
	if not data or not host.Parent or not friend.Parent then
		return
	end
	if data.InvitedFriends[tostring(friend.UserId)] then
		return -- already paid for this friend
	end
	pendingInvites[host] = pendingInvites[host] or {}
	pendingInvites[host][friend.UserId] = true
	events:FireClient(host, "InviteOffer", {
		UserId = friend.UserId,
		Name = friend.DisplayName,
		Amount = Config.Invite.Reward,
	})
end

Players.PlayerAdded:Connect(function(newcomer)
	task.wait(3)
	if not newcomer.Parent or newcomer.AccountAge < Config.Invite.MinFriendAccountAgeDays then
		return
	end
	for _, host in ipairs(Players:GetPlayers()) do
		if host ~= newcomer then
			task.spawn(function()
				local ok, isFriend = pcall(function()
					return host:IsFriendsWith(newcomer.UserId)
				end)
				if ok and isFriend then
					offerInvite(host, newcomer)
				end
			end)
		end
	end
end)

local function claimInvite(player: Player, friendId: any): string
	friendId = tonumber(friendId)
	local pending = pendingInvites[player]
	if not friendId or not pending or not pending[friendId] then
		return "Invalid"
	end
	local data = PlayerStats.Get(player)
	if not data then
		return "NoData"
	end
	pending[friendId] = nil
	local key = tostring(friendId)
	if data.InvitedFriends[key] then
		return "Claimed"
	end
	data.InvitedFriends[key] = true
	Money.Add(player, Config.Invite.Reward)
	task.spawn(PlayerStats.Save, player)
	return "Ok"
end

-- ============================ group ============================
local function inGroup(player: Player, groupId: number): boolean
	-- asks Roblox fresh, so joining the group during the session counts
	local ok, groups = pcall(function()
		return GroupService:GetGroupsAsync(player.UserId)
	end)
	if ok and groups then
		for _, g in ipairs(groups) do
			if g.Id == groupId then
				return true
			end
		end
		return false
	end
	local ok2, member = pcall(function()
		return player:IsInGroupAsync(groupId)
	end)
	return ok2 and member == true
end

local function claimGroup(player: Player): string
	local groupId = Config.Group.GroupId
	if groupId == 0 then
		return "NotSetUp"
	end
	local data = PlayerStats.Get(player)
	if not data then
		return "NoData"
	end
	if data.GroupClaimed then
		return "Claimed"
	end
	if not inGroup(player, groupId) then
		return "NotMember"
	end
	data.GroupClaimed = true
	Money.Add(player, Config.Group.Reward)
	task.spawn(PlayerStats.Save, player)
	return "Ok"
end

-- ============================ like ============================
local function makeCoil(): Tool?
	local fromStorage = ServerStorage:FindFirstChild(Config.Like.ToolName)
	if fromStorage then
		return ItemGiver.fromStorage(Config.Like.ToolName)()
	end
	return ItemGiver.fromAsset(Config.Like.AssetId)()
end

local function giveCoil(player: Player)
	ItemGiver.give(player, Config.Like.ToolName, makeCoil)
end

local function claimLike(player: Player): (string, number?)
	if not Config.Like.Enabled then
		return "NotSetUp"
	end
	local data = PlayerStats.Get(player)
	if not data then
		return "NoData"
	end
	if data.LikeClaimed then
		return "Claimed"
	end
	local started = likeStarted[player]
	if not started then
		return "NotStarted"
	end
	local left = Config.Like.WaitSeconds - (os.clock() - started)
	if left > 0 then
		return "TooSoon", math.ceil(left)
	end
	data.LikeClaimed = true
	giveCoil(player)
	task.spawn(PlayerStats.Save, player)
	return "Ok"
end

-- give the coil back every time someone who claimed it joins
Players.PlayerAdded:Connect(function(player)
	local data = PlayerStats.Wait(player)
	if not data or not data.LikeClaimed then
		return
	end
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	task.wait(1)
	if player.Parent then
		giveCoil(player)
	end
end)

-- ============================ requests from the menu ============================
requests.OnServerInvoke = function(player, action, arg)
	if action == "State" then
		local data = PlayerStats.Wait(player)
		return {
			Loaded = data ~= nil,
			GroupId = Config.Group.GroupId,
			GroupReward = Config.Group.Reward,
			GroupClaimed = data and data.GroupClaimed or false,
			LikeEnabled = Config.Like.Enabled,
			LikeClaimed = data and data.LikeClaimed or false,
			LikeWait = Config.Like.WaitSeconds,
			InviteReward = Config.Invite.Reward,
		}
	end
	if busy[player] then
		return "Busy"
	end
	busy[player] = true
	local ok, status, extra = pcall(function(): (string, number?)
		if action == "ClaimInvite" then
			return claimInvite(player, arg)
		elseif action == "ClaimGroup" then
			return claimGroup(player)
		elseif action == "StartLike" then
			if not likeStarted[player] then
				likeStarted[player] = os.clock()
			end
			return "Ok"
		elseif action == "ClaimLike" then
			return claimLike(player)
		end
		return "Invalid"
	end)
	busy[player] = nil
	if not ok then
		warn("[Rewards] " .. tostring(status))
		return "Invalid"
	end
	return status, extra
end

Players.PlayerRemoving:Connect(function(player)
	pendingInvites[player] = nil
	likeStarted[player] = nil
	busy[player] = nil
end)
