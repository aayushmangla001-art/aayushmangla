-- Purchases (server)
-- The game's single Robux purchase handler (Roblox allows only one).
--
-- Two kinds of products:
--  * Simple products (money packs): Purchases.registerProduct(id, function(player) ... end)
--  * Action products from Config.Products (Revive, Kill All, troll actions, ...):
--    buying one gives the player a saved "credit"; the action they clicked is then
--    done with it straight away. If the action can't happen any more (for example the
--    target left), the credit is kept and used the next time they click that button,
--    so nobody ever loses something they paid for.
--
--   Purchases.useOrBuy(player, "KillAll", check, use)
--     check(player) -> true if the action is allowed right now
--     use(player)   -> does the action, returns true if it happened
--   returns "Used", "Prompted", "Invalid", "NotSetUp" or "NoData"

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("GameKit"):WaitForChild("Config"))
local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))

local MAX_RECEIPTS = 50

local Purchases = {}

type Handler = (Player, any) -> boolean
type Pending = { key: string, use: (Player) -> boolean }

local simple: { [number]: Handler } = {}
local keyById: { [number]: string } = {}
for key, product in pairs(Config.Products) do
	if product.Id ~= 0 then
		keyById[product.Id] = key
	end
end
local pending: { [Player]: Pending } = {}

function Purchases.registerProduct(productId: number, handler: Handler)
	simple[productId] = handler
end

function Purchases.credits(player: Player, key: string): number
	local data = PlayerStats.Get(player)
	return data and (data.Credits[key] or 0) or 0
end

local function remember(data: PlayerStats.Data, receiptId: string)
	table.insert(data.Receipts, receiptId)
	while #data.Receipts > MAX_RECEIPTS do
		table.remove(data.Receipts, 1)
	end
end

-- spend one credit on the pending action (if there is one)
local function usePending(player: Player, key: string)
	local p = pending[player]
	local data = PlayerStats.Get(player)
	if not p or p.key ~= key or not data then
		return
	end
	pending[player] = nil
	if (data.Credits[key] or 0) > 0 and p.use(player) then
		data.Credits[key] -= 1
		task.spawn(PlayerStats.Save, player)
	end
end

function Purchases.useOrBuy(player: Player, key: string, check: (Player) -> boolean, use: (Player) -> boolean): string
	local data = PlayerStats.Get(player)
	if not data then
		return "NoData"
	end
	if not check(player) then
		return "Invalid"
	end
	if (data.Credits[key] or 0) > 0 then
		if use(player) then
			data.Credits[key] -= 1
			task.spawn(PlayerStats.Save, player)
			return "Used"
		end
		return "Invalid"
	end
	local product = Config.Products[key]
	if not product or product.Id == 0 then
		if RunService:IsStudio() then
			-- no product made yet: free in Studio so it can be tested
			return use(player) and "Used" or "Invalid"
		end
		return "NotSetUp"
	end
	pending[player] = { key = key, use = use }
	MarketplaceService:PromptProductPurchase(player, product.Id)
	return "Prompted"
end

MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, isPurchased)
	if isPurchased then
		return -- ProcessReceipt finishes the job
	end
	local player = Players:GetPlayerByUserId(userId)
	local p = player and pending[player]
	if player and p and keyById[productId] == p.key then
		pending[player] = nil
	end
end)

Players.PlayerRemoving:Connect(function(player)
	pending[player] = nil
end)

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		-- they left first; Roblox will try again next time they join
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = PlayerStats.Wait(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if table.find(data.Receipts, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already given
	end

	local handler = simple[receipt.ProductId]
	if handler then
		if not handler(player, receipt) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		remember(data, receipt.PurchaseId)
		task.spawn(PlayerStats.Save, player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local key = keyById[receipt.ProductId]
	if not key then
		warn("[Purchases] Unknown product " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	data.Credits[key] = (data.Credits[key] or 0) + 1
	remember(data, receipt.PurchaseId)
	if not PlayerStats.Save(player) then
		-- not saved: undo and let Roblox retry, so nothing is lost or doubled
		data.Credits[key] -= 1
		table.remove(data.Receipts, #data.Receipts)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	task.spawn(usePending, player, key)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

return Purchases
