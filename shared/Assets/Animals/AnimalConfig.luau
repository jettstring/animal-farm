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
	eggEarnings: number, -- earnings per egg dropped
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
		eggEarnings = 1,
	},
	
	["Giraffe"] = {
		displayName = "Giraffe",
		rarity = "Uncommon",
		odds = 0.6,
		eggEarnings = 5,
	},
	
	["Elephant"] = {
		displayName = "Elephant",
		rarity = "Rare",
		odds = 0.4,
		eggEarnings = 20,
	},
	
	["Gorilla"] = {
		displayName = "Gorilla",
		rarity = "Rare",
		odds = 0.35,
		eggEarnings = 50,
	},
	
	["Lion"] = {
		displayName = "Lion",
		rarity = "Legendary",
		odds = 0.1,
		eggEarnings = 100,
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
