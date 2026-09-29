local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Scribe = require(ReplicatedStorage.Packages.Scribe)


export type AnimalData = {
	definitionKey: string,
	level: number,
	mutation: string?,
}

export type StandData = {
	unlocked: boolean,
	occupant: AnimalData,
}

export type FloorData = {
	animalStands: { StandData }, -- dense: one entry per stand, locked or not
	upgrades: FloorUpgrades,
}

export type RollStandData = {
    upgrades: {},
	slotData: {[number]: AnimalData},
}


export type FloorUpgrades = {
    droneSpeed: number,
    eggYield: number,
    eggGrowSpeed: number
}


return {
    currency = { 
        Money = Scribe.Int(10_000, { Min = 0 })
    },

    inventory = {
        animals = Scribe.DictOf(Scribe.Int(0)),
    },

    index = {
        animals = {} :: { [string]: { string: boolean} },
    },
    
    base = {
        unlockedFloors = 1,
        crateValue = 0,
        eggsCollected = 0,
        
        floors = {} :: { FloorData }, -- dense: floors unlock sequentially
        
        rollStandData = {
            slotData = {},
            upgrades = {
                rollSlots = 2,
                rollLuck = 1,
            },
        },
    },
}