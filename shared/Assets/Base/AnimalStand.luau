local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Trove = require(ReplicatedStorage.Packages.Trove)

--------------------------------------------------
-- DEPENDENCIES -- 
--------------------------------------------------

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
local AnimalConfig = require(AnimalAssets:WaitForChild("AnimalConfig"))
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
	Services: any,
	Floor: any,
	StandIndex: number,
	StandFolder: Folder,
	StandData: StandData?,
	AnimalModel: Model?,
	
}

export type AnimalStand = typeof(setmetatable({} :: self, AnimalStand))

function AnimalStand.new(floor: any, standIndex: number, standFolder: Folder, standData: AnimalStand?, services: any)
	local self = setmetatable({} :: self, AnimalStand)
	self.Services = services
	self.Trove = Trove.new()
	
	self.Floor = floor
	self.StandIndex = standIndex
	self.StandFolder = standFolder
	self.StandData = standData
	self.AnimalModel = nil
	
	self:_Refresh()
	
	return self
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
	standFolder:SetAttribute("DefinitionKey", (animalData and animalData.definitionKey) or nil)
	standFolder:SetAttribute("Mutation", (animalData and animalData.mutation) or nil)
	standFolder:SetAttribute("Level", (animalData and animalData.level) or nil)
	
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

return AnimalStand
