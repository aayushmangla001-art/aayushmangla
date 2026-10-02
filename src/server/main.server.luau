-- Example server Script. Shows up in Studio as ServerScriptService.Server.main

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Hello = require(ReplicatedStorage.Shared.Hello)

print(Hello.greet("server"))
