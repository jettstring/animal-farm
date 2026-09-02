local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileTemplate = {
	Money = 10000,
	
	base = {
		floors = {
			[1] = {
				
			} :: FloorData
		},
		rollStands = {
			
		}
	}:: BaseData,
	
	inventory = {
		animals = {} :: {[string]: AnimalData}
	},
}

export type BaseData = {
	floors: {[number]: FloorData},
	rollStands: {[number]: AnimalData},
}

export type FloorData = {
	animalStands: {[number]: AnimalStand},  -- resolve unlocked stands by key existence
	upgrades: { [string]: any}
}

export type AnimalStand = { }

export type AnimalData = {
	definitionKey: string,
	level: number,
	mutations: {string},
	floor: number?, -- resolve animal stand from floor/slot existence
	slot: number?,
} 

export type ProfileTemplate = typeof(ProfileTemplate) 
return ProfileTemplate
