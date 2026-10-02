-- BridgeState (server)
-- What the GlassBridge script knows, shared with the revive and bridge-button
-- scripts. Server only: the safe tiles must never reach players' computers
-- unless they paid for "Show Path".

local BridgeState = {}

BridgeState.ready = false
BridgeState.rows = {} :: { { BasePart } } -- each row's tiles, start to finish
BridgeState.safeTiles = {} :: { BasePart } -- the safe tile of every row
BridgeState.lastSafe = {} :: { [Player]: BasePart } -- last safe tile stepped on this try
BridgeState.minX = 0
BridgeState.maxX = 0
BridgeState.minZ = 0
BridgeState.maxZ = 0
BridgeState.lowestY = 0

-- Fired when a player fails the bridge: kind = "Glass" (wrong tile) or "Fall".
-- lastTile = the last safe tile they reached (nil if they hadn't reached one).
-- try = the tiles already paid this try (given back if they revive).
type FailListener = (player: Player, kind: string, lastTile: BasePart?, try: any) -> ()
local failListeners: { FailListener } = {}

function BridgeState.onFail(listener: FailListener)
	table.insert(failListeners, listener)
end

function BridgeState.fireFail(player: Player, kind: string, lastTile: BasePart?, try: any)
	for _, listener in ipairs(failListeners) do
		task.spawn(listener, player, kind, lastTile, try)
	end
end

-- set by GlassBridge: carries on a try after a revive (keeps the paid tiles)
function BridgeState.resumeTry(_player: Player, _try: any, _tile: BasePart) end

-- forget a player's progress (used by Skip to End)
function BridgeState.clearProgress(player: Player)
	BridgeState.lastSafe[player] = nil
end

function BridgeState.waitReady()
	while not BridgeState.ready do
		task.wait(0.2)
	end
end

-- is this position standing on (or just above) the main bridge?
function BridgeState.isOnBridge(position: Vector3): boolean
	if not BridgeState.ready then
		return false
	end
	return position.X >= BridgeState.minX - 4 and position.X <= BridgeState.maxX + 4
		and position.Z >= BridgeState.minZ - 4 and position.Z <= BridgeState.maxZ + 4
		and position.Y >= BridgeState.lowestY - 4
		and position.Y <= BridgeState.lowestY + 20
end

return BridgeState
