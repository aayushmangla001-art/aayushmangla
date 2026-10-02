-- MoneyShop: gives money when a player buys a money pack with Robux.
-- This is the game's only ProcessReceipt handler; if you add other Developer
-- Products later (like the 2x reward), handle them in this same function.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Money = require(script.Parent:WaitForChild("Money"))
local PACKS = require(ReplicatedStorage:WaitForChild("MoneyShopConfig"))

local packById = {}
for _, pack in ipairs(PACKS) do
	if pack.ProductId and pack.ProductId ~= 0 then
		packById[pack.ProductId] = pack
	end
end

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		-- they left before we could give it; Roblox will retry next time they join
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local pack = packById[receipt.ProductId]
	if not pack then
		warn("[MoneyShop] Unknown product " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Money.Add(player, pack.Amount)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
