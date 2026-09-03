local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileTemplate = {
	Money = 10000,pbase
	
	base = {
		floors = {
			[1] = {
				
			} :: FloorData
		},
		
		rollData = {
			unlockedCount = 2,
			rollLuck = 1,
			slotData = {
				[1] = {
					definitionKey = "Lion"
				}
			}
		}
		
		
	}:: BaseData,
	
	inventory = {
		animals = {} :: {[string]: AnimalData}
	},
}

export type BaseData = {
	floors: {[number]: FloorData},
	rollData: RollData,
}

export type RollData = {
	unlockedCount: number,
	rollLuck: number,
	slotData: {[number]: AnimalData},
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
