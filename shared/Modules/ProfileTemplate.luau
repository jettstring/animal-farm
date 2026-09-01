local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileTemplate = {
	Money = 10000,
	
	baseData = {
		
	}:: BaseData,
	
	inventory = {
		loot = {} :: {[string]: LootData}
	},
}

export type BaseData = {
	floors: {[number]: FloorData}
}

export type FloorData = {
	shops: {[number]: ShopData}, 
	upgrades: { [string]: any}
}

export type ShopData = { }

export type LootData = {
	definitionKey: string,
	level: number,
	mutations: {string},
	floor: number?,
	slot: number?,
} 

export type ProfileTemplate = typeof(ProfileTemplate) 
return ProfileTemplate
