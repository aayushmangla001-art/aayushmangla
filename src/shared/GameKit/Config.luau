-- Config (shared)
-- Every number, price and ID used by the new systems lives here, so you can
-- tune the game without touching any other script.
--
-- ROBUX PRODUCTS: create each one in the Creator Dashboard
--   (create.roblox.com > your game > Monetization > Developer Products),
-- then paste its ID below. While an ID is 0:
--   * in Studio the button works for free, so you can test it
--   * in the real game the button says "Coming soon" and does nothing

local Config = {}

Config.Products = {
	Revive = { Id = 0, Price = 9, Name = "Revive" },
	SkipToEnd = { Id = 0, Price = 49, Name = "Skip to End" },
	ShowPath = { Id = 0, Price = 29, Name = "Show Path" },
	KillAll = { Id = 0, Price = 99, Name = "Kill All" },
	TrollKill = { Id = 0, Price = 19, Name = "Kill" },
	TrollFling = { Id = 0, Price = 19, Name = "Fling" },
	TrollPush = { Id = 0, Price = 9, Name = "Push" },
}

-- Glass bridge revive
Config.Revive = {
	OfferSeconds = 12, -- how long the "Revive?" pop-up stays up
}

-- Glass bridge buttons
Config.BridgePowers = {
	ShowPathSeconds = 180, -- how long the safe path stays revealed
}

-- Troll menu
Config.Troll = {
	Cooldown = 3, -- seconds between troll actions from the same player
	FlingPower = 180,
	PushPower = 70,
}

-- Invite friends
Config.Invite = {
	Reward = 2000,
	MinFriendAccountAgeDays = 3, -- brand-new alt accounts don't count
}

-- Group reward: put your Roblox group's ID here (the number in the group's web address)
Config.Group = {
	GroupId = 0,
	Reward = 2000,
}

-- Like reward. Roblox doesn't let games check whether someone liked them, so
-- this is on trust: the player is asked to like the game, and can claim after a short wait.
Config.Like = {
	Enabled = true,
	WaitSeconds = 20,
	ToolName = "SpeedCoil",
	AssetId = 99119158, -- Roblox's Speed Coil gear (used if ServerStorage has no tool called SpeedCoil)
}

-- Global leaderboards
Config.Leaderboards = {
	Size = 10, -- players shown on each board
	RefreshSeconds = 60,
	SaveSeconds = 120,
	-- Where the boards go if you haven't placed your own (see the README):
	-- offset from the spawn plate, in studs
	AutoOffset = Vector3.new(0, 0, 40),
}

-- Loading screen
Config.Loading = {
	Title = "GLASS BRIDGE",
	MinSeconds = 2,
	SkipAfterSeconds = 8,
	MaxSeconds = 25,
	Tips = {
		"Only one glass in each row is safe. Choose wisely!",
		"Your first revive on the bridge is FREE!",
		"Invite a friend and get $2,000!",
		"Stand in the AFK area to earn money while you're away.",
		"Spin the wheel for a chance at $10,000!",
	},
}

-- One look for every new menu
Config.Theme = {
	Font = Enum.Font.FredokaOne,
	Text = Color3.fromRGB(255, 255, 255),
	Outline = Color3.fromRGB(25, 25, 40),
	Panel = Color3.fromRGB(40, 44, 70),
	PanelDark = Color3.fromRGB(28, 30, 50),
	Green = Color3.fromRGB(70, 210, 90),
	Blue = Color3.fromRGB(60, 150, 255),
	Red = Color3.fromRGB(240, 70, 80),
	Yellow = Color3.fromRGB(255, 200, 40),
	Purple = Color3.fromRGB(160, 90, 255),
	Pink = Color3.fromRGB(255, 100, 180),
	Robux = Color3.fromRGB(40, 190, 120),
}

-- Sound effects. These use sounds that come with Roblox itself, so they always
-- load. To use a sound from the Creator Store instead, replace Id with
-- "rbxassetid://NUMBER". Volume 0 turns a sound off.
Config.Sounds = {
	Click = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.6 },
	Open = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.35, Speed = 1.3 },
	Close = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.3, Speed = 0.9 },
	Popup = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.4, Speed = 1.6 },
	Notify = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.35, Speed = 1.4 },
	Purchase = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Speed = 0.8 },
	Reward = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Speed = 1.2 },
	Cash = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.25, Speed = 1.8 },
	Error = { Id = "rbxasset://sounds/button.wav", Volume = 0.5, Speed = 0.6 },
	GlassSafe = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.45, Speed = 2.2 },
	GlassBreak = { Id = "rbxasset://sounds/glassbreak.wav", Volume = 0.9 },
	Fall = { Id = "rbxasset://sounds/action_falling.mp3", Volume = 0.7 },
	Land = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 1 },
	Victory = { Id = "rbxasset://sounds/victory.wav", Volume = 0.6 },
	WheelTick = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.35, Speed = 1.4 },
	Portal = { Id = "rbxasset://sounds/Rocket whoosh 01.wav", Volume = 0.5, Speed = 1.2 },
	Area = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.3, Speed = 0.7 },
	Revive = { Id = "rbxasset://sounds/Launching rocket.wav", Volume = 0.4, Speed = 1.5 },
	Teleport = { Id = "rbxasset://sounds/Rocket whoosh 01.wav", Volume = 0.5, Speed = 1.5 },
	Kill = { Id = "rbxasset://sounds/splat.wav", Volume = 0.8 },
	Fling = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 0.8, Speed = 0.8 },
	Push = { Id = "rbxasset://sounds/hit.wav", Volume = 0.8 },
}

return Config
