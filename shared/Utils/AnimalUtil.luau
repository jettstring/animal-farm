local ReplicatedStorage = game:GetService("ReplicatedStorage")

--------------------------------------------------
-- DEPENDENCIES -- 
--------------------------------------------------

local Assets = ReplicatedStorage:WaitForChild("Assets")
local AnimalAssets = Assets:WaitForChild("Animals")
local AnimalConfig = require(AnimalAssets:WaitForChild("AnimalConfig"))
local AnimalDefinitions = AnimalConfig.AnimalDefinitions

--------------------------------------------------
-- TYPES -- 
--------------------------------------------------

type AnimalDefinition = AnimalConfig.AnimalDefinition
type MutationDefinition = AnimalConfig.MutationDefinition

local AnimalUtil = {}

function AnimalUtil.rollAnimalResult(luck: number): string
	local luck = math.max(luck or 1, 1)

	local totalOdds = 0
	for animalName, animalDef: AnimalDefinition in AnimalDefinitions do
		local animalOdds = math.clamp(animalDef.odds, 0, 1)
		totalOdds += animalOdds
	end
	
	local roll = math.random() * totalOdds
	local cumulativeWeight = 0
	for animalName, animalDef: AnimalDefinition in AnimalDefinitions do
		cumulativeWeight += math.clamp(animalDef.odds, 0, 1)
		if roll <= cumulativeWeight then
			return animalName
		end
	end
	
	return nil
end

function AnimalUtil.getSortedAnimals(): {string}
	local sorted = {}
	for animalName in AnimalDefinitions do
		table.insert(sorted, animalName)
	end
	table.sort(sorted, function(a, b)
		return AnimalDefinitions[a].odds > AnimalDefinitions[b].odds
	end)

	return sorted
end


AnimalUtil.SortedAnimals = AnimalUtil.getSortedAnimals()


return AnimalUtil
