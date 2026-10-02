-- RewardsUI (client)
-- * INVITE button: opens Roblox's invite-friends window
-- * Pop-up to claim $2,000 when one of your friends joins
-- * REWARDS menu: group reward and like reward (Speed Coil)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local GroupService = game:GetService("GroupService")

local GameKit = ReplicatedStorage:WaitForChild("GameKit")
local Config = require(GameKit:WaitForChild("Config"))
local Net = require(GameKit:WaitForChild("Net"))
local UI = require(GameKit:WaitForChild("UI"))
local Sfx = require(GameKit:WaitForChild("Sfx"))
local Vfx = require(GameKit:WaitForChild("Vfx"))

local player = Players.LocalPlayer
local Theme = Config.Theme
local events = Net.event("Rewards")
local requests = Net.func("RewardsRequest")

local function celebrate(text: string)
	Sfx.play("Reward")
	Vfx.confetti(50)
	Vfx.floatText(text, Theme.Green)
end

local function ask(action: string, arg: any?): (string, number?)
	local ok, status, extra = pcall(function()
		return requests:InvokeServer(action, arg)
	end)
	if not ok then
		return "Invalid", nil
	end
	return status, extra
end

-- ============================ invite ============================
local function openInvite()
	local ok, canInvite = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	if ok and canInvite then
		pcall(function()
			SocialService:PromptGameInvite(player)
		end)
	else
		Sfx.play("Error")
		UI.notify("Inviting isn't available on this account", Theme.Red)
	end
end

UI.sideButton("💌", "INVITE", Theme.Green, 1, openInvite)

events.OnClientEvent:Connect(function(kind, info)
	if kind ~= "InviteOffer" then
		return
	end
	UI.popup({
		Title = "FRIEND JOINED!",
		Body = string.format("%s joined your game!\nClaim your invite reward.", info.Name),
		Color = Theme.Panel,
		Buttons = {
			{
				Text = "CLAIM " .. UI.money(info.Amount),
				Color = Theme.Green,
				OnClick = function()
					local status = ask("ClaimInvite", info.UserId)
					if status == "Ok" then
						celebrate("+" .. UI.money(info.Amount))
					elseif status == "Claimed" then
						UI.notify("You already got the reward for this friend", Theme.Blue)
					elseif status == "NoData" then
						UI.notify("Your data is still loading - try again in a moment", Theme.Red)
					end
				end,
			},
		},
	})
end)

-- ============================ rewards menu ============================
local _, root = UI.screen("RewardsMenu", 8)
local panel = UI.panel(root, UDim2.fromOffset(600, 400), UDim2.fromScale(0.5, 0.5))
panel.Visible = false

UI.label(panel, "🎁 FREE REWARDS", UDim2.new(1, -120, 0, 46), UDim2.fromOffset(20, 12), Theme.Yellow).TextXAlignment =
	Enum.TextXAlignment.Left
local closeButton = UI.button(panel, "X", Theme.Red, function()
	UI.close(panel)
end)
closeButton.Size = UDim2.fromOffset(46, 46)
closeButton.Position = UDim2.new(1, -60, 0, 12)

local function card(index: number, icon: string, titleText: string, bodyText: string, color: Color3): Frame
	local f = Instance.new("Frame")
	f.Size = UDim2.new(0.5, -27, 1, -84)
	f.Position = UDim2.new((index - 1) * 0.5, index == 1 and 18 or 9, 0, 70)
	f.BackgroundColor3 = Theme.PanelDark
	f.Parent = panel
	UI.corner(f, 14)
	UI.stroke(f, 3, color)
	UI.label(f, icon, UDim2.new(1, 0, 0, 60), UDim2.fromOffset(0, 8))
	UI.label(f, titleText, UDim2.new(1, -20, 0, 34), UDim2.fromOffset(10, 70), color)
	local body = UI.label(f, bodyText, UDim2.new(1, -24, 0, 70), UDim2.fromOffset(12, 108), Color3.fromRGB(210, 220, 245))
	body.Name = "Body"
	return f
end

