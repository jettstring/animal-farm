local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileTemplate = {
	currency = {
		["Money"] = 10_000,
	},
	
	base = {
		unlockedFloors = 0,
		
		floors = {
			--[1] = {
			--	animalStands = {
			--		--[1] = {
			--		--	occupant = {
			--		--		definitionKey = "Lion",
			--		--		level = 1,
			--		--		mutation = nil
			--		--	} :: AnimalData
			--		--} :: StandData
			--	},
			--	upgrades = {}
			--} :: FloorData
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
		animals = {} :: {[string]: number}
	},
}

export type BaseData = {
	unlockedFloors: number,
	floors: {[number]: FloorData},
	rollData: RollData,
}

export type RollData = {
	unlockedCount: number,
	rollLuck: number,
	slotData: {[number]: AnimalData},
}

export type FloorData = {
	animalStands: {[number]: StandData},  -- resolve unlocked stands by key existence
	upgrades: { [string]: any}
}

export type StandData = {
	unlocked: boolean,
	occupant: AnimalData,
}


export type AnimalData = {
	definitionKey: string,
	level: number,
	mutation: string,
} 

export type ProfileTemplate = typeof(ProfileTemplate) 
return ProfileTemplate
