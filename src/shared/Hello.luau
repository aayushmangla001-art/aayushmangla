-- Example ModuleScript. Shows up in Studio as ReplicatedStorage.Shared.Hello
-- and can be required from both server and client scripts.

local Hello = {}

function Hello.greet(name: string): string
	return `Hello, {name}!`
end

return Hello
