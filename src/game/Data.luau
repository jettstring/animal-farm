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
	upgrades: { [string]: number },
}

export type RollData = {
	unlockedCount: number,
	rollLuck: number,
	slotData: {[number]: AnimalData},
}

return Scribe({
    ProfileStoreIndex = "DEV-11",
    ProfileKeyPrefix = "", -- ["" .. UserId]
    Mode = "Live", -- Live / Mock / NoSave

    Template = {
        currency = { 
            Money = Scribe.Int(10_000, { Min = 0 })
        },

        inventory = {
            animals = Scribe.DictOf(Scribe.Int(0)),
        },

        index = {
            animals = {} :: { [string]: { [string]: boolean} },
        },
        
        base = {
            unlockedFloors = 1,
            crateValue = 0,
            eggsCollected = 0,
            floors = {} :: { FloorData }, -- dense: floors unlock sequentially
            rollData = {
                unlockedCount = 2,
                rollLuck = 1,
                slotData = {},
            },
    	},
	},

})