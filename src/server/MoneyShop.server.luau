-- MoneyShop: gives money when a player buys a money pack with Robux.
-- Robux purchases are all handled by the Purchases module (Roblox allows only one
-- handler); this script tells it what each money pack gives.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Money = require(script.Parent:WaitForChild("Money"))
local Purchases = require(script.Parent:WaitForChild("Purchases"))
local PACKS = require(ReplicatedStorage:WaitForChild("MoneyShopConfig"))

for _, pack in ipairs(PACKS) do
	if pack.ProductId and pack.ProductId ~= 0 then
		local amount = pack.Amount
		Purchases.registerProduct(pack.ProductId, function(player)
			Money.Add(player, amount)
			return true
		end)
	end
end
