local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Trove = require(ReplicatedStorage.Packages.Trove)

--------------------------------------------------
-- DEPENDENCIES -- 
--------------------------------------------------

-- Services
local AnimalService = require(ServerScriptService.ServerMain.Services.AnimalService)

local ProfileTemplate = require(ReplicatedStorage.Modules.ProfileTemplate)

-- Utils
local Utils = ReplicatedStorage:FindFirstChild("Utils")
local BaseUtil = require(Utils.BaseUtil)
local AnimalUtil = require(Utils.AnimalUtil)

local Assets = ReplicatedStorage:FindFirstChild("Assets")

-- Base Assets
local BaseAssets = Assets:FindFirstChild("Base")

-- Animal Assets
local AnimalAssets = Assets:WaitForChild("Animals")
local AnimalConfig = require(ReplicatedStorage.Modules.AnimalConfig)
local AnimalDefinitions = AnimalConfig.AnimalDefinitions

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local remotes = {
	BuyAnimalStand = remotesFolder.Base.BuyAnimalStand,
}

-------------------------------------------------
-- TYPES -- 
--------------------------------------------------

type Profile = ProfileTemplate.ProfileTemplate
type StandData = ProfileTemplate.StandData
type AnimalData = ProfileTemplate.AnimalData
type FloorData = ProfileTemplate.FloorData

type AnimalDefinition = AnimalConfig.AnimalDefinition
type AnimalMutation = AnimalConfig.AnimalMutation


--------------------------------------------------
-- MAIN -- 
--------------------------------------------------

local AnimalStand = {}
AnimalStand.__index = AnimalStand


type self = {
	Trove: any,
	Floor: any,
	StandIndex: number,
	StandFolder: Folder,
	StandData: StandData?,
	AnimalModel: Model?,
	ReadyAt: number?,
}

export type AnimalStand = typeof(setmetatable({} :: self, AnimalStand))

function AnimalStand.new(floor: any, standIndex: number, standFolder: Folder, standData: AnimalStand?)
	local self = setmetatable({} :: self, AnimalStand)
	self.Trove = Trove.new()
	
	self.Floor = floor
	self.StandIndex = standIndex
	self.StandFolder = standFolder
	self.StandData = standData
	self.AnimalModel = nil
	
	self.StandThread = nil
	
	self:_Refresh()
	
	return self
end

function AnimalStand._Refresh(self: AnimalStand)
	local standFolder: Folder = self.StandFolder
	local standModel: Model = standFolder.StandModel
	local unlockSign: Model = standFolder.UnlockSign

	local animalModel: Model? = self.AnimalModel
	local standData: StandData? = self.StandData

	local unlocked = standData.unlocked
	standFolder:SetAttribute("Active", unlocked)

	BaseUtil.showInstance(standModel, unlocked)
	BaseUtil.showInstance(unlockSign, not unlocked)

	-- unlock cost
	local unlockCost: number = BaseUtil.getStandCost(self.Floor.FloorIndex)
	standFolder:SetAttribute("UnlockCost", unlockCost)

	-- update animal attributes 
	local animalData: AnimalData? = unlocked and standData.occupant

	if animalData then
		if not self.ReadyAt then
			self:StartGrowing()
		end
	else
		self.ReadyAt = nil
	end

	standFolder:SetAttribute("DefinitionKey", (animalData and animalData.definitionKey) or nil)
	standFolder:SetAttribute("Mutation", (animalData and animalData.mutation) or nil)
	standFolder:SetAttribute("Level", (animalData and animalData.level) or nil)
	standFolder:SetAttribute("EggEarnings", self:GetEggEarnings())
	standFolder:SetAttribute("EggGrowTime", self:GetEggGrowTime())
	standFolder:SetAttribute("EggReadyAt", (animalData and self.ReadyAt) or nil)
end


--------------------------------------------------
-- ACTIONS -- 
--------------------------------------------------

function AnimalStand.AddAnimal(self: AnimalStand, animalData: AnimalData): (boolean, string?)
	local standData: StandData = self.StandData
	if not standData.unlocked then
		warn("[AddAnimal] stand not unlocked")
		return false, "Stand Locked"
	end
	
	local occupant: AnimalData = standData.occupant
	if occupant then
		warn("[AddAnimal] stand already occupied")
		return nil, "Already Occupied"
	end
	
	-- validate animalData
	if not animalData or not animalData.definitionKey then
		warn("[AddAnimal] invalid animalData: ", animalData)
		return nil, "Invalid AnimalData"
	end
	
	standData.occupant = {
		definitionKey = animalData.definitionKey,
		level = animalData.level or 1,
		mutation = animalData.mutation or nil,
	}
	
	self:_Refresh()
	return true
