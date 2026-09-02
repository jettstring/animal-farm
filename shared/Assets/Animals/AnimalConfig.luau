local ReplicatedStorage = game:GetService("ReplicatedStorage")

--------------------------------------------------
-- DEPENDENCIES -- 
--------------------------------------------------

local Assets = ReplicatedStorage:WaitForChild("Assets")
local AnimalAssets = Assets:WaitForChild("Animals")

--------------------------------------------------
-- TYPES -- 
--------------------------------------------------

export type AnimalDefinition = {
	displayName: string,
	rarity: AnimalRarity,
	odds: number,
}

export type AnimalRarity = "Common" | "Uncommon" | "Rare" | "Legendary" | "Mythical"


export type  MutationDefinition = {
	odds: number,
	multiplier: number
}

export type AnimalMutation = "Frozen" | "Galaxy" | "Rainbow" | "Admin"


local AnimalDefinitions: {[string]: AnimalDefinition} = {
	
	["Cow"] = {
		displayName = "Cow",
		rarity = "Common",
		odds = 0.8,
	},
	
	["Giraffe"] = {
		displayName = "Giraffe",
		rarity = "Uncommon",
		odds = 0.6,
	},
	
	["Elephant"] = {
		displayName = "Elephant",
		rarity = "Rare",
		odds = 0.4,
	},
	
	["Gorilla"] = {
		displayName = "Gorilla",
		rarity = "Rare",
		odds = 0.35,
	},
	
	["Lion"] = {
		displayName = "Lion",
		rarity = "Legendary",
		odds = 0.1,
	},
	
} 

local MutationDefinitions: {[AnimalMutation]: MutationDefinition} = {
	
	["Galaxy"] = {
		multiplier = 2,
		odds = 0.5,
	},
	
	
}

return {
	AnimalDefinitions = AnimalDefinitions,
	MutationDefinitions = MutationDefinitions
}
