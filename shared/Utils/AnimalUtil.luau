local ReplicatedStorage = game:GetService("ReplicatedStorage")

--------------------------------------------------
-- DEPENDENCIES -- 
--------------------------------------------------

local ProfileTemplate = require(ReplicatedStorage.Modules.ProfileTemplate)

local Assets = ReplicatedStorage:WaitForChild("Assets")
local AnimalAssets = Assets:WaitForChild("Animals")
local AnimalConfig = require(AnimalAssets:WaitForChild("AnimalConfig"))
local AnimalDefinitions = AnimalConfig.AnimalDefinitions
local AnimalModels = AnimalAssets.AnimalModels

--------------------------------------------------
-- TYPES -- 
--------------------------------------------------

type AnimalDefinition = AnimalConfig.AnimalDefinition
type MutationDefinition = AnimalConfig.MutationDefinition

type Profile = ProfileTemplate.ProfileTemplate
type AnimalData = ProfileTemplate.AnimalData

local AnimalUtil = {}

function AnimalUtil.isStack(animalKey: string): boolean
	return string.sub(animalKey, 1, 1) ~= "."
end

function AnimalUtil.getAnimalData(animalKey: string, value: AnimalData | number): AnimalData
	local split = string.split(animalKey, "_")
	assert(#split == 3, `malformed animal key: "{animalKey}"`)
	
	return {
		definitionKey = split[1],
		level = split[2],
		mutation = split[3]
	}
end

function AnimalUtil.generateAnimalKey(animalData: AnimalData): string
	local newKey = animalData.definitionKey .. "_" .. animalData.level .. "_" .. animalData.mutation
	return newKey
end


function AnimalUtil.getAnimalModel(animalData: AnimalData): Model
	local defKey = animalData.definitionKey
	local animalDef = defKey and AnimalDefinitions[animalData.definitionKey]
	if not animalDef then
		warn("[getAnimalModel] invalid animalData: ", animalData)
		return nil
	end
	
	local baseModel: Model = AnimalModels:FindFirstChild(defKey)
	if not baseModel then
		warn("[getAnimalModel] missing animal model for: ", defKey)
		return nil
	end
	
	local clone = baseModel:Clone()
	
	-- TODO: apply mutation effects
	
	return clone
end

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