-- group card
local groupCard = card(1, "👥", "GROUP REWARD", "Join our group and get " .. UI.money(Config.Group.Reward) .. "!", Theme.Blue)
local joinButton = UI.button(groupCard, "JOIN GROUP", Theme.Blue, function()
	if Config.Group.GroupId == 0 then
		UI.notify("Coming soon!", Theme.Purple)
		return
	end
	pcall(function()
		GroupService:PromptJoinAsync(Config.Group.GroupId)
	end)
end)
joinButton.Size = UDim2.new(1, -24, 0, 44)
joinButton.Position = UDim2.new(0, 12, 1, -106)

local groupClaim: TextButton
groupClaim = UI.button(groupCard, "CLAIM", Theme.Green, function()
	local status = ask("ClaimGroup")
	if status == "Ok" then
		celebrate("+" .. UI.money(Config.Group.Reward))
		UI.setText(groupClaim, "CLAIMED ✔")
	elseif status == "Claimed" then
		UI.notify("You already claimed this reward", Theme.Blue)
	elseif status == "NotMember" then
		Sfx.play("Error")
		UI.notify("Join the group first, then claim!", Theme.Red)
	elseif status == "NotSetUp" then
		UI.notify("Coming soon!", Theme.Purple)
	elseif status == "NoData" then
		UI.notify("Your data is still loading - try again in a moment", Theme.Red)
	end
end)
groupClaim.Size = UDim2.new(1, -24, 0, 44)
groupClaim.Position = UDim2.new(0, 12, 1, -56)

-- like card
local likeCard = card(2, "👍", "LIKE REWARD", "Like the game and get a free SPEED COIL!", Theme.Pink)
local likeBody = likeCard:FindFirstChild("Body") :: TextLabel
local likeClaimed = false
local likeButton: TextButton
local likeReadyAt: number? = nil

local function likeTick()
	while likeReadyAt and not likeClaimed do
		local left = math.ceil(likeReadyAt - os.clock())
		if left <= 0 then
			UI.setText(likeButton, "CLAIM COIL")
			break
		end
		UI.setText(likeButton, "CLAIM IN " .. left)
		task.wait(0.5)
	end
end

likeButton = UI.button(likeCard, "👍 I'LL LIKE IT", Theme.Pink, function()
	if likeClaimed then
		UI.notify("You already have your Speed Coil reward", Theme.Blue)
		return
	end
	if not likeReadyAt then
		local status = ask("StartLike")
		if status ~= "Ok" then
			return
		end
		likeReadyAt = os.clock() + Config.Like.WaitSeconds
		likeBody.Text = "Open the Roblox menu (top-left) and tap 👍 to like the game, then claim!"
		task.spawn(likeTick)
		return
	end
	local status, left = ask("ClaimLike")
	if status == "Ok" then
		likeClaimed = true
		celebrate("SPEED COIL!")
		UI.setText(likeButton, "CLAIMED ✔")
		likeBody.Text = "Thanks for liking the game! The Speed Coil is yours."
	elseif status == "TooSoon" then
		UI.notify("Almost! Claim in " .. tostring(left) .. "s", Theme.Blue)
	elseif status == "Claimed" then
		likeClaimed = true
		UI.setText(likeButton, "CLAIMED ✔")
	elseif status == "NotSetUp" then
		UI.notify("Coming soon!", Theme.Purple)
	elseif status == "NoData" then
		UI.notify("Your data is still loading - try again in a moment", Theme.Red)
	end
end)
likeButton.Size = UDim2.new(1, -24, 0, 50)
likeButton.Position = UDim2.new(0, 12, 1, -62)

-- show what's already claimed
task.spawn(function()
	local ok, state = pcall(function()
		return requests:InvokeServer("State")
	end)
	if not ok or type(state) ~= "table" then
		return
	end
	if state.GroupClaimed then
		UI.setText(groupClaim, "CLAIMED ✔")
	end
	if state.LikeClaimed then
		likeClaimed = true
		UI.setText(likeButton, "CLAIMED ✔")
		likeBody.Text = "Thanks for liking the game! The Speed Coil is yours."
	end
	if not state.LikeEnabled then
		likeCard.Visible = false
	end
end)

UI.sideButton("🎁", "REWARDS", Theme.Yellow, 2, function()
	UI.toggle(panel)
end)
