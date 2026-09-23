export type AnimalDefinition = {
	displayName: string,
	rarity: string?,
	odds: number,
	price: number, -- price of the animal
	eggEarnings: number, -- earnings per egg dropped
	eggGrowTime: number, -- time for egg to grow
	nonRollable: boolean? -- if the animal cannot be rolled for
}

export type  MutationDefinition = {
	odds: number,
	multiplier: number
}

export type AnimalMutation = "Frozen" | "Galaxy" | "Rainbow" | "Admin"

local AnimalDefinitions: {[string]: AnimalDefinition} = {
	
	["Cow"] = {
		displayName = "Cow",
		rarity = "Common",
		odds = 1/2,
		price = 10,
		eggEarnings = 1,
		eggGrowTime = 1,
	},
	
	["Giraffe"] = {
		displayName = "Giraffe",
		odds = 1/5,
		price = 50,
		eggEarnings = 5,
		eggGrowTime = 2,
	},
	
	["Elephant"] = {
		displayName = "Elephant",
		odds = 1/6,
		price = 200,
		eggEarnings = 20,
		eggGrowTime = 3,
	},
	
	["Gorilla"] = {
		displayName = "Gorilla",
		rarity = "Rare",
		odds = 1/12,
		price = 500,
		eggEarnings = 50,
		eggGrowTime = 3,	
	},
	
	["Lion"] = {
		displayName = "Lion",
		odds = 1/20,
		price = 1000,
		eggEarnings = 100,
		eggGrowTime = 4,
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
