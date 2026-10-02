-- Example LocalScript. Shows up in Studio as StarterPlayer.StarterPlayerScripts.Client.main

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Hello = require(ReplicatedStorage.Shared.Hello)

print(Hello.greet("client"))
