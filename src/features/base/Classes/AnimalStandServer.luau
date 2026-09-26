local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)

--------------------------------------------------
-- DEPENDENCIES --
--------------------------------------------------

-- Services

local Scribe = require(ReplicatedStorage.Packages.Scribe)
local Data = require(ReplicatedStorage.Source.Game.Data).Server
local DataTemplate = require(ReplicatedStorage.Source.Game.DataTemplate)
local AnimalService = require(ServerScriptService.Features.Animal.AnimalServiceServer)
local BaseServiceUtils = require(ReplicatedStorage.Source.Features.Base.BaseServiceUtils)
local AnimalConfig = require(ReplicatedStorage.Source.Features.Animal.AnimalConfig)
local AnimalDefinitions = AnimalConfig.AnimalDefinitions

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local remotes = {
	BuyAnimalStand = remotesFolder.Base.BuyAnimalStand,
}

-------------------------------------------------
-- TYPES --
--------------------------------------------------

type AnimalData = DataTemplate.AnimalData
type FloorData = DataTemplate.FloorData

type AnimalDefinition = AnimalConfig.AnimalDefinition
type AnimalMutation = AnimalConfig.AnimalMutation

--------------------------------------------------
-- MAIN --
--------------------------------------------------

local AnimalStandServer = {}
AnimalStandServer.__index = AnimalStandServer

type self = {
	Trove: Trove.Trove,
	Owner: Player,
	FloorIndex: number,
	StandIndex: number,
	StandFolder: Folder,
	StandData: Scribe.PlayerData<DataTemplate.StandData>,
	AnimalModel: Model?,
	ReadyAt: number?,
}
	
export type AnimalStandServer = typeof(setmetatable({} :: self, AnimalStandServer))


function AnimalStandServer.new(owner: Player, floorIndex: number, standIndex: number, standFolder: Folder, standData: Scribe.PlayerData<DataTemplate.StandData>)
	local self = setmetatable({} :: self, AnimalStandServer)
	
	self.Trove = Trove.new()
	self.Owner = owner
	self.FloorIndex = floorIndex
	self.StandIndex = standIndex
	self.StandFolder = standFolder
	self.StandData = standData
	self.AnimalModel = nil

	self.StandThread = nil

	self:_Refresh()

	return self
end

function AnimalStandServer._Refresh(self: AnimalStandServer)
	local standFolder: Folder = self.StandFolder
	local standModel: Model = standFolder.StandModel
	local unlockSign: Model = standFolder.UnlockSign

	local unlocked = self.StandData.unlocked.Get() == true
	local occupant = unlocked and self.StandData.occupant.Get() or nil

	BaseServiceUtils.showInstance(standModel, unlocked)
	BaseServiceUtils.showInstance(unlockSign, not unlocked)

	if occupant then
		if not self.ReadyAt then
			self:StartGrowing()
		end
	else
		self.ReadyAt = nil
	end

	standFolder:SetAttribute("Active", unlocked)
	standFolder:SetAttribute("UnlockCost", BaseServiceUtils.getStandCost(self.FloorIndex))
	standFolder:SetAttribute("DefinitionKey", occupant and occupant.definitionKey or nil)
	standFolder:SetAttribute("Mutation", occupant and occupant.mutation or nil)
	standFolder:SetAttribute("Level", occupant and occupant.level or nil)
	standFolder:SetAttribute("EggReadyAt", occupant and self.ReadyAt or nil)
	standFolder:SetAttribute("EggEarnings", self:GetEggEarnings())
	standFolder:SetAttribute("EggGrowTime", self:GetEggGrowTime())
end

--------------------------------------------------
-- ACTIONS --
--------------------------------------------------

function AnimalStandServer.AddAnimal(self: AnimalStandServer, animalData: AnimalData): (boolean, string?)
	if not self:isUnlocked() then
		warn("[AddAnimal] stand not unlocked")
		return false, "Stand Locked"
	end

	local occupant = self.StandData.occupant.Get()
	if occupant then
		warn("[AddAnimal] stand already occupied")
		return nil, "Already Occupied"
	end

	-- validate animalData
	if not animalData or not animalData.definitionKey then
		warn("[AddAnimal] invalid animalData: ", animalData)
		return nil, "Invalid AnimalData"
	end

	self.StandData.occupant.Set({
		definitionKey = animalData.definitionKey,
		level = animalData.level or 1,
		mutation = animalData.mutation or nil,
	})

	self:_Refresh()
	return true
