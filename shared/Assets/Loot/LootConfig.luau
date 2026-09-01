local ReplicatedStorage = game:GetService("ReplicatedStorage")

--------------------------------------------------
-- Assets -- 
--------------------------------------------------

local Assets = ReplicatedStorage:WaitForChild("Assets")
local LootAssets = Assets:WaitForChild("Loot")

--------------------------------------------------
-- TYPES -- 
--------------------------------------------------

export type LootDefinition = {
	displayName: string,
	rollChance: number,
	rarity: LootRarity,
}

export type RarityDefinition = {
	rollChance: number,
	multiplier: number
}

export type LootRarity = "Common" | "Uncommon" | "Rare" | "Legendary" | "Mythical"

local LootDefinitions: {[string]: LootDefinition} = {
	
	["Soda"] = {
		displayName = "Soda",
		rollChance = 0.99,
		rarity = "Common"
	},
	
	
} 

local RarityDefinitions: {[LootRarity]: RarityDefinition} = {
	
	["Common"] = {
		rollChance = 0.5,
		multiplier = 2,
	},
	
	
	
}

return {
	LootDefinitions = LootDefinitions,
	RarityDefinitions = RarityDefinitions
}