end

function AnimalStand.RemoveAnimal(self: AnimalStand): boolean
	local owner: Player = self.Floor.Base.Owner
	
	local standData: StandData = self.StandData
	if not standData.unlocked then
		warn("[RemoveAnimal] stand not unlocked")
		return false
	end

	local occupant: AnimalData = standData.occupant
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
	standData.occupant = nil
	self:_Refresh()
	
	return true
end

function AnimalStand.LevelAnimal(self: AnimalStand, levels: number): boolean
	if typeof(levels) ~= "number" then 
		warn("[LevelAnimal] invalid levels passed: ", levels)
		return nil
	end
	levels = math.round(math.max(levels, 1))
	
	local standData: StandData = self.StandData
	if not standData.unlocked then
		warn("[LevelAnimal] stand not unlocked")
		return nil
	end
	
	local occupant: AnimalData = standData.occupant
	if not occupant then
		warn("[LevelAnimal] stand not occupied")
		return nil
	end
	
	occupant.level = occupant.level + levels
	self:_Refresh()
	
	return true
end

function AnimalStand.CollectEgg(self: AnimalStand)
	local earnings = self:GetEggEarnings()
	if not earnings then warn("[CollectEgg] could not get egg earnings") return end
	
	self:StartGrowing()
	self:_Refresh()
	
	local floorIndex = self.Floor.FloorIndex
	local travelTime = BaseUtil.getConveyorTravelTime(floorIndex, self.StandIndex) 
	self.Trove:Add(task.delay(travelTime, function()
		self.Floor.Base:IncrementCrateValue(earnings)
	end))
end

function AnimalStand.StartGrowing(self: AnimalStand)
	self.ReadyAt = workspace:GetServerTimeNow() + self:GetEggGrowTime()
end

function AnimalStand.Unlock(self: AnimalStand)
	local standData: StandData = self.StandData
	standData.unlocked = true

	-- fire owner for reveal
	local owner: Player = self.Floor.Base.Owner
	remotes.BuyAnimalStand:FireClient(owner, self.StandIndex)

	-- activate
	self.Trove:Add(task.delay(3, function()
		self:_Refresh()
	end))

	return true
end


function AnimalStand.Destroy(self: AnimalStand)
	self.Trove:Destroy()
	
	-- clear attributes
	for attributeName, _ in self.StandFolder:GetAttributes() do
		self.StandFolder:SetAttribute(attributeName, nil)
	end
end


--------------------------------------------------
-- HELPERS -- 
--------------------------------------------------

function AnimalStand.IsEggReady(self: AnimalStand, now: number): boolean
	return self.ReadyAt and now >= self.ReadyAt
end

function AnimalStand.GetEggEarnings(self: AnimalStand): number
	local standData: StandData? = self.StandData
	local occupant = standData and standData.occupant
	if not occupant or not occupant.definitionKey then return nil end

	local animalDef: AnimalDefinition = AnimalDefinitions[occupant.definitionKey]
	if not animalDef then return nil end
	
	local earnings = 0

	local baseEarnings = animalDef.eggEarnings
	if not baseEarnings then
		warn("[GetEggEarnings] invalid baseEarnings: ", animalDef)
		return nil
	end
	
	earnings += baseEarnings
	
	return earnings
end


function AnimalStand.GetEggGrowTime(self: AnimalStand): number
	local standData: StandData? = self.StandData
	local occupant = standData and standData.occupant
	if not occupant or not occupant.definitionKey then return nil end
	
	local animalDef: AnimalDefinition = AnimalDefinitions[occupant.definitionKey]
	if not animalDef then return nil end
	
	local baseTime = animalDef.eggGrowTime
	if not baseTime then
		warn("[GetEggGrowTime] invalid eggGrowTime: ", animalDef)
		return nil
	end
	
	-- TODO: get floor egg regen upgrade multiplier
	
	return baseTime
end


return AnimalStand