end

function AnimalStandServer.RemoveAnimal(self: AnimalStandServer): boolean
	local owner: Player = self.Owner

	local standData = self.StandData
	if not self:isUnlocked() then
		warn("[RemoveAnimal] stand not unlocked")
		return false
	end

	local occupant = self.StandData.occupant.Get()
	if not occupant then
		warn("[RemoveAnimal] stand not occupied")
		return nil
	end

	-- validate occupant animalData
	if not occupant.definitionKey then
		warn("[RemoveAnimal] invalid occupant animalData: ", occupant)
		return nil
	end

	local success = AnimalService:GiveAnimal(owner, occupant)
	if not success then
		warn("[RemoveAnimal] failed to give animal ", occupant)
		return false
	end

	-- remove occupant
	self.StandData.occupant.Set(nil)
	self:_Refresh()

	return true
end

function AnimalStandServer.LevelAnimal(self: AnimalStandServer, levels: number): boolean
	if typeof(levels) ~= "number" then
		warn("[LevelAnimal] invalid levels passed: ", levels)
		return nil
	end
	levels = math.round(math.max(levels, 1))

	local standData = self.StandData
	if not self:isUnlocked() then
		warn("[LevelAnimal] stand not unlocked")
		return nil
	end

	local occupant = standData.occupant.Get()
	if not occupant then
		warn("[LevelAnimal] stand not occupied")
		return nil
	end

	standData.occupant.level.Set(occupant.level + levels)
	self:_Refresh()

	return true
end

function AnimalStandServer.CollectEgg(self: AnimalStandServer): number?
	local earnings = self:GetEggEarnings()
	self:StartGrowing()
	self:_Refresh()
	return earnings
end

function AnimalStandServer.StartGrowing(self: AnimalStandServer)
	self.ReadyAt = workspace:GetServerTimeNow() + self:GetEggGrowTime()
end

function AnimalStandServer.Unlock(self: AnimalStandServer)
	self.StandData.unlocked.Set(true)

	-- fire owner for reveal
	remotes.BuyAnimalStand:FireClient(self.Owner, self.StandIndex)

	-- activate
	self.Trove:Add(task.delay(3, function()
		self:_Refresh()
	end))

	return true
end

function AnimalStandServer.Destroy(self: AnimalStandServer)
	self.Trove:Destroy()

	-- clear attributes
	for attributeName, _ in self.StandFolder:GetAttributes() do
		self.StandFolder:SetAttribute(attributeName, nil)
	end
end

--------------------------------------------------
-- HELPERS --
--------------------------------------------------

function AnimalStandServer.isUnlocked(self: AnimalStandServer): boolean
	return self.StandData.unlocked.Get()
end

function AnimalStandServer.GetOccupant(self: AnimalStandServer)
	return self.StandData.occupant.Get()
end

function AnimalStandServer.IsEggReady(self: AnimalStandServer, now: number): boolean
	return self.ReadyAt and now >= self.ReadyAt
end

function AnimalStandServer.GetEggEarnings(self: AnimalStandServer): number
	local occupant = self.StandData.occupant.Get()
	if not occupant or not occupant.definitionKey then
		return nil
	end

	local animalDef: AnimalDefinition = AnimalDefinitions[occupant.definitionKey]
	if not animalDef then
		return nil
	end

	local earnings = 0

	local baseEarnings = animalDef.eggEarnings
	if not baseEarnings then
		warn("[GetEggEarnings] invalid baseEarnings: ", animalDef)
		return nil
	end

	earnings += baseEarnings

	return earnings
end

function AnimalStandServer.GetEggGrowTime(self: AnimalStandServer): number
	local occupant = self.StandData.occupant.Get()
	if not occupant or not occupant.definitionKey then
		return nil
	end

	local animalDef: AnimalDefinition = AnimalDefinitions[occupant.definitionKey]
	if not animalDef then
		return nil
	end

	local baseTime = animalDef.eggGrowTime
	if not baseTime then
		warn("[GetEggGrowTime] invalid eggGrowTime: ", animalDef)
		return nil
	end

	-- TODO: get floor egg regen upgrade multiplier

	return baseTime
end

return AnimalStandServer
