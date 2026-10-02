-- starts saving playtime and the other player stats as soon as the server starts
require(game:GetService("ServerScriptService"):WaitForChild("PlayerStats")).init()
