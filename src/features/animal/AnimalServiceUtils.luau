local ReplicatedStorage = game:GetService("ReplicatedStorage")

--------------------------------------------------
-- DEPENDENCIES --
--------------------------------------------------

local ProfileTemplate = require(ReplicatedStorage.Source.Features.Data.ProfileTemplate)
local Rarities = require(ReplicatedStorage.Source.Features.Animal.Modules.Rarities)

local Assets = ReplicatedStorage:WaitForChild("Assets")
local AnimalAssets = Assets:WaitForChild("Animals")
local AnimalConfig = require(ReplicatedStorage.Source.Features.Animal.AnimalConfig)
local AnimalDefinitions = AnimalConfig.AnimalDefinitions
local AnimalModels = AnimalAssets.AnimalModels
local EggModels = AnimalAssets.EggModels

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

function AnimalUtil.getAnimalData(animalKey: string): AnimalData
	local split = string.split(animalKey, "_")
	assert(#split == 2 or #split == 3, `malformed animal key: "{animalKey}"`)

	return {
		definitionKey = split[1],
		level = tonumber(split[2]),
		mutation = split[3],
	}
end

function AnimalUtil.generateAnimalKey(animalData: AnimalData): string?
	local definitionKey = animalData.definitionKey
	if not definitionKey or not AnimalDefinitions[definitionKey] then
		warn("[generateAnimalKey] invalid definitionKey:", definitionKey)
		return nil
	end

	local level = animalData.level or 1
	local key = definitionKey .. "_" .. level
	if animalData.mutation then
		key = key .. "_" .. animalData.mutation
	end

	return key
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

function AnimalUtil.getAnimalDefinitionFromData(animalData: AnimalData): AnimalDefinition?
	local defKey = animalData.definitionKey
	if not defKey then
		warn("[getAnimalDefinition] invalid animalData: ", animalData)
		return nil
	end

	local animalDef = AnimalDefinitions[defKey]
	if not animalDef then
		warn("[getAnimalDefinition] missing animal definition for: ", defKey)
		return nil
	end

	return animalDef
end

function AnimalUtil.getEggModel(animalData: AnimalData): Model
	local defKey = animalData.definitionKey
	local animalDef = defKey and AnimalDefinitions[animalData.definitionKey]
	if not animalDef then
		warn("[getEggModel] invalid animalData: ", animalData)
		return nil
	end

	local baseModel: Model = EggModels:FindFirstChild(defKey)
	if not baseModel then
		warn("[getEggModel] missing animal model for: ", defKey)
		return nil
	end

	local clone = baseModel:Clone()

	-- TODO: apply mutation effects

	return clone
end

function AnimalUtil.getRandomAnimalKey(restrictToRollable: boolean?): string?
	local animalKeys = {}
	for defKey, animalDef in AnimalDefinitions do
		if restrictToRollable and animalDef.nonRollable then
			continue
		end
		table.insert(animalKeys, defKey)
	end

	if #animalKeys == 0 then
		warn("[getRandomAnimalKey] no animals available to roll")
		return nil
	end

	return animalKeys[math.random(1, #animalKeys)]
end

function AnimalUtil.resolveRarityInfo(defKey: string): Rarities.RarityInfo?
	local animalDef = AnimalDefinitions[defKey]
	if not animalDef then
		warn("[resolveRarity] missing animal definition for: ", defKey)
		return nil
	end

	if animalDef.rarity then
		return Rarities.getRarityInfo(animalDef.rarity)
	end

	return Rarities.getRarityForOdds(animalDef.odds)
end



function AnimalUtil.getLevelCost(definitionKey: AnimalData, level: number): number
	local animalDef: AnimalDefinition = AnimalDefinitions[definitionKey]
	if not animalDef then
		warn("[getLevelCost] invalid definitionKey:", definitionKey)
		return nil
	end

	local earningsPerEgg = animalDef.eggEarnings

	return math.round(earningsPerEgg * level ^ 1.2)
end

function AnimalUtil.getLevelUpCost(definitionKey: string, fromLevel: number, count: number): number
	local total = 0
	for i = 0, count - 1 do
		total += AnimalUtil.getLevelCost(definitionKey, fromLevel + i)
	end
	return total
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

function AnimalUtil.getSortedAnimals(): { string }
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
