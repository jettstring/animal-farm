local FLOOR_PRICE_EXP = 1.5

type UpgradeLevel = {
    maxLevels: number,
    priceExp: number,
    levels: { [number]: number },
}

local floorUpgrades = {

    droneSpeed = {
        maxLevels = 10,
        priceExp = 1.5,
        levels = {
            [2] = 100,
        }
    },

    eggYield = {
        maxLevels = 10,
        priceExp = 1.5,
        levels = {
            [2] = 100,
        }
    },

    eggGrowSpeed = {
        maxLevels = 10,
        priceExp = 1.5,
        levels = {
            [2] = 100,
        }
    }
} :: { [string]: UpgradeLevel }


local rollUpgrades = {

    rollSlots = {
       [2] = 100,
       [3] = 100,
       [4] = 100,
       [5] = 100,
       [6] = 100,
    },

    rollLuck = {
        maxLevels = 50,
        priceExp = 1.2,
        levels = {
            [2] = 100,
        }
    } :: UpgradeLevel
    
}

local floors = {
    [2] = {
        price = 100,
    },

    [3] = {
        price = 100,
    },

    [4] = {
        price = 100,
    },

    [5] = {
        price = 100,
    },

    [6] = {
        price = 100,
    },
    
    [7] = {
        price = 100,
    },
}


for upgradeName, upgradeEntry in floorUpgrades do
    for i = 2, upgradeEntry.maxLevels do
        upgradeEntry.levels[i] = upgradeEntry.levels[i] or math.floor((upgradeEntry.levels[i - 1] and upgradeEntry.levels[i - 1] or 100) * upgradeEntry.priceExp)
    end
end

for i = 2, rollUpgrades.rollLuck.maxLevels do
    rollUpgrades.rollLuck.levels[i] = rollUpgrades.rollLuck.levels[i] or math.floor((rollUpgrades.rollLuck.levels[i - 1] and rollUpgrades.rollLuck.levels[i - 1] or 100) * rollUpgrades.rollLuck.priceExp)
end

local BaseUpgrades = {
    floorUpgrades = floorUpgrades,
    floors = floors,
    rollUpgrades = rollUpgrades,
}

function BaseUpgrades.getFloorUpgradePrice(upgradeName: string, level: number, floorHeight: number): number?
    local upgrade = BaseUpgrades.floorUpgrades[upgradeName]
    if not upgrade then return nil end

    if not level or not upgrade.levels[level] then
        return nil
    end

    local price = upgrade.levels[level] * math.floor(floorHeight ^ FLOOR_PRICE_EXP)

    return price
end

function BaseUpgrades.getRollUpgradePrice(upgradeName: string, level: number): number?
	local upgrade = BaseUpgrades.rollUpgrades[upgradeName]
	if not upgrade then
		return nil
	end

	local price = (upgrade.levels and upgrade.levels[level]) or upgrade[level]

	return price
end

return BaseUpgrades